from __future__ import annotations

import logging
from html import escape

import httpx

from app.config import Settings, get_settings


logger = logging.getLogger(__name__)

BREVO_SMTP_EMAIL_URL = "https://api.brevo.com/v3/smtp/email"
BREVO_TIMEOUT_SECONDS = 10.0
JSON_MEDIA_TYPE = "application/json"


def _is_brevo_enabled(settings: Settings) -> bool:
    return bool(
        settings.brevo_welcome_enabled
        and settings.brevo_api_key
        and settings.brevo_sender_email
    )


def _welcome_subject() -> str:
    return "Confirmação de cadastro — TouchIn"


def _welcome_text(display_name: str, recipient_email: str) -> str:
    return (
        f"Prezado(a) {display_name},\n\n"
        "Seu cadastro na plataforma TouchIn foi concluído com sucesso.\n"
        f"Você poderá acessar sua conta utilizando o endereço de e-mail: {recipient_email}.\n\n"
        "Caso não reconheça esta ação, por favor responda a esta mensagem ou entre em contato com nossa equipe de suporte.\n\n"
        "Atenciosamente,\n"
        "Equipe TouchIn\n"
    )


def _welcome_html(display_name: str, recipient_email: str) -> str:
    safe_display_name = escape(display_name)
    safe_email = escape(recipient_email)
    return (
        f"<p>Prezado(a) {safe_display_name},</p>"
        "<p>Seu cadastro na plataforma <strong>TouchIn</strong> foi concluído com sucesso.</p>"
        "<p>Você poderá acessar sua conta utilizando o endereço de e-mail: "
        f"<strong>{safe_email}</strong>.</p>"
        "<p>Caso não reconheça esta ação, por favor responda a esta mensagem ou entre em contato com nossa equipe de suporte.</p>"
        "<p>Atenciosamente,<br>Equipe TouchIn</p>"
    )


def _credentials_subject() -> str:
    return "Credenciais de acesso — TouchIn"


def _credentials_text(display_name: str, recipient_email: str, temp_password: str) -> str:
    return (
        f"Prezado(a) {display_name},\n\n"
        "Sua conta na plataforma TouchIn foi criada.\n"
        f"E-mail de acesso: {recipient_email}\n"
        f"Senha temporária: {temp_password}\n\n"
        "Por segurança, altere sua senha após o primeiro acesso.\n\n"
        "Atenciosamente,\n"
        "Equipe TouchIn\n"
    )


def _credentials_html(display_name: str, recipient_email: str, temp_password: str) -> str:
    safe_display_name = escape(display_name)
    safe_email = escape(recipient_email)
    safe_password = escape(temp_password)
    return (
        f"<p>Prezado(a) {safe_display_name},</p>"
        "<p>Sua conta na plataforma <strong>TouchIn</strong> foi criada.</p>"
        "<p>E-mail de acesso: "
        f"<strong>{safe_email}</strong><br>"
        f"Senha temporária: <strong>{safe_password}</strong></p>"
        "<p>Por segurança, altere sua senha após o primeiro acesso.</p>"
        "<p>Atenciosamente,<br>Equipe TouchIn</p>"
    )


def _password_reset_subject() -> str:
    return "Redefinição de senha — TouchIn"


def _password_reset_text(display_name: str, recipient_email: str, temp_password: str) -> str:
    return (
        f"Prezado(a) {display_name},\n\n"
        "Recebemos uma solicitação para redefinir sua senha.\n"
        f"E-mail de acesso: {recipient_email}\n"
        f"Senha temporária: {temp_password}\n\n"
        "Por segurança, altere sua senha após o primeiro acesso.\n\n"
        "Atenciosamente,\n"
        "Equipe TouchIn\n"
    )


def _password_reset_html(display_name: str, recipient_email: str, temp_password: str) -> str:
    safe_display_name = escape(display_name)
    safe_email = escape(recipient_email)
    safe_password = escape(temp_password)
    return (
        f"<p>Prezado(a) {safe_display_name},</p>"
        "<p>Recebemos uma solicitação para redefinir sua senha.</p>"
        "<p>E-mail de acesso: "
        f"<strong>{safe_email}</strong><br>"
        f"Senha temporária: <strong>{safe_password}</strong></p>"
        "<p>Por segurança, altere sua senha após o primeiro acesso.</p>"
        "<p>Atenciosamente,<br>Equipe TouchIn</p>"
    )


def _password_changed_subject() -> str:
    return "Senha atualizada — TouchIn"


def _password_changed_text(display_name: str, recipient_email: str) -> str:
    return (
        f"Prezado(a) {display_name},\n\n"
        "Sua senha foi atualizada com sucesso.\n"
        f"E-mail de acesso: {recipient_email}\n\n"
        "Se você não realizou esta alteração, entre em contato com nossa equipe de suporte.\n\n"
        "Atenciosamente,\n"
        "Equipe TouchIn\n"
    )


def _password_changed_html(display_name: str, recipient_email: str) -> str:
    safe_display_name = escape(display_name)
    safe_email = escape(recipient_email)
    return (
        f"<p>Prezado(a) {safe_display_name},</p>"
        "<p>Sua senha foi atualizada com sucesso.</p>"
        "<p>E-mail de acesso: "
        f"<strong>{safe_email}</strong>.</p>"
        "<p>Se você não realizou esta alteração, entre em contato com nossa equipe de suporte.</p>"
        "<p>Atenciosamente,<br>Equipe TouchIn</p>"
    )


def send_employee_credentials_email(
    *,
    recipient_email: str,
    employee_name: str,
    temp_password: str,
) -> None:
    settings = get_settings()
    if not _is_brevo_enabled(settings):
        return

    display_name = employee_name.strip() or recipient_email.strip()
    payload = {
        "sender": {
            "email": settings.brevo_sender_email,
            "name": settings.brevo_sender_name,
        },
        "to": [{"email": recipient_email.strip(), "name": display_name}],
        "subject": _credentials_subject(),
        "textContent": _credentials_text(display_name, recipient_email.strip(), temp_password),
        "htmlContent": _credentials_html(display_name, recipient_email.strip(), temp_password),
    }
    headers = {
        "accept": JSON_MEDIA_TYPE,
        "api-key": settings.brevo_api_key or "",
        "content-type": JSON_MEDIA_TYPE,
    }

    try:
        response = httpx.post(
            BREVO_SMTP_EMAIL_URL,
            json=payload,
            headers=headers,
            timeout=BREVO_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else "n/a"
        logger.warning(
            "Brevo credentials email failed without blocking employee creation. status=%s",
            status_code,
        )


def send_password_reset_email(
    *,
    recipient_email: str,
    display_name: str,
    temp_password: str,
) -> None:
    settings = get_settings()
    if not _is_brevo_enabled(settings):
        return

    payload = {
        "sender": {
            "email": settings.brevo_sender_email,
            "name": settings.brevo_sender_name,
        },
        "to": [{"email": recipient_email.strip(), "name": display_name.strip()}],
        "subject": _password_reset_subject(),
        "textContent": _password_reset_text(display_name, recipient_email.strip(), temp_password),
        "htmlContent": _password_reset_html(display_name, recipient_email.strip(), temp_password),
    }
    headers = {
        "accept": JSON_MEDIA_TYPE,
        "api-key": settings.brevo_api_key or "",
        "content-type": JSON_MEDIA_TYPE,
    }

    try:
        response = httpx.post(
            BREVO_SMTP_EMAIL_URL,
            json=payload,
            headers=headers,
            timeout=BREVO_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else "n/a"
        logger.warning(
            "Brevo password reset email failed without blocking reset. status=%s",
            status_code,
        )


def send_password_changed_email(
    *,
    recipient_email: str,
    display_name: str,
) -> None:
    settings = get_settings()
    if not _is_brevo_enabled(settings):
        return

    payload = {
        "sender": {
            "email": settings.brevo_sender_email,
            "name": settings.brevo_sender_name,
        },
        "to": [{"email": recipient_email.strip(), "name": display_name.strip()}],
        "subject": _password_changed_subject(),
        "textContent": _password_changed_text(display_name, recipient_email.strip()),
        "htmlContent": _password_changed_html(display_name, recipient_email.strip()),
    }
    headers = {
        "accept": JSON_MEDIA_TYPE,
        "api-key": settings.brevo_api_key or "",
        "content-type": JSON_MEDIA_TYPE,
    }

    try:
        response = httpx.post(
            BREVO_SMTP_EMAIL_URL,
            json=payload,
            headers=headers,
            timeout=BREVO_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else "n/a"
        logger.warning(
            "Brevo password change email failed without blocking change. status=%s",
            status_code,
        )


def send_company_welcome_email(
    *,
    recipient_email: str,
    company_name: str,
    trade_name: str,
) -> None:
    settings = get_settings()
    if not _is_brevo_enabled(settings):
        return

    display_name = trade_name.strip() or company_name.strip()
    payload = {
        "sender": {
            "email": settings.brevo_sender_email,
            "name": settings.brevo_sender_name,
        },
        "to": [{"email": recipient_email.strip(), "name": display_name}],
        "subject": _welcome_subject(),
        "textContent": _welcome_text(display_name, recipient_email.strip()),
        "htmlContent": _welcome_html(display_name, recipient_email.strip()),
    }
    headers = {
        "accept": JSON_MEDIA_TYPE,
        "api-key": settings.brevo_api_key or "",
        "content-type": JSON_MEDIA_TYPE,
    }

    try:
        response = httpx.post(
            BREVO_SMTP_EMAIL_URL,
            json=payload,
            headers=headers,
            timeout=BREVO_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else "n/a"
        logger.warning(
            "Brevo welcome email failed without blocking registration. status=%s",
            status_code,
        )
