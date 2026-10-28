from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Request, status
from sqlalchemy.orm import Session

from app.authorization import require_permission
from app.dependencies import get_current_context, get_db
from app.schemas.auth import (
    AuthContextResponse,
    AuthSessionResponse,
    CompanyRegisterRequest,
    LoginRequest,
    PasswordChangeRequest,
    PasswordResetRequest,
    PasswordResetConfirmRequest,
)
from app.schemas.base import MessageResponse
from app.services.auth import (
    AuthenticatedContext,
    change_password,
    get_auth_context,
    login,
    logout,
    register_company,
)
from app.services import auth as auth_service
from app.services.password_reset import confirm_password_reset, request_password_reset
from app.services.brevo import send_password_changed_email, send_password_reset_email


router = APIRouter()


@router.post(
    "/register-company",
    response_model=AuthSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_company_route(
    payload: CompanyRegisterRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> AuthSessionResponse:
    response = register_company(db, payload, send_welcome_email=False)
    background_tasks.add_task(
        auth_service.send_company_welcome_email,
        recipient_email=str(payload.email).strip(),
        company_name=payload.company_name,
        trade_name=payload.trade_name,
    )
    return response


@router.post("/login", response_model=AuthSessionResponse)
def login_route(
    payload: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> AuthSessionResponse:
    return login(
        db,
        payload,
        client_ip=request.client.host if request.client else "unknown",
    )


@router.post("/reset-password", response_model=MessageResponse)
def reset_password_route(
    payload: PasswordResetRequest,
    background_tasks: BackgroundTasks,
    request: Request,
    db: Session = Depends(get_db),
) -> MessageResponse:
    email_job = request_password_reset(
        db,
        email=str(payload.email).strip(),
        client_ip=request.client.host if request.client else "unknown",
    )
    if email_job is not None:
        recipient_email, display_name, token = email_job
        background_tasks.add_task(
            send_password_reset_email,
            recipient_email=recipient_email,
            display_name=display_name,
            token=token,
        )
    return MessageResponse(message="If the email is registered, password reset instructions will be sent.")


@router.post("/reset-password/confirm", response_model=MessageResponse)
def confirm_password_reset_route(
    payload: PasswordResetConfirmRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> MessageResponse:
    confirm_password_reset(
        db,
        token=payload.token,
        new_password=payload.new_password,
        client_ip=request.client.host if request.client else "unknown",
    )
    return MessageResponse(message="Password updated successfully.")


@router.post("/change-password", response_model=MessageResponse)
def change_password_route(
    payload: PasswordChangeRequest,
    background_tasks: BackgroundTasks,
    context: AuthenticatedContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> MessageResponse:
    recipient_email, display_name = change_password(
        db,
        context=context,
        current_password=payload.current_password,
        new_password=payload.new_password,
    )
    background_tasks.add_task(
        send_password_changed_email,
        recipient_email=recipient_email,
        display_name=display_name,
    )
    return MessageResponse(message="Password updated successfully.")


@router.get("/me", response_model=AuthContextResponse)
def me_route(
    context: AuthenticatedContext = Depends(require_permission("auth.read_context")),
) -> AuthContextResponse:
    return get_auth_context(context)


@router.post("/logout", response_model=MessageResponse)
def logout_route(
    context: AuthenticatedContext = Depends(get_current_context),
    db: Session = Depends(get_db),
) -> MessageResponse:
    logout(db, context)
    return MessageResponse(message="Session revoked successfully.")
