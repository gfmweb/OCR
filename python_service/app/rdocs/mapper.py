from __future__ import annotations

from dataclasses import dataclass

from app.domain.ocr import ParsedField, empty_field
from app.passport.models import FIELD_KEYS
from app.passport.normalize import PassportFieldNormalizer, cross_field_warnings
from app.rdocs.provider import DocumentFieldsSnapshot

PASSPORT_DOCTYPES = frozenset({"INTPASSPORT_1997", "INTPASSPORT_2011"})
REGISTRATION_DOCTYPE = "INTPASSPORTADDR"
_HANDWRITTEN_PLACEHOLDER = "[рукопись]"
_TEXT_FIELDS = {
    "lastName": "Last_name_ru",
    "firstName": "First_name_ru",
    "middleName": "Middle_name_ru",
    "gender": "Sex_ru",
    "birthDate": "Birth_date",
    "birthPlace": "Birth_place_ru",
    "issueDate": "Issue_date",
    "issuedBy": "Issue_organization_ru",
    "departmentCode": "Issue_organisation_code",
}


@dataclass(frozen=True)
class MappedDocument:
    document_type: str
    view: str
    error_code: str | None
    document_confidence: float
    fields: dict[str, ParsedField]
    warnings: list[dict]


def map_rdocs_result(
    snapshot: DocumentFieldsSnapshot,
    normalizer: PassportFieldNormalizer | None = None,
    page: str = "first_spread",
) -> MappedDocument:
    parser = normalizer or PassportFieldNormalizer()
    doctype = _normalize_doctype(snapshot.doctype)
    confidence = _doc_confidence(snapshot.quality)
    expected = _normalize_page(page)
    if expected == "registration":
        if REGISTRATION_DOCTYPE not in doctype:
            return _rejected(confidence, "NOT_REGISTRATION_PAGE")
        return _map_registration(snapshot, parser, confidence)
    if doctype not in PASSPORT_DOCTYPES:
        return _rejected(confidence, "NOT_FIRST_SPREAD")
    return _map_first_spread(snapshot, parser, confidence)


def _map_first_spread(
    snapshot: DocumentFieldsSnapshot,
    parser: PassportFieldNormalizer,
    confidence: float,
) -> MappedDocument:
    raw_ocr = snapshot.ocr
    series_raw, number_raw = _split_licence(raw_ocr.get("Licence_number"))
    values = {key: _as_text(raw_ocr.get(source)) for key, source in _TEXT_FIELDS.items()}
    values["series"] = series_raw
    values["number"] = number_raw
    fields = {key: _to_field(parser, key, values.get(key), confidence) for key in FIELD_KEYS}
    warnings = [
        {"code": warning.code, "field": warning.field}
        for warning in cross_field_warnings(
            {
                key: _passport_field_shim(field)
                for key, field in fields.items()
                if key != "registrationAddress"
            }
        )
    ]
    if snapshot.photo_jpeg is None:
        warnings.append({"code": "PHOTO_NOT_FOUND", "field": "photo"})
    if snapshot.signature_jpeg is None:
        warnings.append({"code": "SIGNATURE_NOT_FOUND", "field": "signature"})
    return MappedDocument(
        document_type="russian_passport",
        view="first_spread",
        error_code=None,
        document_confidence=confidence,
        fields=fields,
        warnings=warnings,
    )


def _map_registration(
    snapshot: DocumentFieldsSnapshot,
    parser: PassportFieldNormalizer,
    confidence: float,
) -> MappedDocument:
    fields = {key: empty_field() for key in FIELD_KEYS}
    address = None if snapshot.handwritten_address else _clean_address(snapshot.ocr.get("Address"))
    warnings: list[dict] = []
    if address:
        fields["registrationAddress"] = _to_field(
            parser, "registrationAddress", address, confidence
        )
    else:
        warnings.append({"code": "ADDRESS_NOT_RECOGNIZED", "field": "registrationAddress"})
    _, number_raw = _split_licence(snapshot.ocr.get("Licence_number"))
    fields["number"] = _to_field(parser, "number", number_raw, confidence)
    return MappedDocument(
        document_type="russian_passport",
        view="registration",
        error_code=None,
        document_confidence=confidence,
        fields=fields,
        warnings=warnings,
    )


def _rejected(confidence: float, error_code: str) -> MappedDocument:
    return MappedDocument(
        document_type="unknown",
        view="unknown",
        error_code=error_code,
        document_confidence=confidence,
        fields={key: empty_field() for key in FIELD_KEYS},
        warnings=[],
    )


def _normalize_page(page: str | None) -> str:
    value = (page or "first_spread").strip().lower()
    if value == "registration":
        return "registration"
    return "first_spread"


def _normalize_doctype(doctype: str | None) -> str:
    return (doctype or "").strip().upper()


def _doc_confidence(quality: dict[str, object]) -> float:
    value = quality.get("DocConf", 0.0)
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return 0.0


def _as_text(value: object | None) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _clean_address(value: object | None) -> str | None:
    text = _as_text(value)
    if text is None:
        return None
    lines: list[str] = []
    for line in text.splitlines():
        cleaned = line.replace(_HANDWRITTEN_PLACEHOLDER, "").strip()
        if cleaned:
            lines.append(cleaned)
    return "\n".join(lines) or None


def _split_licence(raw: object | None) -> tuple[str | None, str | None]:
    text = _as_text(raw)
    if text is None:
        return None, None
    digits = "".join(char for char in text if char.isdigit())
    if len(digits) >= 10:
        return digits[:4], digits[4:10]
    parts = text.split()
    if len(parts) >= 2:
        return parts[0], parts[1]
    return text, None


def _to_field(
    parser: PassportFieldNormalizer,
    key: str,
    raw: str | None,
    confidence: float,
) -> ParsedField:
    if not raw:
        return empty_field()
    attempt = parser.parse_field(key, [raw])
    if attempt.valid and attempt.value:
        return ParsedField(
            value=attempt.value,
            raw_value=raw,
            confidence=confidence,
            source_region=None,
        )
    return ParsedField(
        value=raw,
        raw_value=raw,
        confidence=min(confidence, 0.4),
        source_region=None,
        alternatives=list(attempt.alternatives),
    )


def _passport_field_shim(field: ParsedField):
    from app.passport.models import PassportField

    return PassportField(raw_value=field.raw_value, value=field.value, confidence=field.confidence)
