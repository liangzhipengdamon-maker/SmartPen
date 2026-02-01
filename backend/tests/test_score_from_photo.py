import base64
from fastapi.testclient import TestClient
from unittest.mock import patch

from app.main import app


def _blank_png_bytes() -> bytes:
    # 1x1 transparent PNG
    b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAA"
        "AAC0lEQVR42mP8/x8AAwMBAAZ6W1cAAAAASUVORK5CYII="
    )
    return base64.b64decode(b64)


def test_score_from_photo_no_strokes_detected():
    client = TestClient(app)
    image_bytes = _blank_png_bytes()

    with patch("app.api.scoring._extract_user_strokes_from_photo") as mock_extract:
        mock_extract.return_value = None
        response = client.post(
            "/api/score/from_photo",
            files={"image": ("blank.png", image_bytes, "image/png")},
            data={"character": "永"},
        )

    assert response.status_code == 422
    data = response.json()
    assert data["detail"]["error_type"] == "no_strokes_detected"
