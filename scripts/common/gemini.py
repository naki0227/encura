"""Minimal Gemini REST client.

Talks to the public REST API directly instead of an SDK: SDKs for Gemini have
been renamed and retired more than once, the REST endpoint has not.

Models are tried in order from GEMINI_MODEL (comma separated), so a retired
model falls through to the next one instead of stopping the crawler.
"""
from __future__ import annotations

import json
import os
import re
import time
from dataclasses import dataclass, field

import requests

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"
DEFAULT_MODELS = ["gemini-3.8-flash", "gemini-3.6-flash"]
TIMEOUT = 120


class GeminiError(RuntimeError):
    pass


@dataclass
class Source:
    uri: str
    title: str = ""


@dataclass
class Result:
    text: str
    model: str
    sources: list[Source] = field(default_factory=list)
    search_queries: list[str] = field(default_factory=list)


def models_from_env() -> list[str]:
    raw = os.environ.get("GEMINI_MODEL", "").strip()
    models = [m.strip() for m in raw.split(",") if m.strip()]
    return models or list(DEFAULT_MODELS)


def _api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        raise GeminiError("GEMINI_API_KEY is not set")
    return key


def error_message(body: str) -> str:
    """The human-readable part of a Google API error body."""
    try:
        return json.loads(body)["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return body[:200]


def _model_unavailable(status: int, body: str) -> bool:
    if status == 404:
        return True
    lowered = body.lower()
    return status == 400 and ("not found" in lowered or "not supported" in lowered)


def _parse(model: str, data: dict) -> Result:
    candidates = data.get("candidates") or []
    if not candidates:
        reason = (data.get("promptFeedback") or {}).get("blockReason", "no candidates")
        raise GeminiError(f"{model}: empty response ({reason})")
    candidate = candidates[0]
    parts = (candidate.get("content") or {}).get("parts") or []
    text = "".join(p.get("text", "") for p in parts if not p.get("thought")).strip()
    if not text:
        raise GeminiError(f"{model}: empty text (finishReason={candidate.get('finishReason')})")

    meta = candidate.get("groundingMetadata") or {}
    sources = []
    for chunk in meta.get("groundingChunks") or []:
        web = chunk.get("web") or {}
        if web.get("uri"):
            sources.append(Source(uri=web["uri"], title=web.get("title", "")))
    return Result(
        text=text,
        model=model,
        sources=sources,
        search_queries=list(meta.get("webSearchQueries") or []),
    )


def generate(
    prompt: str,
    *,
    search: bool = False,
    system: str | None = None,
    json_output: bool = False,
    models: list[str] | None = None,
    session: requests.Session | None = None,
) -> Result:
    """Run one prompt. `search=True` grounds the answer with Google Search."""
    http = session or requests.Session()
    payload: dict = {"contents": [{"role": "user", "parts": [{"text": prompt}]}]}
    if system:
        payload["system_instruction"] = {"parts": [{"text": system}]}
    if search:
        payload["tools"] = [{"google_search": {}}]
    elif json_output:
        # Structured output is only requested without tools; grounded answers
        # are parsed with extract_json instead.
        payload["generationConfig"] = {"responseMimeType": "application/json"}

    errors = []
    for model in models or models_from_env():
        for attempt in range(3):
            try:
                res = http.post(
                    f"{ENDPOINT}/{model}:generateContent",
                    headers={"x-goog-api-key": _api_key(), "Content-Type": "application/json"},
                    data=json.dumps(payload),
                    timeout=TIMEOUT,
                )
            except requests.RequestException as e:
                errors.append(f"{model}: {e}")
                time.sleep(2 ** attempt)
                continue
            if res.status_code == 200:
                return _parse(model, res.json())
            body = res.text[:500]
            if _model_unavailable(res.status_code, body):
                errors.append(f"{model}: unavailable ({res.status_code})")
                break  # next model
            if res.status_code in (429, 500, 502, 503, 504):
                errors.append(f"{model}: {res.status_code}")
                time.sleep(5 * (attempt + 1))
                continue
            # 400/401/403: bad key or bad request. Another model will not help.
            raise GeminiError(f"{model}: HTTP {res.status_code}: {error_message(res.text)}")
    raise GeminiError("all models failed: " + "; ".join(errors))


_FENCE = re.compile(r"```(?:json)?\s*(.*?)```", re.S)


def extract_json(text: str):
    """Pull the JSON value out of a model answer (fenced or bare)."""
    match = _FENCE.search(text)
    candidate = match.group(1) if match else text
    candidate = candidate.strip()
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        pass
    # Fall back to the outermost [...] or {...} in the text.
    for open_, close in (("[", "]"), ("{", "}")):
        start, end = candidate.find(open_), candidate.rfind(close)
        if start != -1 and end > start:
            try:
                return json.loads(candidate[start : end + 1])
            except json.JSONDecodeError:
                continue
    raise GeminiError(f"no JSON in model output: {text[:200]!r}")
