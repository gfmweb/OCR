from app.passport.geometry import NormRect, is_below, is_right_of, overlaps_x


def test_is_below_uses_normalized_gap() -> None:
    label = NormRect(0.1, 0.2, 0.15, 0.04)
    value = NormRect(0.1, 0.25, 0.18, 0.04)
    far = NormRect(0.1, 0.8, 0.18, 0.04)
    assert is_below(value, label)
    assert not is_below(far, label)


def test_is_right_of_and_overlap() -> None:
    label = NormRect(0.1, 0.2, 0.12, 0.04)
    value = NormRect(0.24, 0.2, 0.14, 0.04)
    assert is_right_of(value, label)
    assert overlaps_x(label, NormRect(0.18, 0.3, 0.1, 0.04))
