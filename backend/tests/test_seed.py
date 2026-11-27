from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import Base
from app.models import Company, Employee, Punch, UserAccount
from app.seed import COMPANY_ID, seed_database


@pytest.fixture

def db() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session
    Base.metadata.drop_all(bind=engine)
    engine.dispose()


def _company(company_id: str = "company-unrelated") -> Company:
    return Company(
        id=company_id,
        legal_name_ciphertext="unrelated-legal-name",
        trade_name_ciphertext="unrelated-trade-name",
        cnpj_ciphertext="unrelated-cnpj",
        cnpj_hash=f"{company_id}-cnpj-hash",
        contact_email_ciphertext="unrelated-email",
        contact_email_hash=f"{company_id}-email-hash",
        contact_phone_ciphertext="unrelated-phone",
        consented_at=datetime.now(timezone.utc),
        timezone="UTC",
    )


def _employee(
    employee_id: str = "employee-unrelated",
    company_id: str = "company-unrelated",
) -> Employee:
    return Employee(
        id=employee_id,
        company_id=company_id,
        name_ciphertext="unrelated-name",
        role_ciphertext="unrelated-role",
        department_ciphertext="unrelated-department",
        email_ciphertext="unrelated-employee-email",
        email_hash=f"{employee_id}-email-hash",
        phone_ciphertext="unrelated-employee-phone",
        unit_ciphertext="unrelated-unit",
        expected_shift_ciphertext="{}",
        status="active",
        work_mode="remote",
        role_level="staff",
        requires_location_on_punch=False,
        trusted_device_required=False,
        pending_adjustments=0,
        notes_ciphertext="unrelated-notes",
    )


def _counts(db: Session) -> tuple[int, int, int, int]:
    return (
        db.scalar(select(func.count()).select_from(Company)),
        db.scalar(select(func.count()).select_from(Employee)),
        db.scalar(select(func.count()).select_from(UserAccount)),
        db.scalar(select(func.count()).select_from(Punch)),
    )


def _use_seed_day(monkeypatch, seed_day: datetime) -> None:
    def local_today_at(hour: int, minute: int) -> datetime:
        return seed_day.replace(hour=hour, minute=minute)

    def days_ago_at(days: int, hour: int, minute: int) -> datetime:
        return seed_day.replace(hour=hour, minute=minute) - timedelta(days=days)

    monkeypatch.setattr("app.seed._local_today_at", local_today_at)
    monkeypatch.setattr("app.seed._days_ago_at", days_ago_at)


def test_seed_repairs_missing_records_alongside_unrelated_company(db: Session) -> None:
    db.add_all([_company(), _employee()])
    db.commit()

    seed_database(db)

    assert db.get(Company, COMPANY_ID) is not None
    unrelated_company = db.get(Company, "company-unrelated")
    assert unrelated_company is not None
    assert unrelated_company.trade_name_ciphertext == "unrelated-trade-name"
    unrelated_employee = db.get(Employee, "employee-unrelated")
    assert unrelated_employee is not None
    assert unrelated_employee.name_ciphertext == "unrelated-name"
    assert _counts(db) == (2, 6, 5, 13)

    missing_employee = db.get(Employee, "emp-05")
    assert missing_employee is not None
    db.delete(missing_employee)
    missing_user = db.get(UserAccount, "user-caio")
    assert missing_user is not None
    db.delete(missing_user)
    missing_punch = db.scalar(select(Punch).where(Punch.employee_id == "emp-01").limit(1))
    assert missing_punch is not None
    db.delete(missing_punch)
    db.commit()

    seed_database(db)

    assert db.get(Employee, "emp-05") is not None
    assert db.get(UserAccount, "user-caio") is not None
    assert _counts(db) == (2, 6, 5, 13)
    expected_counts = _counts(db)
    seed_database(db)
    assert _counts(db) == expected_counts


def test_seed_rejects_a_non_seed_employee_using_a_reserved_seed_id(db: Session) -> None:
    db.add(_company())
    db.add(_employee(employee_id="emp-01"))
    db.commit()

    with pytest.raises(RuntimeError, match="conflicts with existing non-seed"):
        seed_database(db)

    assert db.get(Employee, "emp-01").company_id == "company-unrelated"
    assert db.get(Company, COMPANY_ID) is None


def test_seed_rejects_a_non_seed_company_using_the_reserved_seed_id(db: Session) -> None:
    company = _company(company_id=COMPANY_ID)
    db.add(company)
    db.commit()

    with pytest.raises(RuntimeError, match="conflicts with existing non-seed"):
        seed_database(db)

    assert db.get(Company, COMPANY_ID).trade_name_ciphertext == "unrelated-trade-name"
    assert _counts(db) == (1, 0, 0, 0)


def test_seed_preserves_edits_to_seed_owned_rows(db: Session) -> None:
    seed_database(db)

    user = db.get(UserAccount, "user-bianca")
    assert user is not None
    user.role = "manager"
    punch = db.scalar(
        select(Punch).where(Punch.employee_id == "emp-01", Punch.type == "checkIn").limit(1),
    )
    assert punch is not None
    punch.type = "breakEnd"
    punch.timestamp += timedelta(minutes=7)
    expected_timestamp = punch.timestamp
    db.commit()

    seed_database(db)

    assert db.get(UserAccount, "user-bianca").role == "manager"
    preserved_punch = db.get(Punch, punch.id)
    assert preserved_punch is not None
    assert preserved_punch.type == "breakEnd"
    assert preserved_punch.timestamp == expected_timestamp
    assert _counts(db) == (1, 5, 5, 13)


def test_seed_punch_ids_and_timestamps_remain_stable_across_dates(
    db: Session,
    monkeypatch,
) -> None:
    _use_seed_day(monkeypatch, datetime(2026, 10, 11, tzinfo=timezone.utc))
    seed_database(db)
    initial_punches = {
        punch.id: (punch.type, punch.timestamp)
        for punch in db.scalars(select(Punch)).all()
    }

    _use_seed_day(monkeypatch, datetime(2026, 10, 12, tzinfo=timezone.utc))
    seed_database(db)

    current_punches = {
        punch.id: (punch.type, punch.timestamp)
        for punch in db.scalars(select(Punch)).all()
    }
    assert current_punches == initial_punches
    assert _counts(db) == (1, 5, 5, 13)


def test_seed_recognizes_legacy_punches_after_date_changes(db: Session, monkeypatch) -> None:
    _use_seed_day(monkeypatch, datetime(2026, 10, 11, tzinfo=timezone.utc))
    seed_database(db)
    legacy_ids = set()
    for index, punch in enumerate(db.scalars(select(Punch)).all()):
        punch.id = f"legacy-punch-{index}"
        legacy_ids.add(punch.id)
    db.commit()

    _use_seed_day(monkeypatch, datetime(2026, 10, 12, tzinfo=timezone.utc))
    seed_database(db)

    current_ids = {punch.id for punch in db.scalars(select(Punch)).all()}
    assert current_ids == legacy_ids
    assert _counts(db) == (1, 5, 5, 13)


def test_seed_preserves_email_edits_on_seed_owned_employee(db: Session) -> None:
    seed_database(db)

    updated_email = "bianca.updated@touchin.com"
    cipher = FieldCipher(get_settings().encryption_secret or "")
    email_hash = lookup_digest(updated_email, get_settings().encryption_secret or "")
    employee = db.get(Employee, "emp-03")
    account = db.get(UserAccount, "user-bianca")
    assert employee is not None
    assert account is not None
    employee.email_ciphertext = cipher.encrypt(updated_email) or ""
    employee.email_hash = email_hash
    account.email_ciphertext = cipher.encrypt(updated_email) or ""
    account.email_hash = email_hash
    db.commit()

    seed_database(db)

    assert db.get(Employee, "emp-03").email_hash == email_hash
    assert db.get(UserAccount, "user-bianca").email_hash == email_hash
    assert _counts(db) == (1, 5, 5, 13)
