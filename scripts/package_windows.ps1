#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if ($env:OS -ne 'Windows_NT') {
    Write-Error 'Соберите Windows-пакет на машине Windows amd64. flutter build windows с Linux недоступен.'
}

if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    Write-Error "Нужна Windows amd64. Текущая архитектура: $env:PROCESSOR_ARCHITECTURE"
}

function Get-CommandPath([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $null
    }
    return $cmd.Source
}

$Root = Split-Path -Parent $PSScriptRoot
$ModelsDir = Join-Path $Root 'python_service\models'
$Staging = Join-Path $Root 'dist\nacta-passport-windows-x64'
$ServiceSrc = Join-Path $Root 'python_service'
$ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'

if (-not (Get-CommandPath 'flutter')) {
    Write-Error 'На этой машине нужен Flutter SDK (flutter build windows).'
}
if (-not (Get-CommandPath 'uv')) {
    Write-Error 'На этой машине нужен uv (https://docs.astral.sh/uv/).'
}

$rdocs = Join-Path $ModelsDir 'rdocs'
if (-not (Test-Path $rdocs -PathType Container)) {
    Write-Error @"
Нет весов OCR в python_service\models\rdocs.
Сначала:
  cd python_service
  uv sync --python 3.12
  uv run python scripts/download_rdocs_models.py
  uv run python scripts/download_models.py
Можно скопировать python_service\models с Linux-машины, где модели уже скачаны.
"@
}

$modelsBytes = (Get-ChildItem -LiteralPath $ModelsDir -Recurse -File -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum).Sum
$modelsMb = [math]::Floor(($modelsBytes / 1MB))
if ($modelsMb -lt 200) {
    Write-Error @"
Каталог python_service\models слишком маленький ($modelsMb МиБ).
Скачайте веса:
  cd python_service
  uv run python scripts/download_rdocs_models.py
  uv run python scripts/download_models.py
"@
}

$pubspec = Get-Content -LiteralPath (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([^\s+]+)') {
    Write-Error 'Не удалось прочитать version из pubspec.yaml.'
}
$Version = $Matches[1]

Write-Host "building Flutter windows release"
Push-Location $Root
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows failed: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$exe = Join-Path $ReleaseDir 'ru_passport.exe'
if (-not (Test-Path $exe)) {
    Write-Error "Нет $exe. flutter build windows --release не собрал клиент."
}

Write-Host "syncing Python 3.12 venv"
Push-Location $ServiceSrc
try {
    & uv python install 3.12
    if ($LASTEXITCODE -ne 0) {
        throw "uv python install 3.12 failed: $LASTEXITCODE"
    }
    & uv venv --python 3.12 --relocatable .venv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "uv venv --relocatable недоступен, обычный venv"
        & uv venv --python 3.12 .venv
        if ($LASTEXITCODE -ne 0) {
            throw "uv venv failed: $LASTEXITCODE"
        }
    }
    & uv sync --python 3.12 --no-dev
    if ($LASTEXITCODE -ne 0) {
        throw "uv sync failed: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$venvPython = Join-Path $ServiceSrc '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Error "Не найден $venvPython после uv sync."
}

$basePrefix = (& $venvPython -c "import sys; print(sys.base_prefix)").Trim()
if (-not $basePrefix -or -not (Test-Path (Join-Path $basePrefix 'python.exe'))) {
    Write-Error "Не удалось определить каталог CPython 3.12 ($basePrefix)."
}

if (Test-Path $Staging) {
    Remove-Item -LiteralPath $Staging -Recurse -Force
}
New-Item -ItemType Directory -Path $Staging | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging 'python_service') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging 'python') | Out-Null

function Copy-Tree {
    param(
        [Parameter(Mandatory = $true)][string]$From,
        [Parameter(Mandatory = $true)][string]$To,
        [string[]]$ExcludeDirs = @()
    )
    New-Item -ItemType Directory -Path $To -Force | Out-Null
    $robocopyArgs = @(
        $From, $To, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/nc', '/ns', '/np'
    )
    foreach ($name in $ExcludeDirs) {
        $robocopyArgs += '/XD'
        $robocopyArgs += $name
    }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & robocopy @robocopyArgs | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($code -ge 8) {
        throw "robocopy failed ($code): $From -> $To"
    }
}

Write-Host "staging Flutter bundle, Python runtime, venv and models"
Copy-Tree -From $ReleaseDir -To $Staging
Copy-Tree -From $ServiceSrc -To (Join-Path $Staging 'python_service') -ExcludeDirs @(
    '.venv', 'models', 'tests', '__pycache__'
)
Remove-Item -LiteralPath (Join-Path $Staging 'python_service\.env') -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $Staging 'python_service\.session_token') -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath (Join-Path $Staging 'python_service') -Recurse -Directory -Filter '__pycache__' |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Copy-Tree -From (Join-Path $ServiceSrc '.venv') -To (Join-Path $Staging 'python_service\.venv')
Copy-Tree -From $ModelsDir -To (Join-Path $Staging 'python_service\models')
Copy-Tree -From $basePrefix -To (Join-Path $Staging 'python\runtime')

$runtimePy = Join-Path $Staging 'python\runtime\python.exe'
if (-not (Test-Path $runtimePy)) {
    Write-Error 'В пакет не попал python\runtime\python.exe.'
}

$scriptsPython = Join-Path $Staging 'python_service\.venv\Scripts\python.exe'
if (-not (Test-Path $scriptsPython)) {
    Write-Error 'В пакет не попал python_service\.venv\Scripts\python.exe.'
}

$runtimeHome = Join-Path $Staging 'python\runtime'
@(
    "home = $runtimeHome"
    'include-system-site-packages = false'
    "executable = $(Join-Path $runtimeHome 'python.exe')"
) | Set-Content -LiteralPath (Join-Path $Staging 'python_service\.venv\pyvenv.cfg') -Encoding ascii

Copy-Item -LiteralPath (Join-Path $Root 'packaging\windows\nacta-passport.cmd') `
    -Destination (Join-Path $Staging 'nacta-passport.cmd') -Force

Remove-Item -LiteralPath (Join-Path $Staging 'python_service\.session_token') -ErrorAction SilentlyContinue

$zip = Join-Path $Root "dist\nacta-passport_${Version}_windows_amd64.zip"
if (Test-Path $zip) {
    Remove-Item -LiteralPath $zip -Force
}
New-Item -ItemType Directory -Path (Join-Path $Root 'dist') -Force | Out-Null
Write-Host "packing $zip (это может занять несколько минут)"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Staging, $zip)

Write-Host "built $zip"
Get-Item -LiteralPath $zip | Format-List FullName, Length
Write-Host "Запуск: распакуйте zip и откройте nacta-passport.cmd"
exit 0
