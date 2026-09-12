from app.domain.ocr import OCRLine
from app.orientation.geometry import rotate_points_cw, unrotate_points_cw
from app.orientation.scoring import (
    choose_rotation,
    rotation_candidates,
    score_ocr_orientation,
    score_orientation,
    should_stop_probing,
)


def _line(text: str, bbox: list[list[float]], confidence: float = 0.95) -> OCRLine:
    return OCRLine(text=text, confidence=confidence, bbox=bbox)


def test_score_prefers_horizontal_cyrillic() -> None:
    horizontal = _line("ИВАНОВ", [[10, 10], [120, 10], [120, 28], [10, 28]])
    vertical = _line("ИВАНОВ", [[10, 10], [28, 10], [28, 120], [10, 120]])
    assert score_ocr_orientation([horizontal]) > score_ocr_orientation([vertical])


def test_choose_rotation_picks_highest_score() -> None:
    assert choose_rotation({0: 0.3, 90: 1.8, 180: 0.2, 270: 0.4}) == 90


def test_choose_rotation_keeps_zero_on_empty_scores() -> None:
    assert choose_rotation({0: 0.0, 90: 0.0, 180: 0.0, 270: 0.0}) == 0


def test_exif_only_breaks_near_tie() -> None:
    assert choose_rotation({0: 1.0, 90: 1.02, 180: 0.2, 270: 0.1}, exif_degrees=0) == 0
    assert choose_rotation({0: 0.2, 90: 2.0, 180: 0.1, 270: 0.1}, exif_degrees=0) == 90


def test_close_flip_prefers_script_not_box_width() -> None:
    chosen = choose_rotation(
        {0: 10.0, 90: 1.0, 180: 10.4, 270: 0.8},
        script_scores={0: 8.0, 90: 0.4, 180: 2.0, 270: 0.3},
    )
    assert chosen == 0


def test_portrait_candidates_try_sideways_first() -> None:
    assert rotation_candidates(height=200, width=100) == (90, 270, 0, 180)
    assert rotation_candidates(height=100, width=200) == (0, 180, 90, 270)


def test_should_stop_when_leader_is_clear() -> None:
    assert should_stop_probing({90: 12.0, 270: 4.0})
    assert not should_stop_probing({90: 12.0, 270: 11.0})
    assert not should_stop_probing({90: 0.0, 270: 0.0})


def test_script_score_ignores_tall_boxes() -> None:
    wide = _line("ИВАНОВ", [[10, 10], [120, 10], [120, 28], [10, 28]])
    tall = _line("ИВАНОВ", [[10, 10], [28, 10], [28, 120], [10, 120]])
    wide_score = score_orientation([wide])
    tall_score = score_orientation([tall])
    assert wide_score.script == tall_score.script
    assert wide_score.total > tall_score.total


def test_unrotate_inverts_clockwise_rotation() -> None:
    width, height = 10.0, 4.0
    original = [[0.0, 0.0], [9.0, 0.0], [9.0, 3.0], [0.0, 3.0]]
    for degrees in (0, 90, 180, 270):
        rotated = rotate_points_cw(original, width, height, degrees)
        restored = unrotate_points_cw(rotated, width, height, degrees)
        for left, right in zip(original, restored, strict=True):
            assert left[0] == round(right[0], 6)
            assert left[1] == round(right[1], 6)
