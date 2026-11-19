from __future__ import annotations

from app.services import secure_provider


def test_full_embeddings_endpoint_path_is_used_as_given() -> None:
    endpoint = "/client/v4/accounts/example/ai/v1/embeddings"
    _host, _port, path = secure_provider._endpoint(
        f"https://provider.example{endpoint}"
    )

    assert path == endpoint, "FULL_EMBEDDINGS_ENDPOINT_PATH_MUST_BE_PRESERVED"
