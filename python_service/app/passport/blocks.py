from __future__ import annotations

from dataclasses import dataclass

from app.domain.ocr import OCRLine
from app.passport.geometry import NormRect, polygon_to_norm_rect


@dataclass(frozen=True)
class OCRBlock:
    id: str
    text: str
    confidence: float
    bbox: NormRect


def blocks_from_lines(
    lines: list[OCRLine],
    image_width: float,
    image_height: float,
) -> list[OCRBlock]:
    blocks: list[OCRBlock] = []
    for index, line in enumerate(lines):
        blocks.append(
            OCRBlock(
                id=f"b{index}",
                text=line.text,
                confidence=float(line.confidence),
                bbox=polygon_to_norm_rect(line.bbox, image_width, image_height),
            )
        )
    return blocks
