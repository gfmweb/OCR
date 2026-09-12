from app.passport.parsers.date import parse_birth_date, parse_issue_date


def test_parse_birth_date() -> None:
    assert parse_birth_date("19.07.1981").value == "19.07.1981"
    assert parse_birth_date("1981-07-19").value == "19.07.1981"
    assert parse_birth_date("19 07 1981").value == "19.07.1981"
    assert parse_birth_date("19-07-1981").value == "19.07.1981"
    assert parse_birth_date("19/07/1981").value == "19.07.1981"
    assert parse_birth_date("19.0З.1981").value == "19.03.1981"
    assert parse_birth_date("19.0З.1981").raw == "19.0З.1981"
    assert parse_birth_date("32.01.1980").value is None


def test_parse_issue_date() -> None:
    assert parse_issue_date("15.05.2012").value == "15.05.2012"
