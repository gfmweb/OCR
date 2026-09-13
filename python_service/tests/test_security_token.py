from pathlib import Path

from app.infrastructure import security


def test_persist_token_ignores_unwritable_path(tmp_path: Path, monkeypatch) -> None:
    target = tmp_path / "readonly" / ".session_token"
    monkeypatch.setattr(security, "TOKEN_FILE", target)
    security.persist_token("token-value")
