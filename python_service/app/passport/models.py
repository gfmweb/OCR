from __future__ import annotations

from dataclasses import dataclass, field

from app.passport.geometry import NormRect


@dataclass
class PassportField:
    raw_value: str | None
    value: str | None
    confidence: float
    source_block_ids: list[str] = field(default_factory=list)
    bbox: NormRect | None = None
    alternatives: list[dict] = field(default_factory=list)

    def to_api_dict(self, image_width: float, image_height: float) -> dict:
        box = None
        source_region = None
        if self.bbox is not None:
            x = self.bbox.x * image_width
            y = self.bbox.y * image_height
            width = self.bbox.width * image_width
            height = self.bbox.height * image_height
            box = {
                "x": round(x, 2),
                "y": round(y, 2),
                "width": round(width, 2),
                "height": round(height, 2),
            }
            source_region = [
                [x, y],
                [x + width, y],
                [x + width, y + height],
                [x, y + height],
            ]
        return {
            "raw_value": self.raw_value,
            "value": self.value,
            "confidence": round(float(self.confidence), 4),
            "source_block_ids": self.source_block_ids,
            "bbox": box,
            "source_region": source_region,
            "alternatives": self.alternatives,
        }


def empty_field() -> PassportField:
    return PassportField(raw_value=None, value=None, confidence=0.0)


FIELD_KEYS: tuple[str, ...] = (
    "series",
    "number",
    "issuedBy",
    "issueDate",
    "departmentCode",
    "lastName",
    "firstName",
    "middleName",
    "gender",
    "birthDate",
    "birthPlace",
    "registrationAddress",
)

PERSONAL_LABELS: frozenset[str] = frozenset(
    {"lastName", "firstName", "middleName", "gender", "birthDate", "birthPlace"}
)
ISSUE_LABELS: frozenset[str] = frozenset({"issuedBy", "issueDate", "departmentCode"})
MULTILINE_FIELDS: frozenset[str] = frozenset({"issuedBy", "birthPlace", "registrationAddress"})


@dataclass(frozen=True)
class PassportFirstSpreadDetection:
    is_passport: bool
    confidence: float
    personal_hits: int = 0
    issue_hits: int = 0
    has_series_or_number: bool = False


@dataclass(frozen=True)
class FieldWarning:
    code: str
    field: str


@dataclass
class PassportFirstSpread:
    series: PassportField
    number: PassportField
    issued_by: PassportField
    issue_date: PassportField
    department_code: PassportField
    last_name: PassportField
    first_name: PassportField
    middle_name: PassportField
    gender: PassportField
    birth_date: PassportField
    birth_place: PassportField
    detection: PassportFirstSpreadDetection
    warnings: list[FieldWarning] = field(default_factory=list)
    assembled_by: str = "geometry"
    llm_ms: int = 0

    def as_fields(self) -> dict[str, PassportField]:
        return {
            "series": self.series,
            "number": self.number,
            "issuedBy": self.issued_by,
            "issueDate": self.issue_date,
            "departmentCode": self.department_code,
            "lastName": self.last_name,
            "firstName": self.first_name,
            "middleName": self.middle_name,
            "gender": self.gender,
            "birthDate": self.birth_date,
            "birthPlace": self.birth_place,
        }
