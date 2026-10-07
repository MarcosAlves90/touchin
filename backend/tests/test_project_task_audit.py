from __future__ import annotations

import json

from sqlalchemy import select

from app.db import SessionLocal
from app.models import AuditEvent
from test_api import TEST_SEED_SECRET, login_headers_for


MANAGER_EMAIL = "caio.martins@touchin.com"


def _manager_headers(client):
    return login_headers_for(client, email=MANAGER_EMAIL, password=TEST_SEED_SECRET)


def _create_project(client, headers, *, name: str = "Audit project") -> dict:
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": name,
            "description": "Project created by issue 40 audit regression coverage.",
            "taskEmployeeLimit": 2,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _create_task(client, headers, project_id: str, *, name: str) -> dict:
    response = client.post(
        f"/api/v1/projects/{project_id}/tasks",
        headers=headers,
        json={
            "name": name,
            "description": f"Description for {name}",
            "type": "feature",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _board(client, headers, project_id: str) -> dict:
    response = client.get(f"/api/v1/projects/{project_id}/kanban", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _events(*, project_id: str, entity_id: str | None = None) -> list[AuditEvent]:
    with SessionLocal() as db:
        query = select(AuditEvent).where(AuditEvent.project_id == project_id)
        if entity_id is not None:
            query = query.where(AuditEvent.entity_id == entity_id)
        return list(db.scalars(query.order_by(AuditEvent.timestamp, AuditEvent.id)).all())


def _metadata(event: AuditEvent) -> dict:
    return json.loads(event.metadata_payload) if event.metadata_payload else {}


def test_project_audit_uses_canonical_actions(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)

    updated = client.put(
        f"/api/v1/projects/{project['id']}",
        headers=headers,
        json={
            "name": "Audit project renamed",
            "description": "Updated description must not be copied into audit metadata.",
            "taskEmployeeLimit": 3,
            "status": "active",
        },
    )
    assert updated.status_code == 200, updated.text

    added = client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=headers,
        json={"employeeId": "emp-04"},
    )
    assert added.status_code == 201, added.text
    removed = client.delete(
        f"/api/v1/projects/{project['id']}/members/emp-04",
        headers=headers,
    )
    assert removed.status_code == 204, removed.text
    deleted = client.delete(f"/api/v1/projects/{project['id']}", headers=headers)
    assert deleted.status_code == 204, deleted.text

    events = _events(project_id=project["id"], entity_id=project["id"])
    assert [event.action for event in events] == [
        "project.created",
        "project.updated",
        "project.member_added",
        "project.member_removed",
        "project.deleted",
    ]
    assert all(event.entity_type == "project" for event in events)
    assert all(event.actor_user_id for event in events)
    assert all(event.company_id for event in events)
    assert all(event.result == "success" for event in events)

    update_metadata = _metadata(events[1])
    assert set(update_metadata["changedFields"]) == {
        "name",
        "description",
        "taskEmployeeLimit",
    }
    assert "Updated description" not in events[1].metadata_payload
    assert _metadata(events[2]) == {"employeeId": "emp-04"}
    assert _metadata(events[3]) == {"employeeId": "emp-04"}


def test_card_audit_uses_stable_identity_and_actor_for_assignees(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers, name="Card audit")
    assert client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=headers,
        json={"employeeId": "emp-04"},
    ).status_code == 201
    task = _create_task(client, headers, project["id"], name="Audited card")

    updated = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{task['id']}",
        headers=headers,
        json={
            "name": "Audited card renamed",
            "description": "Changed card description",
            "type": "bug",
            "parentTaskId": None,
        },
    )
    assert updated.status_code == 200, updated.text

    assignee_base = (
        f"/api/v1/projects/{project['id']}/kanban/cards/{task['id']}/assignees"
    )
    added = client.post(f"{assignee_base}/emp-04", headers=headers)
    assert added.status_code == 200, added.text
    removed = client.delete(f"{assignee_base}/emp-04", headers=headers)
    assert removed.status_code == 200, removed.text
    deleted = client.delete(
        f"/api/v1/projects/{project['id']}/tasks/{task['id']}",
        headers=headers,
    )
    assert deleted.status_code == 204, deleted.text

    events = _events(project_id=project["id"], entity_id=task["id"])
    assert [event.action for event in events] == [
        "card.created",
        "card.updated",
        "card.assignee_added",
        "card.assignee_removed",
        "card.deleted",
    ]
    assert all(event.entity_type == "card" for event in events)
    assert all(event.actor_user_id for event in events)
    assert all(event.project_id == project["id"] for event in events)
    assert all(_metadata(event)["cardNumber"] == task["cardNumber"] for event in events)
    assert _metadata(events[2])["employeeId"] == "emp-04"
    assert _metadata(events[3])["employeeId"] == "emp-04"
    assert set(_metadata(events[1])["changedFields"]) == {
        "name",
        "description",
        "type",
    }


def test_card_move_reorder_and_stale_request_audit_without_duplicates(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers, name="Movement audit")
    first = _create_task(client, headers, project["id"], name="First")
    second = _create_task(client, headers, project["id"], name="Second")
    initial = _board(client, headers, project["id"])
    source = initial["columns"][0]

    created_column = client.post(
        f"/api/v1/projects/{project['id']}/kanban/columns",
        headers=headers,
        json={"name": "Doing", "expectedVersion": initial["kanbanVersion"]},
    )
    assert created_column.status_code == 201, created_column.text
    with_target = created_column.json()
    target = next(column for column in with_target["columns"] if column["id"] != source["id"])

    moved = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": with_target["kanbanVersion"],
            "columns": [
                {"columnId": source["id"], "taskIds": [second["id"]]},
                {"columnId": target["id"], "taskIds": [first["id"]]},
            ],
        },
    )
    assert moved.status_code == 200, moved.text
    moved_board = moved.json()

    movement_events = [
        event
        for event in _events(project_id=project["id"])
        if event.action in {"card.moved", "card.reordered"}
    ]
    assert [(event.action, event.entity_id) for event in movement_events] == [
        ("card.moved", first["id"]),
    ]
    assert _metadata(movement_events[0]) == {
        "cardNumber": first["cardNumber"],
        "fromColumnId": source["id"],
        "toColumnId": target["id"],
    }

    third = _create_task(client, headers, project["id"], name="Third")
    before_reorder = _board(client, headers, project["id"])
    source_before = next(column for column in before_reorder["columns"] if column["id"] == source["id"])
    assert [card["id"] for card in source_before["cards"]] == [second["id"], third["id"]]

    reordered = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": before_reorder["kanbanVersion"],
            "columns": [
                {"columnId": source["id"], "taskIds": [third["id"], second["id"]]},
            ],
        },
    )
    assert reordered.status_code == 200, reordered.text
    reordered_board = reordered.json()

    reorder_events = [
        event
        for event in _events(project_id=project["id"])
        if event.action == "card.reordered"
    ]
    assert {event.entity_id for event in reorder_events} == {second["id"], third["id"]}
    for event in reorder_events:
        metadata = _metadata(event)
        assert metadata["columnId"] == source["id"]
        assert metadata["fromPosition"] != metadata["toPosition"]
        assert metadata["cardNumber"] in {second["cardNumber"], third["cardNumber"]}

    count_before_noop = len(reorder_events)
    no_op = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": reordered_board["kanbanVersion"],
            "columns": [
                {"columnId": source["id"], "taskIds": [third["id"], second["id"]]},
            ],
        },
    )
    assert no_op.status_code == 200, no_op.text
    assert len(
        [
            event
            for event in _events(project_id=project["id"])
            if event.action == "card.reordered"
        ]
    ) == count_before_noop

    stale = client.put(
        f"/api/v1/projects/{project['id']}/kanban/cards/order",
        headers=headers,
        json={
            "expectedVersion": moved_board["kanbanVersion"],
            "columns": [
                {"columnId": source["id"], "taskIds": [second["id"], third["id"]]},
            ],
        },
    )
    assert stale.status_code == 409
    assert len(
        [
            event
            for event in _events(project_id=project["id"])
            if event.action in {"card.moved", "card.reordered"}
        ]
    ) == 1 + count_before_noop


def test_kanban_column_audit_uses_canonical_actions_and_column_identity(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers, name="Column audit")
    initial = _board(client, headers, project["id"])
    first_column = initial["columns"][0]

    created = client.post(
        f"/api/v1/projects/{project['id']}/kanban/columns",
        headers=headers,
        json={"name": "Doing", "expectedVersion": initial["kanbanVersion"]},
    )
    assert created.status_code == 201, created.text
    created_board = created.json()
    second_column = next(
        column for column in created_board["columns"] if column["id"] != first_column["id"]
    )

    renamed = client.put(
        f"/api/v1/projects/{project['id']}/kanban/columns/{second_column['id']}",
        headers=headers,
        json={"name": "In progress", "expectedVersion": created_board["kanbanVersion"]},
    )
    assert renamed.status_code == 200, renamed.text
    renamed_board = renamed.json()

    reordered = client.put(
        f"/api/v1/projects/{project['id']}/kanban/columns/order",
        headers=headers,
        json={
            "expectedVersion": renamed_board["kanbanVersion"],
            "columnIds": [second_column["id"], first_column["id"]],
        },
    )
    assert reordered.status_code == 200, reordered.text
    reordered_board = reordered.json()

    deleted = client.delete(
        f"/api/v1/projects/{project['id']}/kanban/columns/{second_column['id']}",
        headers=headers,
        params={"expectedVersion": reordered_board["kanbanVersion"]},
    )
    assert deleted.status_code == 200, deleted.text

    events = _events(project_id=project["id"])
    relevant = [event for event in events if event.action.startswith("kanban.column_")]
    assert [event.action for event in relevant if event.entity_id == second_column["id"]] == [
        "kanban.column_created",
        "kanban.column_updated",
        "kanban.column_reordered",
        "kanban.column_deleted",
    ]
    reorder_events = [event for event in relevant if event.action == "kanban.column_reordered"]
    assert {event.entity_id for event in reorder_events} == {
        first_column["id"],
        second_column["id"],
    }
    for event in reorder_events:
        metadata = _metadata(event)
        assert metadata["fromPosition"] != metadata["toPosition"]
        assert all(key not in event.metadata_payload.lower() for key in ("password", "token", "secret"))
        assert event.entity_type == "kanban_column"
        assert event.actor_user_id
        assert event.project_id == project["id"]
