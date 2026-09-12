from app.passport.detector import PassportFirstSpreadDetector
from app.passport.labels import PassportLabelDetector
from app.passport.parser import build_parser
from tests.passport.conftest import block, first_spread_blocks


def test_detector_requires_more_than_passport_word() -> None:
    detector = PassportFirstSpreadDetector()
    labels = PassportLabelDetector()
    blocks = [block("p", "ПАСПОРТ", 0.2, 0.2, w=0.3)]
    decision = detector.detect(labels.detect(blocks), blocks)
    assert decision.is_passport is False


def test_parser_reads_first_spread() -> None:
    parsed = build_parser().parse(first_spread_blocks())
    assert parsed.detection.is_passport
    assert parsed.last_name.value == "ИВАНОВ"
    assert parsed.first_name.value == "ИВАН"
    assert parsed.middle_name.value == "ИВАНОВИЧ"
    assert parsed.gender.value == "male"
    assert parsed.birth_date.value == "19.07.1981"
    assert parsed.birth_date.raw_value == "19.07.1981"
    assert parsed.birth_place.value is not None
    assert "УФА" in parsed.birth_place.value
    assert parsed.issued_by.value is not None
    assert "УФМС" in parsed.issued_by.value
    assert parsed.issue_date.value == "15.05.2012"
    assert parsed.department_code.value == "770-001"
    assert parsed.series.value == "4508"
    assert parsed.number.value == "123456"


def test_missing_middle_name_stays_null() -> None:
    parsed = build_parser().parse(first_spread_blocks(include_middle_name=False))
    assert parsed.last_name.value == "ИВАНОВ"
    assert parsed.middle_name.value is None


def test_english_caption_is_not_the_name() -> None:
    blocks = first_spread_blocks()
    blocks = [
        block("ln", "Фамилия", 0.55, 0.16, w=0.14),
        block("en", "Surname", 0.72, 0.16, w=0.12),
        block("lnv", "ПЕТРОВ", 0.55, 0.21, w=0.16),
        *[item for item in blocks if item.id not in {"ln", "lnv"}],
    ]
    parsed = build_parser().parse(blocks)
    assert parsed.last_name.value == "ПЕТРОВ"


def test_issue_before_birth_keeps_values_and_warns() -> None:
    blocks = first_spread_blocks()
    blocks = [
        block("idv", "01.01.1970", 0.28, 0.33, w=0.14) if item.id == "idv" else item
        for item in blocks
    ]
    parsed = build_parser().parse(blocks)
    assert parsed.issue_date.value == "01.01.1970"
    assert parsed.birth_date.value == "19.07.1981"
    assert any(item.code == "ISSUE_BEFORE_BIRTH" for item in parsed.warnings)
