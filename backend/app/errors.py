from __future__ import annotations

from enum import Enum


class ErrorKind(str, Enum):
    bad_request = "bad_request"
    unauthorized = "unauthorized"
    forbidden = "forbidden"
    not_found = "not_found"
    conflict = "conflict"


class DomainError(Exception):
    def __init__(self, kind: ErrorKind, detail: str, *, code: str | None = None) -> None:
        super().__init__(detail)
        self.kind = kind
        self.detail = detail
        self.code = code
