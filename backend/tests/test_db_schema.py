from sqlalchemy import create_engine, inspect, text

from app.database_schema import upgrade_database_schema


def test_upgrade_database_schema_adds_project_id_to_legacy_punches_table(tmp_path):
    database_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{database_path}", future=True)
    with engine.begin() as connection:
        connection.execute(
            text(
                "CREATE TABLE punches ("
                "id VARCHAR(64) PRIMARY KEY, "
                "company_id VARCHAR(64) NOT NULL, "
                "employee_id VARCHAR(64) NOT NULL, "
                "type VARCHAR(32) NOT NULL, "
                "timestamp DATETIME NOT NULL, "
                "detail_ciphertext TEXT NOT NULL, "
                "location_payload_ciphertext TEXT, "
                "created_at DATETIME NOT NULL"
                ")",
            ),
        )

    upgrade_database_schema(engine)

    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("punches")}
    indexes = {index["name"] for index in inspector.get_indexes("punches")}
    assert "project_id" in columns
    assert "ix_punches_project_id" in indexes


def test_upgrade_database_schema_adds_task_employee_limit_to_legacy_projects(tmp_path):
    database_path = tmp_path / "legacy-projects.db"
    engine = create_engine(f"sqlite:///{database_path}", future=True)
    with engine.begin() as connection:
        connection.execute(
            text(
                "CREATE TABLE projects ("
                "id VARCHAR(64) PRIMARY KEY, "
                "company_id VARCHAR(64) NOT NULL, "
                "name_ciphertext TEXT NOT NULL, "
                "description_ciphertext TEXT, "
                "status VARCHAR(32) NOT NULL, "
                "created_at DATETIME NOT NULL, "
                "updated_at DATETIME NOT NULL"
                ")",
            ),
        )
        connection.execute(
            text(
                "INSERT INTO projects "
                "(id, company_id, name_ciphertext, description_ciphertext, status, created_at, updated_at) "
                "VALUES ('project-legacy', 'company-legacy', 'name', 'description', 'active', "
                "'2026-01-01', '2026-01-01')"
            ),
        )

    upgrade_database_schema(engine)

    columns = {column["name"]: column for column in inspect(engine).get_columns("projects")}
    assert "task_employee_limit" in columns
    assert columns["task_employee_limit"]["nullable"] is False
    with engine.connect() as connection:
        default_value = connection.execute(
            text("select task_employee_limit from projects where id = 'project-legacy'"),
        ).scalar_one()
        assert default_value == 1
