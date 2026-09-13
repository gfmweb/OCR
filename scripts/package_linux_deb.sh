#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$ROOT/python_service/models"
IMAGE="${NACTA_DEB_IMAGE:-nacta-passport-deb-builder}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Нужен Docker, чтобы собрать .deb под glibc Ubuntu 22.04." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "На хосте нужен Flutter SDK (монтируется в контейнер)." >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "На хосте нужен uv (монтируется в контейнер)." >&2
  exit 1
fi

if [[ ! -d "$MODELS_DIR/rdocs" ]]; then
  echo "Нет весов OCR в python_service/models/rdocs." >&2
  echo "Сначала:" >&2
  echo "  cd python_service && uv sync --python 3.12" >&2
  echo "  uv run python scripts/download_rdocs_models.py" >&2
  echo "  uv run python scripts/download_models.py" >&2
  exit 1
fi

MODELS_MB="$(du -sm "$MODELS_DIR" | awk '{print $1}')"
if [[ "${MODELS_MB:-0}" -lt 200 ]]; then
  echo "Каталог python_service/models слишком маленький (${MODELS_MB} МиБ)." >&2
  echo "Скачайте веса:" >&2
  echo "  cd python_service && uv run python scripts/download_rdocs_models.py" >&2
  echo "  uv run python scripts/download_models.py" >&2
  exit 1
fi

FLUTTER_BIN="$(command -v flutter)"
FLUTTER_SDK="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
UV_BIN="$(command -v uv)"
PACK_CACHE="${NACTA_DEB_CACHE:-$HOME/.cache/nacta-deb}"
UV_CACHE_DIR="${UV_CACHE_DIR:-$PACK_CACHE/uv}"
PUB_CACHE="${PUB_CACHE:-$PACK_CACHE/pub}"
UV_PYTHON_DIR="$PACK_CACHE/uv-python"

mkdir -p "$ROOT/dist" "$UV_CACHE_DIR" "$PUB_CACHE" "$UV_PYTHON_DIR"

docker build \
  -t "$IMAGE" \
  -f "$ROOT/packaging/linux/Dockerfile" \
  "$ROOT/packaging/linux"

# Host uid so Flutter SDK / caches are not rewritten as root.
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

docker run --rm \
  --network host \
  --user "${HOST_UID}:${HOST_GID}" \
  -e HOME=/tmp/builder-home \
  -e PUB_CACHE=/tmp/builder-home/.pub-cache \
  -e UV_CACHE_DIR=/tmp/builder-home/.cache/uv \
  -e UV_PYTHON_INSTALL_DIR=/tmp/builder-home/.local/share/uv/python \
  -v "$ROOT":/src:ro \
  -v "$MODELS_DIR":/models:ro \
  -v "$ROOT/dist":/out \
  -v "$FLUTTER_SDK":/opt/flutter \
  -v "$UV_BIN":/usr/local/bin/uv:ro \
  -v "$UV_CACHE_DIR":/tmp/builder-home/.cache/uv \
  -v "$UV_PYTHON_DIR":/tmp/builder-home/.local/share/uv/python \
  -v "$PUB_CACHE":/tmp/builder-home/.pub-cache \
  "$IMAGE"
