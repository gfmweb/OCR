from __future__ import annotations

from datetime import datetime

from app.passport.models import FieldWarning, PassportField
from app.passport.parsers.birth_place import BirthPlaceParser
from app.passport.parsers.date import DateParser
from app.passport.parsers.department import DepartmentCodeParser
from app.passport.parsers.gender import GenderParser
from app.passport.parsers.issued_by import IssuedByParser
from app.passport.parsers.name import NameParser
from app.passport.parsers.number import PassportNumberParser
from app.passport.parsers.result import ParseAttempt


class PassportFieldNormalizer:
    def __init__(self) -> None:
        self._name = NameParser()
        self._date = DateParser()
        self._gender = GenderParser()
        self._department = DepartmentCodeParser()
        self._place = BirthPlaceParser()
        self._issued = IssuedByParser()
        self._numbers = PassportNumberParser()

    def parse_field(self, field: str, lines: list[str]) -> ParseAttempt:
        raw = " ".join(part.strip() for part in lines if part.strip())
        if field in {"lastName", "firstName", "middleName"}:
            return self._name.parse(raw)
        if field in {"birthDate", "issueDate"}:
            return self._date.parse(raw)
        if field == "gender":
            return self._gender.parse(raw)
        if field == "departmentCode":
            return self._department.parse(raw)
        if field == "birthPlace":
            return self._place.merge_lines(lines)
        if field == "issuedBy":
            return self._issued.merge_lines(lines)
        if field == "series":
            return self._numbers.parse_series(raw)
        if field == "number":
            return self._numbers.parse_number(raw)
        return ParseAttempt(raw=raw, value=raw or None, valid=bool(raw))


def cross_field_warnings(fields: dict[str, PassportField]) -> list[FieldWarning]:
    birth = fields["birthDate"].value
    issue = fields["issueDate"].value
    if not birth or not issue:
        return []
    try:
        birth_dt = _parse_date(birth)
        issue_dt = _parse_date(issue)
    except ValueError:
        return []
    if issue_dt is None or birth_dt is None:
        return []
    if issue_dt < birth_dt:
        return [FieldWarning(code="ISSUE_BEFORE_BIRTH", field="issueDate")]
    return []


def _parse_date(value: str) -> datetime | None:
    for fmt in ("%d.%m.%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    return None
