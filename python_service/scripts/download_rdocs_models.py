"""Download RussianDocsOCR ONNX weights into python_service/models/rdocs."""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.infrastructure.config import get_settings


def main() -> int:
    settings = get_settings()
    settings.rdocs_models_dir.mkdir(parents=True, exist_ok=True)
    os.environ["RDOCS_MODELS_ROOT"] = str(settings.rdocs_models_dir)
    from document_processing.fetch_models import main as fetch_models

    return int(fetch_models() or 0)


if __name__ == "__main__":
    raise SystemExit(main())
