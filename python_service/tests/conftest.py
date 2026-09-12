from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pytest
from app.api.server import create_app
from app.domain.ocr import OCRLine
from app.infrastructure.config import Settings
from app.rdocs.provider import DocumentFieldsSnapshot
from fastapi.testclient import TestClient


class FakeOCRProvider:
    name = "fake"
    model_version = "fake-1"

    def warmup(self) -> None:
        return None

    def recognize(self, image: np.ndarray) -> list[OCRLine]:
        height, width = image.shape[:2]
        return [
            OCRLine(
                text="ТЕСТ",
                confidence=0.99,
                bbox=[[10.0, 10.0], [width - 10.0, 10.0], [width - 10.0, 40.0], [10.0, 40.0]],
            )
        ]


@dataclass
class FakeFieldsProvider:
    snapshot: DocumentFieldsSnapshot
    name: str = "fake-rdocs"
    model_version: str = "fake-rdocs-1"
    ready: bool = False
    calls: int = 0
    last_shape: tuple[int, ...] | None = field(default=None, init=False)

    def warmup(self) -> None:
        self.ready = True

    def process(self, rgb_image: np.ndarray) -> DocumentFieldsSnapshot:
        self.calls += 1
        self.last_shape = rgb_image.shape
        return self.snapshot


def passport_snapshot() -> DocumentFieldsSnapshot:
    return DocumentFieldsSnapshot(
        doctype="INTPASSPORT_2011",
        ocr={
            "Last_name_ru": "ИВАНОВ",
            "First_name_ru": "ИВАН",
            "Middle_name_ru": "ИВАНОВИЧ",
            "Sex_ru": "М",
            "Birth_date": "01.01.1990",
            "Birth_place_ru": "Г. МОСКВА",
            "Licence_number": "1234 567890",
            "Issue_date": "15.06.2010",
            "Issue_organization_ru": "ОТДЕЛ МВД МОСКВА",
            "Issue_organisation_code": "770-001",
        },
        quality={"DocConf": 0.92},
    )


def none_snapshot() -> DocumentFieldsSnapshot:
    return DocumentFieldsSnapshot(doctype="NONE", ocr={}, quality={"DocConf": 0.1})


@pytest.fixture
def settings() -> Settings:
    return Settings(session_token="test-token-test-token-test-token12", api_host="127.0.0.1")


@pytest.fixture
def client(settings) -> TestClient:
    app = create_app(
        settings=settings,
        provider=FakeOCRProvider(),
        fields_provider=FakeFieldsProvider(passport_snapshot()),
        warmup=False,
    )
    with TestClient(app) as test_client:
        yield test_client


def auth_header(settings) -> dict[str, str]:
    return {"Authorization": f"Bearer {settings.session_token}"}
