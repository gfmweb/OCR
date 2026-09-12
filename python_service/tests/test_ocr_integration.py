from __future__ import annotations

import io
from pathlib import Path

import pytest
from app.api.server import create_app
from app.infrastructure.config import Settings
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFont
from tests.conftest import FakeFieldsProvider, FakeOCRProvider, none_snapshot

CYRILLIC_TEXT = "ПАСПОРТ ИВАНОВ"


def _cyrillic_font() -> ImageFont.ImageFont:
    candidates = [
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        Path("/usr/share/fonts/truetype/freefont/FreeSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=64)
    pytest.skip("No Cyrillic TTF font available")


def _synthetic_png() -> bytes:
    image = Image.new("RGB", (900, 240), color=(255, 255, 255))
    draw = ImageDraw.Draw(image)
    draw.text((40, 80), CYRILLIC_TEXT, fill=(0, 0, 0), font=_cyrillic_font())
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _app(settings: Settings) -> object:
    return create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(none_snapshot()),
        warmup=True,
    )


@pytest.mark.integration
def test_upright_synthetic_keeps_zero_rotation() -> None:
    token = "integration-token-integration-token12"
    settings = Settings(session_token=token, api_host="127.0.0.1")
    with TestClient(_app(settings)) as client:
        health = client.get("/health", headers={"Authorization": f"Bearer {token}"})
        assert health.status_code == 200
        assert health.json()["status"] == "ready"
        response = client.post(
            "/api/v1/recognize",
            headers={"Authorization": f"Bearer {token}"},
            files={"image": ("synthetic.png", _synthetic_png(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["rotation_degrees"] == 0
    assert payload["timings"]["orientation"] == 0
    assert payload["lines"] == []
    assert payload["error_code"] == "NOT_FIRST_SPREAD"
    assert payload["fields"]["lastName"]["value"] is None


@pytest.mark.integration
def test_sideways_synthetic_does_not_set_our_rotation() -> None:
    import cv2
    import numpy as np

    token = "integration-token-integration-token12"
    settings = Settings(session_token=token, api_host="127.0.0.1")
    source = cv2.imdecode(np.frombuffer(_synthetic_png(), dtype=np.uint8), cv2.IMREAD_COLOR)
    sideways = cv2.rotate(source, cv2.ROTATE_90_CLOCKWISE)
    ok, encoded = cv2.imencode(".png", sideways)
    assert ok
    with TestClient(_app(settings)) as client:
        response = client.post(
            "/api/v1/recognize",
            headers={"Authorization": f"Bearer {token}"},
            files={"image": ("sideways.png", encoded.tobytes(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["rotation_degrees"] == 0
    assert payload["lines"] == []
    assert payload["error_code"] == "NOT_FIRST_SPREAD"
    assert payload["fields"]["lastName"]["value"] is None
