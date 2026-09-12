"""Warm up PaddleOCR so models are cached under python_service/models."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.infrastructure.config import get_settings
from app.ocr.model_manager import ModelManager
from app.ocr.paddle_provider import PaddleOCRProvider


def main() -> None:
    settings = get_settings()
    settings.models_dir.mkdir(parents=True, exist_ok=True)
    manager = ModelManager(settings=settings, provider=PaddleOCRProvider(settings))
    manager.warmup()
    print(f"models_ready dir={settings.models_dir} version={manager.provider.model_version}")


if __name__ == "__main__":
    main()
