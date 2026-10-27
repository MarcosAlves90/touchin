from __future__ import annotations

import csv
import io
from datetime import datetime, timedelta, timezone

from app.seed import MARINA_EMAIL

from tests.test_audit import login_headers


def _parse_instant(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _create_audited_project(client, headers) -> str:
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={"name": "Projeto com fuso", "description": "Gera um evento de auditoria."},
    )
    assert response.status_code == 201
    return response.json()["id"]


def test_audit_event_list_timestamps_carry_utc_offset(client):
    headers = login_headers(client, MARINA_EMAIL)
    started_at = datetime.now(timezone.utc).replace(microsecond=0)
    project_id = _create_audited_project(client, headers)
    finished_at = datetime.now(timezone.utc) + timedelta(seconds=1)

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={"project_id": project_id},
    )

    assert response.status_code == 200
    events = response.json()
    assert events
    for event in events:
        instant = _parse_instant(event["timestamp"])
        assert instant.utcoffset() == timedelta(0), event["timestamp"]
        assert started_at <= instant <= finished_at, event["timestamp"]


def test_audit_export_timestamp_matches_list_instant(client):
    headers = login_headers(client, MARINA_EMAIL)
    project_id = _create_audited_project(client, headers)
    params = {"project_id": project_id, "action": "project.created"}

    listed = client.get("/api/v1/audit-events", headers=headers, params=params)
    exported = client.get("/api/v1/audit-events/export", headers=headers, params=params)

    assert listed.status_code == 200
    assert exported.status_code == 200
    [event] = listed.json()
    header, row = list(csv.reader(io.StringIO(exported.content.decode("utf-8-sig"))))
    exported_value = row[header.index("timestamp_utc")]
    assert exported_value.endswith("Z")
    assert _parse_instant(exported_value) == _parse_instant(event["timestamp"])
