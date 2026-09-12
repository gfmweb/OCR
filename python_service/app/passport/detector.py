from __future__ import annotations

from app.passport.blocks import OCRBlock
from app.passport.labels import LabelHit
from app.passport.models import ISSUE_LABELS, PERSONAL_LABELS, PassportFirstSpreadDetection
from app.passport.parsers.number import PassportNumberParser


class PassportFirstSpreadDetector:
    def __init__(
        self,
        min_personal_labels: int = 3,
        min_issue_labels: int = 2,
    ) -> None:
        self._min_personal = min_personal_labels
        self._min_issue = min_issue_labels
        self._numbers = PassportNumberParser()

    def detect(
        self,
        hits: dict[str, LabelHit],
        blocks: list[OCRBlock],
    ) -> PassportFirstSpreadDetection:
        personal = sum(1 for key in PERSONAL_LABELS if key in hits)
        issue = sum(1 for key in ISSUE_LABELS if key in hits)
        series, number = self._numbers.from_blocks(blocks)
        has_id = bool((series and series.valid) or (number and number.valid))
        is_passport = personal >= self._min_personal and issue >= self._min_issue
        matched = personal + issue + (1 if has_id else 0)
        confidence = 0.0
        if is_passport:
            confidence = min(0.99, 0.45 + 0.07 * matched)
        else:
            confidence = min(0.4, 0.05 * matched)
        return PassportFirstSpreadDetection(
            is_passport=is_passport,
            confidence=round(confidence, 4),
            personal_hits=personal,
            issue_hits=issue,
            has_series_or_number=has_id,
        )
