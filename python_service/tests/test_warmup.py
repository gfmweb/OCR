from __future__ import annotations

import threading
from types import SimpleNamespace

from app.api.server import create_app
from app.rdocs.pipeline import RussianDocsFieldsProvider
from fastapi.testclient import TestClient
from starlette import status
from tests.conftest import FakeFieldsProvider, FakeOCRProvider, auth_header, passport_snapshot
from tests.test_api import _png_bytes


class BlockingFieldsProvider(FakeFieldsProvider):
    def __init__(self, snapshot, gate: threading.Event) -> None:
        super().__init__(snapshot)
        self.gate = gate
        self.released = False

    def warmup(self, on_stage=None) -> None:
        if on_stage is not None:
            on_stage("loading_models")
        self.gate.wait(timeout=5)
        super().warmup(on_stage=on_stage)

    def release(self) -> None:
        self.released = True
        super().release()


class _FakePipeline:
    def __init__(self, fail: bool = False) -> None:
        self.shapes: list[tuple[int, ...]] = []
        self.fail = fail

    def process_img(self, image, **kwargs):
        self.shapes.append(tuple(image.shape))
        if self.fail:
            raise RuntimeError("probe failed")
        return SimpleNamespace(
            doctype="NONE",
            ocr={},
            quality={},
            text_fields_meta=None,
        )


def test_health_starting_reports_progress(settings) -> None:
    gate = threading.Event()
    provider = BlockingFieldsProvider(passport_snapshot(), gate)
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=provider,
        warmup=True,
    )
    with TestClient(app) as client:
        payload = client.get("/health", headers=auth_header(settings)).json()
        assert payload["status"] == "starting"
        assert payload["stage"] in {"starting_server", "loading_models"}
        assert payload["progress"] < 100
        assert payload["rdocs_ready"] is False
        response = client.post(
            "/api/v1/recognize",
            headers=auth_header(settings),
            files={"image": ("sample.png", _png_bytes(), "image/png")},
        )
        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
        assert response.json()["detail"]["error_code"] == "SERVICE_STARTING"
        gate.set()
        thread = getattr(app.state, "warmup_thread", None)
        if thread is not None:
            thread.join(timeout=2)
        ready = client.get("/health", headers=auth_header(settings)).json()
        assert ready["status"] == "ready"
        assert ready["progress"] == 100
        assert ready["stage"] == "ready"


def test_shutdown_releases_provider(settings) -> None:
    provider = BlockingFieldsProvider(passport_snapshot(), threading.Event())
    provider.ready = True
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=provider,
        warmup=False,
    )
    with TestClient(app) as client:
        response = client.post("/shutdown", headers=auth_header(settings))
        assert response.status_code == 200
        assert response.json()["status"] == "shutting_down"
        assert provider.released is True
        assert provider.ready is False


def test_probe_uses_synthetic_image(settings) -> None:
    provider = RussianDocsFieldsProvider(settings)
    pipeline = _FakePipeline()
    provider._pipeline = pipeline
    provider.probe()
    assert pipeline.shapes == [(64, 64, 3)]


def test_probe_error_does_not_drop_pipeline(settings) -> None:
    provider = RussianDocsFieldsProvider(settings)
    pipeline = _FakePipeline(fail=True)
    provider._pipeline = pipeline
    try:
        provider.probe()
    except RuntimeError:
        if provider._pipeline is None:
            raise
    assert provider._pipeline is pipeline
    provider.release()
    assert provider.ready is False
    assert provider._pipeline is None
