from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class ParseAttempt:
    raw: str
    value: str | None
    valid: bool
    alternatives: list[dict] = field(default_factory=list)
    confident: bool = True


NUMERIC_CONFUSIONS = {
    "O": "0",
    "О": "0",
    "o": "0",
    "о": "0",
    "Q": "0",
    "I": "1",
    "l": "1",
    "|": "1",
    "З": "3",
    "з": "3",
    "б": "6",
}


def map_numeric_char(char: str) -> str:
    return NUMERIC_CONFUSIONS.get(char, char)


def numeric_text(text: str) -> str:
    return "".join(map_numeric_char(char) for char in text)
