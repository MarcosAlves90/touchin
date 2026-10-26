from __future__ import annotations

import csv
import io
from collections.abc import Iterable, Iterator, Sequence
from datetime import datetime, timezone

CSV_COLUMNS = (
    "timestamp_utc",
    "actor_user_id",
    "action",
    "result",
    "entity_type",
    "entity_id",
    "project_id",
)

_CSV_LINE_TERMINATOR = "\r\n"
_FORMULA_PREFIXES = ("=", "+", "-", "@")
_CONTROL_FORMULA_PREFIXES = ("\t", "\r")


def _format_timestamp(value: object) -> str:
    if not isinstance(value, datetime):
        return "" if value is None else str(value)
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _neutralize_formula(value: str) -> str:
    stripped = value.lstrip(" ")
    if stripped.startswith(_FORMULA_PREFIXES) or stripped.startswith(
        _CONTROL_FORMULA_PREFIXES
    ):
        return "'" + value
    return value


def _format_cell(value: object, *, timestamp: bool = False) -> str:
    if value is None:
        return ""
    text = _format_timestamp(value) if timestamp else str(value)
    return _neutralize_formula(text)


def _csv_line(values: Sequence[str]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator=_CSV_LINE_TERMINATOR)
    writer.writerow(values)
    return buffer.getvalue()


def iter_audit_csv(rows: Iterable[Sequence[object]]) -> Iterator[str]:
    """Yield an UTF-8 BOM, a fixed header, and RFC 4180 encoded rows."""
    yield "\ufeff"
    yield _csv_line(CSV_COLUMNS)
    for row in rows:
        timestamp, actor_user_id, action, result, entity_type, entity_id, project_id = row
        yield _csv_line(
            (
                _format_cell(timestamp, timestamp=True),
                _format_cell(actor_user_id),
                _format_cell(action),
                _format_cell(result),
                _format_cell(entity_type),
                _format_cell(entity_id),
                _format_cell(project_id),
            )
        )
