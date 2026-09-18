from __future__ import annotations

from datetime import timedelta

import pytest

from app.config import Settings, get_settings
from app.crypto import lookup_digest
from app.db import SessionLocal, ensure_utc, utcnow
from app.models import AuthSession, UserAccount
from app.services.auth import change_password, login, reset_password
from app.services.auth import _resolve_user, _ensure_accounts_active, resolve_context
from app.schemas.auth import LoginRequest


def test_resolve_user_returns_user_and_email_hash(client):
    with SessionLocal() as db:
        user, _, _ = _resolve_user(db, email="marina.costa@touchin.com")
        assert user is not None
        assert user.id is not None


def test_resolve_user_returns_none_for_unknown_email(client):
    with SessionLocal() as db:
        user, _, _ = _resolve_user(db, email="unknown@example.com")
        assert user is None


def test_ensure_accounts_active_passes_for_active_accounts(client):
    with SessionLocal() as db:
        from app.models import Company
        user = db.query(UserAccount).first()
        assert user is not None
        company = db.query(Company).first()
        assert company is not None
        _ensure_accounts_active(user, company)


def test_ensure_accounts_active_raises_for_inactive_user(client):
    with SessionLocal() as db:
        from app.models import Company
        user = db.query(UserAccount).first()
        assert user is not None
        company = db.query(Company).first()
        assert company is not None
        user.is_active = False
        db.flush()

        from app.errors import DomainError
        with pytest.raises(DomainError):
            _ensure_accounts_active(user, company)


def test_reset_password_sets_must_change_password_flag(client):
    with SessionLocal() as db:
        user_before = db.query(UserAccount).filter(
            UserAccount.email_hash == lookup_digest(
                "marina.costa@touchin.com",
                get_settings().encryption_secret or "",
            )
        ).first()
        assert user_before is not None
        assert not user_before.must_change_password

    _, _, _ = reset_password(
        db=SessionLocal(),
        email="marina.costa@touchin.com",
    )

    with SessionLocal() as db:
        user_after = db.query(UserAccount).filter(
            UserAccount.email_hash == lookup_digest(
                "marina.costa@touchin.com",
                get_settings().encryption_secret or "",
            )
        ).first()
        assert user_after is not None
        assert user_after.must_change_password is True


def test_change_password_clears_must_change_password_flag(client):
    # Use a single session to ensure object tracking across operations
    db = SessionLocal()

    try:
        # First reset to set the flag and get temp password
        _, _, temp_password = reset_password(db=db, email="marina.costa@touchin.com")

        # Login with the temporary password
        auth_response = login(
            db=db,
            payload=LoginRequest(
                email="marina.costa@touchin.com",
                password=temp_password,
                keep_connected=True,
            ),
        )

        context = resolve_context(db=db, token=auth_response.access_token)

        fresh_password = "NewSecurePass@123"
        _, _ = change_password(
            db=db,
            context=context,
            current_password=temp_password,
            new_password=fresh_password,
        )

        user = db.query(UserAccount).filter(
            UserAccount.email_hash == lookup_digest(
                "marina.costa@touchin.com",
                get_settings().encryption_secret or "",
            )
        ).first()
        assert user is not None
        assert user.must_change_password is False
    finally:
        db.close()


def test_login_response_includes_must_change_password(client):
    auth_response = login(
        db=SessionLocal(),
        payload=LoginRequest(
            email="marina.costa@touchin.com",
            password=get_settings().seed_admin_password,
            keep_connected=True,
        ),
    )
    assert auth_response.must_change_password is False


def test_resolve_context_throttles_last_used_touch(client, monkeypatch):
    db = SessionLocal()
    try:
        auth_response = login(
            db=db,
            payload=LoginRequest(
                email="marina.costa@touchin.com",
                password=get_settings().seed_admin_password,
                keep_connected=True,
            ),
        )
        session = db.query(AuthSession).filter(
            AuthSession.token_hash == lookup_digest(
                auth_response.access_token,
                get_settings().token_secret or "",
            )
        ).first()
        assert session is not None
        assert session.last_used_at is None

        first_touch = utcnow()
        monkeypatch.setattr("app.domain.auth_read.utcnow", lambda: first_touch)
        resolve_context(db=db, token=auth_response.access_token)
        db.refresh(session)
        assert ensure_utc(session.last_used_at) == first_touch

        second_touch = first_touch + timedelta(minutes=1)
        monkeypatch.setattr("app.domain.auth_read.utcnow", lambda: second_touch)
        resolve_context(db=db, token=auth_response.access_token)
        db.refresh(session)
        assert ensure_utc(session.last_used_at) == first_touch
    finally:
        db.close()


def test_seed_on_startup_defaults_off_in_production(monkeypatch):
    monkeypatch.setenv("TOUCHIN_ENV", "production")
    monkeypatch.delenv("TOUCHIN_SEED_ON_STARTUP", raising=False)
    monkeypatch.delenv("TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP", raising=False)
    monkeypatch.setenv("TOUCHIN_TOKEN_SECRET", "token-secret")
    monkeypatch.setenv("TOUCHIN_ENCRYPTION_SECRET", "encryption-secret")
    monkeypatch.setenv("TOUCHIN_SEED_ADMIN_PASSWORD", "admin-password")

    settings = Settings()

    assert settings.seed_on_startup is False
    assert settings.bootstrap_database_on_startup is False
