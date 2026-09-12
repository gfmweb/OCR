import numpy as np
from app.domain.ocr import OCRLine
from app.orientation.service import OrientationService


class ScriptedOCRProvider:
    name = "scripted"
    model_version = "scripted-1"

    def __init__(self, replies: list[list[OCRLine]]) -> None:
        self._replies = replies
        self.calls = 0

    def warmup(self) -> None:
        return None

    def recognize(self, image: np.ndarray) -> list[OCRLine]:
        lines = self._replies[min(self.calls, len(self._replies) - 1)]
        self.calls += 1
        return lines


def _cyrillic(confidence: float = 0.95) -> list[OCRLine]:
    return [
        OCRLine(
            text="ИВАНОВ",
            confidence=confidence,
            bbox=[[10, 10], [120, 10], [120, 28], [10, 28]],
        )
    ]


def test_portrait_probe_stops_after_clear_sideways_winner() -> None:
    provider = ScriptedOCRProvider(
        [
            _cyrillic(0.99),
            _cyrillic(0.2),
            _cyrillic(0.99),
            _cyrillic(0.99),
        ]
    )
    service = OrientationService(provider=provider, max_side=640)
    image = np.zeros((400, 200, 3), dtype=np.uint8)
    decision = service.detect(image, b"not-a-jpeg")
    assert decision.degrees == 90
    assert provider.calls == 2
    assert 0 not in decision.scores
    assert 180 not in decision.scores
