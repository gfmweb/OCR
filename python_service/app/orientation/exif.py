from __future__ import annotations

import io

from PIL import Image, UnidentifiedImageError

_EXIF_ORIENTATION = 274
_TO_CW_DEGREES = {
    1: 0,
    3: 180,
    6: 90,
    8: 270,
}


def exif_rotation_degrees(payload: bytes) -> int | None:
    """How many degrees CW the stored pixels should be rotated to match EXIF."""
    try:
        with Image.open(io.BytesIO(payload)) as image:
            orientation = image.getexif().get(_EXIF_ORIENTATION)
    except (UnidentifiedImageError, OSError, ValueError):
        return None
    return _TO_CW_DEGREES.get(int(orientation)) if orientation is not None else None
