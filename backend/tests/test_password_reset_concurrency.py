from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import Base, utcnow
from app.errors import DomainError
from app.models import Company, PasswordResetToken, UserAccount
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
