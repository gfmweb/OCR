@echo off
setlocal EnableExtensions
set "NACTA_HOME=%~dp0"
if "%NACTA_HOME:~-1%"=="\" set "NACTA_HOME=%NACTA_HOME:~0,-1%"

set "OCR_MODELS_DIR=%NACTA_HOME%\python_service\models"
set "OCR_RDOCS_MODELS_DIR=%NACTA_HOME%\python_service\models\rdocs"

set "VENV_CFG=%NACTA_HOME%\python_service\.venv\pyvenv.cfg"
set "RUNTIME=%NACTA_HOME%\python\runtime"
if exist "%RUNTIME%\python.exe" (
  > "%VENV_CFG%" (
    echo home = %RUNTIME%
    echo include-system-site-packages = false
    echo executable = %RUNTIME%\python.exe
  )
)

cd /d "%NACTA_HOME%"
start "" /D "%NACTA_HOME%" "%NACTA_HOME%\ru_passport.exe" %*
exit /b 0
