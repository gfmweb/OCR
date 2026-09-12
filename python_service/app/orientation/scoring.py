from __future__ import annotations

from dataclasses import dataclass

from app.domain.ocr import OCRLine

CANDIDATE_ROTATIONS = (0, 90, 180, 270)
_CYRILLIC_START = 0x0400
_CYRILLIC_END = 0x04FF
_EARLY_EXIT_RATIO = 1.8


@dataclass(frozen=True)
class OrientationScore:
    total: float
    script: float


def rotation_candidates(height: int, width: int) -> tuple[int, ...]:
    if height > width:
        return (90, 270, 0, 180)
    return (0, 180, 90, 270)


def score_ocr_orientation(lines: list[OCRLine]) -> float:
    return score_orientation(lines).total


def score_orientation(lines: list[OCRLine]) -> OrientationScore:
    """Higher script score means more confident upright letters, ignoring box shape."""
    total = 0.0
    script = 0.0
    for line in lines:
        text = line.text.strip()
        if not text:
            continue
        letters = 0
        cyrillic = 0
        digits = 0
        for char in text:
            code = ord(char)
            if _CYRILLIC_START <= code <= _CYRILLIC_END:
                letters += 1
                cyrillic += 1
            elif char.isalpha():
                letters += 1
            elif char.isdigit():
                digits += 1
        if letters == 0 and digits == 0:
            continue
        cyr_ratio = cyrillic / max(len(text), 1)
        char_weight = letters + 0.4 * digits
        script_weight = 0.55 + 0.45 * cyr_ratio
        line_script = float(line.confidence) * char_weight * script_weight
        horizontal_bonus = 1.4 if _is_horizontal(line.bbox) else 0.4
        script += line_script
        total += line_script * horizontal_bonus
    return OrientationScore(total=total, script=script)


def choose_rotation(
    scores: dict[int, float],
    exif_degrees: int | None = None,
    script_scores: dict[int, float] | None = None,
) -> int:
    if not scores:
        return 0
    ranked = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    best_rotation, best_score = ranked[0]
    if best_score <= 0:
        return exif_degrees if exif_degrees in scores else 0
    opposite = (best_rotation + 180) % 360
    scripts = script_scores or {}
    if opposite in scores:
        opposite_score = scores[opposite]
        close = _nearly_equal(best_score, opposite_score)
        if close:
            best_script = scripts.get(best_rotation, best_score)
            opposite_script = scripts.get(opposite, opposite_score)
            if opposite_script > best_script:
                best_rotation = opposite
                best_score = opposite_score
            elif opposite_script == best_script:
                best_rotation = min(best_rotation, opposite)
                best_score = scores[best_rotation]
    if (
        exif_degrees in scores
        and scores[exif_degrees] >= best_score * 0.85
        and abs(scores[exif_degrees] - best_score) <= max(best_score * 0.15, 1e-6)
    ):
        return exif_degrees
    return best_rotation


def should_stop_probing(scores: dict[int, float]) -> bool:
    if len(scores) < 2:
        return False
    ranked = sorted(scores.values(), reverse=True)
    return ranked[0] > 0 and ranked[0] >= _EARLY_EXIT_RATIO * ranked[1]


def _nearly_equal(left: float, right: float) -> bool:
    peak = max(left, right, 1e-6)
    return abs(left - right) <= max(peak * 0.15, 1e-6)


def _is_horizontal(bbox: list[list[float]]) -> bool:
    if len(bbox) < 2:
        return True
    xs = [point[0] for point in bbox]
    ys = [point[1] for point in bbox]
    width = max(xs) - min(xs)
    height = max(ys) - min(ys)
    return width >= height * 1.15
