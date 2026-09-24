from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import sessionmaker

from app.database_schema import upgrade_database_schema
from app.db import Base, engine
from app.errors import DomainError, ErrorKind
from app.schemas.project import ProjectDraftPayload
from app.schemas.task import TaskDraftPayload
from app.seed import seed_database
from app.services.projects import create_project
from app.services.tasks import create_task
from test_api import TEST_SEED_SECRET, login_headers_for


MANAGER_EMAIL = "caio.martins@touchin.com"
EMPLOYEE_EMAIL = "joao.lima@touchin.com"


def _manager_headers(client):
    return login_headers_for(client, email=MANAGER_EMAIL, password=TEST_SEED_SECRET)


def _employee_headers(client):
    return login_headers_for(client, email=EMPLOYEE_EMAIL, password=TEST_SEED_SECRET)


def _create_project(client, headers, *, name="Projeto Kanban", limit=2):
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": name,
            "description": "Projeto para validar o Kanban.",
            "taskEmployeeLimit": limit,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _assign_project_member(client, headers, project_id: str, employee_id: str) -> None:
    response = client.post(
        f"/api/v1/projects/{project_id}/members",
        headers=headers,
        json={"employeeId": employee_id},
    )
    assert response.status_code in {200, 201}, response.text


def _create_task(client, headers, project_id: str, *, name: str):
    response = client.post(
        f"/api/v1/projects/{project_id}/tasks",
        headers=headers,
        json={
            "name": name,
            "description": f"Descrição {name}",
            "type": "feature",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _board(client, headers, project_id: str):
    response = client.get(f"/api/v1/projects/{project_id}/kanban", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_manager_can_read_board_without_project_membership_and_employee_requires_membership(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers)

    board = _board(client, manager_headers, project["id"])
    assert board["projectId"] == project["id"]
    assert board["kanbanVersion"] == 0
    assert len(board["columns"]) == 1
    assert board["columns"][0]["name"] == "A fazer"

    denied = client.get(
        f"/api/v1/projects/{project['id']}/kanban",
        headers=employee_headers,
    )
    assert denied.status_code == 404

    _assign_project_member(client, manager_headers, project["id"], "emp-04")
    allowed = client.get(
        f"/api/v1/projects/{project['id']}/kanban",
        headers=employee_headers,
    )
    assert allowed.status_code == 200


def test_legacy_task_create_gets_monotonic_card_identity_and_deleted_number_is_not_reused(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)

    first = _create_task(client, headers, project["id"], name="Primeiro")
    second = _create_task(client, headers, project["id"], name="Segundo")
    third = _create_task(client, headers, project["id"], name="Terceiro")
    assert (first["cardNumber"], second["cardNumber"], third["cardNumber"]) == (
        1,
        2,
        3,
    )
    assert first["kanbanColumnId"]
    assert first["kanbanPosition"] == 0
    assert second["kanbanPosition"] == 1
    assert third["kanbanPosition"] == 2

    deleted = client.delete(
        f"/api/v1/projects/{project['id']}/tasks/{third['id']}",
        headers=headers,
    )
    assert deleted.status_code == 204, deleted.text

    upgrade_database_schema(engine)
    upgrade_database_schema(engine)

    fourth = _create_task(client, headers, project["id"], name="Quarto")
    assert fourth["cardNumber"] == 4
    assert fourth["id"] != third["id"]

    board = _board(client, headers, project["id"])
    assert [card["cardNumber"] for card in board["columns"][0]["cards"]] == [
        1,
        2,
        4,
    ]


def test_card_numbers_are_scoped_per_project(client):
    headers = _manager_headers(client)
    project_a = _create_project(client, headers, name="Projeto A")
    project_b = _create_project(client, headers, name="Projeto B")

    a = _create_task(client, headers, project_a["id"], name="A")
    b = _create_task(client, headers, project_b["id"], name="B")
    assert a["cardNumber"] == 1
    assert b["cardNumber"] == 1


def test_move_reorder_uses_expected_version_and_rejects_stale_write(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)
    first = _create_task(client, headers, project["id"], name="Primeiro")
    second = _create_task(client, headers, project["id"], name="Segundo")
    board = _board(client, headers, project["id"])
    column_id = board["columns"][0]["id"]
    version = board["kanbanVersion"]

    accepted = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": version,
            "columns": [
                {"columnId": column_id, "taskIds": [second["id"], first["id"]]},
            ],
        },
    )
    assert accepted.status_code == 200, accepted.text
    updated = accepted.json()
    assert updated["kanbanVersion"] == version + 1
    assert [card["id"] for card in updated["columns"][0]["cards"]] == [
        second["id"],
        first["id"],
    ]

    stale = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": version,
            "columns": [
                {"columnId": column_id, "taskIds": [first["id"], second["id"]]},
            ],
        },
    )
    assert stale.status_code == 409
    assert "version" in stale.json()["detail"].lower()

    reloaded = _board(client, headers, project["id"])
    assert [card["id"] for card in reloaded["columns"][0]["cards"]] == [
        second["id"],
        first["id"],
    ]
    assert [card["kanbanPosition"] for card in reloaded["columns"][0]["cards"]] == [0, 1]


def test_manager_manages_columns_employee_cannot_and_delete_is_conservative(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers)
    _assign_project_member(client, manager_headers, project["id"], "emp-04")
    board = _board(client, manager_headers, project["id"])
    initial = board["columns"][0]

    forbidden = client.post(
        f"/api/v1/projects/{project['id']}/kanban/columns",
        headers=employee_headers,
        json={"name": "Em andamento", "expectedVersion": board["kanbanVersion"]},
    )
    assert forbidden.status_code == 403

    created = client.post(
        f"/api/v1/projects/{project['id']}/kanban/columns",
        headers=manager_headers,
        json={"name": "Em andamento", "expectedVersion": board["kanbanVersion"]},
    )
    assert created.status_code == 201, created.text
    board = created.json()
    assert [column["name"] for column in board["columns"]] == ["A fazer", "Em andamento"]

    task = _create_task(client, manager_headers, project["id"], name="Card")
    board = _board(client, manager_headers, project["id"])
    non_empty = client.delete(
        f"/api/v1/projects/{project['id']}/kanban/columns/{initial['id']}",
        headers=manager_headers,
        params={"expectedVersion": board["kanbanVersion"]},
    )
    assert non_empty.status_code == 409

    empty_column = next(c for c in board["columns"] if c["id"] != initial["id"])
    deleted = client.delete(
        f"/api/v1/projects/{project['id']}/kanban/columns/{empty_column['id']}",
        headers=manager_headers,
        params={"expectedVersion": board["kanbanVersion"]},
    )
    assert deleted.status_code == 200, deleted.text
    single = deleted.json()
    assert len(single["columns"]) == 1

    last = client.delete(
        f"/api/v1/projects/{project['id']}/kanban/columns/{initial['id']}",
        headers=manager_headers,
        params={"expectedVersion": single["kanbanVersion"]},
    )
    assert last.status_code == 409


def test_employee_project_member_can_manage_card_assignees_but_not_outsiders(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers, limit=2)
    for employee_id in ("emp-04", "emp-05"):
        _assign_project_member(client, manager_headers, project["id"], employee_id)
    task = _create_task(client, manager_headers, project["id"], name="Card")
    base = f"/api/v1/projects/{project['id']}/kanban/cards/{task['id']}/assignees"

    added = client.post(f"{base}/emp-05", headers=employee_headers)
    assert added.status_code == 200, added.text
    assert {item["employeeId"] for item in added.json()["assignees"]} == {"emp-05"}

    outsider = client.post(f"{base}/emp-03", headers=employee_headers)
    assert outsider.status_code == 409

    removed = client.delete(f"{base}/emp-05", headers=employee_headers)
    assert removed.status_code == 200, removed.text
    assert removed.json()["assignees"] == []


def test_delete_card_with_children_is_rejected(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)
    parent = _create_task(client, headers, project["id"], name="Pai")
    child_response = client.post(
        f"/api/v1/projects/{project['id']}/tasks",
        headers=headers,
        json={
            "name": "Filha",
            "description": "Descrição Filha",
            "type": "feature",
            "parentTaskId": parent["id"],
        },
    )
    assert child_response.status_code == 201, child_response.text

    deleted = client.delete(
        f"/api/v1/projects/{project['id']}/tasks/{parent['id']}",
        headers=headers,
    )
    assert deleted.status_code == 409


def test_legacy_schema_upgrade_backfills_kanban_identity_and_is_idempotent(tmp_path, monkeypatch):
    from app import database_schema

    monkeypatch.setenv("TOUCHIN_ENCRYPTION_SECRET", "migration-test-secret")
    database_path = tmp_path / "legacy-kanban.db"
    engine = create_engine(f"sqlite:///{database_path}", future=True)
    with engine.begin() as connection:
        connection.execute(text(
            "CREATE TABLE projects ("
            "id VARCHAR(64) PRIMARY KEY, company_id VARCHAR(64) NOT NULL, "
            "name_ciphertext TEXT NOT NULL, description_ciphertext TEXT, "
            "task_employee_limit INTEGER NOT NULL DEFAULT 1, status VARCHAR(32) NOT NULL, "
            "created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL)"
        ))
        connection.execute(text(
            "CREATE TABLE tasks ("
            "id VARCHAR(64) PRIMARY KEY, project_id VARCHAR(64) NOT NULL, "
            "parent_task_id VARCHAR(64), name_ciphertext TEXT NOT NULL, "
            "description_ciphertext TEXT NOT NULL, type VARCHAR(32) NOT NULL, "
            "created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL)"
        ))
        connection.execute(text(
            "INSERT INTO projects VALUES "
            "('p1','c1','n',NULL,2,'active','2026-01-01','2026-01-01')"
        ))
        connection.execute(text(
            "INSERT INTO tasks VALUES "
            "('t2','p1',NULL,'n2','d2','feature','2026-01-02','2026-01-02'),"
            "('t1','p1',NULL,'n1','d1','feature','2026-01-01','2026-01-01')"
        ))

    database_schema.upgrade_database_schema(engine)
    database_schema.upgrade_database_schema(engine)

    inspector = inspect(engine)
    project_columns = {c["name"] for c in inspector.get_columns("projects")}
    task_columns = {c["name"] for c in inspector.get_columns("tasks")}
    assert {"next_card_number", "kanban_version"} <= project_columns
    assert {"card_number", "kanban_column_id", "kanban_position"} <= task_columns
    assert "kanban_columns" in inspector.get_table_names()

    with engine.connect() as connection:
        project = connection.execute(
            text("SELECT next_card_number, kanban_version FROM projects WHERE id='p1'")
        ).one()
        tasks = connection.execute(
            text(
                "SELECT id, card_number, kanban_column_id, kanban_position "
                "FROM tasks WHERE project_id='p1' ORDER BY card_number"
            )
        ).all()
        columns = connection.execute(
            text("SELECT id, position FROM kanban_columns WHERE project_id='p1'")
        ).all()

    assert project.next_card_number == 3
    assert project.kanban_version == 0
    assert [(row.id, row.card_number, row.kanban_position) for row in tasks] == [
        ("t1", 1, 0),
        ("t2", 2, 1),
    ]
    assert len({row.kanban_column_id for row in tasks}) == 1
    assert len(columns) == 1
    assert columns[0].position == 0


def test_concurrent_card_create_does_not_duplicate_number(tmp_path):
    engine = create_engine(
        f"sqlite:///{tmp_path / 'kanban-concurrency.db'}",
        future=True,
        connect_args={"timeout": 10},
    )
    LocalSession = sessionmaker(bind=engine, expire_on_commit=False)
    Base.metadata.create_all(bind=engine)
    with LocalSession() as db:
        seed_database(db)
        project = create_project(
            db,
            company_id="company-touchin",
            payload=ProjectDraftPayload(
                name="Concorrência",
                description="Sequência concorrente.",
                task_employee_limit=2,
            ),
        )

    barrier = Barrier(2)

    def worker(name: str) -> int:
        with LocalSession() as db:
            barrier.wait()
            task = create_task(
                db,
                company_id="company-touchin",
                project_id=project.id,
                payload=TaskDraftPayload(
                    name=name,
                    description=f"Descrição {name}",
                    type="feature",
                ),
            )
            return task.card_number

    with ThreadPoolExecutor(max_workers=2) as pool:
        numbers = list(pool.map(worker, ("A", "B")))

    assert sorted(numbers) == [1, 2]
