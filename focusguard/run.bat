@echo off
cd /d "%~dp0"

set "VENV_PY=%~dp0.venv\Scripts\pythonw.exe"
if exist "%VENV_PY%" (
    start "" "%VENV_PY%" main.py
    goto :eof
)

REM Intenta lanzar sin consola (pythonw). Si no existe, usa python normal.
where pythonw >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "" pythonw main.py
) else (
    start "" python main.py
)
