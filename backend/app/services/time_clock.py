from __future__ import annotations

from sqlalchemy import and_, or_, select, update
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import begin_serialized_write, ensure_utc, utcnow
from app.domain.project_policy import validate_project_for_punch
from app.domain.time_clock_read import (
    serialize_managed_record,
    serialize_record,
)
from app.errors import DomainError, ErrorKind
from app.models import Employee, Punch, WorkLog
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


def _lock_employee_for_punch_write(db: Session, *, company_id: str, employee_id: str) -> Employee:
    # SQLite requires a write reservation before reading the state; PostgreSQL
    # serializes all four punch writers on the same employee row.
    begin_serialized_write(db)
    statement = select(Employee).where(
        Employee.company_id == company_id, Employee.id == employee_id,
    )
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        statement = statement.with_for_update()
    employee = db.scalar(statement)
    if employee is None:
        raise DomainError(ErrorKind.not_found, "Funcionário não encontrado.")
    return employee


def _latest_punch(db: Session, *, employee_id: str) -> Punch | None:
    return db.scalar(
        select(Punch).where(Punch.employee_id == employee_id)
        .order_by(Punch.timestamp.desc(), Punch.id.desc()).limit(1)
    )


def _next_punch(db: Session, *, record: Punch) -> Punch | None:
    return db.scalar(select(Punch).where(
        Punch.employee_id == record.employee_id,
        or_(Punch.timestamp > record.timestamp,
            and_(Punch.timestamp == record.timestamp, Punch.id > record.id)),
    ).order_by(Punch.timestamp, Punch.id).limit(1))


def _previous_punch(db: Session, *, record: Punch) -> Punch | None:
    return db.scalar(select(Punch).where(
        Punch.employee_id == record.employee_id,
        or_(Punch.timestamp < record.timestamp,
            and_(Punch.timestamp == record.timestamp, Punch.id < record.id)),
    ).order_by(Punch.timestamp.desc(), Punch.id.desc()).limit(1))


_ALLOWED_FOLLOWING_PUNCH_TYPES = {
    None: {PunchType.check_in.value},
    PunchType.check_in.value: {PunchType.break_start.value, PunchType.check_out.value},
    PunchType.break_start.value: {PunchType.break_end.value, PunchType.check_out.value},
    PunchType.break_end.value: {PunchType.break_start.value, PunchType.check_out.value},
    PunchType.check_out.value: {PunchType.check_in.value},
}


def _ensure_work_interval_not_already_accounted(
    db: Session, *, company_id: str, employee_id: str,
    start, end, exclude_log_id: str | None = None,
) -> None:
    """Prevent a replacement punch from billing preserved historical work again.

    All punch writers hold the employee's row lock (or SQLite write reservation)
    before calling this check. Include detached rows and pre-snapshot legacy rows;
    WorkLog.punch_id is not an indicator of whether time was accounted.
    """
    query = select(WorkLog.id).where(
        WorkLog.company_id == company_id,
        or_(WorkLog.employee_id == employee_id,
            WorkLog.employee_id_snapshot == employee_id),
        WorkLog.start_time < end,
        WorkLog.end_time > start,
    )
    if exclude_log_id is not None:
        query = query.where(WorkLog.id != exclude_log_id)
    if db.scalar(query.limit(1)) is not None:
        raise DomainError(
            ErrorKind.conflict,
            "Este período já possui atividades contabilizadas. "
            "Solicite um ajuste de ponto sem sobrepor o histórico preservado.",
        )


def _validate_adjacent_punches(previous: Punch | None, following: Punch | None) -> None:
    """Prevent administrative writes from corrupting a whole shift sequence."""
    if following is None:
        return  # A shift is allowed to remain open.
    preceding_type = previous.type if previous is not None else None
    if following.type not in _ALLOWED_FOLLOWING_PUNCH_TYPES.get(preceding_type, set()):
        raise DomainError(
            ErrorKind.conflict,
            "A alteração produziria uma sequência inválida de registros de ponto.",
        )


def _reconcile_linked_work_log(
    db: Session, *, punch_id: str, detach_if_invalid: bool = False,
) -> None:
    """Recalculate only the existing work log of a directly affected punch.

    Activity description, task snapshots and original project attribution stay
    historical; changing a punch's project cannot silently reassign work.
    """
    log = db.scalar(select(WorkLog).where(WorkLog.punch_id == punch_id))
    if log is None:
        return
    punch = db.get(Punch, punch_id)
    if punch is None:
        return
    previous = _previous_punch(db, record=punch)
    if (previous is None
            or previous.type not in {PunchType.check_in.value, PunchType.break_end.value}
            or punch.type not in {PunchType.break_start.value, PunchType.check_out.value}):
        if detach_if_invalid:
            # The original evidence remains intact even when an admin removes
            # the opening punch needed to reconstruct its duration.
            log.punch_id = None
            return
        raise DomainError(
            ErrorKind.conflict,
            "A alteração produziria uma sequência inconsistente com o apontamento histórico.",
        )
    end = ensure_utc(punch.timestamp)
    start = ensure_utc(previous.timestamp)
    _ensure_work_interval_not_already_accounted(
        db, company_id=log.company_id,
        employee_id=log.employee_id_snapshot or log.employee_id or punch.employee_id,
        start=start, end=end, exclude_log_id=log.id,
    )
    log.start_time = start
    log.end_time = end
    log.duration_seconds = max(int((end - start).total_seconds()), 0)


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
    employee = _lock_employee_for_punch_write(
        db, company_id=employee.company_id, employee_id=employee.id,
    )
    cipher = _cipher()
    punch_type = PunchType(payload.type)
    last_punch = _latest_punch(db, employee_id=employee.id)
    current_status = {
        None: "checkedOut",
        PunchType.check_in.value: "working",
        PunchType.break_end.value: "working",
        PunchType.break_start.value: "onBreak",
        PunchType.check_out.value: "checkedOut",
    }[last_punch.type if last_punch is not None else None]
    allowed_types = {
        "checkedOut": {PunchType.check_in},
        "working": {PunchType.break_start, PunchType.check_out},
        "onBreak": {PunchType.break_end, PunchType.check_out},
    }
    if punch_type not in allowed_types[current_status]:
        raise DomainError(
            ErrorKind.conflict,
            (
                "Transição de ponto inválida para o estado atual. "
                f"Estado atual: {current_status}."
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

    active_project_id = payload.project_id or (last_punch.project_id if last_punch else None)

    if active_project_id or payload.work_log:
        if punch_type == PunchType.check_out and current_status == "onBreak":
            raise DomainError(ErrorKind.bad_request, "Não é possível encerrar a jornada durante uma pausa ao usar apontamento de tarefas. Encerre a pausa primeiro.")

    tasks_for_log = []
    if punch_type in (PunchType.break_start, PunchType.check_out) and current_status == "working":
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
            
        if not active_project_id:
            active_project_id = tasks_for_log[0].project_id

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
        PunchType.check_in: "Entrada registrada",
        PunchType.break_start: "Pausa iniciada",
        PunchType.break_end: "Jornada retomada",
        PunchType.check_out: "Saída registrada",
    }[punch_type]
    detail += " com localização informada." if payload.location is not None else "."
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
        assert last_punch is not None
        start_time = ensure_utc(last_punch.timestamp)
        end_time = ensure_utc(record.timestamp)
        _ensure_work_interval_not_already_accounted(
            db, company_id=employee.company_id, employee_id=employee.id,
            start=start_time, end=end_time,
        )
        duration_seconds = int((end_time - start_time).total_seconds())
        if duration_seconds < 0:
            duration_seconds = 0
            
        task_titles = [cipher.decrypt(t.name_ciphertext) or "" for t in tasks_for_log]
        task_snapshots_ciphertext = cipher.encrypt(json.dumps(task_titles)) or ""
            
        work_log = WorkLog(
            company_id=employee.company_id,
            employee_id=employee.id,
            employee_id_snapshot=employee.id,
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
    employee = _lock_employee_for_punch_write(db, company_id=company_id, employee_id=employee_id)
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
    db.flush()
    previous = _previous_punch(db, record=record)
    subsequent = _next_punch(db, record=record)
    _validate_adjacent_punches(previous, record)
    _validate_adjacent_punches(record, subsequent)
    if subsequent is not None:
        _reconcile_linked_work_log(db, punch_id=subsequent.id)
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
    _lock_employee_for_punch_write(db, company_id=company_id, employee_id=employee_id)
    record = _get_employee_punch(
        db,
        company_id=company_id,
        employee_id=employee_id,
        punch_id=punch_id,
    )
    previous_predecessor = _previous_punch(db, record=record)
    previous_successor = _next_punch(db, record=record)

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

    db.flush()
    predecessor = _previous_punch(db, record=record)
    successor = _next_punch(db, record=record)
    # A moved punch must not leave an invalid edge behind at its old slot.
    if ((previous_predecessor.id if previous_predecessor else None) !=
            (predecessor.id if predecessor else None) or
            (previous_successor.id if previous_successor else None) !=
            (successor.id if successor else None)):
        _validate_adjacent_punches(previous_predecessor, previous_successor)
    _validate_adjacent_punches(predecessor, record)
    _validate_adjacent_punches(record, successor)
    for affected_id in {record.id, previous_successor.id if previous_successor else None,
                        successor.id if successor else None} - {None}:
        _reconcile_linked_work_log(db, punch_id=affected_id)
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
    _lock_employee_for_punch_write(db, company_id=company_id, employee_id=employee_id)
    record = _get_employee_punch(
        db,
        company_id=company_id,
        employee_id=employee_id,
        punch_id=punch_id,
    )
    predecessor = _previous_punch(db, record=record)
    successor = _next_punch(db, record=record)
    if predecessor is not None and successor is not None:
        _validate_adjacent_punches(predecessor, successor)
    # Keep the accounted work (including its original duration and task
    # snapshots), but release its link to the deleted live punch.
    db.execute(update(WorkLog).where(WorkLog.punch_id == punch_id).values(punch_id=None))
    db.delete(record)
    db.flush()
    if successor is not None:
        _reconcile_linked_work_log(db, punch_id=successor.id, detach_if_invalid=True)
    db.commit()
