from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, status

from app.infrastructure.config import SERVICE_ROOT

TOKEN_FILE = SERVICE_ROOT / ".session_token"


def generate_session_token() -> str:
    return secrets.token_urlsafe(32)


def persist_token(token: str) -> None:
    TOKEN_FILE.write_text(token, encoding="utf-8")
    TOKEN_FILE.chmod(0o600)


def load_or_create_token(configured: str) -> str:
    if configured.strip():
        token = configured.strip()
        persist_token(token)
        return token
    token = generate_session_token()
    persist_token(token)
    return token


def tokens_match(provided: str, expected: str) -> bool:
    provided_bytes = provided.encode("utf-8")
    expected_bytes = expected.encode("utf-8")
    if len(provided_bytes) != len(expected_bytes):
        return False
    return secrets.compare_digest(provided_bytes, expected_bytes)


def require_bearer_token(expected: str, authorization: str | None) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    provided = authorization.removeprefix("Bearer ").strip()
    if not tokens_match(provided, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )


def authorization_dependency(expected: str):
    async def _check(authorization: str | None = Header(default=None)) -> None:
        require_bearer_token(expected, authorization)

    return _check
