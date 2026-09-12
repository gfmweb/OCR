import logging

from app.infrastructure.logging import PrivacyJsonFormatter, log_event


def test_privacy_formatter_strips_forbidden_fields() -> None:
    formatter = PrivacyJsonFormatter()
    record = logging.LogRecord(
        name="ocr",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="recognize_done",
        args=(),
        exc_info=None,
    )
    record.ocr_fields = {
        "request_id": "abc",
        "stage": "ocr",
        "duration_ms": 12,
        "text": "ИВАНОВ",
        "surname": "ИВАНОВ",
        "image": "base64-secret",
        "ocr_text": "secret",
        "fields": {"surname": "ИВАНОВ"},
        "gender": "МУЖ",
        "unknown": "drop-me",
        "prompt": "ИВАНОВ OCR",
        "completion": "lastName ИВАНОВ",
        "photo_jpeg_base64": "/9j/secret-face",
        "signature_jpeg_base64": "/9j/secret-sign",
        "address": "Г. МОСКВА",
        "has_photo": True,
        "has_signature": True,
    }
    rendered = formatter.format(record)
    assert "abc" in rendered
    assert '"stage": "ocr"' in rendered
    assert "ИВАНОВ" not in rendered
    assert "base64-secret" not in rendered
    assert "secret" not in rendered
    assert "drop-me" not in rendered
    assert "prompt" not in rendered
    assert "completion" not in rendered
    assert "secret-face" not in rendered
    assert "secret-sign" not in rendered
    assert "МОСКВА" not in rendered
    assert '"has_photo": true' in rendered
    assert '"has_signature": true' in rendered


def test_log_event_does_not_embed_text(caplog) -> None:
    logger = logging.getLogger("ocr-test-privacy")
    caplog.set_level(logging.INFO, logger="ocr-test-privacy")
    log_event(logger, "ocr", request_id="r1", stage="ocr", text="ПЕТРОВ")
    assert "ПЕТРОВ" not in caplog.text
