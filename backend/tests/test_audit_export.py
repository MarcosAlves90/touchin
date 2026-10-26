from __future__ import annotations

import csv
import io
from datetime import datetime, timedelta, timezone

from app.db import SessionLocal
from app.models import AuditEvent, Company
from app.seed import CAIO_EMAIL, JOAO_EMAIL, MARINA_EMAIL
from app.services.audit_export import CSV_COLUMNS

from tests.test_audit import login_headers

EXPORT_ENTITY_TYPE = "export-contract"


def _company_id() -> str:
    with SessionLocal() as db:
        company = db.query(Company).first()
        assert company is not None
        return company.id


def _add_events(events: list[AuditEvent]) -> None:
    with SessionLocal() as db:
        db.add_all(events)
        db.commit()


def _event(
    event_id: str,
    *,
    company_id: str,
    timestamp: datetime,
    entity_id: str,
    entity_type: str = EXPORT_ENTITY_TYPE,
    action: str = "export.test",
    result: str = "success",
    actor_user_id: str | None = "user-marina",
    project_id: str | None = None,
) -> AuditEvent:
    return AuditEvent(
        id=event_id,
        company_id=company_id,
        actor_user_id=actor_user_id,
        project_id=project_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        result=result,
        timestamp=timestamp,
    )


def _parse_csv(response) -> list[list[str]]:
    text = response.content.decode("utf-8-sig")
    return list(csv.reader(io.StringIO(text)))


def _export_headers(client) -> dict[str, str]:
    return login_headers(client, MARINA_EMAIL)


def test_export_returns_every_matching_record_across_pages_in_stable_order(client):
    company_id = _company_id()
    base = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
    events = [
        _event(
            f"evt_export_{index:03d}",
            company_id=company_id,
            timestamp=base - timedelta(seconds=index),
            entity_id=f"row-{index:03d}",
        )
        for index in range(130)
    ]
    # Same timestamp exercises the id tiebreaker and the second page.
    events.append(
        _event(
            "evt_export_tie_a",
            company_id=company_id,
            timestamp=base,
            entity_id="tie-a",
            entity_type="export-tie",
        )
    )
    events.append(
        _event(
            "evt_export_tie_b",
            company_id=company_id,
            timestamp=base,
            entity_id="tie-b",
            entity_type="export-tie",
        )
    )
    events.append(
        _event(
            "evt_export_other_type",
            company_id=company_id,
            timestamp=base,
            entity_id="other-type",
            entity_type="other-contract",
        )
    )
    events.append(
        _event(
            "evt_export_other_company",
            company_id="comp_fake",
            timestamp=base,
            entity_id="other-company",
        )
    )
    _add_events(events)

    headers = _export_headers(client)
    params = {"entity_type": EXPORT_ENTITY_TYPE, "action": "export.test"}

    first_page = client.get(
        "/api/v1/audit-events", headers=headers, params={**params, "limit": 100}
    )
    second_page = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={**params, "limit": 100, "page": 2},
    )
    assert first_page.status_code == 200
    assert second_page.status_code == 200
    listed_entity_ids = [
        event["entity_id"] for event in first_page.json() + second_page.json()
    ]

    response = client.get(
        "/api/v1/audit-events/export", headers=headers, params=params
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-audit-export-rows"] == "130"
    assert "audit-events-" in response.headers["content-disposition"]
    assert "content-length" not in response.headers

    rows = _parse_csv(response)
    assert rows[0] == list(CSV_COLUMNS)
    exported_entity_ids = [row[5] for row in rows[1:]]
    assert exported_entity_ids == listed_entity_ids
    assert len(exported_entity_ids) == 130
    assert "other-type" not in exported_entity_ids
    assert "other-company" not in exported_entity_ids

    ties = client.get(
        "/api/v1/audit-events/export",
        headers=headers,
        params={"entity_type": "export-tie"},
    )
    tie_rows = _parse_csv(ties)
    assert [row[5] for row in tie_rows[1:]] == ["tie-b", "tie-a"]


def test_export_requires_audit_read_permission(client):
    for email in (JOAO_EMAIL, CAIO_EMAIL):
        response = client.get(
            "/api/v1/audit-events/export", headers=login_headers(client, email)
        )
        if email == CAIO_EMAIL and response.status_code == 200:
            continue
        assert response.status_code == 403


def test_export_does_not_leak_another_company(client):
    company_id = _company_id()
    _add_events(
        [
            _event(
                "evt_export_mine",
                company_id=company_id,
                timestamp=datetime(2026, 4, 2, tzinfo=timezone.utc),
                entity_id="mine",
            ),
            _event(
                "evt_export_theirs",
                company_id="comp_other",
                timestamp=datetime(2026, 4, 3, tzinfo=timezone.utc),
                entity_id="theirs",
            ),
        ]
    )

    response = client.get(
        "/api/v1/audit-events/export",
        headers=_export_headers(client),
        params={"entity_type": EXPORT_ENTITY_TYPE},
    )

    assert response.status_code == 200
    assert response.headers["x-audit-export-rows"] == "1"
    rows = _parse_csv(response)
    assert [row[5] for row in rows[1:]] == ["mine"]


def test_export_keeps_existing_date_filter_semantics(client):
    company_id = _company_id()
    start = datetime(2026, 5, 1, tzinfo=timezone.utc)
    end = datetime(2026, 5, 2, tzinfo=timezone.utc)
    _add_events(
        [
            _event(
                "evt_export_before",
                company_id=company_id,
                timestamp=start - timedelta(seconds=1),
                entity_id="before",
            ),
            _event(
                "evt_export_start",
                company_id=company_id,
                timestamp=start,
                entity_id="at-start",
            ),
            _event(
                "evt_export_inside",
                company_id=company_id,
                timestamp=start + timedelta(hours=12),
                entity_id="inside",
            ),
            _event(
                "evt_export_end",
                company_id=company_id,
                timestamp=end,
                entity_id="at-end",
            ),
        ]
    )

    params = {
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "entity_type": EXPORT_ENTITY_TYPE,
    }
    headers = _export_headers(client)

    listed = client.get("/api/v1/audit-events", headers=headers, params=params)
    exported = client.get(
        "/api/v1/audit-events/export", headers=headers, params=params
    )

    assert listed.status_code == 200
    assert exported.status_code == 200
    assert [row[5] for row in _parse_csv(exported)[1:]] == [
        event["entity_id"] for event in listed.json()
    ]
    assert [row[5] for row in _parse_csv(exported)[1:]] == ["inside", "at-start"]


def test_export_escapes_rfc4180_and_neutralizes_formulas(client):
    company_id = _company_id()
    timestamp = datetime(2026, 6, 1, 8, 30, 15, tzinfo=timezone.utc)
    _add_events(
        [
            _event(
                "evt_export_escaped",
                company_id=company_id,
                timestamp=timestamp,
                entity_id='quoted, "comma"\nnew line',
                action="export.safety",
                actor_user_id="usuário-ç",
                project_id="proj-1",
            ),
            _event(
                "evt_export_formula_equals",
                company_id=company_id,
                timestamp=timestamp - timedelta(seconds=1),
                entity_id="=1+1",
                action="export.safety",
            ),
            _event(
                "evt_export_formula_plus",
                company_id=company_id,
                timestamp=timestamp - timedelta(seconds=2),
                entity_id="+SUM(A1)",
                action="export.safety",
            ),
            _event(
                "evt_export_formula_minus",
                company_id=company_id,
                timestamp=timestamp - timedelta(seconds=3),
                entity_id="-2+3",
                action="export.safety",
            ),
            _event(
                "evt_export_formula_at",
                company_id=company_id,
                timestamp=timestamp - timedelta(seconds=4),
                entity_id="@SUM(A1)",
                action="export.safety",
            ),
            _event(
                "evt_export_formula_padded",
                company_id=company_id,
                timestamp=timestamp - timedelta(seconds=5),
                entity_id="   =HYPERLINK(\"http://example.test\")",
                action="export.safety",
            ),
        ]
    )

    response = client.get(
        "/api/v1/audit-events/export",
        headers=_export_headers(client),
        params={"action": "export.safety"},
    )

    assert response.status_code == 200
    rows = _parse_csv(response)
    assert rows[0] == list(CSV_COLUMNS)
    assert len(rows) == 7

    escaped = rows[1]
    assert escaped[1] == "usuário-ç"
    assert escaped[2] == "export.safety"
    assert escaped[5] == 'quoted, "comma"\nnew line'
    assert escaped[6] == "proj-1"
    assert escaped[0] == "2026-06-01T08:30:15Z"

    formula_cells = [row[5] for row in rows[2:]]
    assert formula_cells == [
        "'=1+1",
        "'+SUM(A1)",
        "'-2+3",
        "'@SUM(A1)",
        "'   =HYPERLINK(\"http://example.test\")",
    ]


def test_export_without_matches_reports_zero_rows_and_only_header(client):
    response = client.get(
        "/api/v1/audit-events/export",
        headers=_export_headers(client),
        params={"entity_type": "no-such-entity-type"},
    )

    assert response.status_code == 200
    assert response.headers["x-audit-export-rows"] == "0"
    assert response.content.decode("utf-8-sig") == (
        ",".join(CSV_COLUMNS) + "\r\n"
    )


def test_export_exposes_row_count_header_to_browser_origins(client):
    response = client.get(
        "/api/v1/audit-events/export",
        headers={
            **_export_headers(client),
            "Origin": "http://localhost:8080",
        },
    )

    assert response.status_code == 200
    exposed = response.headers["access-control-expose-headers"]
    assert "X-Audit-Export-Rows" in exposed
    assert "Content-Disposition" in exposed
