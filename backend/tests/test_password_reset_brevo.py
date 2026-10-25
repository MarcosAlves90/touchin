from __future__ import annotations

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
