import os
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.core.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

AUTH = {"Authorization": "Bearer app-token", "X-User-Id": "user_12345678"}
ADMIN = {"Authorization": "Bearer admin-token"}


@pytest.fixture
def client(tmp_path):
    settings = Settings(
        app_token="app-token",
        admin_token="admin-token",
        data_dir=str(tmp_path),
        seed_keys={"groq": ["gsk_test_key_one", "gsk_test_key_two"]},
    )
    return TestClient(create_app(settings))
