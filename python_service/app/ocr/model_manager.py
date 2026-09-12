from __future__ import annotations

from dataclasses import dataclass, field

from app.infrastructure.config import Settings
from app.ocr.provider import OCRProvider


@dataclass
class ModelManager:
    settings: Settings
    provider: OCRProvider
    ready: bool = field(default=False, init=False)

    def warmup(self) -> None:
        if self.ready:
            return
        self.settings.models_dir.mkdir(parents=True, exist_ok=True)
        self.provider.warmup()
        self.ready = True
