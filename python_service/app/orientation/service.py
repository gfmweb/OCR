from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from app.domain.ocr import OCRLine
from app.ocr.provider import OCRProvider
from app.orientation.exif import exif_rotation_degrees
from app.orientation.geometry import rotate_image
from app.orientation.scoring import (
    choose_rotation,
    rotation_candidates,
    score_orientation,
    should_stop_probing,
)
from app.preprocessing.image_io import resize_max_side, to_grayscale_bgr


@dataclass(frozen=True)
class OrientationDecision:
    degrees: int
    scores: dict[int, float]
    script_scores: dict[int, float]
    exif_degrees: int | None
    winner_lines: list[OCRLine]
    probe_image: np.ndarray


class OrientationService:
    def __init__(self, provider: OCRProvider, max_side: int) -> None:
        self._provider = provider
        self._max_side = max_side

    def detect(self, image: np.ndarray, payload: bytes) -> OrientationDecision:
        probe, _scale = resize_max_side(image, self._max_side)
        height, width = probe.shape[:2]
        exif_degrees = exif_rotation_degrees(payload)
        order = rotation_candidates(height, width)
        scores: dict[int, float] = {}
        script_scores: dict[int, float] = {}
        lines_by_rotation: dict[int, list[OCRLine]] = {}
        probe_by_rotation: dict[int, np.ndarray] = {}

        def probe_degrees(degrees: int) -> None:
            if degrees in scores:
                return
            rotated = rotate_image(probe, degrees)
            gray = to_grayscale_bgr(rotated)
            lines = self._provider.recognize(gray)
            if gray is not rotated and rotated is not probe:
                del gray
            scored = score_orientation(lines)
            scores[degrees] = scored.total
            script_scores[degrees] = scored.script
            lines_by_rotation[degrees] = lines
            probe_by_rotation[degrees] = rotated

        likely = order[:2]
        rest = order[2:]
        for degrees in likely:
            probe_degrees(degrees)
        if not should_stop_probing(scores) or max(scores.values(), default=0.0) <= 0:
            winner = max(scores, key=lambda key: (scores[key], -key), default=likely[0])
            opposite = (winner + 180) % 360
            probe_degrees(opposite)
            if max(scores.values(), default=0.0) <= 0:
                for degrees in rest:
                    probe_degrees(degrees)
                    if should_stop_probing(scores):
                        break

        winner = choose_rotation(scores, exif_degrees=exif_degrees, script_scores=script_scores)
        return OrientationDecision(
            degrees=winner,
            scores=scores,
            script_scores=script_scores,
            exif_degrees=exif_degrees,
            winner_lines=lines_by_rotation[winner],
            probe_image=probe_by_rotation[winner],
        )
