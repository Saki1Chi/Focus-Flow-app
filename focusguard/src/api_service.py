"""
ApiService: cliente HTTP para el backend FocusFlow CMS (FastAPI).

Espeja exactamente la clase ApiService de la app Flutter:
  - Mismos endpoints (/api/tasks, /api/categories, /api/stats)
  - Mismo formato JSON snake_case
  - recurrence serializada como JSON string (igual que Flutter jsonEncode)
  - Autenticación via header X-Token (obtenido con login())
"""
from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Dict, List, Optional

import requests

from .models import RecurrenceRule, Task, TaskMode, TaskStatus

log = logging.getLogger("focusguard.api_service")

_TIMEOUT      = 15   # segundos (igual que Flutter)
_BULK_TIMEOUT = 60   # segundos para bulk sync


class ApiService:
    """
    Cliente REST para el FocusFlow CMS.

    Uso:
        api = ApiService("http://localhost:8000")
        api.create_task(task)
        tasks = api.get_tasks(date="2026-04-06")
        api.bulk_sync(all_tasks)
    """

    def __init__(self, base_url: str = "http://localhost:8000", token: str = "") -> None:
        self._base  = base_url.rstrip("/")
        self._token = token
        # Advertir si la URL es HTTP y no es localhost (#2)
        is_http  = base_url.startswith("http://")
        is_local = any(base_url.startswith(f"http://{h}")
                       for h in ("localhost", "127.", "0.0.0.0"))
        if is_http and not is_local:
            log.warning(
                "ApiService: URL remota sin TLS — los datos viajan sin cifrar: %s",
                self._base,
            )

    @property
    def _headers(self) -> dict:
        headers = {"Content-Type": "application/json"}
        if self._token:
            headers["X-Token"] = self._token  # (#1) Autenticación via token
        return headers

    # ── Serialización (igual que Flutter _taskToSnake / _snakeToCamel) ─────────

    def _to_api(self, task: Task) -> dict:
        """Task → dict snake_case para el backend."""
        return {
            "id":                  task.id,
            "title":               task.title,
            "description":         task.description,
            "date":                task.date.isoformat(),
            "start_time":          task.start_time.isoformat() if task.start_time else None,
            "end_time":            task.end_time.isoformat()   if task.end_time   else None,
            "status":              int(task.status),
            "mode":                int(task.mode),
            # recurrence como JSON string, igual que Flutter: jsonEncode(recurrence.toJson())
            "recurrence":          json.dumps(task.recurrence.to_dict()) if task.recurrence else None,
            "is_carried_over":     task.is_carried_over,
            "day_order":           task.day_order,
            "parent_id":           task.parent_id,
            "is_recurring_parent": task.is_recurring_parent,
        }

    def _from_api(self, d: dict) -> Task:
        """Dict snake_case del backend → Task."""
        rec_raw = d.get("recurrence")
        recurrence: Optional[RecurrenceRule] = None
        if rec_raw:
            rec_dict = json.loads(rec_raw) if isinstance(rec_raw, str) else rec_raw
            recurrence = RecurrenceRule.from_dict(rec_dict)

        return Task(
            id=d["id"],
            title=d.get("title", ""),
            description=d.get("description", ""),
            date=datetime.fromisoformat(d["date"]),
            start_time=datetime.fromisoformat(d["start_time"]) if d.get("start_time") else None,
            end_time=datetime.fromisoformat(d["end_time"])     if d.get("end_time")     else None,
            status=TaskStatus(d.get("status", 0)),
            mode=TaskMode(d.get("mode", 0)),
            recurrence=recurrence,
            is_carried_over=d.get("is_carried_over", False),
            day_order=d.get("day_order", 0),
            parent_id=d.get("parent_id"),
            is_recurring_parent=d.get("is_recurring_parent", False),
        )

    # ── Tasks ──────────────────────────────────────────────────────────────────

    # ── Auth ───────────────────────────────────────────────────────────────────

    def login(self, username: str, password: str) -> str:
        """
        POST /api/users/login — retorna el token de sesión.
        Lanza requests.HTTPError si las credenciales son incorrectas.
        """
        res = requests.post(
            f"{self._base}/api/users/login",
            json={"username": username, "password": password},
            headers={"Content-Type": "application/json"},
            timeout=_TIMEOUT,
            verify=True,
        )
        res.raise_for_status()
        return res.json()["token"]

    # ── Tasks ──────────────────────────────────────────────────────────────────

    def get_tasks(
        self,
        date:   Optional[str] = None,
        status: Optional[int] = None,
        mode:   Optional[int] = None,
    ) -> List[Task]:
        """GET /api/tasks — equivalente a ApiService.getTasks() en Flutter."""
        params: dict = {}
        if date   is not None: params["date"]   = date
        if status is not None: params["status"] = status
        if mode   is not None: params["mode"]   = mode

        res = requests.get(
            f"{self._base}/api/tasks",
            params=params, headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()
        return [self._from_api(d) for d in res.json()]

    def create_task(self, task: Task) -> None:
        """POST /api/tasks — equivalente a ApiService.createTask() en Flutter."""
        res = requests.post(
            f"{self._base}/api/tasks",
            json=self._to_api(task),
            headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()

    def update_task(self, task: Task) -> None:
        """PUT /api/tasks/{id} — equivalente a ApiService.updateTask() en Flutter."""
        res = requests.put(
            f"{self._base}/api/tasks/{task.id}",
            json=self._to_api(task),
            headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()

    def delete_task(self, task_id: str) -> None:
        """DELETE /api/tasks/{id} — equivalente a ApiService.deleteTask() en Flutter."""
        res = requests.delete(
            f"{self._base}/api/tasks/{task_id}",
            headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()

    def bulk_sync(self, tasks: List[Task]) -> Dict[str, int]:
        """
        POST /api/tasks/bulk — upsert masivo.
        Equivalente a ApiService.bulkSync() en Flutter.
        Retorna {"created": int, "updated": int}.
        """
        body = [self._to_api(t) for t in tasks]
        res = requests.post(
            f"{self._base}/api/tasks/bulk",
            json=body,
            headers=self._headers, timeout=_BULK_TIMEOUT, verify=True,
        )
        res.raise_for_status()
        return res.json()

    # ── Categories ─────────────────────────────────────────────────────────────

    def get_categories(self) -> List[dict]:
        """GET /api/categories — equivalente a ApiService.getCategories() en Flutter."""
        res = requests.get(
            f"{self._base}/api/categories",
            headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()
        return res.json()

    # ── Stats ──────────────────────────────────────────────────────────────────

    def get_stats(self) -> Dict[str, int]:
        """
        GET /api/stats — equivalente a ApiService.getStats() en Flutter.
        Retorna {"total", "pending", "in_progress", "completed", "categories"}.
        """
        res = requests.get(
            f"{self._base}/api/stats",
            headers=self._headers, timeout=_TIMEOUT, verify=True,
        )
        res.raise_for_status()
        return res.json()
