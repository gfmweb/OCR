from __future__ import annotations

import cv2
import numpy as np

from app.domain.ocr import BoundingBox

ROTATION_FLAGS = {
    90: cv2.ROTATE_90_CLOCKWISE,
    180: cv2.ROTATE_180,
    270: cv2.ROTATE_90_COUNTERCLOCKWISE,
}


def rotate_image(image: np.ndarray, degrees: int) -> np.ndarray:
    degrees = degrees % 360
    if degrees == 0:
        return image
    flag = ROTATION_FLAGS.get(degrees)
    if flag is None:
        raise ValueError(f"Unsupported rotation: {degrees}")
    return cv2.rotate(image, flag)


def size_after_rotation(width: int, height: int, degrees: int) -> tuple[int, int]:
    if degrees % 180 == 0:
        return width, height
    return height, width


def rotate_points_cw(
    points: BoundingBox,
    width: float,
    height: float,
    degrees: int,
) -> BoundingBox:
    degrees = degrees % 360
    rotated: BoundingBox = []
    for x, y in points:
        if degrees == 0:
            nx, ny = x, y
        elif degrees == 90:
            nx, ny = height - 1 - y, x
        elif degrees == 180:
            nx, ny = width - 1 - x, height - 1 - y
        elif degrees == 270:
            nx, ny = y, width - 1 - x
        else:
            raise ValueError(f"Unsupported rotation: {degrees}")
        rotated.append([float(nx), float(ny)])
    return rotated


def unrotate_points_cw(
    points: BoundingBox,
    original_width: float,
    original_height: float,
    degrees: int,
) -> BoundingBox:
    """Map points from an image rotated `degrees` CW back to the original pixels."""
    inverse = (360 - (degrees % 360)) % 360
    upright_width, upright_height = size_after_rotation(
        int(original_width),
        int(original_height),
        degrees,
    )
    return rotate_points_cw(points, upright_width, upright_height, inverse)
