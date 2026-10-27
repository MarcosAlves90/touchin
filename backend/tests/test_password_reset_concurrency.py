from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, Event
from os import getenv

import pytest
from fastapi.testclient import TestClient

from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import Base, utcnow
from app.dependencies import get_db
from app.errors import DomainError
from app.main import create_app
from app.models import AuthSession, Company, PasswordResetToken, UserAccount
from app.schemas.auth import LoginRequest
from app.seed import seed_database
from app.services import auth as auth_service
from app.services.auth import login, resolve_context
from app.security import hash_password, verify_password
from app.services.password_reset import confirm_password_reset, request_password_reset


def test_two_connections_can_consume_the_same_token_only_once(tmp_path):
    engine = create_engine(
        f"sqlite:///{tmp_path / 'reset-concurrent.db'}",
        connect_args={"check_same_thread": False, "timeout": 10},
    )
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, expire_on_commit=False)
    secret = get_settings().encryption_secret or ""
    email = "threaded@example.com"
    cipher = FieldCipher(secret)

    with sessions() as db:
        company = Company(
            legal_name_ciphertext=cipher.encrypt("Threaded Company"),
            trade_name_ciphertext=cipher.encrypt("Threaded"),
            cnpj_ciphertext=cipher.encrypt("12345678901234"),
            cnpj_hash=lookup_digest("12345678901234", secret),
            contact_email_ciphertext=cipher.encrypt(email),
            contact_email_hash=lookup_digest(email, secret),
            contact_phone_ciphertext=cipher.encrypt("11999999999"),
            consented_at=utcnow(),
        )
        user = UserAccount(
            company=company,
            email_ciphertext=cipher.encrypt(email),
            email_hash=lookup_digest(email, secret),
            password_hash=hash_password("old-password"),
            role="admin",
        )
        db.add(user)
        db.commit()
        job = request_password_reset(db, email=email, client_ip="192.0.2.200")
        assert job is not None
        token = job[2]

    barrier = Barrier(2)

    def attempt(password: str):
        with sessions() as db:
            barrier.wait(timeout=10)
            try:
                confirm_password_reset(
                    db, token=token, new_password=password, client_ip="192.0.2.200"
                )
                return "accepted", password
            except DomainError:
                return "rejected", password

    passwords = ("ConcurrentPasswordA!123", "ConcurrentPasswordB!123")
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(attempt, passwords))
    assert sorted(result[0] for result in results) == ["accepted", "rejected"]

    accepted_password = next(password for status, password in results if status == "accepted")
    with sessions() as db:
        stored = db.scalar(select(UserAccount).where(UserAccount.email_hash == lookup_digest(email, secret)))
        token_row = db.scalar(select(PasswordResetToken))
        assert stored is not None and token_row is not None
        assert verify_password(accepted_password, stored.password_hash)
        assert token_row.consumed_at is not None
    engine.dispose()


def test_pg_login_cannot_issue_old_password_session_after_reset(monkeypatch):
    url = getenv("TOUCHIN_TIME_CLOCK_PG_URL", "")
    if not url:
        pytest.skip("TOUCHIN_TIME_CLOCK_PG_URL: isolated PostgreSQL required")
    engine = create_engine(url, isolation_level="READ COMMITTED", pool_size=5,
                           connect_args={"connect_timeout": 4})
    try:
        with engine.connect() as conn:
            name = conn.scalar(text("select current_database()"))
            isolation = conn.scalar(text("show transaction_isolation"))
        if not name.startswith("touchin_time_clock_test_") or isolation != "read committed":
            pytest.fail("Refusing unsafe/non-READ COMMITTED PostgreSQL database")
        Base.metadata.drop_all(engine)
        Base.metadata.create_all(engine)
        factory = sessionmaker(bind=engine, expire_on_commit=False, autoflush=False)
        with factory() as db:
            seed_database(db)
            job = request_password_reset(db, email="marina.costa@touchin.com", client_ip="192.0.2.221")
            assert job is not None
            reset_token = job[2]

        verified_old_password = Event()
        release_login = Event()
        reset_done = Event()
        real_verify = auth_service.verify_password

        def pause_after_verification(password, hashed_password):
            verified = real_verify(password, hashed_password)
            if verified:
                verified_old_password.set()
                assert release_login.wait(15), "Login was not released"
            return verified

        monkeypatch.setattr(auth_service, "verify_password", pause_after_verification)

        def login_old_password():
            with factory() as db:
                return login(db, LoginRequest(email="marina.costa@touchin.com",
                                              password=get_settings().seed_admin_password,
                                              keep_connected=True))

        def reset_password():
            try:
                with factory() as db:
                    confirm_password_reset(db, token=reset_token,
                                           new_password="RaceSafeNewPassword!123",
                                           client_ip="192.0.2.222")
            finally:
                reset_done.set()

        with ThreadPoolExecutor(max_workers=2) as executor:
            login_future = executor.submit(login_old_password)
            assert verified_old_password.wait(10), "Login never reached verification"
            reset_future = executor.submit(reset_password)
            try:
                # Without a user row lock, reset commits first and a stale
                # login can then mint a session that was never revoked.
                reset_completed_during_login = reset_done.wait(timeout=1.5)
            finally:
                release_login.set()
            login_response = login_future.result(timeout=15)
            reset_future.result(timeout=15)

        assert not reset_completed_during_login, "Reset bypassed the login user-row lock"
        monkeypatch.setattr(auth_service, "verify_password", real_verify)
        # Exercise the HTTP contract consumed by the frontend against the
        # same real PostgreSQL sessions, not a mocked authentication result.
        app = create_app()

        def isolated_pg_session():
            with factory() as db:
                yield db

        app.dependency_overrides[get_db] = isolated_pg_session
        with factory() as db:
            token_hash = lookup_digest(login_response.access_token,
                                       get_settings().token_secret or "")
            row = db.scalar(select(AuthSession).where(AuthSession.token_hash == token_hash))
            assert row is not None
            assert row.revoked_at is not None, (
                "Old-password login session stayed valid after reset; "
                f"reset_completed_during_login={reset_completed_during_login}"
            )
            with pytest.raises(DomainError):
                resolve_context(db, login_response.access_token)
        with factory() as db:
            with pytest.raises(DomainError):
                login(db, LoginRequest(email="marina.costa@touchin.com",
                                       password=get_settings().seed_admin_password,
                                       keep_connected=True))
            db.rollback()

        client = TestClient(app)
        try:
            old_me = client.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {login_response.access_token}"},
            )
            assert old_me.status_code == 401, old_me.text
            fresh_login = client.post(
                "/api/v1/auth/login",
                json={"email": "marina.costa@touchin.com", "password": "RaceSafeNewPassword!123"},
            )
            assert fresh_login.status_code == 200, fresh_login.text
            fresh_token = fresh_login.json()["accessToken"]
            fresh_me = client.get(
                "/api/v1/auth/me",
                headers={"Authorization": f"Bearer {fresh_token}"},
            )
            assert fresh_me.status_code == 200, fresh_me.text
            assert fresh_me.json()["user"]["email"] == "marina.costa@touchin.com"
        finally:
            client.close()
    finally:
        engine.dispose()
