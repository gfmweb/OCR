from __future__ import annotations

import numpy as np
from app.rdocs.extract import (
    encode_jpeg,
    extract_photo_jpeg,
    extract_signature_jpeg,
    read_licence_number,
)


def test_extract_photo_from_face_patch() -> None:
    canvas = np.zeros((80, 80, 3), dtype=np.uint8)
    patch = np.full((30, 24, 3), 180, dtype=np.uint8)
    canvas[10:40, 8:32] = patch
    jpeg = extract_photo_jpeg(
        canvas,
        {
            "bbox": [[8, 10, 32, 40, 0.91, 0, "Face"]],
            "warped_img": [patch],
        },
    )
    assert jpeg is not None
    assert jpeg[:2] == b"\xff\xd8"


def test_extract_photo_from_box_when_patch_missing() -> None:
    canvas = np.zeros((60, 60, 3), dtype=np.uint8)
    canvas[5:35, 5:25] = 200
    jpeg = extract_photo_jpeg(
        canvas,
        {"bbox": [[5, 5, 25, 35, 0.8, 0, "Face"]], "warped_img": []},
    )
    assert jpeg is not None


def test_read_licence_prefers_rotated_digits() -> None:
    patch = np.zeros((20, 40, 3), dtype=np.uint8)

    def ocr(image: np.ndarray) -> str:
        if image.shape[0] > image.shape[1]:
            return "1234 567890"
        return "ABC"

    text = read_licence_number(
        {"bbox": [[0, 0, 40, 20, 0.9, 5, "Licence_number"]], "warped_img": [patch]},
        ocr,
    )
    assert text == "1234 567890"


def test_encode_jpeg_rejects_empty() -> None:
    assert encode_jpeg(None) is None
    assert encode_jpeg(np.zeros((0, 0, 3), dtype=np.uint8)) is None


def test_extract_signature_from_patch() -> None:
    canvas = np.zeros((80, 120, 3), dtype=np.uint8)
    patch = np.full((20, 70, 3), 30, dtype=np.uint8)
    jpeg = extract_signature_jpeg(
        canvas,
        {
            "bbox": [[10, 50, 80, 70, 0.87, 9, "Signature"]],
            "warped_img": [patch],
        },
    )
    assert jpeg is not None
    assert jpeg[:2] == b"\xff\xd8"
