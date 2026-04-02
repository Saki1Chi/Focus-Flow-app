"""
TaskRepository: CRUD de tareas y sesiones sobre archivos JSON.
  data/tasks.json    — lista de Task
  data/sessions.json — lista de BlockSession
"""
from __future__ import annotations

import json
import logging
import threading
import uuid
from datetime import datetime, date
from pathlib import Path
from typing import List, Optional

from .models import Task, TaskStatus, BlockSession

log = logging.getLogger("focusguard.repository")

_BASE_DIR     = Path(__file__).resolve().parent.parent
_DATA_DIR     = _BASE_DIR / "data"
_TASKS_PATH   = _DATA_DIR / "tasks.json"
_SESSIONS_PATH= _DATA_DIR / "sessions.json"

_lock = threading.RLock()


def _date_only(dt: datetime) -> date:
    return dt.date()


def _load_json(path: Path) -> list:
    if not path.exists():
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return []


def _save_json(path: Path, data: list) -> None:
    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(path)


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
            tasks = self.get_all_tasks()
            tasks = [t for t in tasks if t.id != task.id]
            tasks.append(task)
            _save_json(_TASKS_PATH, [t.to_dict() for t in tasks])

    def delete_task(self, task_id: str) -> None:
        with _lock:
            tasks = [t for t in self.get_all_tasks() if t.id != task_id]
            _save_json(_TASKS_PATH, [t.to_dict() for t in tasks])

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
