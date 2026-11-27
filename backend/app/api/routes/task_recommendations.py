from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.authorization import require_permission
from app.dependencies import get_db
from app.schemas.task_recommendations import (
    TaskRecommendationRequest,
    TaskRecommendationsResponse,
)
from app.services.auth import AuthenticatedContext
from app.services.task_recommendations import suggest_tasks

router = APIRouter()


@router.post(
    "/{project_id}/task-recommendations",
    response_model=TaskRecommendationsResponse,
)
def recommend_project_tasks_route(
    project_id: str,
    payload: TaskRecommendationRequest,
    context: AuthenticatedContext = Depends(require_permission("projects.read")),
    db: Session = Depends(get_db),
) -> TaskRecommendationsResponse:
    return suggest_tasks(
        db,
        context=context,
        project_id=project_id,
        description=payload.description,
    )
