from app.passport.parsers.birth_place import parse_birth_place
from app.passport.parsers.issued_by import parse_issued_by


def test_parse_birth_place() -> None:
    parsed = parse_birth_place("Г. УФА РЕСПУБЛИКА БАШКОРТОСТАН")
    assert parsed.value is not None
    assert "УФА" in parsed.value
    merged = parse_birth_place("Г. УФА, РЕСПУБЛИКА БАШКОРТОСТАН")
    assert merged.value == "Г. УФА, РЕСПУБЛИКА БАШКОРТОСТАН"


def test_parse_issued_by() -> None:
    raw = "ОТДЕЛОМ УФМС РОССИИ ПО РЕСПУБЛИКЕ БАШКОРТОСТАН В ГОРОДЕ УФЕ"
    parsed = parse_issued_by(raw)
    assert parsed.value == raw
