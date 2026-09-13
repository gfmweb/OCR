# Nacta паспорт

Локальное desktop-приложение для Windows и Linux. Изображение и паспортные данные **не покидают компьютер**.

Сейчас реализован **вертикальный срез**:

`файл → ориентация 0/90/180/270 → OpenCV (decode/resize/grayscale) → PaddleOCR (CPU, кириллица) → JSON строк OCR → Flutter UI`

Ориентация определяется по содержимому (OCR score по четырём поворотам), EXIF используется только как слабый tie-break.

Полный Document Understanding pipeline (детектор документа, перспектива, parser паспорта, fusion, validation) — следующие фазы. Срез нужен, чтобы измерить качество OCR, а не чтобы «угадывать» паспорт.

## Ограничения текущей версии

- Нет классификации «это паспорт РФ».
- Нет выправления перспективы и наклона (deskew).
- Автоповорот 0/90/180/270 уже есть; мелкий произвольный угол пока нет.
- Нет разбора полей (ФИО, серия, номер).
- Нет multi-OCR fusion и calibrated confidence.
- На CPU (особенно 2 ядра) первый запуск и OCR могут занимать десятки секунд.

## Архитектура среза

```
Flutter desktop
    → LocalOcrClient (Bearer token)
        → FastAPI 127.0.0.1
            → OCRProvider
                → PaddleOCRProvider
```

Parser и UI не зависят от PaddleOCR. Позже можно добавить `ONNXOCRProvider`.

## Privacy / security

- API слушает только `127.0.0.1`, никогда `0.0.0.0`.
- На каждый запуск генерируется session token. Запросы: `Authorization: Bearer <token>`.
- Нет облачного OCR, analytics SDK и LLM.
- В логи пишутся только `request_id`, `stage`, `duration_ms`, `error_code`, `model_version`.
- Не логируются изображение, OCR-текст, ФИО, даты, серия и номер.
- Результаты OCR не сохраняются на диск.

## Требования для разработки

- Flutter 3.44+ (Linux desktop)
- [uv](https://docs.astral.sh/uv/) и Python **3.12** (системный 3.14 не подходит для PaddlePaddle)
- Интернет только при установке зависимостей и первом скачивании моделей

## Запуск Linux

```bash
# 1. Python OCR-сервис
cd python_service
uv python install 3.12
uv sync --python 3.12
uv run python -m app
```

В stdout появится `SESSION_TOKEN=...`. Модели качаются при первом warmup в `python_service/models/`.

В другом терминале:

```bash
export OCR_SERVICE_URL=http://127.0.0.1:8765
export OCR_SESSION_TOKEN='<токен из stdout сервиса>'
flutter run -d linux
```

Если переменные окружения не заданы, Flutter сам запустит `python_service/.venv/bin/python -m app` с одноразовым токеном.

Первый `uv sync` ставит CPU-сборку `paddlepaddle==3.2.2` с индекса Paddle.
`paddlepaddle 3.3.x` на CPU ломает PP-OCRv5 из-за бага oneDNN/PIR, поэтому версия зафиксирована.

Модели отдельно:

```bash
cd python_service
uv run python scripts/download_models.py
```

## Тесты

```bash
cd python_service
uv run pytest                 # unit, без загрузки Paddle-моделей
uv run pytest -m integration  # синтетическая кириллица, медленно на CPU
uv run ruff check .

cd ..
flutter analyze
flutter test
```

Реальные паспорта в git не класть. Для evaluation позже используйте локальный каталог вне репозитория.

## Linux .deb (Ubuntu/Debian amd64 22.04+)

Полный offline-пакет: Flutter-клиент, Python 3.12, venv и веса OCR. Не для Fedora, Arch, ARM и Alpine. Сборка идёт в Docker `ubuntu:22.04`, чтобы glibc не был привязан к Ubuntu 26.04.

Нужны уже скачанные модели (`python_service/models/`, обычно несколько сотен МБ или больше):

```bash
cd python_service
uv sync --python 3.12
uv run python scripts/download_rdocs_models.py
uv run python scripts/download_models.py
cd ..
./scripts/package_linux_deb.sh
```

Установка:

```bash
sudo apt install ./dist/nacta-passport_1.0.0_amd64.deb
nacta-passport
```

На целевой машине: x86_64, Ubuntu 22.04 / Debian 12 или новее, несколько ГБ RAM и свободного диска. После установки интернет не нужен; первый запуск всё равно может быть долгим — модели поднимаются в память.

## Windows zip (amd64)

Полный offline-пакет, как Linux .deb: Flutter-клиент, Python 3.12, venv и веса OCR. Собирается **только на Windows** (`flutter build windows` с Linux недоступен). `flutter build windows` без скрипта упаковки даёт лишь UI — OCR не найдёт `.venv`.

Нужны уже скачанные модели (`python_service/models/`). Их можно скачать на этой машине или скопировать каталог с Linux:

```powershell
cd python_service
uv sync --python 3.12
uv run python scripts/download_rdocs_models.py
uv run python scripts/download_models.py
cd ..
.\scripts\package_windows.ps1
```

Результат: `dist/nacta-passport-windows-x64/` и `dist/nacta-passport_1.0.0_windows_amd64.zip`.

Запуск:

```text
распаковать zip
nacta-passport.cmd
```

На целевой машине: 64-bit Windows, [Visual C++ Redistributable 2015–2022 x64](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist), несколько ГБ RAM и диска. После сборки интернет не нужен; первый запуск может быть долгим — модели поднимаются в память. Не запускайте `ru_passport.exe` из `build\windows\...` без `python_service`.

## Конфигурация

См. [python_service/.env.example](python_service/.env.example): порт, порог размера изображения, имена моделей, CPU/GPU.

GPU не обязателен. По умолчанию `OCR_USE_GPU=false` и `OCR_DEVICE=cpu`.
