from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.authorization import require_permission
from app.dependencies import get_db
from app.schemas.ai_settings import (
    AISettingsResponse,
    AISettingsUpdate,
    ProviderTestPayload,
    ProviderTestResponse,
)
from app.services.ai_settings import (
    get_company_settings,
    get_provider_configuration,
    save_settings,
    test_provider_connection,
)
from app.services.auth import AuthenticatedContext

router = APIRouter()
_manage = require_permission("companies.manage")


@router.get("/ai-settings", response_model=AISettingsResponse)
def get_ai_settings_route(
    context: AuthenticatedContext = Depends(_manage),
    db: Session = Depends(get_db),
) -> AISettingsResponse:
    return get_company_settings(db, context.company.id)


@router.put("/ai-settings", response_model=AISettingsResponse)
def update_ai_settings_route(
    payload: AISettingsUpdate,
    context: AuthenticatedContext = Depends(_manage),
    db: Session = Depends(get_db),
) -> AISettingsResponse:
    return save_settings(db, context=context, payload=payload)


@router.post("/ai-settings/test", response_model=ProviderTestResponse)
def test_ai_provider_route(
    payload: ProviderTestPayload,
    context: AuthenticatedContext = Depends(_manage),
    db: Session = Depends(get_db),
) -> ProviderTestResponse:
    success = test_provider_connection(
        db,
        company_id=context.company.id,
        provider_base_url=payload.provider_base_url,
        model_id=payload.model_id,
        api_key=payload.api_key,
    )
    return ProviderTestResponse(
        success=success,
        message="Conexão validada." if success else "Não foi possível validar a conexão. Verifique o provedor e tente novamente.",
    )
