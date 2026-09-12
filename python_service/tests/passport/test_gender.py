from app.passport.parsers.gender import parse_gender


def test_parse_gender() -> None:
    assert parse_gender("М").value == "male"
    assert parse_gender("МУЖ").value == "male"
    assert parse_gender("МУЖСКОЙ").value == "male"
    assert parse_gender("Ж").value == "female"
    assert parse_gender("ЖЕН").value == "female"
    assert parse_gender("ЖЕНСКИЙ").value == "female"
    assert parse_gender("ИВАН").value is None
