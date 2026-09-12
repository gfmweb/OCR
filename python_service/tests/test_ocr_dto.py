from app.domain.ocr import OCRLine, OCRResult, StageTimings


def test_ocr_line_roundtrip() -> None:
    line = OCRLine(
        text="ИВАНОВ",
        confidence=0.994,
        bbox=[[1.0, 2.0], [30.0, 2.0], [30.0, 10.0], [1.0, 10.0]],
    )
    restored = OCRLine.from_dict(line.to_dict())
    assert restored.text == "ИВАНОВ"
    assert restored.confidence == 0.994
    assert restored.bbox[0] == [1.0, 2.0]


def test_ocr_result_json_shape() -> None:
    result = OCRResult(
        request_id="req-1",
        lines=[OCRLine(text="ТЕСТ", confidence=0.9, bbox=[[0, 0], [1, 0], [1, 1], [0, 1]])],
        timings=StageTimings(image_loading=1, orientation=4, preprocessing=2, ocr=3, total_ms=10),
        image_width=100,
        image_height=50,
        rotation_degrees=90,
        model_version="fake-1",
        provider="fake",
    )
    payload = result.to_dict()
    assert payload["request_id"] == "req-1"
    assert payload["timings"]["ocr"] == 3
    assert payload["timings"]["orientation"] == 4
    assert payload["timings"]["parsing"] == 0
    assert payload["timings"]["llm"] == 0
    assert payload["rotation_degrees"] == 90
    assert payload["document_type"] == "unknown"
    assert payload["fields"] == {}
    assert payload["lines"][0]["text"] == "ТЕСТ"
    assert payload["photo_jpeg_base64"] is None
    assert payload["signature_jpeg_base64"] is None
    assert "surname" not in payload
