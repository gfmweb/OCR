from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any

Point = list[float]
BoundingBox = list[Point]


@dataclass(frozen=True)
class OCRLine:
    text: str
    confidence: float
    bbox: BoundingBox

    def to_dict(self) -> dict:
        return {
            "text": self.text,
            "confidence": round(float(self.confidence), 4),
            "bbox": self.bbox,
        }

    @classmethod
    def from_dict(cls, payload: dict) -> OCRLine:
        return cls(
            text=str(payload["text"]),
            confidence=float(payload["confidence"]),
            bbox=[[float(x), float(y)] for x, y in payload["bbox"]],
        )


@dataclass
class ParsedField:
    value: str | None
    confidence: float
    source_region: BoundingBox | None
    raw_value: str | None = None
    source_block_ids: list[str] = field(default_factory=list)
    bbox: dict | None = None
    alternatives: list[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "raw_value": self.raw_value,
            "value": self.value,
            "confidence": round(float(self.confidence), 4),
            "source_block_ids": self.source_block_ids,
            "bbox": self.bbox,
            "source_region": self.source_region,
            "alternatives": self.alternatives,
        }


def empty_field() -> ParsedField:
    return ParsedField(value=None, confidence=0.0, source_region=None)


@dataclass
class StageTimings:
    image_loading: int = 0
    orientation: int = 0
    preprocessing: int = 0
    ocr: int = 0
    parsing: int = 0
    llm: int = 0
    total_ms: int = 0

    def to_dict(self) -> dict[str, int]:
        return asdict(self)


@dataclass
class OCRResult:
    request_id: str
    lines: list[OCRLine]
    timings: StageTimings
    image_width: int
    image_height: int
    model_version: str
    provider: str
    rotation_degrees: int = 0
    document_type: str = "unknown"
    document_confidence: float = 0.0
    view: str = "unknown"
    error_code: str | None = None
    fields: dict[str, ParsedField] = field(default_factory=dict)
    warnings: list[dict] = field(default_factory=list)
    extras: dict = field(default_factory=dict)
    photo_jpeg_base64: str | None = None
    signature_jpeg_base64: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "request_id": self.request_id,
            "document_type": self.document_type,
            "document_confidence": round(float(self.document_confidence), 4),
            "view": self.view,
            "error_code": self.error_code,
            "warnings": self.warnings,
            "fields": {key: value.to_dict() for key, value in self.fields.items()},
            "lines": [line.to_dict() for line in self.lines],
            "timings": self.timings.to_dict(),
            "image_width": self.image_width,
            "image_height": self.image_height,
            "rotation_degrees": self.rotation_degrees,
            "model_version": self.model_version,
            "provider": self.provider,
            "photo_jpeg_base64": self.photo_jpeg_base64,
            "signature_jpeg_base64": self.signature_jpeg_base64,
        }
