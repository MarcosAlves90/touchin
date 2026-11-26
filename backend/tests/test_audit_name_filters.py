"""Name and ID searches use the same scoped audit stream for list and export."""

from __future__ import annotations

import csv
from datetime import datetime, timedelta, timezone
from io import StringIO

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import SessionLocal
from app.models import AuditEvent, Company, Employee, KanbanColumn, Project, Task, UserAccount
from app.seed import MARINA_EMAIL

from test_audit import login_headers

PATH = "/api/v1/audit-events"


def test_named_filters_combine_before_pagination_and_match_csv(client):
    headers = login_headers(client, MARINA_EMAIL)
    cipher = FieldCipher(get_settings().encryption_secret or "")
    start = datetime(2026, 11, 1, tzinfo=timezone.utc)

    with SessionLocal() as db:
        company = db.query(Company).first()
        assert company is not None
        author = db.query(UserAccount).filter(
            UserAccount.company_id == company.id,
            UserAccount.role == "admin",
            UserAccount.employee_id.is_not(None),
        ).first()
        assert author is not None
        author.employee.name_ciphertext = cipher.encrypt("Maria  Conceição do Vale")
        project = Project(id="named-audit-proj-01", company_id=company.id,
                          name_ciphertext=cipher.encrypt("Integração de Logística"))
        column = KanbanColumn(id="named-audit-column-01", project=project, position=0,
                              name_ciphertext=cipher.encrypt("Em Revisão"))
        tasks = [
            Task(id=identifier, project=project, kanban_column=column, card_number=n,
                 kanban_position=n, name_ciphertext=cipher.encrypt(name),
                 description_ciphertext="", type="feature")
            for n, (identifier, name) in enumerate((
                ("named-audit-card-01", "Revisão da jornada"),
                ("named-audit-card-02", "Revisão da jornada"),
                ("named-audit-card-03", "Importação de crachás %_"),
            ), start=1)
        ]
        company.trade_name_ciphertext = cipher.encrypt("Organização Médica")
        db.add_all([project, column, *tasks])
        db.flush()

        def event(row_id, *, target, kind, seconds, actor=author.id, result="success"):
            return AuditEvent(
                id=row_id, company_id=company.id, actor_user_id=actor,
                project_id=project.id, action="named-filter.test", result=result,
                entity_type=kind, entity_id=target,
                timestamp=start + timedelta(seconds=seconds),
            )

        db.add_all([
            event("named-audit-older", target=tasks[0].id, kind="card", seconds=1),
            event("named-audit-newer", target=tasks[1].id, kind="card", seconds=2),
            event("named-audit-other-action", target=tasks[1].id, kind="card",
                  seconds=3, result="failure"),
            event("named-audit-other-name", target=tasks[2].id, kind="card", seconds=4),
            event("named-audit-column", target=column.id, kind="kanban_column", seconds=5),
            event("named-audit-employee", target=author.employee_id, kind="employee", seconds=6),
            event("named-audit-project", target=project.id, kind="project", seconds=7),
            event("named-audit-deleted", target="deleted-unknown-entity", kind="card", seconds=8),
            event("named-audit-settings", target=company.id, kind="company_ai_settings", seconds=9),
        ])
        db.commit()

    filters = {
        "actor_user_id": " CONCEICAO   DO ",
        "entity_id": "REVISAO da",
        "project_id": "LOGISTICA",
        "action": "named-filter.test",
        "entity_type": "card",
        "result": "success",
    }
    for page, event_id in ((1, "named-audit-newer"), (2, "named-audit-older"), (3, None)):
        response = client.get(PATH, headers=headers, params={**filters, "limit": 1, "page": page})
        assert response.status_code == 200, response.text
        if event_id is None:
            assert response.json() == []
        else:
            [row] = response.json()
            assert row["id"] == event_id
            assert row["actor_name"] == "Maria  Conceição do Vale"
            assert row["entity_name"] == "Revisão da jornada"
            assert row["project_name"] == "Integração de Logística"

    export = client.get(f"{PATH}/export", headers=headers, params=filters)
    assert export.status_code == 200, export.text
    assert export.headers["x-audit-export-rows"] == "2"
    rows = list(csv.DictReader(StringIO(export.content.decode("utf-8-sig"))))
    assert [row["entity_id"] for row in rows] == ["named-audit-card-02", "named-audit-card-01"]

    for target, event_id in (
        ("em revisao", "named-audit-column"),
        ("Maria Conceicao", "named-audit-employee"),
        ("logistica", "named-audit-project"),
        ("organizacao medica", "named-audit-settings"),
        ("%_", "named-audit-other-name"),
        ("deleted-unknown-entity", "named-audit-deleted"),
    ):
        exact = client.get(PATH, headers=headers, params={
            "entity_id": target, "action": "named-filter.test",
        })
        assert exact.status_code == 200, exact.text
        [row] = exact.json()
        assert row["id"] == event_id
        if event_id == "named-audit-deleted":
            assert row["entity_name"] is None


def test_names_never_resolve_from_a_different_audit_tenant(client):
    headers = login_headers(client, MARINA_EMAIL)
    cipher = FieldCipher(get_settings().encryption_secret or "")
    with SessionLocal() as db:
        local = db.query(Company).first()
        assert local is not None
        other = Company(
            id="audit-filter-other-company",
            legal_name_ciphertext=local.legal_name_ciphertext,
            trade_name_ciphertext=local.trade_name_ciphertext,
            cnpj_ciphertext=local.cnpj_ciphertext,
            cnpj_hash="audit-filter-other-cnpj",
            contact_email_ciphertext=local.contact_email_ciphertext,
            contact_email_hash="audit-filter-other-email",
            contact_phone_ciphertext=local.contact_phone_ciphertext,
            consented_at=local.consented_at,
        )
        project = Project(id="other-project-id", company=other,
                          name_ciphertext=cipher.encrypt("Nome privado do outro projeto"))
        column = KanbanColumn(id="other-column-id", project=project, position=0,
                              name_ciphertext=cipher.encrypt("Nome privado da outra coluna"))
        task = Task(id="other-task-id", project=project, kanban_column=column, card_number=1,
                    kanban_position=1, name_ciphertext=cipher.encrypt("Nome privado de outro cartão"),
                    description_ciphertext="", type="feature")
        db.add_all([other, project, column, task])
        db.flush()
        employee = db.query(Employee).filter(Employee.company_id == local.id).first()
        assert employee is not None
        user = UserAccount(
            id="audit-filter-local-account-other-employee", company_id=local.id,
            email_ciphertext=cipher.encrypt("invalid-reference@example.invalid"),
            email_hash="audit-filter-local-account-other-employee", password_hash="not-used",
            role="employee", is_active=True,
        )
        # Point an audit event at a foreign author's account or project, as can happen
        # with a malformed import; the admin must get only its own audit row, not names.
        foreign_employee = Employee(
            id="audit-filter-foreign-employee", company_id=other.id,
            name_ciphertext=cipher.encrypt("Nome privado do outro funcionário"),
            role_ciphertext=employee.role_ciphertext, department_ciphertext=employee.department_ciphertext,
            email_ciphertext=employee.email_ciphertext, email_hash="audit-filter-foreign-employee-email",
            phone_ciphertext=employee.phone_ciphertext, unit_ciphertext=employee.unit_ciphertext,
            expected_shift_ciphertext=employee.expected_shift_ciphertext,
            status="active", work_mode="remote", role_level="employee", notes_ciphertext=employee.notes_ciphertext,
        )
        user.employee = foreign_employee
        db.add_all([foreign_employee, user])
        db.flush()
        for entity, entity_type in ((task, "card"), (column, "kanban_column"),
                                    (project, "project"), (foreign_employee, "employee")):
            db.add(AuditEvent(
                id=f"audit-forged-{entity_type}", company_id=local.id, project_id=project.id,
                actor_user_id=user.id, entity_type=entity_type, entity_id=entity.id,
                action="named-filter.boundary", result="success", timestamp=datetime.now(timezone.utc),
            ))
        db.commit()

    params = {"action": "named-filter.boundary"}
    response = client.get(PATH, headers=headers, params=params)
    assert response.status_code == 200, response.text
    assert len(response.json()) == 4
    assert all(row["entity_name"] is row["actor_name"] is row["project_name"] is None
               for row in response.json())
    for parameter in ("actor_user_id", "entity_id", "project_id"):
        response = client.get(PATH, headers=headers, params={**params, parameter: "nome privado"})
        assert response.status_code == 200, response.text
        assert response.json() == []
