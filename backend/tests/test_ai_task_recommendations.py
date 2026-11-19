from __future__ import annotations

import socket
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import create_engine, inspect, select

from app.config import get_settings
from app.crypto import FieldCipher
from app.database_schema import upgrade_database_schema
from app.db import SessionLocal, utcnow
from app.models import AuditEvent, Company, CompanyAISettings, KanbanColumn, Project, Task
from app.services import secure_provider, task_recommendations
from app.services.secure_provider import (
    ProviderError,
    _parse_embeddings,
    validate_provider_url,
    validate_provider_url_syntax,
)
from app.services.task_recommendations import (
    evaluate_fixture,
    rank_semantic,
)
from app.seed import JOAO_EMAIL
from tests.test_api import TEST_SEED_SECRET, login_headers, login_headers_for


def _create_project_with_task(
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    task_name: str,
) -> None:
    cipher = FieldCipher(get_settings().encryption_secret or "")
    with SessionLocal() as db:
        if company_id != "company-touchin":
            db.add(
                Company(
                    id=company_id,
                    legal_name_ciphertext=cipher.encrypt("Empresa de teste") or "",
                    trade_name_ciphertext=cipher.encrypt("Empresa de teste") or "",
                    cnpj_ciphertext=cipher.encrypt("12345678000199") or "",
                    cnpj_hash=f"test-{company_id}",
                    contact_email_ciphertext=cipher.encrypt("test@example.com") or "",
                    contact_email_hash=f"test-email-{company_id}",
                    contact_phone_ciphertext=cipher.encrypt("11999999999") or "",
                    consented_at=utcnow(),
                )
            )
            db.flush()
        db.add(
            Project(
                id=project_id,
                company_id=company_id,
                name_ciphertext=cipher.encrypt("Projeto de avaliação") or "",
                description_ciphertext=cipher.encrypt("Projeto de teste") or "",
                status="active",
            )
        )
        db.flush()
        column_id = f"column-{project_id}"
        db.add(
            KanbanColumn(
                id=column_id,
                project_id=project_id,
                name_ciphertext=cipher.encrypt("A fazer") or "",
                position=0,
            )
        )
        db.flush()
        db.add(
            Task(
                id=task_id,
                project_id=project_id,
                card_number=1,
                kanban_column_id=column_id,
                kanban_position=0,
                name_ciphertext=cipher.encrypt(task_name) or "",
                description_ciphertext=cipher.encrypt("Autenticação e sessão") or "",
                type="feature",
            )
        )
        db.commit()


def test_existing_company_schema_upgrade_creates_ai_settings_table() -> None:
    engine = create_engine("sqlite://")
    try:
        with engine.begin() as connection:
            connection.exec_driver_sql("CREATE TABLE companies (id VARCHAR(64) PRIMARY KEY)")
            upgrade_database_schema(connection)
            assert "company_ai_settings" in inspect(connection).get_table_names()
            assert "task_recommendation_quotas" in inspect(connection).get_table_names()
    finally:
        engine.dispose()


def test_ai_settings_routes_require_company_manage_permission(client: TestClient) -> None:
    headers = login_headers_for(
        client,
        email=JOAO_EMAIL,
        password=TEST_SEED_SECRET,
    )
    response = client.get(
        "/api/v1/admin/ai-settings",
        headers=headers,
    )
    assert response.status_code == 403


def test_connection_check_only_reuses_a_saved_key_on_its_origin(client, monkeypatch) -> None:
    headers = login_headers(client)
    route = "/api/v1/admin/ai-settings"
    config = {"providerBaseUrl": "https://configured.invalid/v1", "modelId": "test-model"}
    assert client.put(route, headers=headers, json={**config, "apiKey": "fixture-only"}).status_code == 200

    def verify(url, _model, key, texts):
        assert (url, key) in {
            ("https://CONFIGURED.invalid:443/new/v1", "fixture-only"),
            ("https://replacement.invalid/v1", "explicit-fixture"),
        }
        return [[1.0] for _ in texts]

    monkeypatch.setattr("app.services.ai_settings.fetch_embeddings", verify)
    for url, credential, expected in (
        ("https://CONFIGURED.invalid:443/new/v1", {}, True),
        ("https://replacement.invalid/v1", {}, False),
        ("https://replacement.invalid/v1", {"apiKey": "explicit-fixture"}, True),
    ):
        response = client.post(f"{route}/test", headers=headers, json={
            **config, "providerBaseUrl": url, **credential,
        })
        assert response.status_code == 200
        assert response.json()["success"] is expected


def test_company_quota_is_shared_across_actors_and_resets_next_hour(client, monkeypatch) -> None:
    company_id = "company-touchin"
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    with SessionLocal() as db:
        db.add(CompanyAISettings(company_id=company_id, enabled=True, revision=1))
        db.commit()
    monkeypatch.setattr(task_recommendations, "utcnow", lambda: now)
    monkeypatch.setattr(task_recommendations, "_COMPANY_CALLS_PER_HOUR", 2)
    monkeypatch.setattr(task_recommendations, "_ACTOR_CALLS_PER_HOUR", 1)

    def reserve(actor):
        with SessionLocal() as db:
            return task_recommendations._reserve_provider_call(db, company_id, actor, 1)

    assert reserve("first")
    assert not reserve("first")
    assert reserve("second")  # An actor rejection did not spend company quota.
    assert not reserve("third")
    now += timedelta(hours=1)
    assert reserve("first")


def test_provider_deadline_bounds_a_blocking_body_read(monkeypatch) -> None:
    monkeypatch.setattr(secure_provider, "_TIMEOUT_SECONDS", 1.0)
    reader, peer = socket.socketpair()
    with reader, peer:
        reader.settimeout(3)
        peer.settimeout(3)
        connection = secure_provider._PinnedHTTPSConnection(
            "provider.invalid", 443, socket.AF_INET, ("127.0.0.1", 443), secure_provider._Deadline(),
        )
        connection.sock = reader
        try:
            connection.request("GET", "/")
            assert peer.recv(4096).startswith(b"GET / HTTP/1.1\r\n")
            peer.sendall(b"HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\n")
            with connection.getresponse() as response:
                assert response.status == 200
                reader.settimeout(3)
                with pytest.raises(TimeoutError):
                    response.read()
                timeout = reader.gettimeout()
                assert timeout is not None and timeout <= 1.0
        finally:
            connection.close()


def test_recommendations_are_disabled_by_default_and_project_scoped(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _create_project_with_task(
        company_id="company-touchin",
        project_id="recommendation-project",
        task_id="selected-project-task",
        task_name="Authentication state lost after browser reload",
    )
    _create_project_with_task(
        company_id="company-other",
        project_id="other-company-project",
        task_id="other-company-task",
        task_name="Other company's confidential task",
    )
    headers = login_headers(client)
    calls: list[list[str]] = []

    def fake_fetch(_url: str, _model: str, _key: str, texts: list[str]) -> list[list[float]]:
        calls.append(texts)
        return [[1.0, 0.0] for _ in texts]

    monkeypatch.setattr("app.services.task_recommendations.fetch_embeddings", fake_fetch)
    description = "A página recarregada expulsa a pessoa conectada."
    endpoint = "/api/v1/projects/recommendation-project/task-recommendations"
    disabled = client.post(endpoint, headers=headers, json={"description": description})
    assert disabled.status_code == 200
    assert disabled.json()["status"] == "disabled"
    assert calls == []

    verification_calls: list[list[str]] = []

    def verify_provider(_url: str, _model: str, _key: str, texts: list[str]) -> list[list[float]]:
        verification_calls.append(texts)
        return [[1.0, 0.0] for _ in texts]

    monkeypatch.setattr("app.services.ai_settings.validate_provider_url", lambda _url: None)
    monkeypatch.setattr("app.services.ai_settings.fetch_embeddings", verify_provider)
    configured = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={
            "enabled": True,
            "providerBaseUrl": "https://provider.invalid/v1",
            "modelId": "synthetic-embedding-test",
            "apiKey": "synthetic-key-never-send-in-prompt",
            "privacyAcknowledged": True,
        },
    )
    assert configured.status_code == 200
    assert verification_calls == [
        ["TouchIn provider enablement verification; no employee or task data is included."]
    ]

    response = client.post(endpoint, headers=headers, json={"description": description})
    assert response.status_code == 200
    assert response.json()["recommendations"] == [
        {"taskId": "selected-project-task", "taskName": "Authentication state lost after browser reload"}
    ]
    assert len(calls) == 1
    assert len(calls[0]) == 2
    assert calls[0][0] == description
    assert "Other company's confidential task" not in " ".join(calls[0])
    assert "synthetic-key-never-send-in-prompt" not in " ".join(calls[0])

    cross_company = client.post(
        "/api/v1/projects/other-company-project/task-recommendations",
        headers=headers,
        json={"description": description},
    )
    assert cross_company.status_code == 404
    assert len(calls) == 1

    def failed_fetch(_url: str, _model: str, _key: str, _texts: list[str]) -> list[list[float]]:
        raise ProviderError("synthetic network failure")

    monkeypatch.setattr("app.services.task_recommendations.fetch_embeddings", failed_fetch)
    unavailable = client.post(endpoint, headers=headers, json={"description": description})
    assert unavailable.status_code == 200
    assert unavailable.json()["status"] == "unavailable"
    assert unavailable.json()["recommendations"] == []

    reenabled = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={
            "enabled": True,
            "providerBaseUrl": "https://provider.invalid/v1",
            "modelId": "synthetic-embedding-test",
            "privacyAcknowledged": True,
        },
    )
    assert reenabled.status_code == 200

    def disable_during_fetch(_url: str, _model: str, _key: str, texts: list[str]) -> list[list[float]]:
        with SessionLocal() as db:
            settings = db.scalar(select(CompanyAISettings))
            assert settings is not None
            settings.enabled = False
            settings.revision += 1
            db.commit()
        return [[1.0, 0.0] for _ in texts]

    monkeypatch.setattr("app.services.task_recommendations.fetch_embeddings", disable_during_fetch)
    stale = client.post(endpoint, headers=headers, json={"description": description})
    assert stale.status_code == 200
    assert stale.json()["status"] == "disabled"
    assert stale.json()["recommendations"] == []


def test_ai_provider_credential_is_encrypted_and_consent_is_required(
    client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    monkeypatch.setattr("app.services.ai_settings.validate_provider_url", lambda _url: None)
    headers = login_headers(client)
    test_key = "synthetic-test-key-do-not-use"
    config = {
        "providerBaseUrl": "https://provider.invalid/v1",
        "modelId": "synthetic-embedding-test",
    }

    saved = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={**config, "enabled": False, "apiKey": test_key},
    )
    assert saved.status_code == 200
    assert saved.json()["apiKeyConfigured"] is True
    assert test_key not in saved.text
    retrieved = client.get("/api/v1/admin/ai-settings", headers=headers)
    assert retrieved.status_code == 200
    assert retrieved.json()["apiKeyConfigured"] is True
    assert "apiKey" not in retrieved.json()
    assert test_key not in retrieved.text

    with SessionLocal() as db:
        row = db.scalar(select(CompanyAISettings))
        assert row is not None and row.api_key_ciphertext
        assert row.api_key_ciphertext != test_key
        assert test_key not in row.api_key_ciphertext
        original_ciphertext = row.api_key_ciphertext
        events = db.scalars(
            select(AuditEvent).where(
                AuditEvent.company_id == "company-touchin",
                AuditEvent.action == "company.ai_task_recommendations.settings_updated",
            )
        ).all()
        assert events
        assert all(test_key not in (event.metadata_payload or "") for event in events)
        assert all("description" not in (event.metadata_payload or "") for event in events)

    def failed_test(_url: str, _model: str, _key: str, _texts: list[str]) -> list[list[float]]:
        raise ProviderError("synthetic provider failure")

    monkeypatch.setattr("app.services.ai_settings.fetch_embeddings", failed_test)
    provider_test = client.post(
        "/api/v1/admin/ai-settings/test",
        headers=headers,
        json={**config, "apiKey": test_key},
    )
    assert provider_test.status_code == 200
    assert provider_test.json()["success"] is False
    assert test_key not in provider_test.text
    assert test_key not in caplog.text

    rotated_key = "synthetic-rotated-key"
    rotated = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={**config, "enabled": False, "apiKey": rotated_key},
    )
    assert rotated.status_code == 200
    assert rotated_key not in rotated.text
    with SessionLocal() as db:
        row = db.scalar(select(CompanyAISettings))
        assert row is not None and row.api_key_ciphertext != original_ciphertext
        assert rotated_key not in row.api_key_ciphertext

    rejected = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={**config, "enabled": True, "privacyAcknowledged": False},
    )
    assert rejected.status_code == 422
    assert client.get("/api/v1/admin/ai-settings", headers=headers).json()["enabled"] is False

    invalid_provider = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={**config, "enabled": True, "privacyAcknowledged": True},
    )
    assert invalid_provider.status_code == 422
    assert client.get("/api/v1/admin/ai-settings", headers=headers).json()["enabled"] is False
    monkeypatch.setattr(
        "app.services.ai_settings.fetch_embeddings",
        lambda _url, _model, _key, texts: [[1.0, 0.0] for _ in texts],
    )
    enabled = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={**config, "enabled": True, "privacyAcknowledged": True},
    )
    assert enabled.status_code == 200
    assert enabled.json()["enabled"] is True
    assert "apiKey" not in enabled.json()

    removed = client.put(
        "/api/v1/admin/ai-settings",
        headers=headers,
        json={
            **config,
            "enabled": False,
            "removeApiKey": True,
        },
    )
    assert removed.status_code == 200
    assert removed.json()["apiKeyConfigured"] is False


def test_semantic_rank_recovers_a_paraphrase_and_limits_suggestions() -> None:
    query = "A página recarregada expulsa a pessoa conectada."
    candidates = [
        {"id": "session", "name": "Sessão encerrada", "text": "Sessão encerrada quando a janela é atualizada."},
        {"id": "layout", "name": "Ajustar layout", "text": "Ajustar espaçamento do formulário."},
        {"id": "token", "name": "Tokens expirados", "text": "Manter a sessão após renovação do token."},
        {"id": "dashboard", "name": "Dashboard", "text": "Atualizar os cartões do painel."},
        {"id": "email", "name": "E-mail", "text": "Editar o modelo de e-mail de boas-vindas."},
    ]
    vectors = [
        [1.0, 0.0],
        [0.99, 0.01],
        [0.0, 1.0],
        [0.0, 0.5],
        [0.95, 0.2],
        [0.86, 0.4],
    ]

    ranked = rank_semantic(query, candidates, vectors)

    assert [item["id"] for item in ranked] == ["session", "dashboard", "email"]


def test_semantic_rank_suppresses_low_confidence_matches() -> None:
    ranked = rank_semantic(
        "Falha de áudio no dispositivo de teste",
        [{"id": "project", "text": "Criar colunas no Kanban"}],
        [[1.0, 0.0], [0.0, 1.0]],
    )
    assert ranked == []


def test_provider_url_validation_and_embedding_response_shape(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    for invalid in (
        "http://provider.example/v1",
        "https://user:pass@provider.example/v1",
        "https://provider.example:8443/v1",
        "https://provider.example:0/v1",
        "https://provider.example/v1?token=value",
    ):
        with pytest.raises(ProviderError):
            validate_provider_url_syntax(invalid)

    with pytest.raises(ProviderError):
        validate_provider_url("https://127.0.0.1/v1")
    with pytest.raises(ProviderError):
        _parse_embeddings(b'{"data":[{"index":0,"embedding":[1]}, {"index":0,"embedding":[0]}]}', 2)

    def mixed_dns(_host: str, port: int, *, type: int) -> list[tuple]:
        return [
            (socket.AF_INET, type, socket.IPPROTO_TCP, "", ("8.8.8.8", port)),
            (socket.AF_INET, type, socket.IPPROTO_TCP, "", ("10.0.0.2", port)),
        ]

    for address in ("10.0.0.2", "169.254.1.2", "192.0.2.1", "0.0.0.0"):
        monkeypatch.setattr(
            secure_provider.socket,
            "getaddrinfo",
            lambda _host, port, *, type, address=address: [
                (socket.AF_INET, type, socket.IPPROTO_TCP, "", (address, port))
            ],
        )
        with pytest.raises(ProviderError, match="non-public"):
            validate_provider_url("https://internal.example/v1")

    monkeypatch.setattr(secure_provider.socket, "getaddrinfo", mixed_dns)
    with pytest.raises(ProviderError, match="non-public"):
        validate_provider_url("https://mixed.example/v1")


def test_provider_calls_are_pinned_bounded_and_do_not_follow_redirects(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    requests: list[tuple[str, str, dict[str, str], bytes]] = []
    response_status = 200
    response_body = b'{"data":[{"index":0,"embedding":[1.0,0.0]}, {"index":1,"embedding":[0.9,0.1]}]}'

    class StubResponse:
        def __init__(self, status: int, body: bytes) -> None:
            self.status = status
            self.body = body

        def read(self, limit: int) -> bytes:
            return self.body[:limit]

        def close(self) -> None:
            pass

    class StubConnection:
        def __init__(self, host, port, family, sockaddr, timeout) -> None:
            self.host = host
            self.port = port
            self.family = family
            self.sockaddr = sockaddr
            self.timeout = timeout

        def request(self, method: str, path: str, *, body: bytes, headers: dict[str, str]) -> None:
            requests.append((method, path, headers, body))

        def getresponse(self) -> StubResponse:
            return StubResponse(response_status, response_body)

        def close(self) -> None:
            pass

    monkeypatch.setattr(
        secure_provider,
        "_public_addresses",
        lambda _host, port: [(socket.AF_INET, ("8.8.8.8", port))],
    )
    monkeypatch.setattr(secure_provider, "_PinnedHTTPSConnection", StubConnection)
    vectors = secure_provider.fetch_embeddings(
        "https://provider.example/v1",
        "test-model",
        "synthetic-api-key",
        ["query text", "task text"],
    )
    assert vectors == [[1.0, 0.0], [0.9, 0.1]]
    method, path, headers, body = requests[-1]
    assert (method, path) == ("POST", "/v1/embeddings")
    assert headers["Authorization"] == "Bearer synthetic-api-key"
    assert b"synthetic-api-key" not in body
    assert b"query text" in body and b"task text" in body

    response_status = 302
    with pytest.raises(ProviderError) as error:
        secure_provider.fetch_embeddings(
            "https://provider.example/v1", "test-model", "synthetic-api-key", ["query"]
        )
    assert "synthetic-api-key" not in str(error.value)
    assert len(requests) == 2

    response_status = 200
    response_body = b"x" * (secure_provider.MAX_RESPONSE_BYTES + 1)
    with pytest.raises(ProviderError, match="size limit"):
        secure_provider.fetch_embeddings(
            "https://provider.example/v1", "test-model", "synthetic-api-key", ["query"]
        )


def test_synthetic_evaluation_fixture_has_a_lexical_baseline() -> None:
    result = evaluate_fixture()
    metrics = result["lexical_baseline"]
    assert metrics["cases"] == 5
    assert 0 <= metrics["top1_recall"] <= 1
    assert 0 <= metrics["top3_recall"] <= 1
    assert 0 <= metrics["false_suggestion_rate"] <= 1
