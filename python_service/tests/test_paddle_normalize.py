import numpy as np
from app.ocr.paddle_provider import _normalize_paddle_result


def test_normalize_v3_dict() -> None:
    raw = [
        {
            "rec_texts": ["ИВАНОВ", "ИВАН"],
            "rec_scores": [0.99, 0.95],
            "rec_polys": [
                [[0, 0], [10, 0], [10, 5], [0, 5]],
                [[0, 10], [12, 10], [12, 16], [0, 16]],
            ],
        }
    ]
    lines = _normalize_paddle_result(raw)
    assert [line.text for line in lines] == ["ИВАНОВ", "ИВАН"]
    assert lines[0].confidence == 0.99
    assert lines[1].bbox[0] == [0.0, 10.0]


def test_normalize_empty() -> None:
    assert _normalize_paddle_result(None) == []
    assert _normalize_paddle_result([]) == []


def test_normalize_empty_numpy_boxes() -> None:
    raw = [{"rec_texts": [], "rec_scores": [], "rec_polys": np.array([])}]
    assert _normalize_paddle_result(raw) == []
