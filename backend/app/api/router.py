from fastapi import APIRouter

from app.api.routes import admin, auth, employees, health, kanban, projects, tasks, time_clock


_PROJECTS_PREFIX = "/projects"


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(employees.router, prefix="/employees", tags=["employees"])
api_router.include_router(projects.router, prefix=_PROJECTS_PREFIX, tags=["projects"])
api_router.include_router(tasks.router, prefix=_PROJECTS_PREFIX, tags=["tasks"])
api_router.include_router(kanban.router, prefix=_PROJECTS_PREFIX, tags=["kanban"])
api_router.include_router(time_clock.router, prefix="/time-clock", tags=["time-clock"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
