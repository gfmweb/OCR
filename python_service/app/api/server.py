from __future__ import annotations

import threading
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI

from app.api.routes import router
from app.application.recognize import RecognizeService
from app.infrastructure.config import Settings
from app.infrastructure.logging import configure_logging, log_event
from app.infrastructure.security import authorization_dependency
from app.infrastructure.warmup import WarmupStatus
from app.ocr.model_manager import ModelManager
from app.ocr.paddle_provider import PaddleOCRProvider
from app.ocr.provider import OCRProvider
from app.rdocs.pipeline import RussianDocsFieldsProvider
from app.rdocs.provider import DocumentFieldsProvider


def create_app(
    settings: Settings,
    provider: OCRProvider | None = None,
    fields_provider: DocumentFieldsProvider | None = None,
    warmup: bool = True,
) -> FastAPI:
    logger = configure_logging()
    resolved_provider = provider or PaddleOCRProvider(settings)
    manager = ModelManager(settings=settings, provider=resolved_provider)
    resolved_fields = fields_provider or RussianDocsFieldsProvider(settings)
    warmup_status = WarmupStatus()

    def _run_warmup() -> None:
        try:
            resolved_fields.warmup(on_stage=warmup_status.set_stage)
            log_event(
                logger,
                "warmup_done",
                stage=warmup_status.stage,
                model_version=manager.provider.model_version,
                rdocs_ready=resolved_fields.ready,
            )
        except TypeError:
            warmup_status.set_stage("loading_models")
            resolved_fields.warmup()
            warmup_status.set_stage("ready")
            log_event(
                logger,
                "warmup_done",
                stage=warmup_status.stage,
                model_version=manager.provider.model_version,
                rdocs_ready=resolved_fields.ready,
            )
        except Exception:
            warmup_status.set_stage("error")
            log_event(
                logger,
                "warmup_failed",
                stage="error",
                model_version=manager.provider.model_version,
            )

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        manager.ready = True
        if warmup:
            log_event(
                logger,
                "warmup_start",
                stage="starting_server",
                model_version=manager.provider.model_version,
            )
            thread = threading.Thread(target=_run_warmup, name="ocr-warmup", daemon=True)
            thread.start()
            app.state.warmup_thread = thread
        else:
            resolved_fields.ready = True
            warmup_status.set_stage("ready")
        yield
        release = getattr(resolved_fields, "release", None)
        if callable(release):
            release()

    app = FastAPI(
        title="RU Passport OCR",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
        lifespan=lifespan,
        dependencies=[Depends(authorization_dependency(settings.session_token))],
    )
    app.state.settings = settings
    app.state.logger = logger
    app.state.manager = manager
    app.state.fields_provider = resolved_fields
    app.state.warmup_status = warmup_status
    app.state.recognize_service = RecognizeService(resolved_fields)
    app.include_router(router)
    return app
