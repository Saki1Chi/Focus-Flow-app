"""
Modelos de datos para FocusGuard v2.
Task, BlockSession, RecurrenceRule con serialización JSON completa.
"""
from __future__ import annotations

import uuid
from calendar import monthrange
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import IntEnum
from typing import List, Optional


# ── Enums ──────────────────────────────────────────────────────────────────────

class TaskStatus(IntEnum):
    PENDING     = 0
    IN_PROGRESS = 1
    COMPLETED   = 2


class TaskMode(IntEnum):
    CALENDAR = 0
    SMART    = 1


class RepeatType(IntEnum):
    DAILY   = 0
    WEEKLY  = 1
    MONTHLY = 2
    YEARLY  = 3


class EndType(IntEnum):
    NEVER              = 0
    AFTER_OCCURRENCES  = 1
    ON_DATE            = 2


# ── Helpers ────────────────────────────────────────────────────────────────────

def _add_months(dt: datetime, months: int) -> datetime:
    m = dt.month - 1 + months
    year = dt.year + m // 12
    month = m % 12 + 1
    day = min(dt.day, monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


# ── RecurrenceRule ─────────────────────────────────────────────────────────────

@dataclass
class RecurrenceRule:
    repeat_type: RepeatType        = RepeatType.DAILY
    interval:    int               = 1
    skip_days:   List[int]         = field(default_factory=list)  # 0=Mon … 6=Sun
    end_type:    EndType           = EndType.NEVER
    occurrences: Optional[int]     = None
    end_date:    Optional[datetime]= None

    def next_occurrence(self, from_date: datetime) -> Optional[datetime]:
        date = from_date
        for _ in range(366):
            if self.repeat_type == RepeatType.DAILY:
                date = date + timedelta(days=self.interval)
            elif self.repeat_type == RepeatType.WEEKLY:
                date = date + timedelta(weeks=self.interval)
            elif self.repeat_type == RepeatType.MONTHLY:
                date = _add_months(date, self.interval)
            else:  # YEARLY
                date = _add_months(date, self.interval * 12)

            if self.end_type == EndType.ON_DATE and self.end_date and date > self.end_date:
                return None
            if date.weekday() in self.skip_days:
                continue
            return date
        return None

    def to_dict(self) -> dict:
        return {
            "repeat_type": int(self.repeat_type),
            "interval":    self.interval,
            "skip_days":   list(self.skip_days),
            "end_type":    int(self.end_type),
            "occurrences": self.occurrences,
            "end_date":    self.end_date.isoformat() if self.end_date else None,
        }

    @classmethod
    def from_dict(cls, d: dict) -> RecurrenceRule:
        return cls(
            repeat_type=RepeatType(d.get("repeat_type", 0)),
            interval=d.get("interval", 1),
            skip_days=d.get("skip_days", []),
            end_type=EndType(d.get("end_type", 0)),
            occurrences=d.get("occurrences"),
            end_date=datetime.fromisoformat(d["end_date"]) if d.get("end_date") else None,
        )


# ── Task ───────────────────────────────────────────────────────────────────────

@dataclass
class Task:
    id:                  str                     = field(default_factory=lambda: str(uuid.uuid4()))
    title:               str                     = ""
    description:         str                     = ""
    date:                datetime                = field(default_factory=datetime.now)
    start_time:          Optional[datetime]      = None
    end_time:            Optional[datetime]      = None
    status:              TaskStatus              = TaskStatus.PENDING
    mode:                TaskMode                = TaskMode.CALENDAR
    recurrence:          Optional[RecurrenceRule]= None
    is_carried_over:     bool                   = False
    day_order:           int                    = 0
    parent_id:           Optional[str]          = None
    is_recurring_parent: bool                   = False

    @property
    def is_overdue(self) -> bool:
        if self.status == TaskStatus.COMPLETED:
            return False
        if self.end_time is None:
            return False
        return datetime.now() > self.end_time

    @property
    def is_starting_soon(self) -> bool:
        if self.start_time is None:
            return False
        diff = (self.start_time - datetime.now()).total_seconds() / 60
        return 0 <= diff <= 15

    def copy_with(self, **kwargs) -> Task:
        d = self.to_dict()
        d.update(kwargs)
        return Task.from_dict(d)

    def to_dict(self) -> dict:
        return {
            "id":                  self.id,
            "title":               self.title,
            "description":         self.description,
            "date":                self.date.isoformat(),
            "start_time":          self.start_time.isoformat() if self.start_time else None,
            "end_time":            self.end_time.isoformat() if self.end_time else None,
            "status":              int(self.status),
            "mode":                int(self.mode),
            "recurrence":          self.recurrence.to_dict() if self.recurrence else None,
            "is_carried_over":     self.is_carried_over,
            "day_order":           self.day_order,
            "parent_id":           self.parent_id,
            "is_recurring_parent": self.is_recurring_parent,
        }

    @classmethod
    def from_dict(cls, d: dict) -> Task:
        return cls(
            id=d["id"],
            title=d.get("title", ""),
            description=d.get("description", ""),
            date=datetime.fromisoformat(d["date"]),
            start_time=datetime.fromisoformat(d["start_time"]) if d.get("start_time") else None,
            end_time=datetime.fromisoformat(d["end_time"])   if d.get("end_time")   else None,
            status=TaskStatus(d.get("status", 0)),
            mode=TaskMode(d.get("mode", 0)),
            recurrence=RecurrenceRule.from_dict(d["recurrence"]) if d.get("recurrence") else None,
            is_carried_over=d.get("is_carried_over", False),
            day_order=d.get("day_order", 0),
            parent_id=d.get("parent_id"),
            is_recurring_parent=d.get("is_recurring_parent", False),
        )


# ── BlockSession ───────────────────────────────────────────────────────────────

@dataclass
class BlockSession:
    id:          str      = field(default_factory=lambda: str(uuid.uuid4()))
    unlocked_at: datetime = field(default_factory=datetime.now)
    expires_at:  datetime = field(default_factory=datetime.now)
    is_active:   bool     = True

    @property
    def is_expired(self) -> bool:
        return datetime.now() > self.expires_at

    @property
    def remaining_seconds(self) -> int:
        return max(0, int((self.expires_at - datetime.now()).total_seconds()))

    def to_dict(self) -> dict:
        return {
            "id":          self.id,
            "unlocked_at": self.unlocked_at.isoformat(),
            "expires_at":  self.expires_at.isoformat(),
            "is_active":   self.is_active,
        }

    @classmethod
    def from_dict(cls, d: dict) -> BlockSession:
        return cls(
            id=d["id"],
            unlocked_at=datetime.fromisoformat(d["unlocked_at"]),
            expires_at=datetime.fromisoformat(d["expires_at"]),
            is_active=d.get("is_active", True),
        )
