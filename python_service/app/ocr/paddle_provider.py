from __future__ import annotations

import os
from typing import Any

import numpy as np

from app.domain.ocr import OCRLine
from app.infrastructure.config import Settings


class PaddleOCRProvider:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._engine: Any = None
        self._prepare_runtime_env()

    def _prepare_runtime_env(self) -> None:
        try:
            self._settings.models_dir.mkdir(parents=True, exist_ok=True)
        except OSError:
            if not self._settings.models_dir.exists():
                raise
        os.environ["PADDLE_PDX_CACHE_HOME"] = str(self._settings.models_dir)
        os.environ["HUGGINGFACE_HUB_CACHE"] = str(self._settings.models_dir / "hf")
        os.environ["PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK"] = "True"
        os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
        os.environ["FLAGS_enable_pir_api"] = "0"
        os.environ["FLAGS_use_mkldnn"] = "0"

    @property
    def name(self) -> str:
        return "paddleocr"

    @property
    def model_version(self) -> str:
        return f"{self._settings.det_model_name}+{self._settings.rec_model_name}"

    def warmup(self) -> None:
        self._engine = self._create_engine()
        probe = np.full((64, 64, 3), 255, dtype=np.uint8)
        self.recognize(probe)

    def recognize(self, image: np.ndarray) -> list[OCRLine]:
        if self._engine is None:
            raise RuntimeError("PaddleOCR is not loaded")
        raw = self._engine.predict(image)
        return _normalize_paddle_result(raw)

    def _create_engine(self) -> Any:
        self._prepare_runtime_env()
        from paddleocr import PaddleOCR

        return PaddleOCR(
            device=self._settings.inference_device,
            text_detection_model_name=self._settings.det_model_name,
            text_recognition_model_name=self._settings.rec_model_name,
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
            enable_mkldnn=False,
        )


def _normalize_paddle_result(raw: Any) -> list[OCRLine]:
    if raw is None:
        return []
    if isinstance(raw, list) and raw and _looks_like_v2(raw[0]):
        return _from_v2(raw)
    pages = raw if isinstance(raw, list) else [raw]
    lines: list[OCRLine] = []
    for page in pages:
        lines.extend(_from_v3_page(page))
    return lines


def _looks_like_v2(item: Any) -> bool:
    return isinstance(item, list) and item and isinstance(item[0], list) and len(item[0]) >= 2


def _from_v2(raw: list) -> list[OCRLine]:
    lines: list[OCRLine] = []
    is_nested = raw and isinstance(raw[0], list) and raw[0] and isinstance(raw[0][0], list)
    pages = raw if is_nested else [raw]
    for page in pages:
        if not page:
            continue
        for item in page:
            box, payload = item[0], item[1]
            text, confidence = payload[0], float(payload[1])
            lines.append(OCRLine(text=str(text), confidence=confidence, bbox=_as_bbox(box)))
    return lines


def _from_v3_page(page: Any) -> list[OCRLine]:
    data = _page_as_dict(page)
    texts = _as_sequence(data.get("rec_texts") or data.get("rec_text"))
    scores = _as_sequence(data.get("rec_scores") or data.get("rec_score"))
    boxes = _as_sequence(
        data.get("rec_polys")
        if _has_items(data.get("rec_polys"))
        else data.get("dt_polys")
        if _has_items(data.get("dt_polys"))
        else data.get("rec_boxes")
    )
    lines: list[OCRLine] = []
    for index, text in enumerate(texts):
        confidence = float(scores[index]) if index < len(scores) else 0.0
        bbox = _as_bbox(boxes[index]) if index < len(boxes) else []
        lines.append(OCRLine(text=str(text), confidence=confidence, bbox=bbox))
    return lines


def _has_items(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, np.ndarray):
        return value.size > 0
    try:
        return len(value) > 0
    except TypeError:
        return bool(value)


def _as_sequence(value: Any) -> list[Any]:
    if not _has_items(value):
        return []
    if isinstance(value, np.ndarray):
        return value.tolist()
    return list(value)


def _page_as_dict(page: Any) -> dict[str, Any]:
    if isinstance(page, dict):
        return page
    if hasattr(page, "keys") and hasattr(page, "__getitem__"):
        return {str(key): page[key] for key in page.keys()}
    dumped = getattr(page, "json", None)
    if callable(dumped):
        payload = dumped()
        if isinstance(payload, dict):
            return payload
    return {
        "rec_texts": getattr(page, "rec_texts", []),
        "rec_scores": getattr(page, "rec_scores", []),
        "rec_polys": getattr(page, "rec_polys", getattr(page, "dt_polys", [])),
    }


def _as_bbox(raw_box: Any) -> list[list[float]]:
    if raw_box is None:
        return []
    array = np.asarray(raw_box, dtype=float)
    if array.size == 8:
        array = array.reshape(4, 2)
    if array.ndim == 1 and array.size == 4:
        x1, y1, x2, y2 = array.tolist()
        return [[x1, y1], [x2, y1], [x2, y2], [x1, y2]]
    return array.reshape(-1, 2).tolist()
