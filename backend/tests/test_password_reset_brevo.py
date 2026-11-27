from __future__ import annotations

import pytest

from app.services import brevo


def test_reset_email_sends_link_without_creating_temporary_credentials(monkeypatch):
    from app.config import Settings

    settings = Settings()
    settings.brevo_api_key = "fixture-api-key"
    settings.brevo_sender_email = "noreply@example.com"
    settings.brevo_welcome_enabled = True
    settings.password_reset_url = "https://touchin.example/#/reset-password"
    monkeypatch.setattr(brevo, "get_settings", lambda: settings)

    sent = []

    class Response:
        def raise_for_status(self):
            return None

    def fake_post(url, *, json, headers, timeout):
        sent.append(json)
        return Response()

    monkeypatch.setattr(brevo.httpx, "post", fake_post)
    brevo.send_password_reset_email(
        recipient_email="worker@example.com",
        display_name="Worker",
        token="token-fixture",
    )
    assert len(sent) == 1
    assert "https://touchin.example/#/reset-password?token=token-fixture" in sent[0]["textContent"]
    assert "Senha temporária" not in sent[0]["textContent"]
    assert "href=\"https://touchin.example/#/reset-password?token=token-fixture\"" in sent[0]["htmlContent"]


@pytest.mark.parametrize("configured_url,expected_prefix", [
    ("https://touchin.example", "https://touchin.example/#/reset-password"),
    ("https://touchin.example/", "https://touchin.example/#/reset-password"),
    ("https://touchin.example/#", "https://touchin.example/#/reset-password"),
    ("https://touchin.example/#/reset-password", "https://touchin.example/#/reset-password"),
])
def test_reset_email_link_from_each_accepted_url(
    monkeypatch, configured_url, expected_prefix
):
    from app.config import Settings

    monkeypatch.setenv("TOUCHIN_PASSWORD_RESET_URL", configured_url)
    settings = Settings()
    settings.brevo_api_key = "fixture-key"
    settings.brevo_sender_email = "noreply@example.com"
    settings.brevo_welcome_enabled = True
    monkeypatch.setattr(brevo, "get_settings", lambda: settings)
    sent = []

    class Response:
        def raise_for_status(self):
            return None

    monkeypatch.setattr(
        brevo.httpx, "post", lambda url, **kwargs: (sent.append(kwargs["json"]), Response())[1]
    )
    brevo.send_password_reset_email(
        recipient_email="worker@example.com", display_name="Worker", token="sample-token"
    )
    assert len(sent) == 1
    expected_link = f"{expected_prefix}?token=sample-token"
    assert expected_link in sent[0]["textContent"]
    assert f'href="{expected_link}"' in sent[0]["htmlContent"]
