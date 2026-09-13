#!/bin/sh
set -eu
PREFIX=/opt/nacta-passport
export NACTA_HOME="$PREFIX"
export OCR_MODELS_DIR="$PREFIX/python_service/models"
export OCR_RDOCS_MODELS_DIR="$PREFIX/python_service/models/rdocs"
cd "$PREFIX"
exec "$PREFIX/ru_passport" "$@"
