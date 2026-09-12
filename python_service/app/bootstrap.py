from __future__ import annotations

import os
import sys

import uvicorn

from app.api.server import create_app
from app.infrastructure.config import get_settings
from app.infrastructure.security import load_or_create_token


def run() -> None:
    settings = get_settings()
    token = load_or_create_token(settings.session_token or os.environ.get("OCR_SESSION_TOKEN", ""))
    settings.session_token = token
    print(f"SESSION_TOKEN={token}", flush=True)
    print(f"BIND={settings.api_host}:{settings.api_port}", flush=True)

    app = create_app(settings=settings, warmup=True)
    config = uvicorn.Config(
        app,
        host=settings.api_host,
        port=settings.api_port,
        log_config=None,
        access_log=False,
    )
    server = uvicorn.Server(config)
    app.state.server = server
    try:
        server.run()
    except KeyboardInterrupt:
        sys.exit(0)
