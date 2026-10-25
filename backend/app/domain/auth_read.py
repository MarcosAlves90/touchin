from __future__ import annotations

from datetime import timedelta

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import ensure_utc, utcnow
from app.domain.identity import normalize_email as _normalize_email
from app.errors import DomainError, ErrorKind
from app.models import AuthSession, Company, Employee, UserAccount
from app.schemas.auth import AuthContextResponse, CompanySummary, UserSummary

_MSG_COMPANY_INACTIVE = "The company account is inactive."
_LAST_USED_TOUCH_INTERVAL = timedelta(minutes=5)


def cipher() -> FieldCipher:
    settings = get_settings()
    return FieldCipher(settings.encryption_secret or "")


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


def resolve_user(db: Session, email: str) -> tuple[UserAccount | None, str, str]:
    settings = get_settings()
    normalized_email = normalize_email(email)
    email_hash = lookup_digest(normalized_email, settings.encryption_secret or "")
    user = db.scalar(select(UserAccount).where(UserAccount.email_hash == email_hash))
    return user, normalized_email, email_hash


def ensure_accounts_active(user: UserAccount, company: Company) -> None:
    if not user.is_active:
        raise DomainError(ErrorKind.forbidden, "This account is inactive.")
    if not company.is_active:
        raise DomainError(ErrorKind.forbidden, _MSG_COMPANY_INACTIVE)


def summarize_company(company: Company, field_cipher: FieldCipher | None = None) -> CompanySummary:
    if field_cipher is None:
        field_cipher = cipher()
    legal_name = field_cipher.decrypt(company.legal_name_ciphertext) or ""
    trade_name = field_cipher.decrypt(company.trade_name_ciphertext) or ""
    cnpj = field_cipher.decrypt(company.cnpj_ciphertext) or ""
    email = field_cipher.decrypt(company.contact_email_ciphertext) or ""
    phone = field_cipher.decrypt(company.contact_phone_ciphertext) or ""
    return CompanySummary(
        id=company.id,
        legal_name=legal_name,
        trade_name=trade_name,
        cnpj_masked=mask_cnpj(cnpj),
        email_masked=mask_email(email),
        phone_masked=mask_phone(phone),
    )


def user_summary(user: UserAccount, field_cipher: FieldCipher) -> UserSummary:
    return UserSummary(
        id=user.id,
        email=field_cipher.decrypt(user.email_ciphertext) or "",
        role=user.role,
        employee_id=user.employee_id,
    )


def display_name_for_user(
    db: Session,
    *,
    user: UserAccount,
    field_cipher: FieldCipher,
) -> str:
    if user.employee_id:
        employee = db.get(Employee, user.employee_id)
        if employee is not None:
            name = field_cipher.decrypt(employee.name_ciphertext) or ""
            if name.strip():
                return name.strip()
    email = field_cipher.decrypt(user.email_ciphertext) or ""
    return email.strip()


def resolve_context(db: Session, token: str):
    settings = get_settings()
    token_hash = lookup_digest(token, settings.token_secret or "")
    auth_session = db.scalar(select(AuthSession).where(AuthSession.token_hash == token_hash))
    now = utcnow()
    expires_at = ensure_utc(auth_session.expires_at) if auth_session is not None else None
    if auth_session is None or auth_session.revoked_at is not None or expires_at is None or expires_at <= now:
        raise DomainError(ErrorKind.unauthorized, "Invalid or expired access token.")

    user = db.get(UserAccount, auth_session.user_id)
    if user is None or not user.is_active:
        raise DomainError(
            ErrorKind.unauthorized,
            "The account associated with this token is unavailable.",
        )

    company = db.get(Company, user.company_id)
    if company is None or not company.is_active:
        raise DomainError(ErrorKind.unauthorized, _MSG_COMPANY_INACTIVE)

    last_used_at = ensure_utc(auth_session.last_used_at)
    should_touch_session = (
        last_used_at is None
        or now - last_used_at >= _LAST_USED_TOUCH_INTERVAL
    )
    if should_touch_session:
        auth_session.last_used_at = now
        db.commit()
    employee = db.get(Employee, user.employee_id) if user.employee_id else None
    return auth_session, user, company, employee


def auth_context_response(user: UserAccount, company: Company) -> AuthContextResponse:
    field_cipher = cipher()
    return AuthContextResponse(
        company=summarize_company(company, field_cipher),
        user=user_summary(user, field_cipher),
        must_change_password=user.must_change_password,
    )
