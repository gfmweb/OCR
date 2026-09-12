from __future__ import annotations

from dataclasses import dataclass

from app.passport.blocks import OCRBlock

KNOWN_LABELS: dict[str, tuple[str, ...]] = {
    "issuedBy": ("ПАСПОРТ ВЫДАН", "PASSPORT ISSUED", "ISSUED BY"),
    "issueDate": ("ДАТА ВЫДАЧИ", "DATE OF ISSUE"),
    "departmentCode": ("КОД ПОДРАЗДЕЛЕНИЯ", "DIVISION CODE", "КОД ПОДРАЗД"),
    "lastName": ("ФАМИЛИЯ", "SURNAME"),
    "firstName": ("ИМЯ", "NAME", "GIVEN NAME"),
    "middleName": ("ОТЧЕСТВО", "PATRONYMIC"),
    "gender": ("ПОЛ", "SEX"),
    "birthDate": ("ДАТА РОЖДЕНИЯ", "DATE OF BIRTH"),
    "birthPlace": ("МЕСТО РОЖДЕНИЯ", "PLACE OF BIRTH"),
}

LATIN_TO_CYRILLIC = str.maketrans(
    {
        "A": "А",
        "B": "В",
        "E": "Е",
        "K": "К",
        "M": "М",
        "H": "Н",
        "O": "О",
        "P": "Р",
        "C": "С",
        "T": "Т",
        "X": "Х",
        "Y": "У",
    }
)

DEFAULT_THRESHOLD = 0.78


@dataclass(frozen=True)
class LabelHit:
    field: str
    block: OCRBlock
    score: float


def normalize_label(text: str) -> str:
    compact = text.upper().replace("Ё", "Е").translate(LATIN_TO_CYRILLIC)
    cleaned: list[str] = []
    for char in compact:
        if char.isalnum() or char in {" ", "-"}:
            cleaned.append(char)
    return " ".join("".join(cleaned).split())


def levenshtein(left: str, right: str) -> int:
    if left == right:
        return 0
    if not left:
        return len(right)
    if not right:
        return len(left)
    previous = list(range(len(right) + 1))
    for i, left_char in enumerate(left, start=1):
        current = [i]
        for j, right_char in enumerate(right, start=1):
            insert_cost = current[j - 1] + 1
            delete_cost = previous[j] + 1
            replace_cost = previous[j - 1] + (left_char != right_char)
            current.append(min(insert_cost, delete_cost, replace_cost))
        previous = current
    return previous[-1]


def similarity(left: str, right: str) -> float:
    if not left or not right:
        return 0.0
    return 1.0 - levenshtein(left, right) / max(len(left), len(right))


def _variants(text: str) -> list[str]:
    normalized = normalize_label(text)
    if not normalized:
        return []
    variants = [normalized]
    parts = normalized.split(" ")
    for count in range(1, min(len(parts), 4) + 1):
        variants.append(" ".join(parts[:count]))
    if "/" in text:
        variants.extend(normalize_label(part) for part in text.split("/"))
    return list(dict.fromkeys(item for item in variants if item))


def alias_score(text: str, aliases: tuple[str, ...]) -> float:
    variants = _variants(text)
    best = 0.0
    for alias in aliases:
        alias_norm = normalize_label(alias)
        for variant in variants:
            score = similarity(variant, alias_norm)
            short = len(alias_norm) <= 4
            if short and variant != alias_norm and not variant.startswith(alias_norm):
                continue
            best = max(best, score)
    return best


def best_known_label(text: str, threshold: float = DEFAULT_THRESHOLD) -> tuple[str, float] | None:
    ranked: list[tuple[float, int, str]] = []
    for field, aliases in KNOWN_LABELS.items():
        score = alias_score(text, aliases)
        if score >= threshold:
            longest = max(len(normalize_label(alias)) for alias in aliases)
            ranked.append((score, longest, field))
    if not ranked:
        return None
    ranked.sort()
    score, _length, field = ranked[-1]
    return field, score


class PassportLabelDetector:
    def __init__(self, threshold: float = DEFAULT_THRESHOLD) -> None:
        self._threshold = threshold

    def detect(self, blocks: list[OCRBlock]) -> dict[str, LabelHit]:
        candidates: list[tuple[float, str, OCRBlock]] = []
        for block in blocks:
            if not block.text.strip():
                continue
            matched = best_known_label(block.text, self._threshold)
            if matched is None:
                continue
            field, score = matched
            candidates.append((score, field, block))
        candidates.sort(key=lambda item: (-item[0], item[1]))
        used_fields: set[str] = set()
        used_blocks: set[str] = set()
        hits: dict[str, LabelHit] = {}
        for score, field, block in candidates:
            if field in used_fields or block.id in used_blocks:
                continue
            used_fields.add(field)
            used_blocks.add(block.id)
            hits[field] = LabelHit(field=field, block=block, score=score)
        return hits

    def looks_like_label(self, text: str) -> bool:
        return best_known_label(text, self._threshold) is not None

    def is_label(self, text: str, field: str) -> bool:
        aliases = KNOWN_LABELS.get(field)
        if aliases is None:
            return False
        return alias_score(text, aliases) >= self._threshold

    def remainder_after_label(self, text: str, field: str) -> str:
        aliases = KNOWN_LABELS.get(field)
        if aliases is None:
            return ""
        parts = text.strip().split()
        if len(parts) < 2:
            return ""
        for take in range(1, len(parts)):
            prefix = " ".join(parts[:take])
            leftover = " ".join(parts[take:])
            if alias_score(prefix, aliases) < self._threshold:
                continue
            if self.looks_like_label(leftover):
                continue
            return leftover
        return ""
