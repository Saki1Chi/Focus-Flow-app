from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


# ─── Category ─────────────────────────────────────────────────────────────────

class CategoryBase(BaseModel):
    name: str
    color: str = "#4A90E2"
    icon: str = "label"


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None


class CategoryResponse(CategoryBase):
    id: int
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ─── Task ─────────────────────────────────────────────────────────────────────

class TaskBase(BaseModel):
    title: str
    description: str = ""
    date: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    status: int = 0
    mode: int = 0
    category_id: Optional[int] = None
    recurrence: Optional[str] = None
    is_carried_over: bool = False
    day_order: int = 0
    parent_id: Optional[str] = None
    is_recurring_parent: bool = False


class TaskCreate(TaskBase):
    id: str  # UUID provided by client or admin panel


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    date: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    status: Optional[int] = None
    mode: Optional[int] = None
    category_id: Optional[int] = None
    recurrence: Optional[str] = None
    is_carried_over: Optional[bool] = None
    day_order: Optional[int] = None
    is_recurring_parent: Optional[bool] = None


class TaskResponse(TaskBase):
    id: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ─── Stats ────────────────────────────────────────────────────────────────────

class StatsResponse(BaseModel):
    total: int
    pending: int
    in_progress: int
    completed: int
    categories: int


# ─── Bulk sync ────────────────────────────────────────────────────────────────

class BulkSyncResult(BaseModel):
    created: int
    updated: int
