from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol, runtime_checkable

import numpy as np


@dataclass(frozen=True)
class DocumentFieldsSnapshot:
    doctype: str
    ocr: dict[str, str]
    quality: dict[str, object] = field(default_factory=dict)
    photo_jpeg: bytes | None = None
    signature_jpeg: bytes | None = None
    handwritten_address: bool = False


@runtime_checkable
class DocumentFieldsProvider(Protocol):
    name: str
    model_version: str
    ready: bool

    def warmup(self) -> None: ...

    def process(self, rgb_image: np.ndarray) -> DocumentFieldsSnapshot: ...
