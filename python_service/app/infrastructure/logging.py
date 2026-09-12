from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any

FORBIDDEN_KEYS = frozenset(
    {
        "text",
        "image",
        "base64",
        "surname",
        "name",
        "patronymic",
        "series",
        "number",
        "first_name",
        "middle_name",
        "lastName",
        "firstName",
        "middleName",
        "birthDate",
        "birthPlace",
        "issuedBy",
        "issueDate",
        "departmentCode",
        "raw_value",
        "birth_date",
        "birth_place",
        "gender",
        "passport_series",
        "passport_number",
        "issue_date",
        "issuing_authority",
        "department_code",
        "lines",
        "ocr_text",
        "fields",
        "value",
        "alternatives",
        "source_region",
        "body",
        "file",
        "filename",
        "prompt",
        "completion",
        "blocks",
        "assembled",
        "last_name_ru",
        "first_name_ru",
        "licence_number",
        "address",
        "registrationaddress",
        "photo",
        "photo_jpeg",
        "photo_jpeg_base64",
        "signature",
        "signature_jpeg",
        "signature_jpeg_base64",
        "handwritten",
    }
)

ALLOWED_KEYS = frozenset(
    {
        "request_id",
        "stage",
        "duration_ms",
        "error_code",
        "model_version",
        "provider",
        "status",
        "event",
        "line_count",
        "image_width",
        "image_height",
        "bytes",
        "rotation_degrees",
        "document_type",
        "view",
        "filled_field_count",
        "rdocs_ready",
        "has_photo",
        "has_signature",
    }
)


class PrivacyJsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "event": record.getMessage(),
        }
        extra = getattr(record, "ocr_fields", None)
        if isinstance(extra, dict):
            payload.update(_sanitize(extra))
        return json.dumps(payload, ensure_ascii=False)


def _sanitize(fields: dict[str, Any]) -> dict[str, Any]:
    clean: dict[str, Any] = {}
    for key, value in fields.items():
        lowered = key.lower()
        if lowered in FORBIDDEN_KEYS:
            continue
        if lowered not in ALLOWED_KEYS:
            continue
        clean[key] = value
    return clean


def configure_logging() -> logging.Logger:
    logger = logging.getLogger("ocr")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(PrivacyJsonFormatter())
    logger.addHandler(handler)
    logger.propagate = False
    return logger


def log_event(logger: logging.Logger, event: str, **fields: Any) -> None:
    logger.info(event, extra={"ocr_fields": fields})
