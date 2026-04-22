"""
TaskRepository: CRUD de tareas y sesiones sobre archivos JSON.
  data/tasks.json    — lista de Task
  data/sessions.json — lista de BlockSession

Sincronización con el backend FocusFlow CMS (mismo protocolo que la app Flutter):
  - save_task / delete_task disparan sync en background (fire-and-forget).
  - pull_from_api(date_str)  descarga tareas del backend y las fusiona localmente.
  - push_to_api()            sube todas las tareas locales vía bulk sync.
"""
from __future__ import annotations

import json
import logging
import shutil
import threading
import uuid
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional

from .models import Task, TaskStatus, BlockSession

log = logging.getLogger("focusguard.repository")

_BASE_DIR      = Path(__file__).resolve().parent.parent
_DATA_DIR      = _BASE_DIR / "data"
_TASKS_PATH    = _DATA_DIR / "tasks.json"
_SESSIONS_PATH = _DATA_DIR / "sessions.json"

_lock = threading.RLock()


# ── Helpers de API (importación diferida para evitar circular) ─────────────────

def _get_api():
    """Retorna un ApiService autenticado si la sincronización está habilitada."""
    try:
        from . import config as cfg
        if not cfg.is_api_sync_enabled():
            return None
        from .api_service import ApiService
        return ApiService(
            base_url=cfg.get_api_base_url(),
            token=cfg.get_api_token(),      # (#1) Incluye X-Token si el usuario inició sesión
        )
    except Exception:
        return None


def _run_async(fn, *args) -> None:
    """Ejecuta fn(*args) en un hilo daemon (fire-and-forget)."""
    threading.Thread(target=fn, args=args, daemon=True, name="focusguard-api-sync").start()


def _safe_api_call(fn, *args) -> None:
    """Wrapper silencioso para llamadas API en background."""
    try:
        fn(*args)
    except Exception as e:
        log.warning(f"API sync error ({fn.__name__}): {e}")


def _date_only(dt: datetime) -> date:
    return dt.date()


def _load_json(path: Path) -> list:
    """Lee JSON con fallback a .bak en caso de corrupción."""
    for candidate in (path, Path(str(path) + ".bak")):
        if not candidate.exists():
            continue
        try:
            with open(candidate, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            continue
    return []


def _save_json(path: Path, data: list) -> None:
    """Escritura atómica + backup."""
    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = Path(str(path) + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(path)
    try:
        bak = Path(str(path) + ".bak")
        shutil.copy2(path, bak)
    except Exception:
        pass


class TaskRepository:

    # ── Tasks ──────────────────────────────────────────────────────────────────

    def get_all_tasks(self) -> List[Task]:
        with _lock:
            tasks: List[Task] = []
            for d in _load_json(_TASKS_PATH):
                try:
                    tasks.append(Task.from_dict(d))
                except Exception as e:
                    log.warning(f"Tarea inválida ignorada: {e}")
            return tasks

    def get_tasks_for_date(self, dt: datetime) -> List[Task]:
        d = _date_only(dt)
        return sorted(
            [t for t in self.get_all_tasks() if _date_only(t.date) == d],
            key=lambda t: t.day_order,
        )

    def get_task_by_id(self, task_id: str) -> Optional[Task]:
        return next((t for t in self.get_all_tasks() if t.id == task_id), None)

    def save_task(self, task: Task) -> None:
        with _lock:
            existing = self.get_all_tasks()
            is_new = not any(t.id == task.id for t in existing)
            tasks = [t for t in existing if t.id != task.id]
            tasks.append(task)
            _save_json(_TASKS_PATH, [t.to_dict() for t in tasks])
        api = _get_api()
        if api:
            if is_new:
                _run_async(_safe_api_call, api.create_task, task)
            else:
                _run_async(_safe_api_call, api.update_task, task)

    def delete_task(self, task_id: str) -> None:
        with _lock:
            tasks = [t for t in self.get_all_tasks() if t.id != task_id]
            _save_json(_TASKS_PATH, [t.to_dict() for t in tasks])
        api = _get_api()
        if api:
            _run_async(_safe_api_call, api.delete_task, task_id)

    def task_exists_on_date(self, title: str, dt: datetime) -> bool:
        d = _date_only(dt)
        return any(
            t.title.lower() == title.lower() and _date_only(t.date) == d
            for t in self.get_all_tasks()
        )

    def replace_all(self, tasks: List[Task]) -> None:
        with _lock:
            _save_json(_TASKS_PATH, [t.to_dict() for t in tasks])

    def dates_with_tasks(self) -> set:
        """Devuelve el conjunto de objetos date que tienen al menos una tarea."""
        return {_date_only(t.date) for t in self.get_all_tasks()}

    # ── Block Sessions ─────────────────────────────────────────────────────────

    def get_active_session(self) -> Optional[BlockSession]:
        for s in self._load_sessions():
            if s.is_active and not s.is_expired:
                return s
        return None

    def save_session(self, session: BlockSession) -> None:
        with _lock:
            sessions = self._load_sessions()
            sessions = [s for s in sessions if s.id != session.id]
            sessions.append(session)
            _save_json(_SESSIONS_PATH, [s.to_dict() for s in sessions])

    def _load_sessions(self) -> List[BlockSession]:
        sessions: List[BlockSession] = []
        for d in _load_json(_SESSIONS_PATH):
            try:
                sessions.append(BlockSession.from_dict(d))
            except Exception:
                pass
        return sessions

    # ── Sincronización con el backend ─────────────────────────────────────────

    def pull_from_api(self, date_str: Optional[str] = None) -> int:
        """
        Descarga tareas del backend y las fusiona localmente (remote wins por ID).
        date_str: "YYYY-MM-DD" para filtrar por fecha, None para todas.
        Retorna el número de tareas recibidas.
        """
        api = _get_api()
        if not api:
            return 0
        try:
            remote_tasks = api.get_tasks(date=date_str)
            with _lock:
                local_by_id = {t.id: t for t in self.get_all_tasks()}
                for rt in remote_tasks:
                    local_by_id[rt.id] = rt
                _save_json(_TASKS_PATH, [t.to_dict() for t in local_by_id.values()])
            log.info(f"pull_from_api: {len(remote_tasks)} tarea(s) recibidas.")
            return len(remote_tasks)
        except Exception as e:
            log.warning(f"pull_from_api error: {e}")
            return 0

    def push_to_api(self) -> Dict[str, int]:
        """
        Sube todas las tareas locales vía POST /api/tasks/bulk.
        Retorna {"created": int, "updated": int}.
        """
        api = _get_api()
        if not api:
            return {"created": 0, "updated": 0}
        try:
            tasks = self.get_all_tasks()
            result = api.bulk_sync(tasks)
            log.info(f"push_to_api: {result}")
            return result
        except Exception as e:
            log.warning(f"push_to_api error: {e}")
            return {"created": 0, "updated": 0}

    # ── Migración del formato antiguo (config.json tasks) ─────────────────────

    def migrate_from_old_config(self, old_tasks: list) -> None:
        """Convierte tareas del formato {id, text, done} al nuevo modelo Task."""
        if not old_tasks or _TASKS_PATH.exists():
            return
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        new_tasks: List[Task] = []
        for i, t in enumerate(old_tasks):
            new_tasks.append(Task(
                id=t.get("id", str(uuid.uuid4())),
                title=t.get("text", ""),
                date=today,
                status=TaskStatus.COMPLETED if t.get("done") else TaskStatus.PENDING,
                day_order=i,
            ))
        _save_json(_TASKS_PATH, [t.to_dict() for t in new_tasks])
        log.info(f"Migradas {len(new_tasks)} tareas del formato antiguo.")
