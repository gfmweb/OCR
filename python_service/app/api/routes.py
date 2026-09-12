from __future__ import annotations

import os
import signal
import threading
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status

from app.application.recognize import RecognizeService
from app.infrastructure.logging import log_event
from app.ocr.model_manager import ModelManager
from app.preprocessing.image_io import ImageDecodeError

router = APIRouter()


def get_manager(request: Request) -> ModelManager:
    return request.app.state.manager


def get_recognize_service(request: Request) -> RecognizeService:
    return request.app.state.recognize_service


@router.get("/health")
def health(request: Request, manager: ModelManager = Depends(get_manager)) -> dict[str, Any]:
    fields = getattr(request.app.state, "fields_provider", None)
    rdocs_ready = bool(getattr(fields, "ready", False))
    return {
        "status": "ready" if manager.ready and rdocs_ready else "starting",
        "provider": manager.provider.name if manager.ready else None,
        "model_version": manager.provider.model_version if manager.ready else None,
        "bind": f"{request.app.state.settings.api_host}:{request.app.state.settings.api_port}",
        "rdocs_ready": rdocs_ready,
    }


@router.post("/api/v1/recognize")
async def recognize(
    request: Request,
    image: UploadFile = File(...),
    page: str = Form("first_spread"),
    service: RecognizeService = Depends(get_recognize_service),
) -> dict[str, Any]:
    settings = request.app.state.settings
    logger = request.app.state.logger
    payload = await image.read()
    if len(payload) > settings.max_upload_bytes:
        log_event(logger, "recognize_rejected", error_code="IMAGE_TOO_LARGE", bytes=len(payload))
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail={"error_code": "IMAGE_TOO_LARGE"},
        )
    page_kind = "registration" if page.strip().lower() == "registration" else "first_spread"
    try:
        result = service.recognize(payload, page=page_kind)
    except ImageDecodeError:
        log_event(logger, "recognize_failed", error_code="IMAGE_DECODE_FAILED")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": "IMAGE_DECODE_FAILED"},
        ) from None
    except Exception:
        log_event(logger, "recognize_failed", error_code="OCR_FAILED")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error_code": "OCR_FAILED"},
        ) from None
    log_event(
        logger,
        "recognize_done",
        request_id=result.request_id,
        stage="ocr",
        duration_ms=result.timings.total_ms,
        model_version=result.model_version,
        provider=result.provider,
        line_count=len(result.lines),
        image_width=result.image_width,
        image_height=result.image_height,
        rotation_degrees=result.rotation_degrees,
        document_type=result.document_type,
        view=result.view,
        error_code=result.error_code,
        filled_field_count=sum(1 for field in result.fields.values() if field.value),
        has_photo=bool(result.photo_jpeg_base64),
        has_signature=bool(result.signature_jpeg_base64),
    )
    return result.to_dict()


@router.post("/shutdown")
def shutdown(request: Request) -> dict[str, str]:
    server = getattr(request.app.state, "server", None)
    if server is not None:
        server.should_exit = True

        def _terminate() -> None:
            os.kill(os.getpid(), signal.SIGTERM)

        threading.Timer(0.3, _terminate).start()
    return {"status": "shutting_down"}
