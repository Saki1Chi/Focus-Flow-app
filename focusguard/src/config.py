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
    import keyring as _keyring
    _KEYRING_OK = True
except ImportError:
    _keyring = None  # type: ignore[assignment]
    _KEYRING_OK = False

try:
    from zoneinfo import ZoneInfo
except ImportError:
    from backports.zoneinfo import ZoneInfo  # type: ignore[no-redef]
from datetime import timezone, timedelta

# ── Rutas dinamicas (todo dentro del proyecto) ────────────────────────────────
BASE_DIR     = Path(__file__).resolve().parent.parent   # FocusGuard/
DATA_DIR     = BASE_DIR / "data"
CONFIG_PATH  = DATA_DIR / "config.json"
HISTORY_PATH = DATA_DIR / "history.json"
LOG_PATH     = DATA_DIR / "focusguard.log"

DATA_DIR.mkdir(parents=True, exist_ok=True)

try:
    MEXICO_TZ = ZoneInfo("America/Mexico_City")
except Exception:
    # Fallback si tzdata no está instalado; usa UTC-6 (CDMX estándar)
    MEXICO_TZ = timezone(timedelta(hours=-6))

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
    # API / sincronización con el dashboard FocusFlow CMS
    "api_base_url":    "http://localhost:8000",
    "api_sync_enabled": True,
    # legacy — solo para migración en primer arranque
    "tasks_date":  "",
    "tasks":       [],
}

# ── Singleton + lock ──────────────────────────────────────────────────────────
_lock: threading.RLock = threading.RLock()
_data: dict | None     = None

# ── Estado de privilegios (fijado por main.py tras el chequeo UAC) ────────────
_admin_status: bool = False

# ── Keyring ───────────────────────────────────────────────────────────────────
_KR_SERVICE  = "FocusGuard"
_KR_TOKEN    = "api_token"

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
    try:
        fh = logging.handlers.RotatingFileHandler(
            LOG_PATH, maxBytes=1_048_576, backupCount=2, encoding="utf-8",
        )
        log_path_used = LOG_PATH
    except PermissionError:
        fallback = Path.cwd() / "focusguard.user.log"
        fh = logging.handlers.RotatingFileHandler(
            fallback, maxBytes=1_048_576, backupCount=2, encoding="utf-8",
        )
        log_path_used = fallback
        # print en vez de logging (aún no configurado)
        print(f"[focusguard] Warning: sin permiso para {LOG_PATH}, usando {fallback}")
    fh.setFormatter(fmt)
    root_log.addHandler(fh)

    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    root_log.addHandler(ch)

    root_log.info(f"Logging inicializado en {log_path_used}")


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


# ── API / sincronización con el dashboard ─────────────────────────────────────
def get_api_base_url() -> str:
    with _lock:
        return load().get("api_base_url", "http://localhost:8000")


def set_api_base_url(url: str) -> None:
    with _lock:
        url = url.rstrip("/")
        _warn_if_insecure_url(url)
        data = load()
        data["api_base_url"] = url
        _save_to_disk(data)
        log.info(f"API base URL configurada: {url!r}")


def _warn_if_insecure_url(url: str) -> None:
    """Advierte si la URL usa HTTP (no HTTPS) y no es localhost."""
    is_http = url.startswith("http://")
    is_local = any(url.startswith(f"http://{h}") for h in ("localhost", "127.", "0.0.0.0"))
    if is_http and not is_local:
        log.warning(
            "URL del backend usa HTTP sin cifrado: %s — "
            "se recomienda HTTPS para comunicaciones remotas.", url
        )


def is_api_sync_enabled() -> bool:
    with _lock:
        return bool(load().get("api_sync_enabled", True))


def set_api_sync_enabled(value: bool) -> None:
    with _lock:
        data = load()
        data["api_sync_enabled"] = value
        _save_to_disk(data)
        log.info(f"Sincronización API {'habilitada' if value else 'deshabilitada'}.")


# ── Nombre de usuario (no sensible, guardado en config.json) ──────────────────
def get_api_username() -> str:
    with _lock:
        return load().get("api_username", "")


def set_api_username(username: str) -> None:
    with _lock:
        data = load()
        data["api_username"] = username
        _save_to_disk(data)


# ── Token de autenticación (guardado en Windows Credential Manager vía keyring)
# Si keyring no está disponible, cae en config.json como fallback (menos seguro).

def get_api_token() -> str:
    """Lee el token desde Windows Credential Manager (o config.json si keyring falla)."""
    if _KEYRING_OK:
        try:
            return _keyring.get_password(_KR_SERVICE, _KR_TOKEN) or ""
        except Exception as e:
            log.warning("keyring get falló: %s — intentando config.json", e)
    with _lock:
        return load().get("api_token_fallback", "")


def set_api_token(token: str) -> None:
    """Guarda el token en Windows Credential Manager (o config.json si keyring falla)."""
    if _KEYRING_OK:
        try:
            if token:
                _keyring.set_password(_KR_SERVICE, _KR_TOKEN, token)
            else:
                _delete_keyring_token()
            log.info("Token guardado en Windows Credential Manager.")
            return
        except Exception as e:
            log.warning("keyring set falló: %s — usando config.json como fallback", e)
    # Fallback: config.json (menos seguro, pero funcional)
    with _lock:
        data = load()
        data["api_token_fallback"] = token
        _save_to_disk(data)
        log.warning("Token guardado en config.json (fallback). Instala keyring para mayor seguridad.")


def delete_api_token() -> None:
    """Elimina el token almacenado."""
    _delete_keyring_token()
    with _lock:
        data = load()
        data.pop("api_token_fallback", None)
        _save_to_disk(data)
    log.info("Token de API eliminado.")


def _delete_keyring_token() -> None:
    if not _KEYRING_OK:
        return
    try:
        _keyring.delete_password(_KR_SERVICE, _KR_TOKEN)
    except Exception:
        pass


# ── Estado de privilegios de administrador ────────────────────────────────────

def set_admin_status(is_admin: bool) -> None:
    """Llamado por main.py tras el chequeo UAC."""
    global _admin_status
    _admin_status = is_admin
    if not is_admin:
        log.warning(
            "FocusGuard corriendo SIN privilegios de administrador. "
            "El bloqueador puede no poder terminar procesos protegidos."
        )


def is_running_as_admin() -> bool:
    return _admin_status


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
        for candidate in (HISTORY_PATH, Path(str(HISTORY_PATH) + ".bak")):
            if not candidate.exists():
                continue
            try:
                with open(candidate, "r", encoding="utf-8") as f:
                    history = json.load(f)
                break
            except Exception:
                history = []

        history = [e for e in history if e.get("fecha") != today]
        history.append({
            "fecha":              today,
            "tareas_total":       total,
            "tareas_completadas": done,
            "desbloqueado_por":   reason,
        })

        tmp = Path(str(HISTORY_PATH) + ".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2, ensure_ascii=False)
        tmp.replace(HISTORY_PATH)
        try:
            bak = Path(str(HISTORY_PATH) + ".bak")
            shutil.copy2(HISTORY_PATH, bak)
        except Exception:
            pass

        log.info(f"Historial guardado: {today}, {done}/{total}, motivo={reason!r}")


def get_streak() -> int:
    """Dias consecutivos con todas las tareas completadas."""
    history = []
    for candidate in (HISTORY_PATH, Path(str(HISTORY_PATH) + ".bak")):
        if not candidate.exists():
            continue
        try:
            with open(candidate, "r", encoding="utf-8") as f:
                history = json.load(f)
            break
        except Exception:
            history = []
    if not history:
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
