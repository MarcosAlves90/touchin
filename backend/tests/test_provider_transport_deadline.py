from __future__ import annotations

import socket

import pytest

from app.services import secure_provider


@pytest.mark.parametrize("phase", ["headers", "body"])
def test_provider_response_uses_remaining_deadline(monkeypatch, phase):
    now = 100.0
    monkeypatch.setattr(secure_provider.time, "monotonic", lambda: now)
    reader, peer = socket.socketpair()
    with reader, peer:
        reader.settimeout(2)
        peer.settimeout(2)
        deadline = secure_provider._Deadline()
        connection = secure_provider._PinnedHTTPSConnection(
            "provider.invalid", 443, socket.AF_INET, ("127.0.0.1", 443), deadline,
        )
        # Inject a connected test socket: exercise the actual HTTP reader without TLS or DNS.
        connection.sock = reader
        try:
            connection.request("GET", "/", headers={"Connection": "close"})
            assert peer.recv(4096).startswith(b"GET / HTTP/1.1\r\n")
            if phase == "headers":
                now += 7
            peer.sendall(b"HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\n")
            try:
                with connection.getresponse() as response:
                    assert response.status == 200
                    now += 7
                    peer.sendall(b"ok")
                    response.read()
            except TimeoutError:
                pass
            else:
                pytest.fail(f"provider response read ignored the elapsed deadline: {phase}")
        finally:
            connection.close()
