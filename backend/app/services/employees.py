from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.domain.employee_read import (
    employee_or_404,
    get_employee as read_employee,
    list_employees as read_list_employees,
    serialize_expected_shift,
)
from app.domain.identity import normalize_email
from app.errors import DomainError, ErrorKind
from app.models import Employee, UserAccount
from app.schemas.employee import EmployeeDraftPayload, EmployeeProfileResponse
from app.security import generate_temp_password, hash_password
from app.services.auth import AuthenticatedContext


def _cipher() -> FieldCipher:
    settings = get_settings()
    return FieldCipher(settings.encryption_secret or "")


def _employee_email_hash(email: str) -> str:
    settings = get_settings()
    return lookup_digest(normalize_email(email), settings.encryption_secret or "")


def _status_value(payload: EmployeeDraftPayload) -> str:
    return str(payload.status)


def _work_mode_value(payload: EmployeeDraftPayload) -> str:
    return str(payload.work_mode)


def _role_level_value(payload: EmployeeDraftPayload) -> str:
    return str(payload.role_level)


def _access_role_value(payload: EmployeeDraftPayload) -> str:
    if payload.access_role is None:
        return "employee"
    if isinstance(payload.access_role, str):
        return payload.access_role
    return payload.access_role.value


def _normalized_email(payload: EmployeeDraftPayload) -> str:
    return normalize_email(str(payload.email))


def _ensure_unique_employee_email(db: Session, *, company_id: str, email_hash: str, employee_id: str | None = None) -> None:
    query = select(Employee).where(
        Employee.company_id == company_id,
        Employee.email_hash == email_hash,
    )
    if employee_id is not None:
        query = query.where(Employee.id != employee_id)
    existing = db.scalar(query)
    if existing is not None:
        raise DomainError(
            ErrorKind.conflict,
            "An employee with this email already exists in the company.",
        )


def _ensure_unique_user_email(db: Session, *, email_hash: str, employee_id: str | None = None) -> None:
    query = select(UserAccount).where(UserAccount.email_hash == email_hash)
    if employee_id is not None:
        query = query.where(UserAccount.employee_id != employee_id)
    existing_user = db.scalar(query)
    if existing_user is not None:
        raise DomainError(ErrorKind.conflict, "A user with this email already exists.")


def create_employee(
    db: Session,
    *,
    company_id: str,
    payload: EmployeeDraftPayload,
    timezone_name: str,
    actor_user_id: str | None = None,
) -> tuple[EmployeeProfileResponse, str]:
    from app.services.audit import AuditService
    cipher = _cipher()
    status_value = _status_value(payload)
    normalized_email = _normalized_email(payload)
    email_hash = _employee_email_hash(normalized_email)
    _ensure_unique_employee_email(db, company_id=company_id, email_hash=email_hash)
    _ensure_unique_user_email(db, email_hash=email_hash)

    temp_password = generate_temp_password()
    employee = Employee(
        company_id=company_id,
        name_ciphertext=cipher.encrypt(payload.name) or "",
        role_ciphertext=cipher.encrypt(payload.role) or "",
        department_ciphertext=cipher.encrypt(payload.department) or "",
        email_ciphertext=cipher.encrypt(normalized_email) or "",
        email_hash=email_hash,
        phone_ciphertext=cipher.encrypt(payload.phone) or "",
        unit_ciphertext=cipher.encrypt(payload.unit) or "",
        expected_shift_ciphertext=cipher.encrypt(
            serialize_expected_shift(
                start=payload.expected_shift_start,
                end=payload.expected_shift_end,
            ),
        )
        or "",
        status=status_value,
        work_mode=_work_mode_value(payload),
        role_level=_role_level_value(payload),
        requires_location_on_punch=payload.requires_location_on_punch,
        trusted_device_required=payload.trusted_device_required,
        pending_adjustments=2 if status_value == "onboarding" else 0,
        notes_ciphertext=cipher.encrypt(payload.notes) or "",
    )
    user = UserAccount(
        company_id=company_id,
        email_ciphertext=cipher.encrypt(normalized_email) or "",
        email_hash=email_hash,
        password_hash=hash_password(temp_password),
        must_change_password=True,
        role=_access_role_value(payload),
        employee=employee,
    )
    db.add_all([employee, user])
    db.flush()
    AuditService.log_action(
        db,
        company_id=company_id,
        actor_user_id=actor_user_id,
        action="employee.created",
        entity_type="employee",
        entity_id=employee.id,
        result="success"
    )
    db.commit()
    db.refresh(employee)
    return (
        read_employee(
            db,
            company_id=company_id,
            employee_id=employee.id,
            timezone_name=timezone_name,
        ),
        temp_password,
    )


def list_employees(db: Session, *, company_id: str, timezone_name: str) -> list[EmployeeProfileResponse]:
    return read_list_employees(db, company_id=company_id, timezone_name=timezone_name)


def get_employee(db: Session, *, company_id: str, employee_id: str, timezone_name: str) -> EmployeeProfileResponse:
    return read_employee(
        db,
        company_id=company_id,
        employee_id=employee_id,
        timezone_name=timezone_name,
    )


def update_employee(
    db: Session,
    *,
    context: AuthenticatedContext,
    company_id: str,
    employee_id: str,
    payload: EmployeeDraftPayload,
    timezone_name: str,
) -> EmployeeProfileResponse:
    from app.services.audit import AuditService
    cipher = _cipher()
    status_value = _status_value(payload)
    employee = employee_or_404(db, company_id=company_id, employee_id=employee_id)

    normalized_email = _normalized_email(payload)
    email_hash = _employee_email_hash(normalized_email)
    _ensure_unique_employee_email(db, company_id=company_id, email_hash=email_hash, employee_id=employee_id)
    _ensure_unique_user_email(db, email_hash=email_hash, employee_id=employee_id)

    linked_account = db.scalar(
        select(UserAccount).where(
            UserAccount.company_id == company_id,
            UserAccount.employee_id == employee_id,
        ),
    )
    is_self_edit = context.user.employee_id == employee_id
    if linked_account is not None:
        if context.user.role == "manager" and is_self_edit:
            raise DomainError(ErrorKind.forbidden, "Managers cannot edit their own profile.")
        if context.user.role == "manager" and linked_account.role == "admin":
            raise DomainError(ErrorKind.forbidden, "Managers cannot edit admin accounts.")
        if linked_account.role == "admin" and not (context.user.role == "admin" and is_self_edit):
            raise DomainError(ErrorKind.forbidden, "Admin profiles can only be edited by the admin account itself.")

    employee.name_ciphertext = cipher.encrypt(payload.name) or ""
    employee.role_ciphertext = cipher.encrypt(payload.role) or ""
    employee.department_ciphertext = cipher.encrypt(payload.department) or ""
    employee.email_ciphertext = cipher.encrypt(normalized_email) or ""
    employee.email_hash = email_hash
    employee.phone_ciphertext = cipher.encrypt(payload.phone) or ""
    employee.unit_ciphertext = cipher.encrypt(payload.unit) or ""
    employee.expected_shift_ciphertext = cipher.encrypt(
        serialize_expected_shift(
            start=payload.expected_shift_start,
            end=payload.expected_shift_end,
        ),
    ) or ""
    employee.status = status_value
    employee.work_mode = _work_mode_value(payload)
    employee.role_level = _role_level_value(payload)
    employee.requires_location_on_punch = payload.requires_location_on_punch
    employee.trusted_device_required = payload.trusted_device_required
    employee.notes_ciphertext = cipher.encrypt(payload.notes) or ""
    if linked_account is not None:
        linked_account.email_ciphertext = cipher.encrypt(normalized_email) or ""
        linked_account.email_hash = email_hash
    if payload.access_role is not None:
        if linked_account is None:
            raise DomainError(ErrorKind.bad_request, "Employee account not found.")
        if linked_account.role == "admin":
            raise DomainError(ErrorKind.forbidden, "Admin role cannot be changed.")
        linked_account.role = _access_role_value(payload)
    
    AuditService.log_action(
        db,
        company_id=company_id,
        actor_user_id=context.user.id,
        action="employee.updated",
        entity_type="employee",
        entity_id=employee.id,
        result="success"
    )
    db.commit()
    return read_employee(
        db,
        company_id=company_id,
        employee_id=employee.id,
        timezone_name=timezone_name,
    )


def delete_employee(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    actor_user_id: str | None = None,
) -> None:
    from app.services.audit import AuditService
    employee = employee_or_404(db, company_id=company_id, employee_id=employee_id)

    linked_accounts = db.scalars(
        select(UserAccount).where(
            UserAccount.company_id == company_id,
            UserAccount.employee_id == employee_id,
        ),
    ).all()
    for account in linked_accounts:
        db.delete(account)

    db.delete(employee)
    AuditService.log_action(
        db,
        company_id=company_id,
        actor_user_id=actor_user_id,
        action="employee.deleted",
        entity_type="employee",
        entity_id=employee.id,
        result="success"
    )
    db.commit()
