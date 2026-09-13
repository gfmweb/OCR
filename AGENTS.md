# AGENTS.md

Локальное desktop-приложение: Flutter + Python OCR на localhost.

## Запуск

- Python: `cd python_service && uv sync --python 3.12 && uv run python -m app`
- Flutter: `flutter run -d linux` или `flutter run -d windows` из корня
- Linux .deb: `./scripts/package_linux_deb.sh` (Docker ubuntu:22.04, нужны веса в `python_service/models/`)
- Windows zip: `.\scripts\package_windows.ps1` (только Windows amd64, нужны веса в `python_service/models/`)
- Dev без автозапуска Python: `OCR_SERVICE_URL=http://127.0.0.1:8765` и `OCR_SESSION_TOKEN`

## Тесты

- Python: `cd python_service && uv run pytest`
- Integration OCR: `cd python_service && uv run pytest -m integration`
- Flutter: `flutter test`
- Lint: `uv run ruff check .` в `python_service`, `flutter analyze` в корне

## Важно

- Ответы — на русском
- API только `127.0.0.1`, session Bearer token
- Не логировать изображения, OCR-текст, ФИО, даты, серию/номер
- Реальные паспорта не коммитить
- Linux .deb: Ubuntu/Debian amd64, пол Ubuntu 22.04
- Windows zip: amd64, сборка только на Windows (`scripts/package_windows.ps1`)
