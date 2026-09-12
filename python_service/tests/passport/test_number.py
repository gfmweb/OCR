from app.passport.parsers.number import parse_number, parse_series


def test_parse_series() -> None:
    assert parse_series("4509").value == "4509"
    assert parse_series("45 09").value == "4509"
    assert parse_series("45O9").value == "4509"


def test_parse_number() -> None:
    assert parse_number("123456").value == "123456"
    assert parse_number("12345б").value == "123456"
    assert parse_number("12").value is None
