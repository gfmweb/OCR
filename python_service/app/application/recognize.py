from __future__ import annotations

import base64
import time
import uuid

import cv2

from app.domain.ocr import OCRResult, StageTimings
from app.passport.normalize import PassportFieldNormalizer
from app.preprocessing.image_io import decode_image
from app.rdocs.mapper import map_rdocs_result
from app.rdocs.provider import DocumentFieldsProvider


class RecognizeService:
    def __init__(self, fields: DocumentFieldsProvider) -> None:
        self._fields = fields
        self._normalizer = PassportFieldNormalizer()

    def recognize(self, payload: bytes, page: str = "first_spread") -> OCRResult:
        request_id = str(uuid.uuid4())
        started = time.perf_counter()

        load_started = time.perf_counter()
        original = decode_image(payload)
        height, width = original.shape[:2]
        image_loading = _elapsed_ms(load_started)

        rgb = cv2.cvtColor(original, cv2.COLOR_BGR2RGB)
        del original

        ocr_started = time.perf_counter()
        snapshot = self._fields.process(rgb)
        ocr_ms = _elapsed_ms(ocr_started)
        del rgb

        parse_started = time.perf_counter()
        mapped = map_rdocs_result(snapshot, self._normalizer, page=page)
        parsing_ms = _elapsed_ms(parse_started)
        photo_jpeg_base64 = None
        signature_jpeg_base64 = None
        if mapped.view == "first_spread":
            if snapshot.photo_jpeg:
                photo_jpeg_base64 = base64.b64encode(snapshot.photo_jpeg).decode("ascii")
            if snapshot.signature_jpeg:
                signature_jpeg_base64 = base64.b64encode(snapshot.signature_jpeg).decode("ascii")

        timings = StageTimings(
            image_loading=image_loading,
            orientation=0,
            preprocessing=0,
            ocr=ocr_ms,
            parsing=parsing_ms,
            llm=0,
            total_ms=_elapsed_ms(started),
        )
        return OCRResult(
            request_id=request_id,
            lines=[],
            timings=timings,
            image_width=width,
            image_height=height,
            rotation_degrees=0,
            model_version=self._fields.model_version,
            provider=self._fields.name,
            document_type=mapped.document_type,
            document_confidence=mapped.document_confidence,
            view=mapped.view,
            error_code=mapped.error_code,
            fields=mapped.fields,
            warnings=mapped.warnings,
            photo_jpeg_base64=photo_jpeg_base64,
            signature_jpeg_base64=signature_jpeg_base64,
        )


def _elapsed_ms(started: float) -> int:
    return int((time.perf_counter() - started) * 1000)
