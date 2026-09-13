from __future__ import annotations

import gc
import os
import threading
from collections.abc import Callable
from pathlib import Path

import numpy as np

from app.infrastructure.config import Settings
from app.rdocs.extract import extract_photo_jpeg, extract_signature_jpeg, read_licence_number
from app.rdocs.provider import DocumentFieldsSnapshot

_StageCallback = Callable[[str], None]


class RussianDocsFieldsProvider:
    name = "russian_docs_ocr"
    model_version = "4.4.1"

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._lock = threading.Lock()
        self._pipeline = None
        self.ready = False

    def warmup(self, on_stage: _StageCallback | None = None) -> None:
        if self.ready and self._pipeline is not None:
            if on_stage is not None:
                on_stage("ready")
            return
        if on_stage is not None:
            on_stage("loading_models")
        models_root = self._settings.rdocs_models_dir
        os.environ["RDOCS_MODELS_ROOT"] = str(models_root)
        _remap_model_paths(models_root)
        from document_processing import Pipeline

        self._pipeline = Pipeline(
            device=self._settings.rdocs_device,
            ocr=self._settings.rdocs_ocr,
        )
        if on_stage is not None:
            on_stage("warmup_inference")
        try:
            self.probe()
        except Exception:
            if self._pipeline is None:
                raise
        self.ready = True
        if on_stage is not None:
            on_stage("ready")

    def probe(self) -> None:
        """Run a synthetic frame through the pipeline so ONNX sessions are hot."""
        if self._pipeline is None:
            raise RuntimeError("RussianDocsOCR pipeline is not loaded")
        probe = np.full((64, 64, 3), 255, dtype=np.uint8)
        with self._lock:
            self._pipeline.process_img(
                probe,
                ocr=True,
                get_doc_borders=True,
                find_text_fields=True,
                check_quality=True,
                low_quality=True,
            )

    def release(self) -> None:
        with self._lock:
            self._pipeline = None
            self.ready = False
        gc.collect()

    def process(self, rgb_image: np.ndarray) -> DocumentFieldsSnapshot:
        if self._pipeline is None:
            self.warmup()
        assert self._pipeline is not None
        with self._lock:
            result = self._pipeline.process_img(
                rgb_image,
                ocr=True,
                get_doc_borders=True,
                find_text_fields=True,
                check_quality=True,
                low_quality=True,
            )
            doctype = str(result.doctype or "")
            raw_ocr = dict(result.ocr or {})
            handwritten = bool(raw_ocr.get("Address_has_handwritten"))
            quality = dict(result.quality or {})
            text_fields = result.text_fields_meta
            canvas = _warped_canvas(result)
            photo_jpeg = None
            signature_jpeg = None
            normalized = doctype.strip().upper()
            if "INTPASSPORTADDR" in normalized:
                try:
                    licence = read_licence_number(
                        text_fields, lambda image: _ocr_cyrillic(self._pipeline, image)
                    )
                except Exception:
                    licence = None
                if licence:
                    raw_ocr["Licence_number"] = licence
            elif normalized in {"INTPASSPORT_1997", "INTPASSPORT_2011"}:
                try:
                    photo_jpeg = extract_photo_jpeg(canvas, text_fields)
                except Exception:
                    photo_jpeg = None
                try:
                    signature_jpeg = extract_signature_jpeg(canvas, text_fields)
                except Exception:
                    signature_jpeg = None
            ocr = {
                str(key): "" if value is None else str(value)
                for key, value in raw_ocr.items()
                if key != "Address_has_handwritten"
            }
        return DocumentFieldsSnapshot(
            doctype=doctype,
            ocr=ocr,
            quality=quality,
            photo_jpeg=photo_jpeg,
            signature_jpeg=signature_jpeg,
            handwritten_address=handwritten,
        )


def _warped_canvas(result) -> np.ndarray | None:
    try:
        canvas = result.img_with_fixed_perspective
    except Exception:
        return None
    if canvas is None or getattr(canvas, "size", 0) == 0:
        return None
    return canvas


def _ocr_cyrillic(pipeline, image) -> str:
    try:
        output = pipeline.ocr_cyr.predict(image)
        payload = output.get(pipeline.ocr_cyr.model_name) or {}
        return str(payload.get("ocr_output") or "")
    except Exception:
        return ""


def _remap_model_paths(models_root: Path) -> None:
    """Point RussianDocsOCR at weights under python_service/models/rdocs."""
    from document_processing import config as rdocs_config

    package_root = Path(rdocs_config.ROOT)
    target_root = models_root / "document_processing"
    rewritten: dict[str, str] = {}
    for key, value in rdocs_config.DEFAULT_CFG.items():
        source = Path(str(value))
        if _is_relative_to(source, target_root):
            rewritten[key] = str(source)
            continue
        try:
            relative = source.resolve().relative_to(package_root)
        except ValueError:
            relative = Path("models") / source.name
        rewritten[key] = str((target_root / relative).resolve())
    rdocs_config.DEFAULT_CFG.update(rewritten)


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False
