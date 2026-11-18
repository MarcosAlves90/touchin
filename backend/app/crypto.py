from __future__ import annotations

import base64
import hashlib
import hmac
import json
from typing import Any

from cryptography.fernet import Fernet


class FieldCipher:
    def __init__(self, secret: str) -> None:
        key = base64.urlsafe_b64encode(hashlib.sha256(secret.encode("utf-8")).digest())
        self._fernet = Fernet(key)

    def encrypt(self, value: str | None) -> str | None:
        if value is None:
            return None
        payload = value.encode("utf-8")
        return self._fernet.encrypt(payload).decode("utf-8")

    def decrypt(self, value: str | None) -> str | None:
        if value is None:
            return None
        return self._fernet.decrypt(value.encode("utf-8")).decode("utf-8")

    def encrypt_json(self, value: dict[str, Any] | None) -> str | None:
        if value is None:
            return None
        return self.encrypt(json.dumps(value, separators=(",", ":")))

    def decrypt_json(self, value: str | None) -> dict[str, Any] | None:
        raw_value = self.decrypt(value)
        if raw_value is None:
            return None
        return json.loads(raw_value)


def lookup_digest(value: str, secret: str) -> str:
    """Return a keyed deterministic lookup digest; never use it for passwords."""
    return hmac.new(
        secret.encode("utf-8"),
        # codeql[py/weak-sensitive-data-hashing] Passwords use PBKDF2; this keyed HMAC indexes normalized data and high-entropy tokens.
        value.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
