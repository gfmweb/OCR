from __future__ import annotations

import re

from app.passport.parsers.result import ParseAttempt

_MALE = frozenset({"М", "M", "МУЖ", "МУЖСКОЙ"})
_FEMALE = frozenset({"Ж", "F", "ЖЕН", "ЖЕНСКИЙ"})


class GenderParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = raw.strip()
        tokens = re.findall(r"[A-ZА-ЯЁ]+", stripped.upper().replace("Ё", "Е"))
        gender = "unknown"
        for token in tokens:
            if token in _MALE:
                gender = "male"
                break
            if token in _FEMALE:
                gender = "female"
                break
        if gender == "unknown":
            return ParseAttempt(raw=stripped, value=None, valid=False)
        return ParseAttempt(raw=stripped, value=gender, valid=True)


def parse_gender(raw: str) -> ParseAttempt:
    return GenderParser().parse(raw)
