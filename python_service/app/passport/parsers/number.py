from __future__ import annotations

import re

from app.passport.blocks import OCRBlock
from app.passport.parsers.result import ParseAttempt, numeric_text

SERIES_RE = re.compile(r"(?<!\d)(\d{2})\s+(\d{2})(?!\d)")
NUMBER_RE = re.compile(r"(?<!\d)(\d{6})(?!\d)")
COMPACT_SERIES_RE = re.compile(r"(?<!\d)(\d{2})\s*(\d{2})(?!\d)")


class PassportNumberParser:
    def parse_series(self, raw: str) -> ParseAttempt:
        digits = "".join(ch for ch in numeric_text(raw) if ch.isdigit())
        if len(digits) == 4:
            return ParseAttempt(raw=raw.strip(), value=digits, valid=True)
        match = SERIES_RE.search(raw) or SERIES_RE.search(numeric_text(raw))
        if match:
            value = match.group(1) + match.group(2)
            return ParseAttempt(raw=raw.strip(), value=value, valid=True)
        return ParseAttempt(raw=raw.strip(), value=None, valid=False)

    def parse_number(self, raw: str) -> ParseAttempt:
        digits = "".join(ch for ch in numeric_text(raw) if ch.isdigit())
        if len(digits) == 6:
            return ParseAttempt(raw=raw.strip(), value=digits, valid=True)
        mapped = "".join(ch for ch in numeric_text(raw) if ch.isdigit())
        match = NUMBER_RE.search(mapped)
        if match:
            return ParseAttempt(raw=raw.strip(), value=match.group(1), valid=True)
        return ParseAttempt(raw=raw.strip(), value=None, valid=False)

    def from_blocks(
        self, blocks: list[OCRBlock]
    ) -> tuple[ParseAttempt | None, ParseAttempt | None]:
        band = [
            block
            for block in blocks
            if block.bbox.cy <= 0.18 or block.bbox.cy >= 0.82
        ]
        series: ParseAttempt | None = None
        number: ParseAttempt | None = None
        for block in band:
            mapped = numeric_text(block.text)
            digits = re.sub(r"\D", "", mapped)
            if number is None:
                parsed_number = self.parse_number(block.text)
                if parsed_number.valid:
                    number = parsed_number
            spaced = SERIES_RE.search(block.text) or SERIES_RE.search(mapped)
            if series is None and spaced:
                series = ParseAttempt(
                    raw=block.text.strip(),
                    value=spaced.group(1) + spaced.group(2),
                    valid=True,
                )
            if series is None and number is not None:
                compact = COMPACT_SERIES_RE.search(mapped)
                if compact and compact.group(1) + compact.group(2) != number.value:
                    series = ParseAttempt(
                        raw=block.text.strip(),
                        value=compact.group(1) + compact.group(2),
                        valid=True,
                    )
            if series is None and number is None and len(digits) == 10:
                series = ParseAttempt(raw=block.text.strip(), value=digits[:4], valid=True)
                number = ParseAttempt(raw=block.text.strip(), value=digits[4:], valid=True)
        return series, number


def parse_series(raw: str) -> ParseAttempt:
    return PassportNumberParser().parse_series(raw)


def parse_number(raw: str) -> ParseAttempt:
    return PassportNumberParser().parse_number(raw)
