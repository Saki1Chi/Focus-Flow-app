@echo off
cd /d "%~dp0"

REM Intenta lanzar sin consola (pythonw). Si no existe, usa python normal.
where pythonw >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    start "" pythonw main.py
) else (
    start "" python main.py
)
