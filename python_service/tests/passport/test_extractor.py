from app.passport.extractor import PassportFieldExtractor
from app.passport.labels import PassportLabelDetector
from tests.passport.conftest import first_spread_blocks


def test_issue_date_label_does_not_block_first_name() -> None:
    detector = PassportLabelDetector()
    extractor = PassportFieldExtractor(detector)
    blocks = first_spread_blocks()
    hits = detector.detect(blocks)
    candidates = extractor.extract(
        "firstName",
        hits["firstName"],
        blocks,
        hits,
        x_min=0.4,
        x_max=1.0,
    )
    texts = [block.text for candidate in candidates for block in candidate.blocks]
    assert "ИВАН" in texts
