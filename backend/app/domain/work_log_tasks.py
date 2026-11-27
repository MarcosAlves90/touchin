from __future__ import annotations

import json

from cryptography.fernet import InvalidToken

from app.crypto import FieldCipher
from app.schemas.punch import PunchTaskResponse


def read_task_snapshots(
    ciphertext: str | None, *, cipher: FieldCipher,
) -> list[PunchTaskResponse] | None:
    """Read both the original name-only snapshots and structured snapshots."""
    if not ciphertext:
        return None
    try:
        values = json.loads(cipher.decrypt(ciphertext) or "null")
    except (InvalidToken, UnicodeError, ValueError):
        return None
    if not isinstance(values, list):
        return None
    snapshots = []
    for value in values:
        item = {"name": value} if isinstance(value, str) else value
        if not isinstance(item, dict) or not isinstance(item.get("name"), str):
            continue
        name = item["name"].strip()
        if not name:
            continue
        task_id = item.get("id")
        number = item.get("cardNumber")
        snapshots.append(PunchTaskResponse(
            name=name,
            id=task_id if isinstance(task_id, str) and task_id.strip() else None,
            card_number=number if type(number) is int and number > 0 else None,
        ))
    return snapshots
