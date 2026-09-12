from __future__ import annotations

from typing import Protocol, runtime_checkable

import numpy as np

from app.domain.ocr import OCRLine


@runtime_checkable
class OCRProvider(Protocol):
    @property
    def name(self) -> str: ...

    @property
    def model_version(self) -> str: ...

    def warmup(self) -> None: ...

    def recognize(self, image: np.ndarray) -> list[OCRLine]: ...
