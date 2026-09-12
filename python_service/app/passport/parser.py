from __future__ import annotations

from typing import Any

from app.passport.blocks import OCRBlock
from app.passport.confidence import field_confidence
from app.passport.detector import PassportFirstSpreadDetector
from app.passport.extractor import PassportFieldExtractor, ValueCandidate, page_bounds
from app.passport.geometry import union
from app.passport.labels import PassportLabelDetector
from app.passport.models import (
    FIELD_KEYS,
    ISSUE_LABELS,
    MULTILINE_FIELDS,
    PERSONAL_LABELS,
    PassportField,
    PassportFirstSpread,
    PassportFirstSpreadDetection,
    empty_field,
)
from app.passport.normalize import PassportFieldNormalizer, cross_field_warnings
from app.passport.parsers.number import PassportNumberParser
from app.passport.parsers.result import ParseAttempt


class PassportFirstSpreadParser:
    def __init__(
        self,
        label_threshold: float = 0.78,
        min_personal_labels: int = 3,
        min_issue_labels: int = 2,
    ) -> None:
        self._labels = PassportLabelDetector(threshold=label_threshold)
        self._extractor = PassportFieldExtractor(self._labels)
        self._detector = PassportFirstSpreadDetector(
            min_personal_labels=min_personal_labels,
            min_issue_labels=min_issue_labels,
        )
        self._numbers = PassportNumberParser()
        self.last_llm_ms = 0
        self.last_assembled_by = "none"

    def parse(self, blocks: list[OCRBlock], assembler: Any | None = None) -> PassportFirstSpread:
        hits = self._labels.detect(blocks)
        detection = self._detector.detect(hits, blocks)
        self.last_llm_ms = 0
        if not detection.is_passport:
            self.last_assembled_by = "none"
            return _empty_spread(detection)
        if assembler is not None:
            outcome = assembler.assemble(blocks, detection)
            self.last_llm_ms = getattr(outcome, "elapsed_ms", 0)
            if getattr(outcome, "ok", False) and getattr(outcome, "spread", None) is not None:
                self.last_assembled_by = "llm"
                return outcome.spread
        self.last_assembled_by = "geometry"
        return self._parse_geometry(blocks, hits, detection)

    def _parse_geometry(
        self,
        blocks: list[OCRBlock],
        hits: dict,
        detection: PassportFirstSpreadDetection,
    ) -> PassportFirstSpread:
        empty = {key: empty_field() for key in FIELD_KEYS}
        series_attempt, number_attempt = self._numbers.from_blocks(blocks)
        series = _from_attempt(series_attempt, _band_blocks(blocks, series_attempt), 0.7)
        number = _from_attempt(number_attempt, _band_blocks(blocks, number_attempt), 0.7)
        issue_min, issue_max, personal_min, personal_max = page_bounds(hits)
        fields = dict(empty)
        fields["series"] = series
        fields["number"] = number
        for key in (*ISSUE_LABELS, *PERSONAL_LABELS):
            hit = hits.get(key)
            if hit is None:
                continue
            bounds = (issue_min, issue_max) if key in ISSUE_LABELS else (personal_min, personal_max)
            candidates = self._extractor.extract(key, hit, blocks, hits, bounds[0], bounds[1])
            fields[key] = _pick(key, candidates)
        warnings = cross_field_warnings(fields)
        if any(item.code == "ISSUE_BEFORE_BIRTH" for item in warnings):
            issue = fields["issueDate"]
            issue.confidence = round(issue.confidence * 0.7, 4)
        return PassportFirstSpread(
            series=fields["series"],
            number=fields["number"],
            issued_by=fields["issuedBy"],
            issue_date=fields["issueDate"],
            department_code=fields["departmentCode"],
            last_name=fields["lastName"],
            first_name=fields["firstName"],
            middle_name=fields["middleName"],
            gender=fields["gender"],
            birth_date=fields["birthDate"],
            birth_place=fields["birthPlace"],
            detection=detection,
            warnings=warnings,
            assembled_by="geometry",
            llm_ms=0,
        )


def build_parser(
    threshold: float = 0.78,
    min_personal_labels: int = 3,
    min_issue_labels: int = 2,
) -> PassportFirstSpreadParser:
    return PassportFirstSpreadParser(
        label_threshold=threshold,
        min_personal_labels=min_personal_labels,
        min_issue_labels=min_issue_labels,
    )


def _empty_spread(detection: PassportFirstSpreadDetection) -> PassportFirstSpread:
    empty = {key: empty_field() for key in FIELD_KEYS}
    return PassportFirstSpread(
        series=empty["series"],
        number=empty["number"],
        issued_by=empty["issuedBy"],
        issue_date=empty["issueDate"],
        department_code=empty["departmentCode"],
        last_name=empty["lastName"],
        first_name=empty["firstName"],
        middle_name=empty["middleName"],
        gender=empty["gender"],
        birth_date=empty["birthDate"],
        birth_place=empty["birthPlace"],
        detection=detection,
        assembled_by="none",
        llm_ms=0,
    )


def _pick(field: str, candidates: list[ValueCandidate]) -> PassportField:
    normalizer = PassportFieldNormalizer()
    ranked: list[tuple[float, PassportField]] = []
    for candidate in candidates:
        texts = [block.text for block in candidate.blocks]
        attempt = normalizer.parse_field(field, texts)
        if not texts:
            continue
        raw = " ".join(part.strip() for part in texts if part.strip())
        ocr = sum(block.confidence for block in candidate.blocks) / max(len(candidate.blocks), 1)
        spatial = candidate.spatial
        format_ok = attempt.valid
        normalized = bool(attempt.value) and attempt.value != attempt.raw
        conf = field_confidence(ocr, spatial, format_ok, normalized or format_ok)
        if not attempt.confident:
            conf = min(conf, 0.42)
        value = attempt.value if attempt.confident else None
        merged = union([block.bbox for block in candidate.blocks])
        ranked.append(
            (
                conf,
                PassportField(
                    raw_value=raw or attempt.raw,
                    value=value,
                    confidence=conf,
                    source_block_ids=[block.id for block in candidate.blocks],
                    bbox=merged,
                    alternatives=attempt.alternatives,
                ),
            )
        )
    if not ranked:
        return empty_field()
    ranked.sort(key=lambda item: item[0], reverse=True)
    best = ranked[0][1]
    extras = []
    for conf, item in ranked[1:]:
        if item.value and item.value != best.value:
            extras.append({"value": item.value, "confidence": conf})
    if extras:
        best.alternatives = [*best.alternatives, *extras]
    if field in MULTILINE_FIELDS and best.value:
        return best
    return best


def _from_attempt(
    attempt: ParseAttempt | None,
    blocks: list[OCRBlock],
    spatial: float,
) -> PassportField:
    if attempt is None or not attempt.valid:
        return empty_field()
    ocr = sum(block.confidence for block in blocks) / max(len(blocks), 1) if blocks else 0.8
    box = union([block.bbox for block in blocks]) if blocks else None
    return PassportField(
        raw_value=attempt.raw,
        value=attempt.value,
        confidence=field_confidence(ocr, spatial, True, True),
        source_block_ids=[block.id for block in blocks],
        bbox=box,
        alternatives=[],
    )


def _band_blocks(blocks: list[OCRBlock], attempt: ParseAttempt | None) -> list[OCRBlock]:
    if attempt is None or not attempt.raw:
        return []
    return [block for block in blocks if block.text.strip() == attempt.raw]
