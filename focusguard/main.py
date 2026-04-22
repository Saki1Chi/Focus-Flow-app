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
try:
    from src.system_tray import SystemTray
except Exception as tray_exc:  # pystray/Pillow pueden faltar; se loguea más abajo
    SystemTray = None  # type: ignore
    _TRAY_IMPORT_ERROR = tray_exc


# ── Elevacion UAC ─────────────────────────────────────────────────────────────
def _is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def request_admin() -> None:
    """Re-lanza el proceso con permisos de administrador si hace falta."""
    if _should_skip_admin():
        return
    if _is_admin():
        return
    script = str(Path(sys.argv[0]).resolve())
    params = " ".join(f'"{a}"' for a in sys.argv[1:])
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, f'"{script}" {params}', None, 1,
    )
    sys.exit(0)


def _should_skip_admin() -> bool:
    """Permite saltar la elevación con env FG_SKIP_ADMIN=1 o flag --no-admin."""
    return (
        os.environ.get("FG_SKIP_ADMIN") == "1"
        or "--no-admin" in sys.argv
    )


# ── Task Scheduler ────────────────────────────────────────────────────────────
def _find_pythonw() -> str:
    """Devuelve la ruta a pythonw.exe si existe; sino usa python.exe."""
    venv_pythonw = Path(__file__).resolve().parent / ".venv" / "Scripts" / "pythonw.exe"
    if venv_pythonw.exists():
        return str(venv_pythonw)
    candidate = Path(sys.executable).parent / "pythonw.exe"
    return str(candidate) if candidate.exists() else sys.executable


def _schtasks_escape(path: str) -> str:
    """
    Sanitiza una ruta para usarla dentro de comillas en el argumento /tr de schtasks.
    En Windows, '"' no es un carácter válido en rutas de archivo, así que se elimina
    como medida de defensa ante rutas inesperadas. (#4)
    """
    return path.replace('"', "")


def setup_autostart() -> None:
    """Registra FocusGuard en Task Scheduler para arrancar con el sistema."""
    main_py = _schtasks_escape(str(Path(__file__).resolve()))

    if getattr(sys, "frozen", False):
        # Compilado con PyInstaller
        exe = _schtasks_escape(sys.executable)
        cmd = f'"{exe}"'
    else:
        pythonw = _schtasks_escape(_find_pythonw())
        cmd = f'"{pythonw}" "{main_py}"'

    try:
        result = subprocess.run(
            [
                "schtasks", "/create",
                "/tn",  "FocusGuard",
                "/tr",  cmd,
                "/sc",  "onlogon",
                "/rl",  "highest",
                "/f",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        log = logging.getLogger("focusguard.main")
        if result.returncode == 0:
            log.info("Task Scheduler actualizado: %s", cmd)
        else:
            log.warning(
                "Task Scheduler no se pudo registrar (rc=%s): %s",
                result.returncode,
                (result.stderr or result.stdout or "").strip(),
            )
    except Exception as exc:
        logging.getLogger("focusguard.main").warning(
            f"setup_autostart fallo: {exc}"
        )


# ── Instalacion de dependencias faltantes ─────────────────────────────────────
def _check_deps() -> None:
    """Verifica dependencias críticas y loguea aviso si faltan."""
    missing = []
    for mod in ("psutil", "plyer", "tkcalendar"):
        try:
            __import__(mod)
        except ImportError:
            missing.append(mod)

    try:
        from zoneinfo import ZoneInfo  # noqa: F401
        ZoneInfo("America/Mexico_City")
    except Exception:
        missing.append("tzdata")

    if missing:
        logging.getLogger("focusguard.main").warning(
            "Faltan dependencias: %s. Instala con `pip install -r requirements.txt`.",
            ", ".join(sorted(set(missing))),
        )


# ── Main ──────────────────────────────────────────────────────────────────────
def main() -> None:
    # 1. Dependencias
    _check_deps()

    # 2. Elevacion UAC
    request_admin()

    # 3. Registrar si se está corriendo con privilegios reales (#3)
    # Debe hacerse DESPUÉS de request_admin() para capturar el resultado correcto.
    # Si el usuario usó --no-admin o FG_SKIP_ADMIN=1, _is_admin() devolverá False.
    cfg.set_admin_status(_is_admin())

    # 4. Logging (escribe en data/focusguard.log)
    setup_logging()
    log = logging.getLogger("focusguard.main")
    log.info("=" * 60)
    log.info(f"FocusGuard iniciando. Python {sys.version}")
    log.info(f"Admin: {cfg.is_running_as_admin()}")
    log.info(f"BASE_DIR: {cfg.BASE_DIR}")
    log.info(f"DATA_DIR: {cfg.DATA_DIR}")

    # 5. Carga config + reset diario
    cfg.load()

    # 6. Registrar autostart
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

    tray = None
    if SystemTray is None:
        err = globals().get("_TRAY_IMPORT_ERROR")
        log.warning("SystemTray no disponible (%s).", err or "import error")
    else:
        def exit_app() -> None:
            blocker.stop()
            root.after(0, root.destroy)

        tray = SystemTray(on_open=open_main, on_exit=exit_app)
        try:
            tray.start()
            log.info("Icono de bandeja iniciado.")
        except Exception as exc:
            log.warning(f"No se pudo iniciar el icono de bandeja: {exc}")

    # 8. Iniciar hilo bloqueador
    blocker.start()
    log.info("BlockerThread iniciado.")

    # 9. Mostrar ventana y entrar al event loop
    root.deiconify()
    log.info("Entrando al event loop de Tkinter.")
    try:
        root.mainloop()
    finally:
        if tray:
            tray.stop()
        log.info("FocusGuard cerrando.")
        blocker.stop()
        blocker.join(timeout=5)
        log.info("FocusGuard cerrado.")


if __name__ == "__main__":
    main()
