from __future__ import annotations

from datetime import timedelta

import pytest
from sqlalchemy import select

from app.config import get_settings
from app.db import SessionLocal, utcnow
from app.errors import DomainError
from app.models import PasswordResetThrottle, PasswordResetToken, UserAccount
from app.schemas.auth import LoginRequest
from app.services.auth import login
from app.services.password_reset import (
    EMAIL_ATTEMPTS_PER_HOUR,
    IP_ATTEMPTS_PER_HOUR,
    confirm_password_reset,
    request_password_reset,
)


EMAIL = "marina.costa@touchin.com"
IP = "192.0.2.88"


def _issue(db, *, email: str = EMAIL, ip: str = IP):
    return request_password_reset(db, email=email, client_ip=ip)


def _confirm(db, token: str, *, password: str = "SecureNewPassword!123", ip: str = IP):
    return confirm_password_reset(db, token=token, new_password=password, client_ip=ip)


def test_public_request_indistinguishable_for_known_unknown_and_throttled(client):
    responses = []
    for address in (EMAIL, "unregistered@example.com"):
        for _ in range(EMAIL_ATTEMPTS_PER_HOUR + 2):
            response = client.post("/api/v1/auth/reset-password", json={"email": address})
            responses.append((response.status_code, response.json()))
    assert len(set(str(response) for response in responses)) == 1


def test_request_persists_only_a_digest_and_does_not_change_credentials(client):
    with SessionLocal() as db:
        original = db.scalar(select(UserAccount).where(UserAccount.role == "admin"))
        assert original is not None
        old_hash = original.password_hash
        issued = _issue(db)
        assert issued is not None
        row = db.scalar(select(PasswordResetToken))
        assert row is not None
        assert issued[2] != row.token_hash
        assert len(row.token_hash) == 64
        db.refresh(original)
        assert original.password_hash == old_hash
        assert not original.must_change_password


def test_expired_and_replayed_token_cannot_change_password(client):
    with SessionLocal() as db:
        issued = _issue(db)
        assert issued is not None
        row = db.scalar(select(PasswordResetToken))
        assert row is not None
        row.expires_at = utcnow() - timedelta(seconds=1)
        db.commit()
        with pytest.raises(DomainError):
            _confirm(db, issued[2])

        next_token = _issue(db)
        assert next_token is not None
        _confirm(db, next_token[2])
        with pytest.raises(DomainError):
            _confirm(db, next_token[2])


def test_new_request_invalidates_earlier_link(client):
    with SessionLocal() as db:
        first = _issue(db)
        second = _issue(db)
        assert first is not None and second is not None
        with pytest.raises(DomainError):
            _confirm(db, first[2])
        _confirm(db, second[2])


def test_rate_limit_persists_across_sessions_and_never_creates_extra_tokens(client):
    for _ in range(EMAIL_ATTEMPTS_PER_HOUR):
        with SessionLocal() as db:
            assert _issue(db) is not None
    with SessionLocal() as db:
        assert _issue(db) is None
        assert db.query(PasswordResetToken).count() == EMAIL_ATTEMPTS_PER_HOUR
        assert db.query(PasswordResetThrottle).count() >= 2


def test_authenticated_change_revokes_pending_recovery_link(client):
    from app.services.auth import change_password, resolve_context

    with SessionLocal() as db:
        issued = _issue(db)
        assert issued is not None
        active = login(db, LoginRequest(
            email=EMAIL, password=get_settings().seed_admin_password,
            keep_connected=True,
        ))
        context = resolve_context(db, active.access_token)
        change_password(
            db, context=context,
            current_password=get_settings().seed_admin_password,
            new_password="AlreadyChangedPassword!123",
        )
        with pytest.raises(DomainError):
            _confirm(db, issued[2])


def test_blocked_ip_cannot_exhaust_another_address_recovery_quota(client):
    blocked_ip = "198.51.100.88"
    with SessionLocal() as db:
        for attempt in range(IP_ATTEMPTS_PER_HOUR):
            _issue(db, email=f"unknown-{attempt}@example.com", ip=blocked_ip)
        for _ in range(EMAIL_ATTEMPTS_PER_HOUR + 1):
            assert _issue(db, email=EMAIL, ip=blocked_ip) is None
        assert _issue(db, email=EMAIL, ip="198.51.100.89") is not None


def test_missing_reset_url_does_not_spend_any_rate_limit(client, monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "password_reset_url", "")
    with SessionLocal() as db:
        assert _issue(db) is None
        assert db.query(PasswordResetThrottle).count() == 0
        assert db.query(PasswordResetToken).count() == 0


def test_request_returns_employee_display_name_for_brevo(client):
    with SessionLocal() as db:
        result = _issue(db, email="bianca.nogueira@touchin.com")
        assert result is not None
        assert result[0] == "bianca.nogueira@touchin.com"
        assert result[1] == "Bianca Nogueira"
