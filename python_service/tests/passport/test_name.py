from app.passport.parsers.name import parse_first_name, parse_last_name, parse_middle_name


def test_parse_last_name() -> None:
    assert parse_last_name("ИВАНОВ").value == "ИВАНОВ"
    assert parse_last_name("ИВАНОВ.").value == "ИВАНОВ"
    noisy = parse_last_name("ИВАН0В")
    assert noisy.value == "ИВАНОВ" or (noisy.value is None and noisy.alternatives)
    dotted = parse_last_name("ИВАН0В.")
    assert dotted.value == "ИВАНОВ" or (dotted.value is None and dotted.alternatives)


def test_parse_first_name() -> None:
    assert parse_first_name("ИВАН").value == "ИВАН"
    assert parse_first_name("12345").value is None


def test_parse_middle_name() -> None:
    assert parse_middle_name("ИВАНОВИЧ").value == "ИВАНОВИЧ"
    assert parse_middle_name("").value is None
