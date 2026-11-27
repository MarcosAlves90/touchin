from datetime import datetime, timedelta, timezone

from sqlalchemy import event, select

from app.db import SessionLocal, engine
from app.domain.time_clock_read import _paginate_query_records
from app.models import Punch


def test_managed_count_does_not_sort_but_pages_keep_deterministic_order(client):
    timestamp = datetime(2026, 5, 1, tzinfo=timezone.utc)
    with SessionLocal() as db:
        db.add_all(
            [
                Punch(
                    id=f"count-punch-{index}",
                    company_id="company-touchin",
                    employee_id="emp-02",
                    type="checkIn",
                    timestamp=timestamp + timedelta(minutes=index // 2),
                    detail_ciphertext="not-decrypted-by-this-test",
                )
                for index in range(5)
            ]
        )
        db.commit()

    statements = []

    def record_sql(connection, cursor, statement, parameters, context, executemany):
        if "FROM punches" in statement:
            statements.append((statement, parameters))

    event.listen(engine, "before_cursor_execute", record_sql)
    try:
        with SessionLocal() as db:
            query = (
                select(Punch)
                .where(
                    Punch.company_id == "company-touchin",
                    Punch.employee_id == "emp-02",
                    Punch.id.like("count-punch-%"),
                )
                .order_by(Punch.timestamp.desc(), Punch.id.desc())
            )
            first = _paginate_query_records(db, query=query, page=1, page_size=2)
            second = _paginate_query_records(db, query=query, page=2, page_size=2)
            last = _paginate_query_records(db, query=query, page=999, page_size=2)
            before_first = _paginate_query_records(db, query=query, page=0, page_size=2)
    finally:
        event.remove(engine, "before_cursor_execute", record_sql)

    assert [record.id for record in first[0]] == ["count-punch-4", "count-punch-3"]
    assert [record.id for record in second[0]] == ["count-punch-2", "count-punch-1"]
    assert [record.id for record in last[0]] == ["count-punch-0"]
    assert [record.id for record in before_first[0]] == ["count-punch-4", "count-punch-3"]
    assert first[1:] == (1, 2, 5, 3, False, True)
    assert second[1:] == (2, 2, 5, 3, True, True)
    assert last[1:] == (3, 2, 5, 3, True, False)

    count_statements = [
        (sql, parameters)
        for sql, parameters in statements
        if "count(" in sql.lower()
    ]
    assert len(count_statements) == 4
    for statement, parameters in count_statements:
        assert "ORDER BY" not in statement.upper()
        assert "punches.company_id" in statement
        assert "punches.employee_id" in statement
        with engine.connect() as connection:
            plan = connection.exec_driver_sql(
                "EXPLAIN QUERY PLAN " + statement,
                parameters,
            ).all()
        assert not any("TEMP B-TREE" in row[3].upper() for row in plan)

    page_statements = [sql for sql, _ in statements if "LIMIT" in sql.upper()]
    assert len(page_statements) == 4
    assert all(
        "ORDER BY punches.timestamp DESC, punches.id DESC" in sql
        for sql in page_statements
    )


def test_managed_pagination_with_no_matches_has_one_empty_page(client):
    with SessionLocal() as db:
        query = (
            select(Punch)
            .where(
                Punch.company_id == "company-touchin",
                Punch.employee_id == "no-such-employee",
            )
            .order_by(Punch.timestamp.desc(), Punch.id.desc())
        )
        assert _paginate_query_records(
            db, query=query, page=99, page_size=2,
        ) == ([], 1, 2, 0, 1, False, False)
