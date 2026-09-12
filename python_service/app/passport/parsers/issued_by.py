from __future__ import annotations

from app.passport.parsers.result import ParseAttempt


class IssuedByParser:
    def parse(self, raw: str) -> ParseAttempt:
        stripped = " ".join(raw.replace("\n", " ").split())
        cleaned = _clean(stripped)
        if len(cleaned) < 3:
            return ParseAttempt(raw=raw.strip(), value=None, valid=False)
        return ParseAttempt(raw=raw.strip(), value=cleaned, valid=True)

    def merge_lines(self, lines: list[str]) -> ParseAttempt:
        raw = " ".join(line.strip() for line in lines if line.strip())
        return self.parse(raw)


def parse_issued_by(raw: str) -> ParseAttempt:
    return IssuedByParser().parse(raw)


def _clean(text: str) -> str:
    allowed: list[str] = []
    for char in text.upper().replace("Ё", "Е"):
        if "А" <= char <= "Я" or char.isdigit() or char in {"-", " ", ".", ",", "/"}:
            allowed.append(char)
    return " ".join("".join(allowed).split())
