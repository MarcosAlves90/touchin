"""Public password recovery with one-use expiring tokens."""

from __future__ import annotations

from datetime import timedelta
from sqlalchemy import delete, select, text, update
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import begin_serialized_write, utcnow
from app.domain.auth_read import display_name_for_user
from app.errors import DomainError, ErrorKind
from app.models import AuthSession, Company, PasswordResetThrottle, PasswordResetToken, UserAccount
from app.security import hash_password, issue_bearer_token

TOKEN_TTL = timedelta(minutes=30)
EMAIL_ATTEMPTS_PER_HOUR = 3
IP_ATTEMPTS_PER_HOUR = 30
INVALID_TOKEN_MESSAGE = "Invalid or expired reset token."


def _token_digest(token: str) -> str:
    return lookup_digest(f"password-reset:{token}", get_settings().token_secret or "")


def _consume_rate_limit(db: Session, *, scope: str, identifier: str, limit: int, now) -> bool:
    hour = int(now.timestamp()) // 3600
    digest = lookup_digest(
        f"password-reset-rate:{scope}:{identifier}:{hour}",
        get_settings().token_secret or "",
    )
    result = db.execute(
        text(
            "INSERT INTO password_reset_throttles "
            "(bucket_hash, bucket_hour, attempts, updated_at) "
            "VALUES (:digest, :hour, 1, :now) "
            "ON CONFLICT (bucket_hash) DO UPDATE "
            "SET attempts = password_reset_throttles.attempts + 1, "
            "updated_at = :now "
            "WHERE password_reset_throttles.attempts < :limit"
        ),
        {"digest": digest, "hour": hour, "now": now, "limit": limit},
    )
    return result.rowcount == 1


def request_password_reset(
    db: Session, *, email: str, client_ip: str
) -> tuple[str, str, str] | None:
    """Return a private email job or None; always use a uniform public response."""
    settings = get_settings()
    now = utcnow()
    normalized_email = email.strip().lower()
    email_digest = lookup_digest(normalized_email, settings.encryption_secret or "")

    if not settings.password_reset_url:
        return None

    begin_serialized_write(db)
    ip_allowed = _consume_rate_limit(
        db, scope="ip", identifier=client_ip, limit=IP_ATTEMPTS_PER_HOUR, now=now
    )
    if not ip_allowed:
        db.commit()
        return None
    email_allowed = _consume_rate_limit(
        db, scope="email", identifier=normalized_email,
        limit=EMAIL_ATTEMPTS_PER_HOUR, now=now,
    )
    if not email_allowed:
        db.commit()
        return None

    # PostgreSQL row lock protects issuance against concurrent completion.
    user = db.scalar(
        select(UserAccount).where(UserAccount.email_hash == email_digest).with_for_update()
    )
    company = db.get(Company, user.company_id) if user is not None else None
    if user is None or not user.is_active or company is None or not company.is_active:
        db.commit()
        return None

    db.execute(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.consumed_at.is_(None))
        .values(consumed_at=now)
    )
    token = issue_bearer_token()
    db.add(PasswordResetToken(
        user_id=user.id,
        token_hash=_token_digest(token),
        created_at=now,
        expires_at=now + TOKEN_TTL,
    ))
    db.execute(delete(PasswordResetThrottle).where(
        PasswordResetThrottle.bucket_hour < int(now.timestamp()) // 3600 - 48
    ))
    db.execute(delete(PasswordResetToken).where(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.expires_at < now - timedelta(days=7)
    ))
    cipher = FieldCipher(settings.encryption_secret or "")
    recipient = cipher.decrypt(user.email_ciphertext)
    display_name = display_name_for_user(db, user=user, field_cipher=cipher)
    db.commit()
    return recipient or normalized_email, display_name, token


def confirm_password_reset(
    db: Session, *, token: str, new_password: str, client_ip: str
) -> None:
    now = utcnow()
    begin_serialized_write(db)
    if not _consume_rate_limit(
        db, scope="confirm-ip", identifier=client_ip,
        limit=IP_ATTEMPTS_PER_HOUR, now=now,
    ):
        db.commit()
        raise DomainError(ErrorKind.bad_request, INVALID_TOKEN_MESSAGE)

    token_row = db.scalar(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == _token_digest(token))
    )
    if token_row is None:
        db.commit()
        raise DomainError(ErrorKind.bad_request, INVALID_TOKEN_MESSAGE)

    user = db.scalar(
        select(UserAccount).where(UserAccount.id == token_row.user_id).with_for_update()
    )
    company = db.get(Company, user.company_id) if user is not None else None
    if user is None or not user.is_active or company is None or not company.is_active:
        db.commit()
        raise DomainError(ErrorKind.bad_request, INVALID_TOKEN_MESSAGE)

    # Conditional claim commits with the password update, never separately.
    claimed = db.execute(
        update(PasswordResetToken)
        .where(
            PasswordResetToken.id == token_row.id,
            PasswordResetToken.consumed_at.is_(None),
            PasswordResetToken.expires_at > now,
        )
        .values(consumed_at=now)
        .execution_options(synchronize_session=False)
    )
    if claimed.rowcount != 1:
        db.commit()
        raise DomainError(ErrorKind.bad_request, INVALID_TOKEN_MESSAGE)

    user.password_hash = hash_password(new_password)
    user.must_change_password = False
    db.execute(
        update(AuthSession)
        .where(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    db.execute(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.consumed_at.is_(None))
        .values(consumed_at=now)
    )
    db.commit()
