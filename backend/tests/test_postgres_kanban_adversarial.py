"""Real PostgreSQL READ COMMITTED adversarial tests.

Run only against an isolated disposable database:
TOUCHIN_PR67_PG_URL=postgresql+psycopg2:///touchin_pr67_adversarial_... \
  .venv/bin/pytest -q tests/test_postgres_kanban_adversarial.py
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import timezone
from os import getenv
from threading import Barrier, Event

import pytest
from sqlalchemy import create_engine, event, inspect, select, text
from sqlalchemy.orm import Session, sessionmaker

from app.db import Base
from app.domain.kanban_read import get_kanban_board
from app.domain.task_read import get_task
from app.errors import DomainError, ErrorKind
from app.models import Employee, EmployeeProject, Project, Task
from app.schemas.kanban import KanbanCardOrderPayload
from app.schemas.project import ProjectDraftPayload
from app.schemas.task import TaskDraftPayload, TaskUpdatePayload
from app.seed import seed_database
from app.services.kanban import reorder_cards
from app.services.projects import assign_project_member, create_project
from app.services.employees import delete_employee
from app.services.tasks import add_task_member, create_task, remove_task_member, update_task

COMPANY = "company-touchin"


@pytest.fixture
def pg():
    url = getenv("TOUCHIN_PR67_PG_URL", "")
    if not url:
        pytest.skip("Set TOUCHIN_PR67_PG_URL to an isolated PostgreSQL test database.")
    engine = create_engine(
        url, future=True, isolation_level="READ COMMITTED",
        pool_size=12, max_overflow=4, connect_args={"connect_timeout": 4},
    )
    with engine.connect() as connection:
        name = connection.scalar(text("SELECT current_database()"))
        isolation = connection.scalar(text("SHOW transaction_isolation"))
    if not name.startswith("touchin_pr67_adversarial_") or isolation != "read committed":
        engine.dispose()
        pytest.fail("Refusing to mutate a non-isolated or non-READ COMMITTED database.")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    SessionFactory = sessionmaker(bind=engine, expire_on_commit=False)
    with SessionFactory() as db:
        seed_database(db)
    try:
        yield SessionFactory, engine
    finally:
        engine.dispose()


def _setup(db, *, cards=2):
    project = create_project(
        db, company_id=COMPANY,
        payload=ProjectDraftPayload(name="Adversarial PostgreSQL", description="READ COMMITTED"),
    )
    tasks = [
        create_task(
            db, company_id=COMPANY, project_id=project.id,
            payload=TaskDraftPayload(name=f"Card {index}", description=f"Descrição {index}",
                                     type="feature"),
        )
        for index in range(cards)
    ]
    board = get_kanban_board(db, company_id=COMPANY, project_id=project.id)
    return project.id, tasks, board


def test_timestamp_collision_can_overwrite_newer_card_with_legacy_occ(pg):
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, (task,), board = _setup(db, cards=1)
    # Deliberately force the database timestamp to remain unchanged after
    # an actual content update: equality of timestamps is not a revision.
    with engine.begin() as connection:
        connection.execute(text("""
            CREATE OR REPLACE FUNCTION pr67_freeze_updated_at() RETURNS trigger AS $$
            BEGIN NEW.updated_at := OLD.updated_at; RETURN NEW; END;
            $$ LANGUAGE plpgsql
        """))
        connection.execute(text("""
            CREATE TRIGGER pr67_freeze_task_timestamp
            BEFORE UPDATE ON tasks
            FOR EACH ROW EXECUTE FUNCTION pr67_freeze_updated_at()
        """))
    stale = task.updated_at
    stale_revision = task.revision
    with SessionFactory() as db:
        update_task(
            db, company_id=COMPANY, project_id=project_id, task_id=task.id,
            payload=TaskUpdatePayload(
                name="Editor A", description="Salvo por A", type="feature",
                expected_updated_at=stale,
                expected_revision=stale_revision,
            ),
        )
    with SessionFactory() as db:
        try:
            update_task(
                db, company_id=COMPANY, project_id=project_id, task_id=task.id,
                payload=TaskUpdatePayload(
                    name="Editor B", description="Sobrescreve A", type="feature",
                    expected_updated_at=stale,
                    expected_revision=stale_revision,
                ),
            )
        except DomainError as exc:
            assert exc.code == "task_version_conflict"
            db.rollback()
        else:
            pytest.fail("Stale editor overwrote changes when updatedAt collided.")
    with SessionFactory() as db:
        assert get_task(db, company_id=COMPANY, project_id=project_id,
                        task_id=task.id).name == "Editor A"


def test_high_contention_between_backlog_reorder_and_card_updates(pg):
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, cards, board = _setup(db)
    version = board.kanban_version
    column_id = board.columns[0].id
    barrier = Barrier(12)

    def worker(index):
        with SessionFactory() as db:
            barrier.wait(timeout=20)
            try:
                if index % 2 == 0:
                    reorder_cards(
                        db, company_id=COMPANY, project_id=project_id,
                        payload=KanbanCardOrderPayload(
                            expected_version=version,
                            columns=[{"columnId": column_id,
                                      "taskIds": [cards[1].id, cards[0].id]}],
                        ),
                    )
                    return "reorder"
                update_task(
                    db, company_id=COMPANY, project_id=project_id,
                    task_id=cards[0].id,
                    payload=TaskUpdatePayload(
                        name=f"Editor {index}", description="Salvo", type="feature",
                        expected_version=version,
                    ),
                )
                return "edit"
            except DomainError as exc:
                assert exc.kind == ErrorKind.conflict
                db.rollback()
                return "conflict"

    with ThreadPoolExecutor(max_workers=12) as pool:
        results = list(pool.map(worker, range(12)))
    assert results.count("conflict") == 11, results
    assert results.count("edit") + results.count("reorder") == 1, results
    with SessionFactory() as db:
        latest = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
        assert latest.kanban_version == version + 1
        assert {card.id for col in latest.columns for card in col.cards} == {
            cards[0].id, cards[1].id
        }


def test_snapshot_read_interleaved_with_committed_writer_is_coherent(pg):
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, (task,), board = _setup(db, cards=1)

    paused = Event()
    continue_read = Event()
    seen = {"count": 0}

    def reader():
        with SessionFactory() as db:
            db.info["interleave_pg"] = True
            return get_kanban_board(db, company_id=COMPANY, project_id=project_id)

    def before_select(state):
        if state.session.info.get("interleave_pg") and "FROM tasks" in str(state.statement):
            if seen["count"] == 0:
                seen["count"] += 1
                paused.set()
                assert continue_read.wait(timeout=10)

    event.listen(Session, "do_orm_execute", before_select)
    try:
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(reader)
            assert paused.wait(timeout=10), "Reader never reached the tasks query."
            try:
                with SessionFactory() as writer:
                    update_task(
                        writer, company_id=COMPANY, project_id=project_id,
                        task_id=task.id,
                        payload=TaskUpdatePayload(
                            name="Novo título", description="Modificado", type="feature",
                            expected_version=board.kanban_version,
                        ),
                    )
            finally:
                continue_read.set()
            observed = future.result(timeout=10)
    finally:
        event.remove(Session, "do_orm_execute", before_select)

    assert observed.kanban_version == board.kanban_version + 1
    assert observed.columns[0].cards[0].name == "Novo título"


def test_delete_employee_concurrent_with_reorders_keeps_all_boards_consistent(pg):
    SessionFactory, engine = pg
    prepared = []
    with SessionFactory() as db:
        for index in range(2):
            project_id, cards, board = _setup(db)
            assign_project_member(
                db, company_id=COMPANY, project_id=project_id, employee_id="emp-04",
            )
            add_task_member(
                db, company_id=COMPANY, project_id=project_id,
                task_id=cards[0].id, employee_id="emp-04",
            )
            prepared.append(
                (project_id, cards, get_kanban_board(
                    db, company_id=COMPANY, project_id=project_id))
            )

    barrier = Barrier(3)

    def remove_global_employee():
        with SessionFactory() as db:
            barrier.wait(timeout=12)
            delete_employee(db, company_id=COMPANY, employee_id="emp-04")
            return "deleted"

    def reorder(item):
        project_id, cards, board = item
        with SessionFactory() as db:
            barrier.wait(timeout=12)
            try:
                reorder_cards(
                    db, company_id=COMPANY, project_id=project_id,
                    payload=KanbanCardOrderPayload(
                        expected_version=board.kanban_version,
                        columns=[{
                            "columnId": board.columns[0].id,
                            "taskIds": [cards[1].id, cards[0].id],
                        }],
                    ),
                )
                return "reordered"
            except DomainError as exc:
                assert exc.code == "kanban_version_conflict"
                db.rollback()
                return "stale"

    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs = [
            executor.submit(remove_global_employee),
            *(executor.submit(reorder, item) for item in prepared),
        ]
        results = [job.result(timeout=20) for job in jobs]
    assert results[0] == "deleted"
    with SessionFactory() as db:
        assert db.get(Employee, "emp-04") is None
        for (project_id, cards, before), outcome in zip(prepared, results[1:]):
            current = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
            assert current.kanban_version == (
                before.kanban_version + 1 + (outcome == "reordered")
            )
            assert len(current.columns[0].cards) == 2
            assert all(card.assignees == [] for card in current.columns[0].cards)
            if outcome == "reordered":
                assert current.columns[0].cards[0].id == cards[1].id
            else:
                assert current.columns[0].cards[0].id == cards[0].id


def test_rolled_back_employee_delete_preserves_assignees_and_versions(pg, monkeypatch):
    from app.services.audit import AuditService

    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, cards, board = _setup(db)
        assign_project_member(
            db, company_id=COMPANY, project_id=project_id, employee_id="emp-04",
        )
        add_task_member(
            db, company_id=COMPANY, project_id=project_id,
            task_id=cards[0].id, employee_id="emp-04",
        )
        before = get_kanban_board(db, company_id=COMPANY, project_id=project_id)

    previous = AuditService.log_action

    def reject_delete(*args, **kwargs):
        if kwargs.get("action") == "employee.deleted":
            raise RuntimeError("injected audit failure before commit")
        return previous(*args, **kwargs)

    monkeypatch.setattr(AuditService, "log_action", reject_delete)
    with SessionFactory() as db:
        with pytest.raises(RuntimeError, match="injected audit failure"):
            delete_employee(db, company_id=COMPANY, employee_id="emp-04")
        db.rollback()
    with SessionFactory() as db:
        assert db.get(Employee, "emp-04") is not None
        current = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
        assert current.kanban_version == before.kanban_version
        assert [member.employee_id for member in current.columns[0].cards[0].assignees] == [
            "emp-04"
        ]


def test_legacy_put_without_precondition_still_allows_lost_update(pg):
    """Preserve legacy API; explicitly document the unresolved compatibility risk."""
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, (task,), board = _setup(db, cards=1)
        first = update_task(
            db, company_id=COMPANY, project_id=project_id, task_id=task.id,
            payload=TaskUpdatePayload(
                name="Editor atual", description="Texto novo", type="feature",
                expected_revision=task.revision,
            ),
        )
    with SessionFactory() as db:
        legacy = update_task(
            db, company_id=COMPANY, project_id=project_id, task_id=task.id,
            payload=TaskUpdatePayload(
                name="Editor antigo", description="Texto obsoleto", type="feature",
            ),
        )
    assert legacy.revision == first.revision + 1
    assert legacy.description == "Texto obsoleto"


def test_reorder_waiting_for_project_lock_cannot_ignore_revoked_membership(pg):
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, cards, board = _setup(db)
        assign_project_member(
            db, company_id=COMPANY, project_id=project_id, employee_id="emp-04",
        )
    begun = Event()

    def queued_reorder():
        with SessionFactory() as db:
            begun.set()
            try:
                reorder_cards(
                    db, company_id=COMPANY, project_id=project_id,
                    employee_id="emp-04",
                    payload=KanbanCardOrderPayload(
                        expected_version=board.kanban_version,
                        columns=[{
                            "columnId": board.columns[0].id,
                            "taskIds": [cards[1].id, cards[0].id],
                        }],
                    ),
                )
            except DomainError as exc:
                db.rollback()
                return exc.kind, exc.code
            return None

    with SessionFactory() as revoker:
        revoker.scalar(
            select(Project).where(Project.id == project_id).with_for_update()
        )
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(queued_reorder)
            assert begun.wait(timeout=10)
            link = revoker.scalar(
                select(EmployeeProject).where(
                    EmployeeProject.project_id == project_id,
                    EmployeeProject.employee_id == "emp-04",
                ),
            )
            revoker.delete(link)
            revoker.commit()
            result = future.result(timeout=10)
    assert result == (ErrorKind.not_found, None)
    with SessionFactory() as db:
        unchanged = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
        assert unchanged.kanban_version == board.kanban_version
        assert [card.id for card in unchanged.columns[0].cards] == [
            cards[0].id, cards[1].id
        ]


@pytest.mark.parametrize("operation", ["add", "remove"])
def test_assignee_write_waiting_for_project_lock_rechecks_requester_access(pg, operation):
    SessionFactory, _ = pg
    with SessionFactory() as db:
        project_id, (card,), _ = _setup(db, cards=1)
        for employee_id in ("emp-04", "emp-05"):
            assign_project_member(
                db, company_id=COMPANY, project_id=project_id, employee_id=employee_id,
            )
        if operation == "remove":
            add_task_member(
                db, company_id=COMPANY, project_id=project_id,
                task_id=card.id, employee_id="emp-05",
            )
        before = get_kanban_board(db, company_id=COMPANY, project_id=project_id)

    started = Event()

    def queued_write():
        with SessionFactory() as db:
            started.set()
            try:
                write = add_task_member if operation == "add" else remove_task_member
                write(
                    db, company_id=COMPANY, project_id=project_id,
                    task_id=card.id, employee_id="emp-05",
                    requester_employee_id="emp-04",
                )
            except DomainError as exc:
                db.rollback()
                return exc.kind
            return None

    with SessionFactory() as revoker:
        revoker.scalar(select(Project).where(Project.id == project_id).with_for_update())
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(queued_write)
            assert started.wait(timeout=10)
            link = revoker.scalar(select(EmployeeProject).where(
                EmployeeProject.project_id == project_id,
                EmployeeProject.employee_id == "emp-04",
            ))
            assert link is not None
            revoker.delete(link)
            revoker.commit()
            assert future.result(timeout=10) == ErrorKind.not_found

    with SessionFactory() as db:
        after = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
        assert after.kanban_version == before.kanban_version
        assert [member.employee_id for member in after.columns[0].cards[0].assignees] == [
            member.employee_id for member in before.columns[0].cards[0].assignees
        ]


def test_many_readers_never_receive_torn_card_snapshot_under_writes(pg):
    SessionFactory, engine = pg
    with SessionFactory() as db:
        project_id, (task,), board = _setup(db, cards=1)
    barrier = Barrier(4)

    def writer():
        barrier.wait(timeout=10)
        for number in range(15):
            with SessionFactory() as db:
                update_task(
                    db, company_id=COMPANY, project_id=project_id,
                    task_id=task.id,
                    payload=TaskUpdatePayload(
                        name=f"Versão {board.kanban_version + number + 1}",
                        description="Estado integral", type="feature",
                    ),
                )
        return 15

    def reader():
        coherent, retried = 0, 0
        barrier.wait(timeout=10)
        for _ in range(30):
            with SessionFactory() as db:
                try:
                    snapshot = get_kanban_board(
                        db, company_id=COMPANY, project_id=project_id,
                    )
                except DomainError as exc:
                    assert exc.code == "kanban_snapshot_conflict"
                    db.rollback()
                    retried += 1
                    continue
                card = snapshot.columns[0].cards[0]
                assert card.name in {
                    "Card 0", f"Versão {snapshot.kanban_version}",
                }, (snapshot.kanban_version, card.name)
                assert card.description in {"Descrição 0", "Estado integral"}
                coherent += 1
        return coherent, retried

    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(writer), *(pool.submit(reader) for _ in range(3))]
        results = [future.result(timeout=30) for future in futures]
    assert results[0] == 15
    assert sum(coherent for coherent, _ in results[1:]) >= 50
    with SessionFactory() as db:
        final = get_kanban_board(db, company_id=COMPANY, project_id=project_id)
        assert final.kanban_version == board.kanban_version + 15
        assert final.columns[0].cards[0].name == f"Versão {final.kanban_version}"


def test_http_backlog_task_edit_and_kanban_reorder_share_revision_contract(pg):
    from fastapi.testclient import TestClient

    from app.dependencies import get_db
    from app.main import create_app
    from test_api import TEST_SEED_SECRET, login_headers_for

    SessionFactory, engine = pg
    app = create_app()

    def isolated_pg_db():
        with SessionFactory() as db:
            yield db

    app.dependency_overrides[get_db] = isolated_pg_db
    try:
        with TestClient(app) as client:
            headers = login_headers_for(
                client, email="caio.martins@touchin.com",
                password=TEST_SEED_SECRET,
            )
            project_id = client.post(
                "/api/v1/projects", headers=headers,
                json={"name": "Integração real", "description": "API PostgreSQL"},
            ).json()["id"]
            card = client.post(
                f"/api/v1/projects/{project_id}/tasks", headers=headers,
                json={"name": "Backlog", "description": "Original", "type": "feature"},
            )
            assert card.status_code == 201, card.text
            initial = card.json()
            assert initial["revision"] == 0
            url = f"/api/v1/projects/{project_id}/tasks/{initial['id']}"
            changed = client.put(
                url, headers=headers,
                json={"name": "Editado no Backlog", "description": "Versão 1",
                      "type": "feature", "expectedRevision": 0,
                      "expectedUpdatedAt": initial["updatedAt"]},
            )
            assert changed.status_code == 200, changed.text
            assert changed.json()["revision"] == 1
            stale = client.put(
                url, headers=headers,
                json={"name": "Editor obsoleto", "description": "Perda de edição",
                      "type": "feature", "expectedRevision": 0},
            )
            assert stale.status_code == 409
            assert stale.json()["code"] == "task_version_conflict"
            board = client.get(
                f"/api/v1/projects/{project_id}/kanban", headers=headers,
            )
            assert board.status_code == 200, board.text
            board_data = board.json()
            first = board_data["columns"][0]
            assert first["cards"][0]["revision"] == 1
            assert first["cards"][0]["name"] == "Editado no Backlog"
            reordered = client.put(
                f"/api/v1/projects/{project_id}/kanban/cards/order",
                headers=headers,
                json={"expectedVersion": board_data["kanbanVersion"], "columns": [
                    {"columnId": first["id"], "taskIds": [initial["id"]]},
                ]},
            )
            assert reordered.status_code == 200, reordered.text
            assert reordered.json()["kanbanVersion"] == board_data["kanbanVersion"] + 1
            assert reordered.json()["columns"][0]["cards"][0]["revision"] == 1
    finally:
        app.dependency_overrides.clear()
