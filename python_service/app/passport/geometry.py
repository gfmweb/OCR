from __future__ import annotations

from dataclasses import dataclass
from math import hypot


@dataclass(frozen=True)
class NormRect:
    x: float
    y: float
    width: float
    height: float

    @property
    def x2(self) -> float:
        return self.x + self.width

    @property
    def y2(self) -> float:
        return self.y + self.height

    @property
    def cx(self) -> float:
        return self.x + self.width / 2.0

    @property
    def cy(self) -> float:
        return self.y + self.height / 2.0


def overlaps_x(left: NormRect, right: NormRect, min_ratio: float = 0.15) -> bool:
    overlap = min(left.x2, right.x2) - max(left.x, right.x)
    if overlap <= 0:
        return False
    span = min(left.width, right.width)
    return overlap >= min_ratio * max(span, 0.01)


def overlaps_y(left: NormRect, right: NormRect, min_ratio: float = 0.15) -> bool:
    overlap = min(left.y2, right.y2) - max(left.y, right.y)
    if overlap <= 0:
        return False
    span = min(left.height, right.height)
    return overlap >= min_ratio * max(span, 0.008)


def distance(left: NormRect, right: NormRect) -> float:
    return hypot(left.cx - right.cx, left.cy - right.cy)


def is_near(left: NormRect, right: NormRect, max_distance: float = 0.14) -> bool:
    return distance(left, right) <= max_distance


def is_above(rect: NormRect, other: NormRect) -> bool:
    return rect.y2 <= other.y + max(0.012, 0.35 * other.height) and overlaps_x(rect, other)


def is_below(rect: NormRect, other: NormRect, max_gap: float = 0.12) -> bool:
    if rect.y + 0.004 < other.y2 - 0.35 * other.height:
        return False
    if rect.y - other.y2 > max_gap:
        return False
    return overlaps_x(rect, other, min_ratio=0.08) or (
        other.x - 0.04 <= rect.x <= other.x2 + 0.12
    )


def is_left_of(rect: NormRect, other: NormRect) -> bool:
    return rect.x2 <= other.x + max(0.01, 0.2 * other.width) and overlaps_y(rect, other)


def is_right_of(rect: NormRect, other: NormRect, max_gap: float = 0.22) -> bool:
    if rect.x + 0.004 < other.x2 - 0.2 * other.width:
        return False
    if rect.x - other.x2 > max_gap:
        return False
    return overlaps_y(rect, other, min_ratio=0.2)


def union(rects: list[NormRect]) -> NormRect | None:
    if not rects:
        return None
    x1 = min(item.x for item in rects)
    y1 = min(item.y for item in rects)
    x2 = max(item.x2 for item in rects)
    y2 = max(item.y2 for item in rects)
    return NormRect(x=x1, y=y1, width=x2 - x1, height=y2 - y1)


def polygon_to_norm_rect(
    points: list[list[float]],
    image_width: float,
    image_height: float,
) -> NormRect:
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    x1 = min(xs) if xs else 0.0
    y1 = min(ys) if ys else 0.0
    x2 = max(xs) if xs else 0.0
    y2 = max(ys) if ys else 0.0
    width = max(image_width, 1.0)
    height = max(image_height, 1.0)
    return NormRect(
        x=x1 / width,
        y=y1 / height,
        width=max(x2 - x1, 1.0) / width,
        height=max(y2 - y1, 1.0) / height,
    )


def split_right(rect: NormRect, ratio: float) -> NormRect:
    cut = min(max(ratio, 0.15), 0.85)
    width = rect.width * cut
    return NormRect(x=rect.x2 - width, y=rect.y, width=width, height=rect.height)
