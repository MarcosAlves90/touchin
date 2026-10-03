from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict


class AuditEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    timestamp: datetime
    company_id: str
    actor_user_id: str | None
    project_id: str | None
    action: str
    entity_type: str
    entity_id: str
    result: str
    metadata_payload: dict[str, Any] | None = None
    correlation_id: str | None
