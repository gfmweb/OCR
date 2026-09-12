from __future__ import annotations

import re

from app.passport.parsers.result import ParseAttempt

_NAME_TOKEN = re.compile(r"^[А-ЯЁ-]+$")


class NameParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = raw.strip()
        if not stripped:
            return ParseAttempt(raw=raw, value=None, valid=False)
        mapped, uncertain = _map_name_confusions(stripped)
        compact = " ".join(mapped.split())
        if not compact or any(ch.isdigit() for ch in compact):
            alternative = _cyrillic_guess(stripped)
            return ParseAttempt(
                raw=stripped,
                value=None,
                valid=False,
                alternatives=_alts(alternative),
                confident=False,
            )
        if not all(_NAME_TOKEN.match(token.replace("Ё", "Е")) for token in compact.split()):
            return ParseAttempt(raw=stripped, value=None, valid=False, confident=False)
        if uncertain:
            return ParseAttempt(
                raw=stripped,
                value=None,
                valid=False,
                alternatives=_alts(compact),
                confident=False,
            )
        return ParseAttempt(raw=stripped, value=compact, valid=True)


def parse_last_name(raw: str) -> ParseAttempt:
    return NameParser().parse(raw)


def parse_first_name(raw: str) -> ParseAttempt:
    return NameParser().parse(raw)


def parse_middle_name(raw: str) -> ParseAttempt:
    return NameParser().parse(raw)


def _map_name_confusions(text: str) -> tuple[str, bool]:
    chars: list[str] = []
    uncertain = False
    letter_count = 0
    zero_count = 0
    for char in text.upper().replace("Ё", "Е"):
        if char in {"0", "O"}:
            chars.append("О")
            zero_count += 1
            continue
        if "А" <= char <= "Я" or char in {"-", " "}:
            chars.append(char)
            if "А" <= char <= "Я":
                letter_count += 1
            continue
        if char.isdigit():
            uncertain = True
            chars.append(char)
    if zero_count > 1 or (zero_count and letter_count < 3):
        uncertain = True
    return "".join(chars), uncertain


def _cyrillic_guess(text: str) -> str | None:
    mapped, _uncertain = _map_name_confusions(text)
    compact = " ".join(mapped.split())
    if compact and all(_NAME_TOKEN.match(token) for token in compact.split()):
        return compact
    return None


def _alts(value: str | None) -> list[dict]:
    if not value:
        return []
    return [{"value": value, "confidence": 0.42}]
