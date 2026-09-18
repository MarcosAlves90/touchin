from __future__ import annotations

from sqlalchemy import inspect, text


def _upgrade_projects(bind, inspector) -> None:
    if "projects" not in inspector.get_table_names():
        return

    project_columns = {column["name"] for column in inspector.get_columns("projects")}
    if "task_employee_limit" in project_columns:
        return

    with bind.begin() as connection:
        connection.execute(
            text(
                "ALTER TABLE projects "
                "ADD COLUMN task_employee_limit INTEGER NOT NULL DEFAULT 1"
            ),
        )


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


def upgrade_database_schema(bind) -> None:
    inspector = inspect(bind)
    _upgrade_projects(bind, inspector)
    inspector = inspect(bind)
    _upgrade_punches(bind, inspector)
