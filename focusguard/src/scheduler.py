"""
SchedulerService: auto-programación de tareas (Smart Mode).
Port de SchedulerService.dart a Python.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import Callable, List, Optional

from .models import Task, TaskMode, TaskStatus

_TASK_DURATION  = timedelta(hours=1, minutes=30)
_WORKDAY_START  = (8, 0)   # (hora, minuto)
_WORKDAY_END    = (20, 0)


class _Slot:
    def __init__(self, start: datetime, end: datetime):
        self.start = start
        self.end   = end

    def overlaps(self, other: _Slot) -> bool:
        return self.start < other.end and self.end > other.start


def _dt(base: datetime, h: int, m: int) -> datetime:
    return base.replace(hour=h, minute=m, second=0, microsecond=0)


class SchedulerService:

    def schedule_tasks(
        self,
        bare_tasks: List[Task],
        date: datetime,
        existing_tasks: List[Task],
    ) -> List[Task]:
        scheduled: List[Task] = []
        occupied  = self._occupied(existing_tasks)

        cursor  = _dt(date, *_WORKDAY_START)
        day_end = _dt(date, *_WORKDAY_END)

        for i, task in enumerate(bare_tasks):
            if any(e.title.lower() == task.title.lower() for e in existing_tasks):
                continue
            slot_start = self._free_slot(cursor, occupied, day_end)
            if slot_start is None:
                break
            slot_end = slot_start + _TASK_DURATION
            occupied.append(_Slot(slot_start, slot_end))
            scheduled.append(Task(
                id=task.id,
                title=task.title,
                description=task.description,
                date=date,
                start_time=slot_start,
                end_time=slot_end,
                day_order=len(existing_tasks) + i,
                mode=TaskMode.SMART,
                status=TaskStatus.PENDING,
            ))
            cursor = slot_end

        return scheduled

    def re_slot_carried_over(
        self,
        task: Task,
        from_date: datetime,
        tasks_for_date: Callable[[datetime], List[Task]],
        max_days_ahead: int = 7,
    ) -> Optional[Task]:
        for d in range(1, max_days_ahead + 1):
            candidate = from_date + timedelta(days=d)
            day_tasks = tasks_for_date(candidate)
            if any(t.title.lower() == task.title.lower() for t in day_tasks):
                continue
            occupied = self._occupied(day_tasks)
            day_end  = _dt(candidate, *_WORKDAY_END)
            slot_start = self._free_slot(_dt(candidate, *_WORKDAY_START), occupied, day_end)
            if slot_start is None:
                continue
            return Task(
                id=str(uuid.uuid4()),
                title=task.title,
                description=task.description,
                date=candidate,
                start_time=slot_start,
                end_time=slot_start + _TASK_DURATION,
                day_order=len(day_tasks),
                mode=task.mode,
                status=TaskStatus.PENDING,
                is_carried_over=True,
                parent_id=task.parent_id,
            )
        return None

    def _occupied(self, tasks: List[Task]) -> List[_Slot]:
        return [
            _Slot(t.start_time, t.end_time)
            for t in tasks if t.start_time and t.end_time
        ]

    def _free_slot(
        self,
        cursor: datetime,
        occupied: List[_Slot],
        day_end: datetime,
    ) -> Optional[datetime]:
        while cursor + _TASK_DURATION <= day_end:
            proposed = _Slot(cursor, cursor + _TASK_DURATION)
            conflicts = [s for s in occupied if s.overlaps(proposed)]
            if not conflicts:
                return cursor
            cursor = max(s.end for s in conflicts)
        return None
