from __future__ import annotations

from collections.abc import Callable

import cv2
import numpy as np

PHOTO_LABELS = frozenset({"face", "photo", "portrait"})
SIGNATURE_LABELS = frozenset({"signature"})
_LICENCE_LABEL = "licence_number"


def extract_photo_jpeg(
    canvas_rgb: np.ndarray | None,
    text_fields: dict | None,
) -> bytes | None:
    patch = _labeled_patch(canvas_rgb, text_fields, PHOTO_LABELS)
    if patch is None:
        patch = _face_crop(canvas_rgb)
    return encode_jpeg(patch)


def extract_signature_jpeg(
    canvas_rgb: np.ndarray | None,
    text_fields: dict | None,
) -> bytes | None:
    return encode_jpeg(_labeled_patch(canvas_rgb, text_fields, SIGNATURE_LABELS))


def read_licence_number(
    text_fields: dict | None,
    ocr: Callable[[np.ndarray], str],
) -> str | None:
    candidates = _labelled_patches(text_fields, _LICENCE_LABEL)
    if not candidates:
        return None
    patch, _conf = max(candidates, key=lambda item: item[1])
    scored: list[tuple[int, str]] = []
    for image in (cv2.rotate(patch, cv2.ROTATE_90_COUNTERCLOCKWISE), patch):
        text = (ocr(image) or "").strip()
        digits = "".join(char for char in text if char.isdigit())
        scored.append((len(digits), text))
    scored.sort(key=lambda item: item[0], reverse=True)
    best_digits, best_text = scored[0]
    if best_digits == 0:
        return None
    return best_text


def encode_jpeg(rgb: np.ndarray | None, quality: int = 85) -> bytes | None:
    if rgb is None or rgb.size == 0:
        return None
    if rgb.ndim != 3 or rgb.shape[2] != 3:
        return None
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    ok, buffer = cv2.imencode(".jpg", bgr, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        return None
    return buffer.tobytes()


def _labeled_patch(
    canvas_rgb: np.ndarray | None,
    text_fields: dict | None,
    allowed: frozenset[str],
) -> np.ndarray | None:
    candidates = _labelled_patches(text_fields, None, allowed=allowed)
    if not candidates:
        return _crop_from_boxes(canvas_rgb, text_fields, allowed)
    patch, _conf = max(candidates, key=lambda item: item[1])
    if patch is not None and patch.size > 0:
        return patch
    return _crop_from_boxes(canvas_rgb, text_fields, allowed)


def _labelled_patches(
    text_fields: dict | None,
    label: str | None,
    allowed: frozenset[str] | None = None,
) -> list[tuple[np.ndarray, float]]:
    if not text_fields:
        return []
    boxes = text_fields.get("bbox") or []
    patches = text_fields.get("warped_img") or []
    found: list[tuple[np.ndarray, float]] = []
    for index, box in enumerate(boxes):
        name = _box_label(box)
        if label is not None and name != label:
            continue
        if allowed is not None and name not in allowed:
            continue
        patch = patches[index] if index < len(patches) else None
        if patch is None or getattr(patch, "size", 0) == 0:
            continue
        found.append((patch, _box_confidence(box)))
    return found


def _crop_from_boxes(
    canvas_rgb: np.ndarray | None,
    text_fields: dict | None,
    allowed: frozenset[str],
) -> np.ndarray | None:
    if canvas_rgb is None or canvas_rgb.size == 0 or not text_fields:
        return None
    best_box = None
    best_conf = -1.0
    for box in text_fields.get("bbox") or []:
        if _box_label(box) not in allowed:
            continue
        conf = _box_confidence(box)
        if conf > best_conf:
            best_box = box
            best_conf = conf
    if best_box is None:
        return None
    return _crop_xyxy(canvas_rgb, best_box)


def _face_crop(canvas_rgb: np.ndarray | None) -> np.ndarray | None:
    if canvas_rgb is None or canvas_rgb.size == 0:
        return None
    height, width = canvas_rgb.shape[:2]
    left_width = max(width // 2, 1)
    left = canvas_rgb[:, :left_width]
    cascade_path = getattr(cv2, "data", None)
    if cascade_path is None:
        return None
    classifier = cv2.CascadeClassifier(
        str(cv2.data.haarcascades) + "haarcascade_frontalface_default.xml"
    )
    if classifier.empty():
        return None
    gray = cv2.cvtColor(left, cv2.COLOR_RGB2GRAY)
    faces = classifier.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(24, 24))
    if len(faces) == 0:
        return None
    x, y, face_w, face_h = max(faces, key=lambda item: int(item[2]) * int(item[3]))
    pad = int(0.15 * max(face_w, face_h))
    x0 = max(0, int(x) - pad)
    y0 = max(0, int(y) - pad)
    x1 = min(left.shape[1], int(x) + int(face_w) + pad)
    y1 = min(left.shape[0], int(y) + int(face_h) + pad)
    crop = left[y0:y1, x0:x1]
    return crop if crop.size else None


def _crop_xyxy(canvas_rgb: np.ndarray, box: list) -> np.ndarray | None:
    if len(box) < 4:
        return None
    height, width = canvas_rgb.shape[:2]
    x1 = max(0, min(width, int(box[0])))
    y1 = max(0, min(height, int(box[1])))
    x2 = max(0, min(width, int(box[2])))
    y2 = max(0, min(height, int(box[3])))
    if x2 <= x1 or y2 <= y1:
        return None
    crop = canvas_rgb[y1:y2, x1:x2]
    return crop if crop.size else None


def _box_label(box: list) -> str:
    if not box:
        return ""
    return str(box[-1]).strip().lower()


def _box_confidence(box: list) -> float:
    if len(box) < 5:
        return 0.0
    try:
        return float(box[4])
    except (TypeError, ValueError):
        return 0.0
