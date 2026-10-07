from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import ensure_utc, utcnow
from app.domain.project_policy import validate_project_for_punch
from app.domain.time_clock import derive_shift_status
from app.domain.time_clock_read import (
    get_employee_records,
    serialize_managed_record,
    serialize_record,
)
from app.errors import DomainError, ErrorKind
from app.models import Employee, Punch
from app.schemas.punch import (
    CreatePunchRequest,
    ManagePunchRequest,
    PunchType,
    UpdateManagedPunchRequest,
)


def _cipher() -> FieldCipher:
    settings = get_settings()
    return FieldCipher(settings.encryption_secret or "")


def _get_company_employee(db: Session, *, company_id: str, employee_id: str) -> Employee:
    employee = db.scalar(
        select(Employee).where(Employee.company_id == company_id, Employee.id == employee_id),
    )
    if employee is None:
        raise DomainError(ErrorKind.not_found, "Funcionário não encontrado.")
    return employee


def _get_employee_punch(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    punch_id: str,
) -> Punch:
    record = db.scalar(
        select(Punch).where(
            Punch.company_id == company_id,
            Punch.employee_id == employee_id,
            Punch.id == punch_id,
        ),
    )
    if record is None:
        raise DomainError(ErrorKind.not_found, "Registro de ponto não encontrado.")
    return record


def create_punch(
    db: Session,
    *,
    employee: Employee,
    payload: CreatePunchRequest,
    timezone_name: str,
):
    cipher = _cipher()
    punch_type = PunchType(payload.type)
    all_records = get_employee_records(db, employee_id=employee.id)
    current_status = derive_shift_status(all_records)
    allowed_types = {
        "checkedOut": {PunchType.check_in},
        "working": {PunchType.break_start, PunchType.check_out},
        "onBreak": {PunchType.break_end, PunchType.check_out},
    }
    if punch_type not in allowed_types[current_status.value]:
        raise DomainError(
            ErrorKind.conflict,
            (
                "Transição de ponto inválida para o estado atual. "
                f"Estado atual: {current_status.value}."
            ),
        )

    if employee.requires_location_on_punch and payload.location is None:
        raise DomainError(
            ErrorKind.bad_request,
            "Este funcionário precisa enviar dados de localização ao bater ponto.",
        )

    if payload.project_id is not None:
        validate_project_for_punch(
            db,
            company_id=employee.company_id,
            employee_id=employee.id,
            project_id=payload.project_id,
        )

    last_punch = all_records[-1] if all_records else None
    active_project_id = payload.project_id or (last_punch.project_id if last_punch else None)

    if active_project_id or payload.work_log:
        if punch_type == PunchType.check_out and current_status.value == "onBreak":
            raise DomainError(ErrorKind.bad_request, "Não é possível encerrar a jornada durante uma pausa ao usar apontamento de tarefas. Encerre a pausa primeiro.")

    tasks_for_log = []
    if punch_type in (PunchType.break_start, PunchType.check_out) and current_status.value == "working":
        if active_project_id or payload.work_log:
            if not payload.work_log:
                raise DomainError(ErrorKind.bad_request, "O registro de atividades é obrigatório ao sair para o almoço ou encerrar a jornada.")
            
            from app.models import Task, WorkLog
            
            task_ids = set(payload.work_log.task_ids)
            if not task_ids:
                raise DomainError(ErrorKind.bad_request, "IDs de tarefas não informados.")
                
            tasks_for_log = db.scalars(
                select(Task).where(Task.id.in_(task_ids))
            ).all()
            
            if len(tasks_for_log) != len(task_ids):
                raise DomainError(ErrorKind.bad_request, "IDs de tarefas inválidos.")
                
            for t in tasks_for_log:
                if t.project_id != active_project_id:
                    raise DomainError(ErrorKind.bad_request, "Tarefas informadas não pertencem ao projeto.")
                validate_project_for_punch(
                    db,
                    company_id=employee.company_id,
                    employee_id=employee.id,
                    project_id=t.project_id,
                )

    detail = {
        PunchType.check_in: "Entrada registrada com localização validada.",
        PunchType.break_start: "Pausa iniciada com localização capturada.",
        PunchType.break_end: "Jornada retomada com localização capturada.",
        PunchType.check_out: "Saída registrada com localização validada.",
    }[punch_type]
    record = Punch(
        company_id=employee.company_id,
        employee_id=employee.id,
        project_id=active_project_id,
        type=punch_type.value,
        timestamp=utcnow(),
        detail_ciphertext=cipher.encrypt(detail) or "",
        location_payload_ciphertext=cipher.encrypt_json(
            payload.location.model_dump(mode="json", by_alias=False)
            if payload.location is not None
            else None,
        ),
    )
    db.add(record)
    
    if tasks_for_log:
        import json
        last_punch = all_records[-1]
        start_time = ensure_utc(last_punch.timestamp)
        end_time = ensure_utc(record.timestamp)
        duration_seconds = int((end_time - start_time).total_seconds())
        if duration_seconds < 0:
            duration_seconds = 0
            
        task_titles = [cipher.decrypt(t.name_ciphertext) or "" for t in tasks_for_log]
        task_snapshots_ciphertext = cipher.encrypt(json.dumps(task_titles)) or ""
            
        work_log = WorkLog(
            company_id=employee.company_id,
            employee_id=employee.id,
            project_id=active_project_id,
            punch_id=record.id,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=duration_seconds,
            description_ciphertext=cipher.encrypt(payload.work_log.description) or "",
            task_snapshots_ciphertext=task_snapshots_ciphertext,
            punch=record,
            tasks=tasks_for_log,
        )
        db.add(work_log)

    db.commit()
    db.refresh(record)
    return serialize_record(record, cipher=cipher)


def create_managed_punch(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    payload: ManagePunchRequest,
):
    cipher = _cipher()
    employee = _get_company_employee(db, company_id=company_id, employee_id=employee_id)
    if payload.project_id is not None:
        validate_project_for_punch(
            db,
            company_id=company_id,
            employee_id=employee.id,
            project_id=payload.project_id,
        )

    record = Punch(
        company_id=company_id,
        employee_id=employee.id,
        project_id=payload.project_id,
        type=PunchType(payload.type).value,
        timestamp=ensure_utc(payload.timestamp) if payload.timestamp is not None else utcnow(),
        detail_ciphertext=cipher.encrypt(payload.detail) or "",
        location_payload_ciphertext=cipher.encrypt_json(
            payload.location.model_dump(mode="json", by_alias=False)
            if payload.location is not None
            else None,
        ),
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return serialize_managed_record(record, cipher=cipher)


def update_managed_punch(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    punch_id: str,
    payload: UpdateManagedPunchRequest,
):
    cipher = _cipher()
    record = _get_employee_punch(
        db,
        company_id=company_id,
        employee_id=employee_id,
        punch_id=punch_id,
    )

    if "type" in payload.model_fields_set and payload.type is not None:
        record.type = PunchType(payload.type).value
    if "timestamp" in payload.model_fields_set and payload.timestamp is not None:
        record.timestamp = ensure_utc(payload.timestamp)
    if "detail" in payload.model_fields_set and payload.detail is not None:
        record.detail_ciphertext = cipher.encrypt(payload.detail) or ""
    if "project_id" in payload.model_fields_set:
        if payload.project_id is not None:
            validate_project_for_punch(
                db,
                company_id=company_id,
                employee_id=employee_id,
                project_id=payload.project_id,
            )
        record.project_id = payload.project_id
    if "location" in payload.model_fields_set:
        record.location_payload_ciphertext = cipher.encrypt_json(
            payload.location.model_dump(mode="json", by_alias=False)
            if payload.location is not None
            else None,
        )

    db.commit()
    db.refresh(record)
    return serialize_managed_record(record, cipher=cipher)


def delete_managed_punch(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    punch_id: str,
) -> None:
    record = _get_employee_punch(
        db,
        company_id=company_id,
        employee_id=employee_id,
        punch_id=punch_id,
    )
    db.delete(record)
    db.commit()
