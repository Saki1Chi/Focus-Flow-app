"""
FocusGuard — punto de entrada principal.

Uso:
    python main.py          (desarrollo)
    pythonw main.py         (produccion, sin consola)
    run.bat                 (launcher alternativo)
"""
from __future__ import annotations

import ctypes
import logging
import os
import subprocess
import sys
from pathlib import Path

import tkinter as tk

# Asegurar que src/ sea importable cuando se ejecuta como script
sys.path.insert(0, str(Path(__file__).resolve().parent))

from src import config as cfg
from src.config import setup_logging
from src.blocker import BlockerThread
from src.tray import StatusBar
from src.ui import MainWindow


# ── Elevacion UAC ─────────────────────────────────────────────────────────────
def _is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def request_admin() -> None:
    """Re-lanza el proceso con permisos de administrador si hace falta."""
    if _is_admin():
        return
    script = str(Path(sys.argv[0]).resolve())
    params = " ".join(f'"{a}"' for a in sys.argv[1:])
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, f'"{script}" {params}', None, 1,
    )
    sys.exit(0)


# ── Task Scheduler ────────────────────────────────────────────────────────────
def _find_pythonw() -> str:
    """Devuelve la ruta a pythonw.exe si existe; sino usa python.exe."""
    candidate = Path(sys.executable).parent / "pythonw.exe"
    return str(candidate) if candidate.exists() else sys.executable


def setup_autostart() -> None:
    """Registra FocusGuard en Task Scheduler para arrancar con el sistema."""
    main_py = str(Path(__file__).resolve())

    if getattr(sys, "frozen", False):
        # Compilado con PyInstaller
        cmd = f'"{sys.executable}"'
    else:
        cmd = f'"{_find_pythonw()}" "{main_py}"'

    try:
        subprocess.run(
            [
                "schtasks", "/create",
                "/tn",  "FocusGuard",
                "/tr",  cmd,
                "/sc",  "onlogon",
                "/rl",  "highest",
                "/f",
            ],
            capture_output=True,
            check=False,
        )
        logging.getLogger("focusguard.main").info(
            f"Task Scheduler actualizado: {cmd}"
        )
    except Exception as exc:
        logging.getLogger("focusguard.main").warning(
            f"setup_autostart fallo: {exc}"
        )


# ── Instalacion de dependencias faltantes ─────────────────────────────────────
def _ensure_deps() -> None:
    """Instala psutil y tzdata si no estan disponibles."""
    deps = []
    try:
        import psutil  # noqa: F401
    except ImportError:
        deps.append("psutil")
    try:
        from zoneinfo import ZoneInfo
        ZoneInfo("America/Mexico_City")
    except (ImportError, KeyError):
        deps.append("tzdata")
    try:
        import plyer  # noqa: F401
    except ImportError:
        deps.append("plyer")
    try:
        import tkcalendar  # noqa: F401
    except ImportError:
        deps.append("tkcalendar")

    if deps:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--quiet"] + deps
        )


# ── Main ──────────────────────────────────────────────────────────────────────
def main() -> None:
    # 1. Dependencias
    _ensure_deps()

    # 2. Elevacion UAC
    request_admin()

    # 3. Logging (escribe en data/focusguard.log)
    setup_logging()
    log = logging.getLogger("focusguard.main")
    log.info("=" * 60)
    log.info(f"FocusGuard iniciando. Python {sys.version}")
    log.info(f"BASE_DIR: {cfg.BASE_DIR}")
    log.info(f"DATA_DIR: {cfg.DATA_DIR}")

    # 4. Carga config + reset diario
    cfg.load()

    # 5. Registrar autostart
    setup_autostart()

    # 6. Tk root (oculto mientras se construye)
    root = tk.Tk()
    root.withdraw()

    # 7. Construir UI
    def open_main() -> None:
        root.deiconify()
        root.lift()
        root.focus_force()

    status_bar = StatusBar(root, on_open=open_main)
    blocker    = BlockerThread(interval=3)
    _app       = MainWindow(root, status_bar, blocker)

    # 8. Iniciar hilo bloqueador
    blocker.start()
    log.info("BlockerThread iniciado.")

    # 9. Mostrar ventana y entrar al event loop
    root.deiconify()
    log.info("Entrando al event loop de Tkinter.")
    try:
        root.mainloop()
    finally:
        log.info("FocusGuard cerrando.")
        blocker.stop()
        blocker.join(timeout=5)
        log.info("FocusGuard cerrado.")


if __name__ == "__main__":
    main()
