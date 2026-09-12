from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

SERVICE_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=SERVICE_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        env_prefix="OCR_",
    )

    api_host: str = "127.0.0.1"
    api_port: int = 8765
    session_token: str = ""
    models_dir: Path = SERVICE_ROOT / "models"
    max_image_side: int = 2560
    orientation_max_side: int = 640
    max_upload_bytes: int = 25 * 1024 * 1024
    request_timeout_sec: float = 180.0
    use_gpu: bool = False
    device: str = "cpu"
    det_model_name: str = "PP-OCRv5_mobile_det"
    rec_model_name: str = "cyrillic_PP-OCRv5_mobile_rec"
    rdocs_models_dir: Path = SERVICE_ROOT / "models" / "rdocs"
    rdocs_ocr: str = "accurate"
    rdocs_device: str = "cpu"
    label_match_threshold: float = 0.78
    min_page3_labels: int = 3
    min_page2_labels: int = 2
    min_combo_page3: int = 2
    min_combo_page2: int = 2

    @field_validator("api_host")
    @classmethod
    def localhost_only(cls, value: str) -> str:
        host = value.strip().lower()
        if host not in {"127.0.0.1", "localhost"}:
            raise ValueError("OCR API must bind to 127.0.0.1")
        return "127.0.0.1"

    @field_validator("models_dir", "rdocs_models_dir", mode="before")
    @classmethod
    def resolve_models_dir(cls, value: Path | str) -> Path:
        path = Path(value)
        if not path.is_absolute():
            path = SERVICE_ROOT / path
        return path

    @property
    def inference_device(self) -> str:
        if self.use_gpu:
            return self.device
        return "cpu"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
