from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.config import get_settings
from app.bootstrap import lifespan
from app.errors import DomainError, ErrorKind


ERROR_STATUS_CODES = {
    ErrorKind.bad_request: 400,
    ErrorKind.unauthorized: 401,
    ErrorKind.forbidden: 403,
    ErrorKind.not_found: 404,
    ErrorKind.conflict: 409,
    ErrorKind.too_many_requests: 429,
}

def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["Content-Disposition", "X-Audit-Export-Rows"],
    )

    @app.exception_handler(DomainError)
    async def domain_error_handler(request: Request, exc: DomainError):
        return JSONResponse(
            status_code=ERROR_STATUS_CODES[exc.kind],
            content={"detail": exc.detail, **({"code": exc.code} if exc.code else {})},
        )

    @app.middleware("http")
    async def https_guard(request: Request, call_next):
        if not settings.enforce_https:
            return await call_next(request)

        forwarded_proto = request.headers.get("x-forwarded-proto", "")
        is_secure = request.url.scheme == "https" or forwarded_proto == "https"
        is_localhost = request.url.hostname in {"127.0.0.1", "localhost"}
        if not is_secure and not is_localhost:
            return JSONResponse(
                status_code=400,
                content={
                    "detail": (
                        "HTTPS is required for non-local requests because this API "
                        "handles personal and location data."
                    ),
                },
            )
        return await call_next(request)

    app.include_router(api_router)
    return app


app = create_app()
