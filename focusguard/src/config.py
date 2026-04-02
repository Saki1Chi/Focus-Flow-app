"""
Gestion de configuracion: singleton en memoria, RLock compartido,
escritura atomica a disco y persistencia de historial.

Rutas:  FocusGuard/
        └── data/
            ├── config.json
            ├── config.json.bak
            ├── history.json
            └── focusguard.log
"""
from __future__ import annotations

import json
import logging
import logging.handlers
import shutil
import threading
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

try:
    from zoneinfo import ZoneInfo
except ImportError:
    from backports.zoneinfo import ZoneInfo  # type: ignore[no-redef]

# ── Rutas dinamicas (todo dentro del proyecto) ────────────────────────────────
BASE_DIR     = Path(__file__).resolve().parent.parent   # FocusGuard/
DATA_DIR     = BASE_DIR / "data"
CONFIG_PATH  = DATA_DIR / "config.json"
HISTORY_PATH = DATA_DIR / "history.json"
LOG_PATH     = DATA_DIR / "focusguard.log"

DATA_DIR.mkdir(parents=True, exist_ok=True)

MEXICO_TZ = ZoneInfo("America/Mexico_City")

DEFAULT_CONFIG: dict = {
    "blocked_apps": [
        "LeagueClient.exe",
        "League of Legends.exe",
        "VALORANT-Win64-Shipping.exe",
        "FortniteClient-Win64-Shipping.exe",
    ],
    "unlock_hour":              21,
    "unlock_duration_minutes":  20,
    "blocks_to_unlock":         3,
    "completed_blocks_today":   0,
    "blocks_date":              "",
    "dark_mode":                False,
    "accent_color":             "blue",
    # legacy — solo para migración en primer arranque
    "tasks_date":  "",
    "tasks":       [],
}

# ── Singleton + lock ──────────────────────────────────────────────────────────
_lock: threading.RLock = threading.RLock()
_data: dict | None     = None

log = logging.getLogger("focusguard.config")


# ── Logging ───────────────────────────────────────────────────────────────────
def setup_logging() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    root_log = logging.getLogger("focusguard")
    root_log.setLevel(logging.DEBUG)

    fmt = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    fh = logging.handlers.RotatingFileHandler(
        LOG_PATH, maxBytes=1_048_576, backupCount=2, encoding="utf-8",
    )
    fh.setFormatter(fmt)
    root_log.addHandler(fh)

    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    root_log.addHandler(ch)


# ── I/O interno ───────────────────────────────────────────────────────────────
def _load_from_disk() -> dict:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    for path in [CONFIG_PATH, Path(str(CONFIG_PATH) + ".bak")]:
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for k, v in DEFAULT_CONFIG.items():
                data.setdefault(k, v)
            return data
        except (FileNotFoundError, json.JSONDecodeError):
            continue
    return dict(DEFAULT_CONFIG)


def _save_to_disk(data: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = Path(str(CONFIG_PATH) + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(CONFIG_PATH)
    try:
        shutil.copy2(CONFIG_PATH, Path(str(CONFIG_PATH) + ".bak"))
    except Exception:
        pass


def _check_daily_reset(data: dict) -> None:
    """Actualiza tasks_date. Las tareas nuevas se manejan en el repository."""
    today = date.today().isoformat()
    if data.get("tasks_date") != today:
        data["tasks_date"] = today
        _save_to_disk(data)
        log.info("Reset diario (config): fecha actualizada.")


# ── API publica ───────────────────────────────────────────────────────────────
def get_lock() -> threading.RLock:
    return _lock


def load() -> dict:
    """Carga el singleton desde disco (solo la primera vez)."""
    global _data
    with _lock:
        if _data is None:
            _data = _load_from_disk()
            _check_daily_reset(_data)
            log.info("Config cargado desde disco.")
        return _data


def get_data() -> dict:
    return load()


def check_daily_reset() -> None:
    """Verifica y aplica reset diario. Seguro para llamar en cada ciclo de UI."""
    with _lock:
        if _data is not None:
            _check_daily_reset(_data)


def is_blocking_active() -> bool:
    with _lock:
        data        = load()
        now         = datetime.now(MEXICO_TZ)
        unlock_hour = data.get("unlock_hour", 21)
        if now.hour >= unlock_hour:
            return False

        # Verificar sesión de focus-blocks activa
        from .repository import TaskRepository  # import aquí para evitar circular
        repo = TaskRepository()
        session = repo.get_active_session()
        if session and not session.is_expired:
            return False

        # Verificar tareas de hoy completadas
        today_tasks = repo.get_tasks_for_date(datetime.now())
        if today_tasks and all(
            t.status == 2  # TaskStatus.COMPLETED — evita import circular
            for t in today_tasks
        ):
            return False

        return True


# ── Tareas ────────────────────────────────────────────────────────────────────
def add_task(text: str) -> None:
    with _lock:
        data = load()
        data["tasks"].append({"id": str(uuid.uuid4()), "text": text.strip(), "done": False})
        _save_to_disk(data)
        log.info(f"Tarea agregada: {text!r}")


def toggle_task(task_id: str) -> None:
    with _lock:
        data = load()
        for t in data["tasks"]:
            if t["id"] == task_id:
                t["done"] = not t["done"]
                log.info(f"Tarea {'completada' if t['done'] else 'pendiente'}: {t['text']!r}")
        _save_to_disk(data)


def remove_task(task_id: str) -> None:
    with _lock:
        data = load()
        data["tasks"] = [t for t in data["tasks"] if t["id"] != task_id]
        _save_to_disk(data)
        log.info(f"Tarea eliminada (id={task_id})")


# ── Apps bloqueadas ───────────────────────────────────────────────────────────
def add_blocked_app(exe: str) -> None:
    with _lock:
        data = load()
        exe  = exe.strip()
        if exe and exe not in data["blocked_apps"]:
            data["blocked_apps"].append(exe)
            _save_to_disk(data)
            log.info(f"App bloqueada agregada: {exe!r}")


def remove_blocked_app(exe: str) -> None:
    with _lock:
        data = load()
        data["blocked_apps"] = [a for a in data["blocked_apps"] if a != exe]
        _save_to_disk(data)
        log.info(f"App bloqueada eliminada: {exe!r}")


# ── Hora de desbloqueo ────────────────────────────────────────────────────────
def get_unlock_hour() -> int:
    with _lock:
        return load().get("unlock_hour", 21)


def set_unlock_hour(hour: int) -> None:
    with _lock:
        data = load()
        data["unlock_hour"] = max(0, min(23, hour))
        _save_to_disk(data)
        log.info(f"Hora de desbloqueo configurada: {hour}:00")


# ── Focus blocks ─────────────────────────────────────────────────────────────
def get_completed_blocks_today() -> int:
    with _lock:
        data  = load()
        today = date.today().isoformat()
        if data.get("blocks_date") != today:
            data["blocks_date"]            = today
            data["completed_blocks_today"] = 0
            _save_to_disk(data)
        return data.get("completed_blocks_today", 0)


def increment_completed_blocks() -> int:
    with _lock:
        data  = load()
        today = date.today().isoformat()
        if data.get("blocks_date") != today:
            data["blocks_date"]            = today
            data["completed_blocks_today"] = 0
        data["completed_blocks_today"] = data.get("completed_blocks_today", 0) + 1
        _save_to_disk(data)
        return data["completed_blocks_today"]


def get_blocks_to_unlock() -> int:
    with _lock:
        return load().get("blocks_to_unlock", 3)


def set_blocks_to_unlock(n: int) -> None:
    with _lock:
        data = load()
        data["blocks_to_unlock"] = max(1, n)
        _save_to_disk(data)


def get_unlock_duration() -> int:
    with _lock:
        return load().get("unlock_duration_minutes", 20)


def set_unlock_duration(minutes: int) -> None:
    with _lock:
        data = load()
        data["unlock_duration_minutes"] = max(1, minutes)
        _save_to_disk(data)


def get_accent_color() -> str:
    with _lock:
        return load().get("accent_color", "blue")


def set_accent_color(key: str) -> None:
    with _lock:
        data = load()
        data["accent_color"] = key
        _save_to_disk(data)


def get_dark_mode() -> bool:
    with _lock:
        return bool(load().get("dark_mode", False))


def set_dark_mode(value: bool) -> None:
    with _lock:
        data = load()
        data["dark_mode"] = value
        _save_to_disk(data)


# ── Historial de productividad ────────────────────────────────────────────────
def save_history(reason: str) -> None:
    """Guarda snapshot del dia en history.json. reason: 'hora' | 'tareas'."""
    with _lock:
        data  = load()
        today = date.today().isoformat()
        tasks = data.get("tasks", [])
        total = len(tasks)
        done  = sum(1 for t in tasks if t["done"])

        history: list = []
        if HISTORY_PATH.exists():
            try:
                with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                    history = json.load(f)
            except Exception:
                history = []

        history = [e for e in history if e.get("fecha") != today]
        history.append({
            "fecha":              today,
            "tareas_total":       total,
            "tareas_completadas": done,
            "desbloqueado_por":   reason,
        })

        with open(HISTORY_PATH, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2, ensure_ascii=False)

        log.info(f"Historial guardado: {today}, {done}/{total}, motivo={reason!r}")


def get_streak() -> int:
    """Dias consecutivos con todas las tareas completadas."""
    if not HISTORY_PATH.exists():
        return 0
    try:
        with open(HISTORY_PATH, "r", encoding="utf-8") as f:
            history = json.load(f)
    except Exception:
        return 0

    today  = date.today()
    streak = 0
    for i in range(365):
        check = (today - timedelta(days=i)).isoformat()
        entry = next((e for e in history if e.get("fecha") == check), None)
        if (
            entry
            and entry.get("tareas_total", 0) > 0
            and entry["tareas_completadas"] == entry["tareas_total"]
        ):
            streak += 1
        else:
            break
    return streak
