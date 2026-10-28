from __future__ import annotations

from sqlalchemy import select

from app.config import get_settings
from app.db import SessionLocal
from app.models import UserAccount
from app.services import auth as auth_service

ACCOUNT_EMAIL = "marina.costa@touchin.com"
INVALID_LOGIN_VALUE = "x" * 32


def _login(client, email: str, password: str, forwarded_for: str):
    return client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password, "keepConnected": True},
        headers={"X-Forwarded-For": forwarded_for},
    )


def test_account_limit_blocks_repeated_failures_across_origins(client, monkeypatch):
    monkeypatch.setattr(
        auth_service, "LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR", 2, raising=False
    )

    responses = [
        _login(client, ACCOUNT_EMAIL, INVALID_LOGIN_VALUE, f"198.51.100.{index}")
        for index in range(1, 4)
    ]

    assert [response.status_code for response in responses] == [401, 401, 429]


def test_source_limit_spans_accounts_and_ignores_forwarded_for(client, monkeypatch):
    monkeypatch.setattr(
        auth_service, "LOGIN_SOURCE_MAX_ATTEMPTS_PER_HOUR", 2, raising=False
    )

    responses = [
        _login(client, f"unknown-{index}@example.com", INVALID_LOGIN_VALUE, f"198.51.100.{index}")
        for index in range(1, 4)
    ]

    assert [response.status_code for response in responses] == [401, 401, 429]


def test_account_throttle_response_does_not_reveal_account_existence(client, monkeypatch):
    monkeypatch.setattr(
        auth_service, "LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR", 1, raising=False
    )
    blocked_responses = []

    for email in (ACCOUNT_EMAIL, "not-registered@example.com"):
        assert _login(client, email, INVALID_LOGIN_VALUE, "192.0.2.10").status_code == 401
        blocked_responses.append(
            _login(client, email, INVALID_LOGIN_VALUE, "192.0.2.10")
        )

    assert [response.status_code for response in blocked_responses] == [429, 429]
    assert blocked_responses[0].json() == blocked_responses[1].json()


def test_successful_login_clears_account_failure_bucket(client, monkeypatch):
    monkeypatch.setattr(
        auth_service, "LOGIN_ACCOUNT_MAX_FAILURES_PER_HOUR", 2, raising=False
    )

    assert _login(client, ACCOUNT_EMAIL, INVALID_LOGIN_VALUE, "192.0.2.11").status_code == 401
    successful = _login(
        client,
        ACCOUNT_EMAIL,
        get_settings().seed_admin_password or "",
        "192.0.2.11",
    )
    assert successful.status_code == 200

    statuses = [
        _login(client, ACCOUNT_EMAIL, INVALID_LOGIN_VALUE, "192.0.2.11").status_code
        for _ in range(3)
    ]
    assert statuses == [401, 401, 429]


def test_login_throttle_persists_only_digest_keys(client):
    _login(client, ACCOUNT_EMAIL, INVALID_LOGIN_VALUE, "203.0.113.77")

    from app.models import LoginAttemptThrottle

    with SessionLocal() as db:
        buckets = db.scalars(select(LoginAttemptThrottle.bucket_hash)).all()

    assert len(buckets) >= 2
    assert all(len(bucket) == 64 for bucket in buckets)
    assert ACCOUNT_EMAIL not in "".join(buckets)
    assert "testclient" not in "".join(buckets)
    assert "203.0.113.77" not in "".join(buckets)
