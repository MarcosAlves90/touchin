from __future__ import annotations

import http.client
import ipaddress
import json
import math
import re
import socket
import ssl
import threading
from urllib.parse import urlsplit

MAX_REQUEST_BYTES = 48_000
MAX_RESPONSE_BYTES = 8_000_000
MAX_TEXTS = 81
MAX_DIMENSIONS = 4096
_TIMEOUT_SECONDS = 6
_REQUEST_SLOTS = threading.BoundedSemaphore(4)


class ProviderError(Exception):
    """A deliberately sanitized provider failure."""


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, host: str, port: int, family: int, sockaddr: tuple, timeout: int):
        super().__init__(host=host, port=port, timeout=timeout, context=ssl.create_default_context())
        self._pinned_family = family
        self._pinned_sockaddr = sockaddr

    def connect(self) -> None:
        sock = socket.socket(self._pinned_family, socket.SOCK_STREAM)
        try:
            sock.settimeout(self.timeout)
            sock.connect(self._pinned_sockaddr)
            self.sock = self._context.wrap_socket(sock, server_hostname=self.host)
        except Exception:
            sock.close()
            raise


def _endpoint(base_url: str) -> tuple[str, int, str]:
    if len(base_url) > 2048:
        raise ProviderError("Provider URL is invalid.")
    try:
        parsed = urlsplit(base_url.strip())
        port = parsed.port if parsed.port is not None else 443
    except ValueError:
        raise ProviderError("Provider URL is invalid.") from None
    host = parsed.hostname
    if (
        parsed.scheme.lower() != "https"
        or not host
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or port != 443
        or not re.fullmatch(r"[A-Za-z0-9.-]+", host)
        or any(part in {".", ".."} for part in parsed.path.split("/"))
    ):
        raise ProviderError("Provider URL must be an HTTPS URL on port 443 without credentials, query, or fragment.")
    path = parsed.path.rstrip("/")
    if not path:
        path = "/v1/embeddings"
    elif path.endswith("/v1"):
        path += "/embeddings"
    elif not path.endswith("/v1/embeddings"):
        path += "/v1/embeddings"
    if len(path) > 2048:
        raise ProviderError("Provider URL is invalid.")
    return host, port, path


def _public_addresses(host: str, port: int) -> list[tuple[int, tuple]]:
    try:
        resolved = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except (OSError, socket.gaierror):
        raise ProviderError("Provider host could not be resolved safely.") from None
    addresses: list[tuple[int, tuple]] = []
    seen: set[tuple[int, str]] = set()
    for family, _socktype, _proto, _canonname, sockaddr in resolved:
        address = sockaddr[0]
        try:
            parsed = ipaddress.ip_address(address)
        except ValueError:
            raise ProviderError("Provider host resolved to an invalid address.") from None
        if not parsed.is_global:
            raise ProviderError("Provider host resolves to a non-public network address.")
        key = (family, str(parsed))
        if key not in seen and family in {socket.AF_INET, socket.AF_INET6}:
            seen.add(key)
            addresses.append((family, sockaddr))
    if not addresses:
        raise ProviderError("Provider host has no public network address.")
    return addresses


def validate_provider_url_syntax(base_url: str) -> str:
    return _endpoint(base_url)[0]


def validate_provider_url(base_url: str) -> None:
    host, port, _path = _endpoint(base_url)
    _public_addresses(host, port)


def _parse_embeddings(response_bytes: bytes, expected_count: int) -> list[list[float]]:
    try:
        payload = json.loads(response_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise ProviderError("Provider returned an invalid response.") from None
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list) or len(data) != expected_count:
        raise ProviderError("Provider returned an invalid embedding response.")
    vectors: list[list[float] | None] = [None] * expected_count
    dimensions: int | None = None
    for item in data:
        if not isinstance(item, dict):
            raise ProviderError("Provider returned an invalid embedding response.")
        index = item.get("index")
        vector = item.get("embedding")
        if not isinstance(index, int) or isinstance(index, bool) or not 0 <= index < expected_count:
            raise ProviderError("Provider returned an invalid embedding response.")
        if vectors[index] is not None or not isinstance(vector, list) or not 1 <= len(vector) <= MAX_DIMENSIONS:
            raise ProviderError("Provider returned an invalid embedding response.")
        if dimensions is not None and len(vector) != dimensions:
            raise ProviderError("Provider returned inconsistent embedding dimensions.")
        dimensions = len(vector)
        normalized: list[float] = []
        for value in vector:
            if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value):
                raise ProviderError("Provider returned an invalid embedding vector.")
            normalized.append(float(value))
        vectors[index] = normalized
    if any(vector is None for vector in vectors):
        raise ProviderError("Provider returned an incomplete embedding response.")
    return [vector for vector in vectors if vector is not None]


def fetch_embeddings(base_url: str, model_id: str, api_key: str, texts: list[str]) -> list[list[float]]:
    if not api_key or len(api_key) > 512 or not model_id or len(model_id) > 200:
        raise ProviderError("Provider configuration is incomplete.")
    if not texts or len(texts) > MAX_TEXTS or any(not isinstance(text, str) or len(text) > 4096 for text in texts):
        raise ProviderError("Embedding request is outside the allowed limits.")
    host, port, path = _endpoint(base_url)
    addresses = _public_addresses(host, port)
    body = json.dumps({"model": model_id, "input": texts}, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(body) > MAX_REQUEST_BYTES:
        raise ProviderError("Embedding request is outside the allowed limits.")
    if not _REQUEST_SLOTS.acquire(blocking=False):
        raise ProviderError("Provider is busy.")
    connection: _PinnedHTTPSConnection | None = None
    try:
        family, sockaddr = addresses[0]
        connection = _PinnedHTTPSConnection(host, port, family, sockaddr, _TIMEOUT_SECONDS)
        connection.request(
            "POST",
            path,
            body=body,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "Connection": "close",
            },
        )
        response = connection.getresponse()
        if response.status < 200 or response.status >= 300:
            raise ProviderError("Embedding provider request failed.")
        raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise ProviderError("Embedding provider response exceeded the size limit.")
        return _parse_embeddings(raw, len(texts))
    except ProviderError:
        raise
    except (OSError, http.client.HTTPException, ssl.SSLError, TimeoutError):
        raise ProviderError("Embedding provider is unavailable.") from None
    finally:
        if connection is not None:
            connection.close()
        _REQUEST_SLOTS.release()
