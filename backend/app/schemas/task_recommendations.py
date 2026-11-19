from __future__ import annotations

from pydantic import Field

from app.schemas.base import CamelModel


class TaskRecommendationRequest(CamelModel):
    description: str = Field(max_length=1000)


class TaskRecommendation(CamelModel):
    task_id: str
    task_name: str


class TaskRecommendationsResponse(CamelModel):
    status: str
    recommendations: list[TaskRecommendation] = Field(default_factory=list)
