from app.passport.labels import PassportLabelDetector
from tests.passport.conftest import block


def test_label_detector_maps_ocr_noise() -> None:
    detector = PassportLabelDetector()
    hits = detector.detect(
        [
            block("a", "ФАМИЛИR", 0.5, 0.2),
            block("b", "ФАМИЛИЯ:", 0.1, 0.2),
        ]
    )
    assert "lastName" in hits
    assert hits["lastName"].block.text.startswith("ФАМИЛИ")


def test_label_detector_does_not_use_values() -> None:
    detector = PassportLabelDetector()
    hits = detector.detect([block("v", "ИВАНОВ", 0.5, 0.2), block("l", "Фамилия", 0.1, 0.2)])
    assert hits["lastName"].block.text == "Фамилия"


def test_word_passport_is_not_a_label() -> None:
    detector = PassportLabelDetector()
    assert detector.detect([block("p", "ПАСПОРТ", 0.2, 0.2)]) == {}
