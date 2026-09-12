from __future__ import annotations

import calendar
import re

from app.passport.parsers.result import ParseAttempt, numeric_text


class DateParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = raw.strip()
        iso_match = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", stripped)
        if iso_match:
            converted = _from_parts(iso_match.group(3), iso_match.group(2), iso_match.group(1))
            if converted is None:
                return ParseAttempt(raw=stripped, value=None, valid=False)
            return ParseAttempt(raw=stripped, value=converted, valid=True)
        mapped = numeric_text(stripped)
        digits = re.findall(r"\d", mapped)
        glued = "".join(digits)
        iso: str | None = None
        if len(glued) == 8:
            iso = _from_parts(glued[0:2], glued[2:4], glued[4:8])
        else:
            match = re.search(r"(\d{1,2})\D+(\d{1,2})\D+(\d{4})", mapped)
            if match:
                iso = _from_parts(match.group(1), match.group(2), match.group(3))
        if iso is None:
            return ParseAttempt(raw=stripped, value=None, valid=False)
        return ParseAttempt(raw=stripped, value=iso, valid=True)


def parse_birth_date(raw: str) -> ParseAttempt:
    return DateParser().parse(raw)


def parse_issue_date(raw: str) -> ParseAttempt:
    return DateParser().parse(raw)


def _from_parts(day_raw: str, month_raw: str, year_raw: str) -> str | None:
    try:
        day = int(day_raw)
        month = int(month_raw)
        year = int(year_raw)
    except ValueError:
        return None
    if year < 1900 or year > 2100 or month < 1 or month > 12:
        return None
    if day < 1 or day > calendar.monthrange(year, month)[1]:
        return None
    return f"{day:02d}.{month:02d}.{year:04d}"
