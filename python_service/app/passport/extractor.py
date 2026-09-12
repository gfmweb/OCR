from __future__ import annotations

from dataclasses import dataclass

from app.passport.blocks import OCRBlock
from app.passport.geometry import (
    NormRect,
    distance,
    is_below,
    is_right_of,
    split_right,
    union,
)
from app.passport.labels import LabelHit, PassportLabelDetector
from app.passport.models import ISSUE_LABELS, MULTILINE_FIELDS, PERSONAL_LABELS


@dataclass(frozen=True)
class ValueCandidate:
    blocks: list[OCRBlock]
    spatial: float
    relation: str


class PassportFieldExtractor:
    def __init__(self, detector: PassportLabelDetector) -> None:
        self._detector = detector

    def extract(
        self,
        field: str,
        hit: LabelHit,
        blocks: list[OCRBlock],
        hits: dict[str, LabelHit],
        x_min: float,
        x_max: float,
    ) -> list[ValueCandidate]:
        label = hit.block
        occupied = {item.block.id for item in hits.values()}
        usable = [
            block
            for block in blocks
            if block.id not in occupied or block.id == label.id
        ]
        remainder = self._remainder_candidate(field, label)
        below = [
            block
            for block in usable
            if block.id != label.id
            and self._in_band(block.bbox, x_min, x_max)
            and is_below(
                block.bbox,
                label.bbox,
                max_gap=0.16 if field in MULTILINE_FIELDS else 0.09,
            )
            and not self._is_foreign_label(block.text, field)
            and not self._blocked_by_next_label(block, label, blocks, field)
        ]
        right = [
            block
            for block in usable
            if block.id != label.id
            and self._in_band(block.bbox, x_min, x_max)
            and is_right_of(block.bbox, label.bbox)
            and not self._is_foreign_label(block.text, field)
            and not self._detector.is_label(block.text, field)
        ]
        below.sort(key=lambda item: (item.bbox.y, item.bbox.x))
        right.sort(key=lambda item: (item.bbox.y, item.bbox.x))
        candidates: list[ValueCandidate] = []
        if remainder is not None:
            candidates.append(remainder)
        if field in MULTILINE_FIELDS and below:
            candidates.append(
                ValueCandidate(blocks=below, spatial=0.9, relation="below")
            )
        elif below:
            first_value = next(
                (block for block in below if not self._detector.is_label(block.text, field)),
                None,
            )
            if first_value is not None:
                candidates.append(
                    ValueCandidate(blocks=[first_value], spatial=0.88, relation="below")
                )
        if not _has_printed_value(candidates, self._detector, field) and right:
            candidates.append(
                ValueCandidate(blocks=[right[0]], spatial=0.72, relation="right")
            )
        return candidates

    def _remainder_candidate(self, field: str, label: OCRBlock) -> ValueCandidate | None:
        leftover = self._detector.remainder_after_label(label.text, field)
        if not leftover:
            return None
        ratio = len(leftover) / max(len(label.text.strip()), 1)
        box = split_right(label.bbox, ratio)
        block = OCRBlock(
            id=f"{label.id}:value",
            text=leftover,
            confidence=label.confidence,
            bbox=box,
        )
        return ValueCandidate(blocks=[block], spatial=0.95, relation="same_line")

    def _is_foreign_label(self, text: str, field: str) -> bool:
        return self._detector.looks_like_label(text) and not self._detector.is_label(text, field)

    def _blocked_by_next_label(
        self,
        block: OCRBlock,
        label: OCRBlock,
        blocks: list[OCRBlock],
        field: str,
    ) -> bool:
        next_top = None
        for item in blocks:
            if not self._is_foreign_label(item.text, field):
                continue
            if item.bbox.y <= label.bbox.y2 + 0.002:
                continue
            if abs(item.bbox.cx - label.bbox.cx) > 0.28:
                continue
            next_top = item.bbox.y if next_top is None else min(next_top, item.bbox.y)
        if next_top is None:
            return False
        return block.bbox.y >= next_top - 0.004

    def _in_band(self, rect: NormRect, x_min: float, x_max: float) -> bool:
        return rect.cx >= x_min - 0.02 and rect.cx <= x_max + 0.02


def page_bounds(hits: dict[str, LabelHit]) -> tuple[float, float, float, float]:
    personal = [hits[key].block.bbox.x for key in PERSONAL_LABELS if key in hits]
    issue = [hits[key].block.bbox.x2 for key in ISSUE_LABELS if key in hits]
    if personal and issue:
        split = (max(issue) + min(personal)) / 2.0
        return 0.0, split, split, 1.0
    return 0.0, 1.0, 0.0, 1.0


def candidate_union(candidate: ValueCandidate) -> NormRect | None:
    return union([block.bbox for block in candidate.blocks])


def spatial_nearness(label: OCRBlock, candidate: ValueCandidate) -> float:
    box = candidate_union(candidate)
    if box is None:
        return 0.0
    dist = distance(label.bbox, box)
    return max(0.0, 1.0 - dist / 0.25)


def _has_printed_value(
    candidates: list[ValueCandidate],
    detector: PassportLabelDetector,
    field: str,
) -> bool:
    for candidate in candidates:
        for block in candidate.blocks:
            if detector.is_label(block.text, field) or detector.looks_like_label(block.text):
                continue
            if block.text.strip():
                return True
    return False
