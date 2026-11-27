import pytest

from app.config import Settings


def test_seed_password_optional_when_seeding_disabled(monkeypatch):
    monkeypatch.setenv("TOUCHIN_ENV", "production")
    monkeypatch.setenv("TOUCHIN_TOKEN_SECRET", "token")
    monkeypatch.setenv("TOUCHIN_ENCRYPTION_SECRET", "encryption")
    monkeypatch.setenv("TOUCHIN_SEED_ON_STARTUP", "false")
    monkeypatch.delenv("TOUCHIN_SEED_ADMIN_PASSWORD", raising=False)
    settings = Settings()
    assert settings.seed_on_startup is False
    assert settings.seed_admin_password is None


@pytest.mark.parametrize("value", ["true", "1"])
def test_seed_password_required_when_seeding_enabled(monkeypatch, value):
    monkeypatch.setenv("TOUCHIN_TOKEN_SECRET", "token")
    monkeypatch.setenv("TOUCHIN_ENCRYPTION_SECRET", "encryption")
    monkeypatch.setenv("TOUCHIN_SEED_ON_STARTUP", value)
    monkeypatch.delenv("TOUCHIN_SEED_ADMIN_PASSWORD", raising=False)
    with pytest.raises(RuntimeError, match="TOUCHIN_SEED_ADMIN_PASSWORD"):
        Settings()


@pytest.mark.parametrize("missing_secret", ["TOUCHIN_TOKEN_SECRET", "TOUCHIN_ENCRYPTION_SECRET"])
def test_security_secrets_always_required_when_seed_is_disabled(monkeypatch, missing_secret):
    monkeypatch.setenv("TOUCHIN_SEED_ON_STARTUP", "false")
    monkeypatch.setenv("TOUCHIN_TOKEN_SECRET", "token")
    monkeypatch.setenv("TOUCHIN_ENCRYPTION_SECRET", "encryption")
    monkeypatch.delenv("TOUCHIN_SEED_ADMIN_PASSWORD", raising=False)
    monkeypatch.delenv(missing_secret)
    with pytest.raises(RuntimeError, match=missing_secret):
        Settings()
