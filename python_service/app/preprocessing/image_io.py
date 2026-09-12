from __future__ import annotations

import cv2
import numpy as np


class ImageDecodeError(ValueError):
    pass


def decode_image(payload: bytes) -> np.ndarray:
    if not payload:
        raise ImageDecodeError("Empty image")
    encoded = np.frombuffer(payload, dtype=np.uint8)
    image = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if image is None:
        raise ImageDecodeError("Unsupported or corrupted image")
    return image


def resize_max_side(image: np.ndarray, max_side: int) -> tuple[np.ndarray, float]:
    height, width = image.shape[:2]
    longest = max(height, width)
    if longest <= max_side:
        return image, 1.0
    scale = max_side / float(longest)
    new_width = max(1, int(round(width * scale)))
    new_height = max(1, int(round(height * scale)))
    resized = cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)
    return resized, scale


def to_grayscale_bgr(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)


def map_bbox_to_original(bbox: list[list[float]], scale: float) -> list[list[float]]:
    if scale == 0:
        return bbox
    return [[point[0] / scale, point[1] / scale] for point in bbox]
