import numpy as np
from app.preprocessing.image_io import map_bbox_to_original, resize_max_side, to_grayscale_bgr


def test_resize_keeps_small_image() -> None:
    image = np.zeros((100, 80, 3), dtype=np.uint8)
    resized, scale = resize_max_side(image, max_side=2560)
    assert scale == 1.0
    assert resized.shape == image.shape


def test_resize_limits_long_side() -> None:
    image = np.zeros((4000, 2000, 3), dtype=np.uint8)
    resized, scale = resize_max_side(image, max_side=1000)
    assert max(resized.shape[:2]) == 1000
    assert scale == 0.25


def test_bbox_maps_back_to_original() -> None:
    bbox = [[10.0, 20.0], [30.0, 20.0], [30.0, 40.0], [10.0, 40.0]]
    mapped = map_bbox_to_original(bbox, scale=0.5)
    assert mapped[0] == [20.0, 40.0]
    assert mapped[2] == [60.0, 80.0]


def test_grayscale_keeps_three_channels() -> None:
    image = np.zeros((16, 16, 3), dtype=np.uint8)
    image[:, :] = (0, 128, 255)
    gray = to_grayscale_bgr(image)
    assert gray.shape == (16, 16, 3)
    assert gray[0, 0, 0] == gray[0, 0, 1] == gray[0, 0, 2]
