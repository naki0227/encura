"""Gemini settings shared by the health check.

The app talks to Gemini only through the curator Edge Function; this module
just knows the REST endpoint, the configured model list (GEMINI_MODEL, comma
separated, tried in order) and how to read Google's error bodies.
"""
from __future__ import annotations

import json
import os

ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"
DEFAULT_MODELS = ["gemini-3.8-flash", "gemini-3.6-flash"]


def models_from_env() -> list[str]:
    raw = os.environ.get("GEMINI_MODEL", "").strip()
    models = [m.strip() for m in raw.split(",") if m.strip()]
    return models or list(DEFAULT_MODELS)


def error_message(body: str) -> str:
    """The human-readable part of a Google API error body."""
    try:
        return json.loads(body)["error"]["message"]
    except (ValueError, KeyError, TypeError):
        return body[:200]
