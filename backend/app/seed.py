from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
import json
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.models import Company, Employee, Punch, UserAccount
from app.security import hash_password

COMPANY_ID = "company-touchin"
COMPANY_EMAIL = "contato@touchin.com"
COMPANY_CNPJ = "12345678000190"
MARINA_EMAIL = "marina.costa@touchin.com"
CAIO_EMAIL = "caio.martins@touchin.com"
BIANCA_EMAIL = "bianca.nogueira@touchin.com"
JOAO_EMAIL = "joao.lima@touchin.com"
SUPER_ADMIN_EMAIL = "super.admin@touchin.com"


@dataclass(frozen=True)
class EmployeeSeed:
    employee_id: str
    name: str
    role: str
    department: str
    email: str
    phone: str
    unit: str
    expected_shift_start: time
    expected_shift_end: time
    status: str
    work_mode: str
    role_level: str
    requires_location_on_punch: bool
    trusted_device_required: bool
    pending_adjustments: int
    notes: str


def _settings():
    return get_settings()


def _cipher() -> FieldCipher:
    settings = _settings()
    return FieldCipher(settings.encryption_secret or "")


def _email_hash(value: str) -> str:
    settings = _settings()
    return lookup_digest(value.lower(), settings.encryption_secret or "")


def _local_today_at(hour: int, minute: int) -> datetime:
    zone = ZoneInfo(_settings().timezone)
    now = datetime.now(zone)
    local_value = datetime(now.year, now.month, now.day, hour, minute, tzinfo=zone)
    return local_value.astimezone(timezone.utc)


def _days_ago_at(days: int, hour: int, minute: int) -> datetime:
    zone = ZoneInfo(_settings().timezone)
    now = datetime.now(zone) - timedelta(days=days)
    local_value = datetime(now.year, now.month, now.day, hour, minute, tzinfo=zone)
    return local_value.astimezone(timezone.utc)


def _serialize_shift(start: time, end: time) -> str:
    return json.dumps(
        {
            "start": start.strftime("%H:%M"),
            "end": end.strftime("%H:%M"),
        },
        separators=(",", ":"),
    )


def _employee_seed_rows() -> list[EmployeeSeed]:
    return [
        EmployeeSeed(
            employee_id="emp-01",
            name="Marina Costa",
            role="Coordenadora de Operacoes",
            department="Operacoes",
            email=MARINA_EMAIL,
            phone="(11) 99123-1001",
            unit="Unidade Paulista",
            expected_shift_start=time(8, 0),
            expected_shift_end=time(17, 0),
            status="active",
            work_mode="onsite",
            role_level="leadership",
            requires_location_on_punch=True,
            trusted_device_required=True,
            pending_adjustments=0,
            notes="Responsavel pela abertura da operacao e pela validacao das equipes presenciais.",
        ),
        EmployeeSeed(
            employee_id="emp-02",
            name="Caio Martins",
            role="Analista de RH",
            department="People Ops",
            email=CAIO_EMAIL,
            phone="(11) 98888-2020",
            unit="Backoffice Centro",
            expected_shift_start=time(9, 0),
            expected_shift_end=time(18, 0),
            status="active",
            work_mode="hybrid",
            role_level="specialist",
            requires_location_on_punch=False,
            trusted_device_required=True,
            pending_adjustments=2,
            notes="Acompanha admissoes, desligamentos e ajustes de cadastro dos funcionarios.",
        ),
        EmployeeSeed(
            employee_id="emp-03",
            name="Bianca Nogueira",
            role="Fiscal de Loja",
            department="Campo",
            email=BIANCA_EMAIL,
            phone="(11) 97777-3030",
            unit="Loja Santo Andre",
            expected_shift_start=time(13, 40),
            expected_shift_end=time(22, 0),
            status="onLeave",
            work_mode="onsite",
            role_level="staff",
            requires_location_on_punch=True,
            trusted_device_required=True,
            pending_adjustments=1,
            notes="Afastada temporariamente. RH precisa revisar escala e substituicao da unidade.",
        ),
        EmployeeSeed(
            employee_id="emp-04",
            name="Joao Pedro Lima",
            role="Desenvolvedor Flutter",
            department="Produto",
            email=JOAO_EMAIL,
            phone="(11) 96666-4040",
            unit="Studio Digital",
            expected_shift_start=time(9, 0),
            expected_shift_end=time(18, 0),
            status="active",
            work_mode="remote",
            role_level="specialist",
            requires_location_on_punch=False,
            trusted_device_required=False,
            pending_adjustments=0,
            notes="Atua no app corporativo e em integrações internas com foco em evolução de produto.",
        ),
        EmployeeSeed(
            employee_id="emp-05",
            name="Larissa Araujo",
            role="Assistente Administrativa",
            department="Financeiro",
            email="larissa.araujo@touchin.com",
            phone="(11) 95555-5050",
            unit="Backoffice Centro",
            expected_shift_start=time(8, 30),
            expected_shift_end=time(17, 30),
            status="onboarding",
            work_mode="hybrid",
            role_level="staff",
            requires_location_on_punch=True,
            trusted_device_required=False,
            pending_adjustments=3,
            notes="Admissao em andamento. Falta concluir politica de localização e dispositivo confiavel.",
        ),
    ]


def _build_company(cipher: FieldCipher, settings) -> Company:
    return Company(
        id=COMPANY_ID,
        legal_name_ciphertext=cipher.encrypt("TouchIn Servicos Digitais LTDA") or "",
        trade_name_ciphertext=cipher.encrypt("TouchIn Servicos Digitais") or "",
        cnpj_ciphertext=cipher.encrypt(COMPANY_CNPJ) or "",
        cnpj_hash=lookup_digest(COMPANY_CNPJ, settings.encryption_secret or ""),
        contact_email_ciphertext=cipher.encrypt(COMPANY_EMAIL) or "",
        contact_email_hash=lookup_digest(COMPANY_EMAIL, settings.encryption_secret or ""),
        contact_phone_ciphertext=cipher.encrypt("(11) 4000-1234") or "",
        consented_at=datetime.now(timezone.utc),
        timezone=settings.timezone,
    )


def _build_employee(company_id: str, seed: EmployeeSeed) -> Employee:
    cipher = _cipher()
    normalized_email = seed.email.lower()
    return Employee(
        id=seed.employee_id,
        company_id=company_id,
        name_ciphertext=cipher.encrypt(seed.name) or "",
        role_ciphertext=cipher.encrypt(seed.role) or "",
        department_ciphertext=cipher.encrypt(seed.department) or "",
        email_ciphertext=cipher.encrypt(normalized_email) or "",
        email_hash=_email_hash(normalized_email),
        phone_ciphertext=cipher.encrypt(seed.phone) or "",
        unit_ciphertext=cipher.encrypt(seed.unit) or "",
        expected_shift_ciphertext=cipher.encrypt(
            _serialize_shift(seed.expected_shift_start, seed.expected_shift_end),
        )
        or "",
        status=seed.status,
        work_mode=seed.work_mode,
        role_level=seed.role_level,
        requires_location_on_punch=seed.requires_location_on_punch,
        trusted_device_required=seed.trusted_device_required,
        pending_adjustments=seed.pending_adjustments,
        notes_ciphertext=cipher.encrypt(seed.notes) or "",
    )


def _build_employees(company_id: str) -> list[Employee]:
    return [_build_employee(company_id, seed) for seed in _employee_seed_rows()]


def _build_users(company_id: str, cipher: FieldCipher, settings) -> list[UserAccount]:
    return [
        UserAccount(
            id="user-marina",
            company_id=company_id,
            employee_id="emp-01",
            email_ciphertext=cipher.encrypt(MARINA_EMAIL) or "",
            email_hash=_email_hash(MARINA_EMAIL),
            password_hash=hash_password(settings.seed_admin_password),
            role="admin",
        ),
        UserAccount(
            id="user-caio",
            company_id=company_id,
            employee_id="emp-02",
            email_ciphertext=cipher.encrypt(CAIO_EMAIL) or "",
            email_hash=_email_hash(CAIO_EMAIL),
            password_hash=hash_password(settings.seed_admin_password),
            role="manager",
        ),
        UserAccount(
            id="user-joao",
            company_id=company_id,
            employee_id="emp-04",
            email_ciphertext=cipher.encrypt(JOAO_EMAIL) or "",
            email_hash=_email_hash(JOAO_EMAIL),
            password_hash=hash_password(settings.seed_admin_password),
            role="employee",
        ),
        UserAccount(
            id="user-bianca",
            company_id=company_id,
            employee_id="emp-03",
            email_ciphertext=cipher.encrypt(BIANCA_EMAIL) or "",
            email_hash=_email_hash(BIANCA_EMAIL),
            password_hash=hash_password(settings.seed_admin_password),
            role="employee",
        ),
        UserAccount(
            id="user-super-admin",
            company_id=company_id,
            employee_id=None,
            email_ciphertext=cipher.encrypt(SUPER_ADMIN_EMAIL) or "",
            email_hash=_email_hash(SUPER_ADMIN_EMAIL),
            password_hash=hash_password(settings.seed_admin_password),
            role="super_admin",
        ),
    ]


def _build_punch(
    *,
    company_id: str,
    employee_id: str,
    punch_type: str,
    timestamp: datetime,
    detail: str,
    location: dict[str, object] | None = None,
) -> Punch:
    cipher = _cipher()
    return Punch(
        company_id=company_id,
        employee_id=employee_id,
        type=punch_type,
        timestamp=timestamp,
        detail_ciphertext=cipher.encrypt(detail) or "",
        location_payload_ciphertext=cipher.encrypt_json(location),
    )


def _build_punches(company_id: str) -> list[Punch]:
    return [
        _build_punch(
            company_id=company_id,
            employee_id="emp-01",
            punch_type="checkIn",
            timestamp=_local_today_at(8, 5),
            detail="Entrada confirmada no dispositivo principal.",
            location={
                "latitude": -23.56310,
                "longitude": -46.65433,
                "accuracy_meters": 18.0,
                "captured_at": _local_today_at(8, 5).isoformat(),
            },
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-01",
            punch_type="breakStart",
            timestamp=_local_today_at(12, 4),
            detail="Pausa iniciada para intervalo.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-01",
            punch_type="breakEnd",
            timestamp=_local_today_at(12, 58),
            detail="Retorno validado sem inconsistencias.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-01",
            punch_type="checkOut",
            timestamp=_local_today_at(16, 26),
            detail="Saida registrada para encerramento do turno.",
            location={
                "latitude": -23.56322,
                "longitude": -46.65455,
                "accuracy_meters": 15.0,
                "captured_at": _local_today_at(16, 26).isoformat(),
            },
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-02",
            punch_type="checkIn",
            timestamp=_local_today_at(9, 0),
            detail="Entrada registrada.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-02",
            punch_type="breakStart",
            timestamp=_local_today_at(12, 10),
            detail="Pausa iniciada.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-02",
            punch_type="breakEnd",
            timestamp=_local_today_at(13, 0),
            detail="Retorno registrado.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-02",
            punch_type="checkOut",
            timestamp=_local_today_at(16, 32),
            detail="Saida registrada.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-03",
            punch_type="checkIn",
            timestamp=_days_ago_at(3, 13, 40),
            detail="Entrada registrada antes do afastamento.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-04",
            punch_type="checkIn",
            timestamp=_local_today_at(9, 0),
            detail="Entrada registrada.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-04",
            punch_type="breakStart",
            timestamp=_local_today_at(12, 10),
            detail="Pausa iniciada.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-04",
            punch_type="breakEnd",
            timestamp=_local_today_at(13, 0),
            detail="Retorno registrado.",
        ),
        _build_punch(
            company_id=company_id,
            employee_id="emp-04",
            punch_type="checkOut",
            timestamp=_local_today_at(16, 51),
            detail="Saida registrada.",
        ),
    ]


def seed_database_if_empty(db: Session) -> None:
    if db.scalar(select(Company.id).limit(1)) is not None:
        return

    settings = _settings()
    cipher = _cipher()
    db.add(_build_company(cipher, settings))
    db.add_all(_build_employees(COMPANY_ID))
    db.add_all(_build_users(COMPANY_ID, cipher, settings))
    db.add_all(_build_punches(COMPANY_ID))
    db.commit()


def seed_database(db: Session) -> None:
    seed_database_if_empty(db)
