from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from sqlalchemy import delete, or_, select, text, update
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.domain.auth_read import (
    auth_context_response,
    display_name_for_user,
    ensure_accounts_active,
    resolve_context as resolve_auth_context,
    resolve_user,
    summarize_company as _summarize_company,
)
from app.domain.auth_session import build_auth_response, issue_session
from app.domain.identity import normalize_email as _normalize_email
from app.db import begin_serialized_write, utcnow
from app.errors import DomainError, ErrorKind
from app.models import (
    AuthSession,
    Company,
    Employee,
    LoginAttemptThrottle,
    PasswordResetToken,
    UserAccount,
)
from app.schemas.auth import (
    AuthContextResponse,
    AuthSessionResponse,
    CompanyRegisterRequest,
    LoginRequest,
)
from app.security import hash_password, verify_password
from app.services.brevo import send_company_welcome_email

LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR = 5
LOGIN_SOURCE_MAX_ATTEMPTS_PER_HOUR = 100
LOGIN_RATE_LIMIT_MESSAGE = "Too many login attempts. Please try again later."


@dataclass(slots=True)
class AuthenticatedContext:
    session: AuthSession
    user: UserAccount
    company: Company
    employee: Employee | None


def _cipher() -> FieldCipher:
    settings = get_settings()
    return FieldCipher(settings.encryption_secret or "")


def _resolve_user(db: Session, email: str) -> tuple[UserAccount | None, str, str]:
    return resolve_user(db, email)


def _ensure_accounts_active(user: UserAccount, company: Company) -> None:
    ensure_accounts_active(user, company)


def normalize_email(value: str) -> str:
    return _normalize_email(value)


def digits_only(value: str) -> str:
    return "".join(character for character in value if character.isdigit())


def mask_email(value: str) -> str:
    local_part, domain = value.split("@", 1)
    visible = local_part[:2]
    hidden = "*" * max(len(local_part) - 2, 1)
    return f"{visible}{hidden}@{domain}"


def mask_phone(value: str) -> str:
    digits = digits_only(value)
    if len(digits) < 4:
        return "*" * len(digits)
    return f"{digits[:2]}*****{digits[-4:]}"


def mask_cnpj(value: str) -> str:
    digits = digits_only(value)
    return f"{digits[:2]}.***.***/****-{digits[-2:]}"


def _login_bucket_key(scope: str, identifier: str, now: datetime) -> tuple[str, int]:
    hour = int(now.timestamp()) // 3600
    digest = lookup_digest(
        f"login-rate:{scope}:{identifier}:{hour}",
        get_settings().token_secret or "",
    )
    return digest, hour


def _consume_login_bucket(
    db: Session,
    *,
    scope: str,
    identifier: str,
    now: datetime,
    limit: int,
) -> tuple[str, int, bool]:
    digest, hour = _login_bucket_key(scope, identifier, now)
    result = db.execute(
        text(
            "INSERT INTO login_attempt_throttles "
            "(bucket_hash, bucket_hour, attempts, updated_at) "
            "VALUES (:digest, :hour, 1, :now) "
            "ON CONFLICT (bucket_hash) DO UPDATE "
            "SET attempts = login_attempt_throttles.attempts + 1, "
            "updated_at = :now "
            "WHERE login_attempt_throttles.attempts < :limit"
        ),
        {"digest": digest, "hour": hour, "now": now, "limit": limit},
    )
    return digest, hour, result.rowcount == 1


def _lock_login_bucket(
    db: Session,
    *,
    scope: str,
    identifier: str,
    now: datetime,
) -> tuple[str, int, int]:
    digest, hour = _login_bucket_key(scope, identifier, now)
    db.execute(
        text(
            "INSERT INTO login_attempt_throttles "
            "(bucket_hash, bucket_hour, attempts, updated_at) "
            "VALUES (:digest, :hour, 0, :now) "
            "ON CONFLICT (bucket_hash) DO NOTHING"
        ),
        {"digest": digest, "hour": hour, "now": now},
    )
    statement = select(LoginAttemptThrottle.attempts).where(
        LoginAttemptThrottle.bucket_hash == digest
    )
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        statement = statement.with_for_update()
    attempts = db.scalar(statement) or 0
    return digest, hour, attempts


def summarize_company(company: Company, cipher: FieldCipher | None = None) -> CompanySummary:
    return _summarize_company(company, cipher)


def _display_name_for_user(
    db: Session,
    *,
    user: UserAccount,
    cipher: FieldCipher,
) -> str:
    return display_name_for_user(db, user=user, field_cipher=cipher)


def register_company(
    db: Session,
    payload: CompanyRegisterRequest,
    *,
    send_welcome_email: bool = True,
) -> AuthSessionResponse:
    settings = get_settings()
    cipher = _cipher()
    normalized_email = normalize_email(str(payload.email))
    normalized_cnpj = digits_only(payload.cnpj)
    email_hash = lookup_digest(normalized_email, settings.encryption_secret or "")
    cnpj_hash = lookup_digest(normalized_cnpj, settings.encryption_secret or "")

    existing_company = db.scalar(
        select(Company).where(
            or_(
                Company.cnpj_hash == cnpj_hash,
                Company.contact_email_hash == email_hash,
            ),
        ),
    )
    if existing_company is not None:
        raise DomainError(
            ErrorKind.conflict,
            "A company with this CNPJ or contact email already exists.",
        )

    existing_user = db.scalar(
        select(UserAccount).where(UserAccount.email_hash == email_hash),
    )
    if existing_user is not None:
        raise DomainError(ErrorKind.conflict, "A user with this email already exists.")

    company = Company(
        legal_name_ciphertext=cipher.encrypt(payload.company_name) or "",
        trade_name_ciphertext=cipher.encrypt(payload.trade_name) or "",
        cnpj_ciphertext=cipher.encrypt(normalized_cnpj) or "",
        cnpj_hash=cnpj_hash,
        contact_email_ciphertext=cipher.encrypt(normalized_email) or "",
        contact_email_hash=email_hash,
        contact_phone_ciphertext=cipher.encrypt(payload.phone) or "",
        consented_at=utcnow(),
        timezone=settings.timezone,
    )
    user = UserAccount(
        company=company,
        email_ciphertext=cipher.encrypt(normalized_email) or "",
        email_hash=email_hash,
        password_hash=hash_password(payload.password),
        role="admin",
    )
    db.add_all([company, user])
    token, auth_session = issue_session(db, user=user, keep_connected=True)
    db.commit()
    db.refresh(company)
    db.refresh(user)
    db.refresh(auth_session)
    if send_welcome_email:
        send_company_welcome_email(
            recipient_email=normalized_email,
            company_name=payload.company_name,
            trade_name=payload.trade_name,
        )
    return build_auth_response(token, auth_session, user, company, cipher)


def login(
    db: Session,
    payload: LoginRequest,
    *,
    client_ip: str = "unknown",
) -> AuthSessionResponse:
    cipher = _cipher()
    now = utcnow()
    normalized_email = normalize_email(str(payload.email))
    # Credential verification and creation of the resulting AuthSession must
    # hold the same user lock used by password reset and password change.
    # Otherwise a stale login can commit a valid session after reset revoked
    # every session that existed at its commit.
    begin_serialized_write(db)

    _, _, source_allowed = _consume_login_bucket(
        db,
        scope="source",
        identifier=client_ip or "unknown",
        now=now,
        limit=LOGIN_SOURCE_MAX_ATTEMPTS_PER_HOUR,
    )
    if not source_allowed:
        db.commit()
        raise DomainError(ErrorKind.too_many_requests, LOGIN_RATE_LIMIT_MESSAGE)

    account_digest, account_hour, account_attempts = _lock_login_bucket(
        db,
        scope="account",
        identifier=normalized_email,
        now=now,
    )
    if account_attempts >= LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR:
        db.commit()
        raise DomainError(ErrorKind.too_many_requests, LOGIN_RATE_LIMIT_MESSAGE)

    user, _, _ = _resolve_user(db, str(payload.email))
    if user is not None:
        user = db.scalar(
            select(UserAccount).where(UserAccount.id == user.id)
            .with_for_update().execution_options(populate_existing=True)
        )
    if user is None or not verify_password(payload.password, user.password_hash):
        _, _, account_allowed = _consume_login_bucket(
            db,
            scope="account",
            identifier=normalized_email,
            now=now,
            limit=LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR,
        )
        db.execute(
            delete(LoginAttemptThrottle).where(
                LoginAttemptThrottle.bucket_hour < account_hour - 48
            )
        )
        db.commit()
        if not account_allowed:
            raise DomainError(ErrorKind.too_many_requests, LOGIN_RATE_LIMIT_MESSAGE)
        raise DomainError(ErrorKind.unauthorized, "Invalid email or password.")

    company = db.get(Company, user.company_id)
    if company is None:
        db.commit()
        raise DomainError(ErrorKind.forbidden, "The company account is inactive.")
    try:
        _ensure_accounts_active(user, company)
    except DomainError:
        db.commit()
        raise

    user.last_login_at = now
    db.execute(
        delete(LoginAttemptThrottle).where(
            LoginAttemptThrottle.bucket_hash == account_digest
        )
    )
    token, auth_session = issue_session(
        db,
        user=user,
        keep_connected=payload.keep_connected,
    )
    db.commit()
    db.refresh(auth_session)
    return build_auth_response(token, auth_session, user, company, cipher)


def change_password(
    db: Session,
    *,
    context: AuthenticatedContext,
    current_password: str,
    new_password: str,
) -> tuple[str, str]:
    cipher = _cipher()
    begin_serialized_write(db)
    user = db.scalar(select(UserAccount).where(UserAccount.id == context.user.id).with_for_update())
    if user is None:
        raise DomainError(ErrorKind.unauthorized, "Invalid session.")
    db.refresh(user)
    if not verify_password(current_password, user.password_hash):
        raise DomainError(ErrorKind.unauthorized, "Invalid password.")

    user.password_hash = hash_password(new_password)
    user.must_change_password = False
    _revoke_active_sessions(db, user_id=user.id)
    db.execute(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.consumed_at.is_(None))
        .values(consumed_at=utcnow())
    )
    db.commit()

    recipient_email = cipher.decrypt(user.email_ciphertext) or ""
    display_name = _display_name_for_user(db, user=user, cipher=cipher)
    return recipient_email, display_name


def resolve_context(db: Session, token: str) -> AuthenticatedContext:
    session, user, company, employee = resolve_auth_context(db, token)
    return AuthenticatedContext(
        session=session,
        user=user,
        company=company,
        employee=employee,
    )


def get_auth_context(context: AuthenticatedContext) -> AuthContextResponse:
    return auth_context_response(context.user, context.company)


def logout(db: Session, context: AuthenticatedContext) -> None:
    context.session.revoked_at = utcnow()
    db.commit()


def _revoke_active_sessions(db: Session, *, user_id: str) -> None:
    db.execute(
        update(AuthSession)
        .where(
            AuthSession.user_id == user_id,
            AuthSession.revoked_at.is_(None),
        )
        .values(revoked_at=utcnow())
    )
