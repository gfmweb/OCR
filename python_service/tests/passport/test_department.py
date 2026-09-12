from app.passport.parsers.department import parse_department_code


def test_parse_department_code() -> None:
    assert parse_department_code("123-456").value == "123-456"
    assert parse_department_code("123456").value == "123-456"
    assert parse_department_code("123 456").value == "123-456"
    assert parse_department_code("123-45O").value == "123-450"
    assert parse_department_code("12").value is None
