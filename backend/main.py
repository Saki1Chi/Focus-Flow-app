from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from database import engine, Base, get_db
import models
from routers import tasks, categories


# ─── App lifecycle ────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


# ─── FastAPI instance ─────────────────────────────────────────────────────────

app = FastAPI(
    title="FocusFlow CMS",
    description="Content management system for the FocusFlow mobile app",
    version="1.0.0",
    lifespan=lifespan,
)

# Allow Flutter app (emulator and physical device) to call the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Routers ─────────────────────────────────────────────────────────────────

app.include_router(tasks.router, prefix="/api/tasks", tags=["Tasks"])
app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])


# ─── Stats endpoint ───────────────────────────────────────────────────────────

@app.get("/api/stats", tags=["Stats"])
def get_stats(db: Session = Depends(get_db)):
    total = db.query(models.Task).count()
    pending = db.query(models.Task).filter(models.Task.status == 0).count()
    in_progress = db.query(models.Task).filter(models.Task.status == 1).count()
    completed = db.query(models.Task).filter(models.Task.status == 2).count()
    category_count = db.query(models.Category).count()

    return {
        "total": total,
        "pending": pending,
        "in_progress": in_progress,
        "completed": completed,
        "categories": category_count,
    }


# ─── Admin panel ─────────────────────────────────────────────────────────────

_static_dir = Path(__file__).parent / "static"

app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")


@app.get("/", include_in_schema=False)
@app.get("/admin", include_in_schema=False)
def admin_panel():
    return FileResponse(str(_static_dir / "index.html"))


# ─── Entry point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
