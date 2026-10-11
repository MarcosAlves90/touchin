from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

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
