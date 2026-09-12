from __future__ import annotations

import io
from pathlib import Path

import pytest
from app.api.server import create_app
from app.infrastructure.config import Settings
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFont
from tests.conftest import FakeFieldsProvider, FakeOCRProvider, none_snapshot

TOKEN = "integration-token-integration-token12"


def _cyrillic_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
        Path("/usr/share/fonts/truetype/freefont/FreeSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    pytest.skip("No Cyrillic TTF font available")


def _first_spread_png() -> bytes:
    image = Image.new("RGB", (1400, 900), color=(255, 255, 255))
    draw = ImageDraw.Draw(image)
    font = _cyrillic_font(34)
    draw.text((40, 80), "ПАСПОРТ ИВАНОВ", fill=(0, 0, 0), font=font)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


@pytest.fixture(scope="module")
def paddle_client() -> TestClient:
    settings = Settings(session_token=TOKEN, api_host="127.0.0.1")
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(none_snapshot()),
        warmup=True,
    )
    with TestClient(app) as client:
        yield client


def _auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


@pytest.mark.integration
def test_upright_spread_stays_zero_and_hides_text(paddle_client: TestClient) -> None:
    response = paddle_client.post(
        "/api/v1/recognize",
        headers=_auth(),
        files={"image": ("spread.png", _first_spread_png(), "image/png")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["rotation_degrees"] == 0
    assert payload["lines"] == []
    assert payload["error_code"] == "NOT_FIRST_SPREAD"
    assert payload["fields"]["lastName"]["value"] is None


@pytest.mark.integration
def test_sideways_spread_rotates_without_returning_text(paddle_client: TestClient) -> None:
    import cv2
    import numpy as np

    source = cv2.imdecode(np.frombuffer(_first_spread_png(), dtype=np.uint8), cv2.IMREAD_COLOR)
    sideways = cv2.rotate(source, cv2.ROTATE_90_CLOCKWISE)
    ok, encoded = cv2.imencode(".png", sideways)
    assert ok
    response = paddle_client.post(
        "/api/v1/recognize",
        headers=_auth(),
        files={"image": ("spread-rot.png", encoded.tobytes(), "image/png")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["rotation_degrees"] == 0
    assert payload["lines"] == []
    assert payload["error_code"] == "NOT_FIRST_SPREAD"
    assert payload["fields"]["lastName"]["value"] is None


def _rdocs_weights_present(settings: Settings) -> bool:
    model = (
        settings.rdocs_models_dir
        / "document_processing"
        / "models"
        / "Borders"
        / "ONNX"
        / "model.onnx"
    )
    return model.is_file()


@pytest.mark.integration
def test_real_rdocs_does_not_fill_fields_from_synthetic_text() -> None:
    pytest.importorskip("document_processing")
    settings = Settings(session_token=TOKEN, api_host="127.0.0.1")
    if not _rdocs_weights_present(settings):
        pytest.skip("RussianDocsOCR weights are not downloaded")
    app = create_app(settings=settings, warmup=True)
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/recognize",
            headers=_auth(),
            files={"image": ("spread.png", _first_spread_png(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["lines"] == []
    assert payload["fields"]["lastName"]["value"] is None
