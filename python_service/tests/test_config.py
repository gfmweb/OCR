from app.infrastructure.config import Settings
from pydantic import ValidationError


def test_settings_force_localhost() -> None:
    settings = Settings(api_host="localhost")
    assert settings.api_host == "127.0.0.1"


def test_settings_reject_public_bind() -> None:
    try:
        Settings(api_host="0.0.0.0")
    except ValidationError as error:
        assert "127.0.0.1" in str(error)
    else:
        raise AssertionError("0.0.0.0 must be rejected")
