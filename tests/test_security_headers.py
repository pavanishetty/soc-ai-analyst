import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.mark.parametrize("path", ["/health", "/does-not-exist"])
def test_security_headers_present(path):
    response = client.get(path)
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"
    assert "default-src 'none'" in response.headers["Content-Security-Policy"]
    assert "no-store" in response.headers["Cache-Control"]


def test_docs_disabled_by_default():
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404