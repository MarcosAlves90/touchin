from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import inspect, text

from app.config import get_settings
from app.crypto import FieldCipher


def _upgrade_projects(bind, inspector) -> None:
    if "projects" not in inspector.get_table_names():
        return

    project_columns = {column["name"] for column in inspector.get_columns("projects")}
    statements: list[str] = []
    if "task_employee_limit" not in project_columns:
        statements.append(
            "ALTER TABLE projects ADD COLUMN task_employee_limit INTEGER NOT NULL DEFAULT 1"
        )
    if "next_card_number" not in project_columns:
        statements.append(
            "ALTER TABLE projects ADD COLUMN next_card_number INTEGER NOT NULL DEFAULT 1"
        )
    if "kanban_version" not in project_columns:
        statements.append(
            "ALTER TABLE projects ADD COLUMN kanban_version INTEGER NOT NULL DEFAULT 0"
        )
    if not statements:
        return

    with bind.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


def _ensure_kanban_columns_table(bind, inspector) -> None:
    if "projects" not in inspector.get_table_names():
        return
    if "kanban_columns" not in inspector.get_table_names():
        timestamp_type = "TIMESTAMP" if bind.dialect.name == "postgresql" else "DATETIME"
        with bind.begin() as connection:
            connection.execute(
                text(
                    "CREATE TABLE kanban_columns ("
                    "id VARCHAR(64) PRIMARY KEY, "
                    "project_id VARCHAR(64) NOT NULL, "
                    "name_ciphertext TEXT NOT NULL, "
                    "position INTEGER NOT NULL, "
                    f"created_at {timestamp_type} NOT NULL, "
                    f"updated_at {timestamp_type} NOT NULL, "
                    "FOREIGN KEY(project_id) REFERENCES projects(id)"
                    ")"
                ),
            )
    with bind.begin() as connection:
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_kanban_columns_project_id "
                "ON kanban_columns (project_id)"
            ),
        )


def _add_task_kanban_columns(bind, inspector) -> None:
    task_columns = {column["name"] for column in inspector.get_columns("tasks")}
    with bind.begin() as connection:
        if "card_number" not in task_columns:
            connection.execute(text("ALTER TABLE tasks ADD COLUMN card_number INTEGER"))
        if "kanban_column_id" not in task_columns:
            kanban_column_sql = "ALTER TABLE tasks ADD COLUMN kanban_column_id VARCHAR(64)"
            if bind.dialect.name == "sqlite":
                kanban_column_sql += " REFERENCES kanban_columns(id)"
            connection.execute(text(kanban_column_sql))
        if "kanban_position" not in task_columns:
            connection.execute(text("ALTER TABLE tasks ADD COLUMN kanban_position INTEGER"))


def _get_or_create_initial_kanban_column(
    connection,
    *,
    project_id: str,
    field_cipher: FieldCipher,
    now: datetime,
) -> str:
    column_id = connection.execute(
        text(
            "SELECT id FROM kanban_columns "
            "WHERE project_id = :project_id ORDER BY position, id LIMIT 1"
        ),
        {"project_id": project_id},
    ).scalar_one_or_none()
    if column_id is not None:
        return column_id

    column_id = str(uuid4())
    connection.execute(
        text(
            "INSERT INTO kanban_columns "
            "(id, project_id, name_ciphertext, position, created_at, updated_at) "
            "VALUES (:id, :project_id, :name, 0, :created_at, :updated_at)"
        ),
        {
            "id": column_id,
            "project_id": project_id,
            "name": field_cipher.encrypt("A fazer") or "",
            "created_at": now,
            "updated_at": now,
        },
    )
    return column_id


def _load_project_tasks_for_kanban(connection, project_id: str):
    return connection.execute(
        text(
            "SELECT id, card_number, kanban_column_id, kanban_position "
            "FROM tasks WHERE project_id = :project_id "
            "ORDER BY created_at, id"
        ),
        {"project_id": project_id},
    ).mappings().all()


def _next_positions_by_column(rows, default_column_id: str) -> dict[str, int]:
    next_position_by_column: dict[str, int] = {}
    for row in rows:
        column_id = row["kanban_column_id"] or default_column_id
        position = row["kanban_position"]
        if position is None:
            continue
        next_position_by_column[column_id] = max(
            next_position_by_column.get(column_id, 0),
            int(position) + 1,
        )
    return next_position_by_column


def _backfill_project_tasks(
    connection,
    *,
    project_id: str,
    default_column_id: str,
) -> None:
    rows = _load_project_tasks_for_kanban(connection, project_id)
    used_numbers = {
        int(row["card_number"])
        for row in rows
        if row["card_number"] is not None
    }
    next_number = max(used_numbers, default=0) + 1
    next_position_by_column = _next_positions_by_column(rows, default_column_id)

    for row in rows:
        card_number = row["card_number"]
        if card_number is None:
            while next_number in used_numbers:
                next_number += 1
            card_number = next_number
            used_numbers.add(next_number)
            next_number += 1

        task_column_id = row["kanban_column_id"] or default_column_id
        task_position = row["kanban_position"]
        if task_position is None:
            task_position = next_position_by_column.get(task_column_id, 0)
            next_position_by_column[task_column_id] = int(task_position) + 1

        connection.execute(
            text(
                "UPDATE tasks SET card_number = :card_number, "
                "kanban_column_id = :column_id, kanban_position = :position "
                "WHERE id = :task_id"
            ),
            {
                "card_number": card_number,
                "column_id": task_column_id,
                "position": task_position,
                "task_id": row["id"],
            },
        )

    current_next_number = connection.execute(
        text("SELECT next_card_number FROM projects WHERE id = :project_id"),
        {"project_id": project_id},
    ).scalar_one()
    connection.execute(
        text(
            "UPDATE projects SET next_card_number = :next_card_number "
            "WHERE id = :project_id"
        ),
        {
            "next_card_number": max(
                int(current_next_number),
                max(used_numbers, default=0) + 1,
            ),
            "project_id": project_id,
        },
    )


def _backfill_tasks_for_kanban(bind) -> None:
    field_cipher = FieldCipher(get_settings().encryption_secret or "")
    now = datetime.now(timezone.utc)
    with bind.begin() as connection:
        project_ids = [
            row[0]
            for row in connection.execute(text("SELECT id FROM projects ORDER BY id")).all()
        ]
        for project_id in project_ids:
            default_column_id = _get_or_create_initial_kanban_column(
                connection,
                project_id=project_id,
                field_cipher=field_cipher,
                now=now,
            )
            _backfill_project_tasks(
                connection,
                project_id=project_id,
                default_column_id=default_column_id,
            )


def _ensure_task_kanban_indexes_and_sqlite_constraints(bind) -> None:
    with bind.begin() as connection:
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_task_card_number_per_project "
                "ON tasks (project_id, card_number)"
            ),
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_tasks_kanban_column_id "
                "ON tasks (kanban_column_id)"
            ),
        )
        if bind.dialect.name != "sqlite":
            return

        connection.execute(
            text(
                "CREATE TRIGGER IF NOT EXISTS trg_tasks_kanban_required_insert "
                "BEFORE INSERT ON tasks "
                "WHEN NEW.card_number IS NULL "
                "OR NEW.kanban_column_id IS NULL "
                "OR NEW.kanban_position IS NULL "
                "BEGIN "
                "SELECT RAISE(ABORT, 'Kanban task fields are required'); "
                "END"
            ),
        )
        connection.execute(
            text(
                "CREATE TRIGGER IF NOT EXISTS trg_tasks_kanban_required_update "
                "BEFORE UPDATE OF card_number, kanban_column_id, kanban_position ON tasks "
                "WHEN NEW.card_number IS NULL "
                "OR NEW.kanban_column_id IS NULL "
                "OR NEW.kanban_position IS NULL "
                "BEGIN "
                "SELECT RAISE(ABORT, 'Kanban task fields are required'); "
                "END"
            ),
        )


def _enforce_postgresql_task_kanban_constraints(bind) -> None:
    if bind.dialect.name != "postgresql":
        return

    refreshed = inspect(bind)
    task_columns = {column["name"]: column for column in refreshed.get_columns("tasks")}
    with bind.begin() as connection:
        for column_name in ("card_number", "kanban_column_id", "kanban_position"):
            if task_columns[column_name]["nullable"]:
                connection.execute(
                    text(f"ALTER TABLE tasks ALTER COLUMN {column_name} SET NOT NULL"),
                )

        foreign_key_names = {
            foreign_key.get("name")
            for foreign_key in refreshed.get_foreign_keys("tasks")
        }
        if "fk_tasks_kanban_column_id" not in foreign_key_names:
            connection.execute(
                text(
                    "ALTER TABLE tasks ADD CONSTRAINT fk_tasks_kanban_column_id "
                    "FOREIGN KEY(kanban_column_id) REFERENCES kanban_columns(id)"
                ),
            )


def _upgrade_tasks_for_kanban(bind, inspector) -> None:
    table_names = inspector.get_table_names()
    if "tasks" not in table_names or "projects" not in table_names:
        return

    _add_task_kanban_columns(bind, inspector)
    _backfill_tasks_for_kanban(bind)
    _ensure_task_kanban_indexes_and_sqlite_constraints(bind)
    _enforce_postgresql_task_kanban_constraints(bind)


def _upgrade_punches(bind, inspector) -> None:
    if "punches" not in inspector.get_table_names():
        return

    punch_columns = {column["name"] for column in inspector.get_columns("punches")}
    if "project_id" in punch_columns:
        return

    with bind.begin() as connection:
        connection.execute(text("ALTER TABLE punches ADD COLUMN project_id VARCHAR(64)"))
        connection.execute(text("CREATE INDEX IF NOT EXISTS ix_punches_project_id ON punches (project_id)"))

        if bind.dialect.name == "postgresql" and "projects" in inspector.get_table_names():
            foreign_keys = {
                foreign_key.get("name")
                for foreign_key in inspector.get_foreign_keys("punches")
            }
            if "fk_punches_project_id_projects" not in foreign_keys:
                connection.execute(
                    text(
                        "ALTER TABLE punches "
                        "ADD CONSTRAINT fk_punches_project_id_projects "
                        "FOREIGN KEY(project_id) REFERENCES projects(id)",
                    ),
                )


def _upgrade_audit_events(bind, inspector) -> None:
    if "audit_events" not in inspector.get_table_names():
        return
    if bind.dialect.name == "postgresql":
        foreign_keys = {
            foreign_key.get("name")
            for foreign_key in inspector.get_foreign_keys("audit_events")
        }
        fk_name = "fk_audit_events_actor_user_id_user_accounts"
        # We also might need to find the FK dynamically if it has a generated name
        for fk in inspector.get_foreign_keys("audit_events"):
            if "actor_user_id" in fk.get("constrained_columns", []):
                fk_name = fk.get("name")
                if fk_name:
                    with bind.begin() as connection:
                        connection.execute(text(f"ALTER TABLE audit_events DROP CONSTRAINT {fk_name}"))
    elif bind.dialect.name == "sqlite":
        has_fk = False
        for fk in inspector.get_foreign_keys("audit_events"):
            if "actor_user_id" in fk.get("constrained_columns", []):
                has_fk = True
                break
        if has_fk:
            with bind.begin() as connection:
                connection.execute(text("PRAGMA foreign_keys=off;"))
                connection.execute(text("""
                    CREATE TABLE audit_events_new (
                        id VARCHAR(64) NOT NULL, 
                        timestamp DATETIME, 
                        company_id VARCHAR(64) NOT NULL, 
                        actor_user_id VARCHAR(64), 
                        project_id VARCHAR(64), 
                        action VARCHAR(128) NOT NULL, 
                        entity_type VARCHAR(64) NOT NULL, 
                        entity_id VARCHAR(64) NOT NULL, 
                        result VARCHAR(32) NOT NULL, 
                        metadata_payload TEXT, 
                        correlation_id VARCHAR(64), 
                        PRIMARY KEY (id), 
                        FOREIGN KEY(company_id) REFERENCES companies (id) ON DELETE CASCADE, 
                        FOREIGN KEY(project_id) REFERENCES projects (id) ON DELETE CASCADE
                    );
                """))
                connection.execute(text("""
                    INSERT INTO audit_events_new SELECT id, timestamp, company_id, actor_user_id, project_id, action, entity_type, entity_id, result, metadata_payload, correlation_id FROM audit_events;
                """))
                connection.execute(text("DROP TABLE audit_events;"))
                connection.execute(text("ALTER TABLE audit_events_new RENAME TO audit_events;"))
                connection.execute(text("CREATE INDEX ix_audit_events_action ON audit_events (action);"))
                connection.execute(text("CREATE INDEX ix_audit_events_company_id ON audit_events (company_id);"))
                connection.execute(text("CREATE INDEX ix_audit_events_correlation_id ON audit_events (correlation_id);"))
                connection.execute(text("PRAGMA foreign_keys=on;"))


def upgrade_database_schema(bind) -> None:
    inspector = inspect(bind)
    _upgrade_projects(bind, inspector)
    inspector = inspect(bind)
    _ensure_kanban_columns_table(bind, inspector)
    inspector = inspect(bind)
    _upgrade_tasks_for_kanban(bind, inspector)
    inspector = inspect(bind)
    _upgrade_punches(bind, inspector)
    inspector = inspect(bind)
    _upgrade_audit_events(bind, inspector)
