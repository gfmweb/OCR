from __future__ import annotations


def field_confidence(
    ocr: float,
    spatial: float,
    format_ok: bool,
    normalized: bool,
    warning: bool = False,
) -> float:
    score = (
        0.35 * max(min(ocr, 1.0), 0.0)
        + 0.25 * max(min(spatial, 1.0), 0.0)
        + 0.25 * (1.0 if format_ok else 0.0)
        + 0.15 * (1.0 if normalized else 0.35)
    )
    if warning:
        score *= 0.7
    return round(min(max(score, 0.0), 0.99), 4)
