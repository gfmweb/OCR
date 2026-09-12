from __future__ import annotations

from app.passport.parsers.result import ParseAttempt, numeric_text


class DepartmentCodeParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = raw.strip()
        mapped = numeric_text(stripped)
        digits = "".join(ch for ch in mapped if ch.isdigit())
        if len(digits) == 6:
            return ParseAttempt(raw=stripped, value=f"{digits[0:3]}-{digits[3:6]}", valid=True)
        return ParseAttempt(raw=stripped, value=None, valid=False)


def parse_department_code(raw: str) -> ParseAttempt:
    return DepartmentCodeParser().parse(raw)
