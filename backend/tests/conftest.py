from __future__ import annotations

from collections.abc import Generator
import os

import pytest
from fastapi.testclient import TestClient


os.environ["TOUCHIN_DATABASE_URL"] = "sqlite://"
os.environ["TOUCHIN_TOKEN_SECRET"] = "tests-token-secret"
os.environ["TOUCHIN_ENCRYPTION_SECRET"] = "tests-encryption-secret"
os.environ["TOUCHIN_SEED_ADMIN_PASSWORD"] = "tests-seed-admin-password"
os.environ["TOUCHIN_SEED_ON_STARTUP"] = "true"

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.seed import seed_database  # noqa: E402


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_database(db)

    app = create_app()
    with TestClient(app) as test_client:
        yield test_client
