from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import utcnow
from app.models import CompanyAISettings
from app.schemas.ai_settings import AISettingsResponse, AISettingsUpdate
from app.services.audit import AuditService
from app.services.auth import AuthenticatedContext
from app.services.secure_provider import (
    ProviderError,
    fetch_embeddings,
    validate_provider_url,
    validate_provider_url_syntax,
)


def _row(db: Session, company_id: str) -> CompanyAISettings | None:
    return db.scalar(
        select(CompanyAISettings).where(CompanyAISettings.company_id == company_id)
    )


def _cipher() -> FieldCipher:
    secret = get_settings().encryption_secret
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Server-side credential encryption is unavailable.",
        )
    return FieldCipher(secret)


def serialize_settings(row: CompanyAISettings | None) -> AISettingsResponse:
    if row is None:
        return AISettingsResponse()
    return AISettingsResponse(
        enabled=row.enabled,
        provider_base_url=row.provider_base_url,
        model_id=row.model_id,
        api_key_configured=bool(row.api_key_ciphertext),
        privacy_acknowledged=row.privacy_acknowledged_at is not None,
        updated_at=row.updated_at.isoformat() if row.updated_at else None,
    )


def get_company_settings(db: Session, company_id: str) -> AISettingsResponse:
    return serialize_settings(_row(db, company_id))


def get_provider_configuration(
    db: Session, company_id: str
) -> tuple[CompanyAISettings | None, str | None]:
    row = _row(db, company_id)
    if row is None or not row.api_key_ciphertext:
        return row, None
    try:
        key = _cipher().decrypt(row.api_key_ciphertext)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Stored provider credentials are unavailable.",
        ) from None
    return row, key


def save_settings(
    db: Session,
    *,
    context: AuthenticatedContext,
    payload: AISettingsUpdate,
) -> AISettingsResponse:
    row = _row(db, context.company.id)
    if row is None:
        row = CompanyAISettings(company_id=context.company.id)
        db.add(row)
        db.flush()

    key_was_configured = bool(row.api_key_ciphertext)
    if payload.api_key:
        credential_action = "rotated" if key_was_configured else "set"
    elif payload.remove_api_key:
        credential_action = "removed" if key_was_configured else "not_configured"
    else:
        credential_action = "retained"

    try:
        provider_host = validate_provider_url_syntax(payload.provider_base_url)
        if payload.enabled:
            validate_provider_url(payload.provider_base_url)
    except ProviderError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from None

    if payload.api_key:
        row.api_key_ciphertext = _cipher().encrypt(payload.api_key)
    elif payload.remove_api_key:
        row.api_key_ciphertext = None
        row.enabled = False

    if payload.enabled:
        if not payload.privacy_acknowledged:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Acknowledge provider data sharing before enabling recommendations.",
            )
        encrypted_key = row.api_key_ciphertext
        if not encrypted_key:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Configure an API key before enabling recommendations.",
            )
        decrypted_key = _cipher().decrypt(encrypted_key)
        if not decrypted_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Stored provider credentials are unavailable.",
            )
        try:
            fetch_embeddings(
                payload.provider_base_url,
                payload.model_id,
                decrypted_key,
                ["TouchIn provider enablement verification; no employee or task data is included."],
            )
        except ProviderError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Could not verify the provider configuration. Check the URL, model, and API key.",
            ) from None
        row.privacy_acknowledged_at = utcnow()

    row.provider_base_url = payload.provider_base_url
    row.model_id = payload.model_id
    row.enabled = payload.enabled and not payload.remove_api_key
    row.revision += 1
    row.updated_at = utcnow()

    AuditService.log_action(
        db,
        company_id=context.company.id,
        action="company.ai_task_recommendations.settings_updated",
        entity_type="company_ai_settings",
        entity_id=context.company.id,
        actor_user_id=context.user.id,
        metadata={
            "enabled": row.enabled,
            "provider_host": provider_host,
            "model_id": payload.model_id[:200],
            "credential_configured": bool(row.api_key_ciphertext),
            "credential_action": credential_action,
        },
    )
    db.commit()
    db.refresh(row)
    return serialize_settings(row)


def test_provider_connection(
    db: Session,
    *,
    company_id: str,
    provider_base_url: str,
    model_id: str,
    api_key: str | None,
) -> bool:
    key = api_key
    if not key:
        _stored_row, key = get_provider_configuration(db, company_id)
    if not key:
        return False
    try:
        fetch_embeddings(
            provider_base_url,
            model_id,
            key,
            ["TouchIn provider connection test; no employee or task data is included."],
        )
    except ProviderError:
        return False
    return True
