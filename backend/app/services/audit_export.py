from __future__ import annotations

import csv
import io
from collections.abc import Iterable, Sequence
from datetime import datetime, timezone
from typing import BinaryIO

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
_CONTROL_FORMULA_PREFIXES = ("\t", "\r", "\n")


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


_CSV_PREAMBLE = "\ufeff" + _csv_line(CSV_COLUMNS)


class AuditCsvTooLarge(Exception):
    def __init__(self, *, row_count: int, byte_count: int, max_bytes: int) -> None:
        self.row_count = row_count
        self.byte_count = byte_count
        self.max_bytes = max_bytes
        super().__init__("Audit CSV exceeds its configured byte limit")


def _csv_data_row(row: Sequence[object]) -> str:
    timestamp, actor_user_id, action, result, entity_type, entity_id, project_id = row
    return _csv_line(
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


def write_audit_csv(
    rows: Iterable[Sequence[object]],
    target: BinaryIO,
    *,
    max_bytes: int | None = None,
) -> int:
    """Write the CSV and return the number of data rows materialized.

    The count comes from the exact rows written to ``target`` so callers do not
    need a second, racy database count to label an export.

    When ``max_bytes`` is supplied, continue counting matching rows after the
    limit is crossed but stop writing to the spool. The caller can then return
    an exact count without buffering or sending an oversized CSV.
    """
    preamble = _CSV_PREAMBLE.encode("utf-8")
    target.write(preamble)
    row_count = 0
    byte_count = len(preamble)
    exceeded = max_bytes is not None and byte_count > max_bytes
    for row in rows:
        encoded = _csv_data_row(row).encode("utf-8")
        byte_count += len(encoded)
        row_count += 1
        if not exceeded and (max_bytes is None or byte_count <= max_bytes):
            target.write(encoded)
        elif max_bytes is not None:
            exceeded = True
    if exceeded and max_bytes is not None:
        raise AuditCsvTooLarge(
            row_count=row_count,
            byte_count=byte_count,
            max_bytes=max_bytes,
        )
    return row_count
