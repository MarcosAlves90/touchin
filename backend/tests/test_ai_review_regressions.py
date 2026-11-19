from __future__ import annotations

import socket

import pytest
from fastapi.testclient import TestClient

from app.services import secure_provider
from tests.test_ai_task_recommendations import _create_project_with_task
from tests.test_api import login_headers


SETTINGS = "/api/v1/admin/ai-settings"
CONFIG = {"providerBaseUrl": "https://configured.invalid/v1", "modelId": "test-model"}


def test_saving_a_different_origin_requires_replacement_or_removal(client: TestClient) -> None:
    headers = login_headers(client)
    saved = client.put(SETTINGS, headers=headers, json={**CONFIG, "apiKey": "test-only"})
    assert saved.status_code == 200
    changed = {**CONFIG, "providerBaseUrl": "https://replacement.invalid/v1"}
    response = client.put(SETTINGS, headers=headers, json=changed)
    assert response.status_code == 422, "origin guard required even with recommendations off"
    assert client.get(SETTINGS, headers=headers).json()["providerBaseUrl"] == CONFIG["providerBaseUrl"]
    assert client.put(SETTINGS, headers=headers, json={**changed, "apiKey": "replacement-only"}).status_code == 200


def test_provider_does_not_accept_a_response_past_its_deadline(monkeypatch: pytest.MonkeyPatch) -> None:
    import time

    now = 100.0
    monkeypatch.setattr(time, "monotonic", lambda: now)
    monkeypatch.setattr(secure_provider, "_public_addresses", lambda *_: [(socket.AF_INET, ("192.0.2.1", 443))])

    class Response:
        status = 200

        def read(self, limit):
            nonlocal now
            now += elapsed
            return b'{"data":[{"index":0,"embedding":[1.0]}]}'

        def close(self):
            pass

    class Connection:
        def __init__(self, *_):
            pass

        def request(self, *args, **kwargs):
            pass

        def getresponse(self):
            return Response()

        def close(self):
            pass

    monkeypatch.setattr(secure_provider, "_PinnedHTTPSConnection", Connection)
    monkeypatch.setattr(secure_provider, "_REQUEST_SLOTS", __import__("threading").BoundedSemaphore(1))

    def fetch():
        return secure_provider.fetch_embeddings(CONFIG["providerBaseUrl"], "test-model", "test-only", ["sample"])

    elapsed = 7
    try:
        fetch()
    except secure_provider.ProviderError:
        pass
    else:
        pytest.fail("deadline required for the whole provider response")
    elapsed = 0
    assert fetch() == [[1.0]]


def test_recommendations_stop_at_actor_quota_across_logins(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    _create_project_with_task(company_id="company-touchin", project_id="quota-project", task_id="quota-task", task_name="Review login")
    monkeypatch.setattr("app.services.ai_settings.validate_provider_url", lambda _: None)
    monkeypatch.setattr("app.services.ai_settings.fetch_embeddings", lambda *args: [[1.0]])
    calls = 0

    def embed(*args):
        nonlocal calls
        calls += 1
        return [[1.0], [1.0]]

    monkeypatch.setattr("app.services.task_recommendations.fetch_embeddings", embed)
    headers = login_headers(client)
    assert client.put(SETTINGS, headers=headers, json={
        **CONFIG, "enabled": True, "privacyAcknowledged": True, "apiKey": "test-only",
    }).status_code == 200
    request = {"description": "Review login behavior"}
    url = "/api/v1/projects/quota-project/task-recommendations"
    for _ in range(30):
        response = client.post(url, headers=headers, json=request)
        assert response.status_code == 200 and response.json()["status"] == "available"
    response = client.post(url, headers=login_headers(client), json=request)
    assert response.status_code == 200
    assert response.json() == {"status": "unavailable", "recommendations": []}, "quota required after 30 calls"
    assert calls == 30
