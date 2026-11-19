from __future__ import annotations

import argparse
import json
import math
import os
import re
import time
import unicodedata
from pathlib import Path

from sqlalchemy import select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.authorization import is_managerial_role
from app.config import get_settings
from app.crypto import FieldCipher
from app.db import begin_serialized_write, utcnow
from app.domain.project_read import project_or_404
from app.models import CompanyAISettings, Task
from app.schemas.task_recommendations import TaskRecommendation, TaskRecommendationsResponse
from app.services.ai_settings import get_provider_configuration
from app.services.auth import AuthenticatedContext
from app.services.secure_provider import ProviderError, fetch_embeddings

MAX_CANDIDATE_TASKS = 80
MAX_RECOMMENDATIONS = 3
MIN_COSINE_SIMILARITY = 0.25
_COMPANY_CALLS_PER_HOUR = 300
_ACTOR_CALLS_PER_HOUR = 30
_STOPWORDS = frozenset({
    "a", "ao", "as", "com", "da", "das", "de", "do", "dos", "e", "em", "na", "nas", "no", "nos", "o", "os", "para", "por", "que", "se", "um", "uma", "user", "the", "to", "and", "of", "in", "on"
})


def normalize_for_search(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    without_marks = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join(re.findall(r"[a-z0-9]+", without_marks))


def _tokens(value: str) -> set[str]:
    return {token for token in normalize_for_search(value).split() if token not in _STOPWORDS and len(token) > 1}


def lexical_similarity(query: str, candidate: str) -> float:
    query_tokens = _tokens(query)
    candidate_tokens = _tokens(candidate)
    if not query_tokens or not candidate_tokens:
        return 0.0
    return len(query_tokens & candidate_tokens) / len(query_tokens)


def cosine_similarity(left: list[float], right: list[float]) -> float:
    if len(left) != len(right) or not left:
        return -1.0
    dot = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        return -1.0
    return dot / (left_norm * right_norm)


def rank_semantic(query: str, candidates: list[dict[str, str]], vectors: list[list[float]]) -> list[dict[str, str]]:
    if len(vectors) != len(candidates) + 1:
        return []
    ranked: list[tuple[float, str, dict[str, str]]] = []
    for candidate, vector in zip(candidates, vectors[1:], strict=True):
        cosine = cosine_similarity(vectors[0], vector)
        lexical = lexical_similarity(query, candidate["text"])
        score = 0.85 * cosine + 0.15 * lexical
        if cosine >= MIN_COSINE_SIMILARITY or lexical >= 0.65:
            ranked.append((score, candidate["id"], candidate))
    ranked.sort(key=lambda row: (-row[0], row[1]))
    return [candidate for _score, _task_id, candidate in ranked[:MAX_RECOMMENDATIONS]]


def lexical_rank(query: str, candidates: list[dict[str, str]]) -> list[dict[str, str]]:
    ranked = [
        (lexical_similarity(query, item["text"]), item["id"], item)
        for item in candidates
    ]
    ranked = [row for row in ranked if row[0] >= 0.2]
    ranked.sort(key=lambda row: (-row[0], row[1]))
    return [item for _score, _task_id, item in ranked[:MAX_RECOMMENDATIONS]]


def _benchmark_metrics(
    cases: list[dict],
    ranked_by_case: list[list[dict[str, str]]],
    latencies_ms: list[float],
) -> dict[str, float | int]:
    top1_hits = 0
    top3_hits = 0
    false_suggestions = 0
    total_suggestions = 0
    for case, ranked in zip(cases, ranked_by_case, strict=True):
        relevant = set(case["relevant_ids"])
        top1_hits += bool(ranked and ranked[0]["id"] in relevant)
        top3_hits += any(item["id"] in relevant for item in ranked[:3])
        total_suggestions += len(ranked[:3])
        false_suggestions += sum(item["id"] not in relevant for item in ranked[:3])
    count = max(len(cases), 1)
    return {
        "cases": len(cases),
        "top1_recall": top1_hits / count,
        "top3_recall": top3_hits / count,
        "false_suggestion_rate": false_suggestions / max(total_suggestions, 1),
        "mean_latency_ms": round(sum(latencies_ms) / max(len(latencies_ms), 1), 2),
    }


def evaluate_fixture(
    *,
    provider_base_url: str | None = None,
    model_id: str | None = None,
    api_key: str | None = None,
) -> dict[str, dict[str, float | int]]:
    fixture_path = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "task_recommendation_evaluation.json"
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    cases = fixture["cases"]
    lexical_results: list[list[dict[str, str]]] = []
    lexical_latencies: list[float] = []
    semantic_results: list[list[dict[str, str]]] = []
    semantic_latencies: list[float] = []

    for case in cases:
        candidates = case["candidates"]
        started = time.perf_counter()
        lexical_results.append(lexical_rank(case["query"], candidates))
        lexical_latencies.append((time.perf_counter() - started) * 1000)
        if provider_base_url is not None:
            if not model_id or not api_key:
                raise ProviderError("Benchmark provider configuration is incomplete.")
            started = time.perf_counter()
            vectors = fetch_embeddings(
                provider_base_url,
                model_id,
                api_key,
                [case["query"], *(item["text"] for item in candidates)],
            )
            semantic_results.append(rank_semantic(case["query"], candidates, vectors))
            semantic_latencies.append((time.perf_counter() - started) * 1000)

    report = {"lexical_baseline": _benchmark_metrics(cases, lexical_results, lexical_latencies)}
    if provider_base_url is not None:
        report["semantic_provider"] = _benchmark_metrics(cases, semantic_results, semantic_latencies)
    return report


def _run_benchmark_cli() -> None:
    parser = argparse.ArgumentParser(description="Evaluate task recommendation ranking on synthetic examples.")
    parser.add_argument("--provider-url", help="HTTPS OpenAI-compatible embeddings base URL.")
    parser.add_argument("--model", help="Embedding model identifier.")
    args = parser.parse_args()
    key = os.environ.get("TOUCHIN_TASK_RECOMMENDATIONS_API_KEY") if args.provider_url else None
    try:
        result = evaluate_fixture(
            provider_base_url=args.provider_url,
            model_id=args.model,
            api_key=key,
        )
    except ProviderError:
        raise SystemExit("Evaluation stopped: provider unavailable or returned an invalid response.") from None
    print(json.dumps(result, ensure_ascii=False, indent=2))


def _result(status: str, items: list[dict[str, str]] | None = None) -> TaskRecommendationsResponse:
    return TaskRecommendationsResponse(
        status=status,
        recommendations=[
            TaskRecommendation(task_id=item["id"], task_name=item["name"])
            for item in (items or [])
        ],
    )


def _reserve_provider_call(db: Session, company_id: str, actor_id: str, revision: int) -> bool:
    try:
        begin_serialized_write(db)
        hour = int(utcnow().timestamp()) // 3600
        for scope, limit in (("company", _COMPANY_CALLS_PER_HOUR), (f"actor:{actor_id}", _ACTOR_CALLS_PER_HOUR)):
            updated = db.execute(
                text("""
                    INSERT INTO task_recommendation_quotas (company_id, scope, bucket_hour, attempts)
                    VALUES (:company_id, :scope, :hour, 1)
                    ON CONFLICT (company_id, scope) DO UPDATE SET
                        bucket_hour = excluded.bucket_hour,
                        attempts = CASE WHEN task_recommendation_quotas.bucket_hour < excluded.bucket_hour
                            THEN 1 ELSE task_recommendation_quotas.attempts + 1 END
                    WHERE task_recommendation_quotas.bucket_hour < excluded.bucket_hour
                        OR (task_recommendation_quotas.bucket_hour = excluded.bucket_hour
                            AND task_recommendation_quotas.attempts < :limit)
                """),
                {"company_id": company_id, "scope": scope, "hour": hour, "limit": limit},
            )
            if updated.rowcount != 1:
                db.rollback()
                return False
        # Don't spend quota or contact the provider with a configuration already replaced.
        current = db.scalar(select(CompanyAISettings.revision).where(
            CompanyAISettings.company_id == company_id, CompanyAISettings.enabled.is_(True),
        ))
        if current != revision:
            db.rollback()
            return False
        db.commit()
        return True
    except SQLAlchemyError:
        db.rollback()
        return False


def suggest_tasks(
    db: Session,
    *,
    context: AuthenticatedContext,
    project_id: str,
    description: str,
) -> TaskRecommendationsResponse:
    employee_id = None
    if not is_managerial_role(context.user.role):
        if context.employee is None:
            from fastapi import HTTPException, status

            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Employee profile is required.")
        employee_id = context.employee.id
    project_or_404(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=employee_id,
    )

    query = description.strip()
    if len(_tokens(query)) < 2:
        return _result("no_match")

    settings_row, api_key = get_provider_configuration(db, context.company.id)
    if settings_row is None or not settings_row.enabled or not api_key:
        return _result("disabled")

    expected_revision = settings_row.revision
    provider_url, model_id = settings_row.provider_base_url, settings_row.model_id
    tasks = db.scalars(
        select(Task)
        .where(Task.project_id == project_id)
        .order_by(Task.id.asc())
        .limit(MAX_CANDIDATE_TASKS)
    ).all()
    if not tasks:
        return _result("no_match")

    secret = get_settings().encryption_secret
    if not secret:
        return _result("unavailable")
    cipher = FieldCipher(secret)
    candidates = []
    for task in tasks:
        name = cipher.decrypt(task.name_ciphertext) or ""
        number_text = f"Tarefa {task.card_number}. " if task.card_number is not None else ""
        text = f"{number_text}{name}. {cipher.decrypt(task.description_ciphertext) or ''}"[:350]
        candidates.append({"id": task.id, "name": name, "text": text})

    if not _reserve_provider_call(db, context.company.id, context.user.id, expected_revision):
        return _result("unavailable")

    try:
        vectors = fetch_embeddings(
            provider_url,
            model_id,
            api_key,
            [query[:1000], *(candidate["text"] for candidate in candidates)],
        )
        ranked = rank_semantic(query, candidates, vectors)
    except ProviderError:
        return _result("unavailable")

    db.rollback()
    latest = db.scalar(
        select(CompanyAISettings).where(CompanyAISettings.company_id == context.company.id)
    )
    if latest is None or not latest.enabled or latest.revision != expected_revision:
        return _result("disabled")
    return _result("available" if ranked else "no_match", ranked)


if __name__ == "__main__":
    _run_benchmark_cli()
