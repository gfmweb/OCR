import io

import numpy as np
from app.api.server import create_app
from app.rdocs.extract import encode_jpeg
from app.rdocs.provider import DocumentFieldsSnapshot
from fastapi.testclient import TestClient
from PIL import Image
from starlette import status
from tests.conftest import FakeFieldsProvider, FakeOCRProvider, auth_header, none_snapshot


def _png_bytes(size: tuple[int, int] = (120, 80)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color=(255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def test_health_requires_token(client) -> None:
    response = client.get("/health")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_health_ok(client, settings) -> None:
    response = client.get("/health", headers=auth_header(settings))
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ready"
    assert payload["stage"] == "ready"
    assert payload["progress"] == 100
    assert payload["provider"] == "fake"
    assert payload["rdocs_ready"] is True
    assert "llm_ready" not in payload


def test_recognize_returns_structured_ocr(client, settings) -> None:
    response = client.post(
        "/api/v1/recognize",
        headers=auth_header(settings),
        files={"image": ("sample.png", _png_bytes(), "image/png")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["provider"] == "fake-rdocs"
    assert payload["lines"] == []
    assert payload["timings"]["total_ms"] >= 0
    assert payload["image_width"] == 120
    assert payload["image_height"] == 80
    assert payload["rotation_degrees"] == 0
    assert payload["timings"]["orientation"] == 0
    assert payload["document_type"] == "russian_passport"
    assert payload["view"] == "first_spread"
    assert payload["error_code"] is None
    assert payload["fields"]["lastName"]["value"] == "ИВАНОВ"
    assert payload["fields"]["series"]["value"] == "1234"
    assert payload["fields"]["number"]["value"] == "567890"
    assert payload["fields"]["gender"]["value"] == "male"
    assert payload["fields"]["registrationAddress"]["value"] is None
    assert payload["photo_jpeg_base64"] is None
    assert payload["signature_jpeg_base64"] is None
    assert any(item["code"] == "PHOTO_NOT_FOUND" for item in payload["warnings"])
    provider = client.app.state.fields_provider
    assert provider.calls == 1
    assert provider.last_shape is not None
    assert provider.last_shape[2] == 3


def test_recognize_rejects_invalid_image(client, settings) -> None:
    response = client.post(
        "/api/v1/recognize",
        headers=auth_header(settings),
        files={"image": ("sample.png", b"not-an-image", "image/png")},
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.json()["detail"]["error_code"] == "IMAGE_DECODE_FAILED"


def test_shutdown_requires_token(client) -> None:
    response = client.post("/shutdown")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_recognize_returns_photo_without_logging_bytes(settings) -> None:
    jpeg = encode_jpeg(np.full((24, 18, 3), 90, dtype=np.uint8))
    assert jpeg is not None
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORT_2011",
        ocr={"Last_name_ru": "ИВАНОВ", "Licence_number": "1234567890"},
        quality={"DocConf": 0.9},
        photo_jpeg=jpeg,
    )
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(snapshot),
        warmup=False,
    )
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/recognize",
            headers=auth_header(settings),
            files={"image": ("sample.png", _png_bytes(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["photo_jpeg_base64"]
    assert not any(item["code"] == "PHOTO_NOT_FOUND" for item in payload["warnings"])


def test_recognize_registration_page(settings) -> None:
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORTADDR",
        ocr={"Address": "Г. МОСКВА", "Licence_number": "1234 567890"},
        quality={"DocConf": 0.81},
        handwritten_address=False,
    )
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(snapshot),
        warmup=False,
    )
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/recognize",
            headers=auth_header(settings),
            data={"page": "registration"},
            files={"image": ("addr.png", _png_bytes(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["view"] == "registration"
    assert payload["error_code"] is None
    assert payload["fields"]["registrationAddress"]["value"] == "Г. МОСКВА"
    assert payload["fields"]["series"]["value"] is None
    assert payload["fields"]["number"]["value"] == "567890"
    assert payload["fields"]["lastName"]["value"] is None
    assert payload["photo_jpeg_base64"] is None
    assert payload["signature_jpeg_base64"] is None


def test_registration_hint_on_other_doctype(settings) -> None:
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(none_snapshot()),
        warmup=False,
    )
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/recognize",
            headers=auth_header(settings),
            data={"page": "registration"},
            files={"image": ("other.png", _png_bytes(), "image/png")},
        )
    assert response.status_code == 200
    payload = response.json()
    assert payload["error_code"] == "NOT_REGISTRATION_PAGE"
    assert payload["fields"]["registrationAddress"]["value"] is None

