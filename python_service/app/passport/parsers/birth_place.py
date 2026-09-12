from __future__ import annotations

from app.passport.parsers.result import ParseAttempt


class BirthPlaceParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = " ".join(raw.replace("\n", " ").split())
        if len(stripped) < 2:
            return ParseAttempt(raw=raw, value=None, valid=False)
        parts = [_clean_line(part) for part in re_split_keep(stripped)]
        parts = [part for part in parts if part]
        if not parts:
            return ParseAttempt(raw=raw.strip(), value=None, valid=False)
        value = ", ".join(parts)
        return ParseAttempt(raw=raw.strip(), value=value, valid=True)

    def merge_lines(self, lines: list[str]) -> ParseAttempt:
        cleaned = [_clean_line(line) for line in lines]
        cleaned = [line for line in cleaned if line]
        raw = " ".join(line.strip() for line in lines if line.strip())
        if not cleaned:
            return ParseAttempt(raw=raw, value=None, valid=False)
        return ParseAttempt(raw=raw, value=", ".join(cleaned), valid=True)


def parse_birth_place(raw: str) -> ParseAttempt:
    return BirthPlaceParser().parse(raw)


def _clean_line(text: str) -> str:
    allowed: list[str] = []
    for char in text.upper().replace("Ё", "Е"):
        if "А" <= char <= "Я" or char.isdigit() or char in {"-", " ", ".", ",", "/"}:
            allowed.append(char)
    return " ".join("".join(allowed).split())


def re_split_keep(text: str) -> list[str]:
    if "," in text:
        return [part.strip() for part in text.split(",") if part.strip()]
    return [text]
