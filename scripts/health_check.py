#!/usr/bin/env python3
"""Liveness check for everything EnCura depends on.

Run daily from GitHub Actions (.github/workflows/health_check.yml) and by hand:

    python scripts/health_check.py

Checks are skipped when their settings are missing, and the run fails when any
check fails. Results go to stdout and, in Actions, to the job summary.

Environment:
  GEMINI_API_KEY, GEMINI_MODEL     Gemini key and model list (same values as the
                                   curator Edge Function); only lists models,
                                   which costs nothing
  SUPABASE_URL, SUPABASE_ANON_KEY  Supabase REST and the curator Edge Function
"""
from __future__ import annotations

import datetime as dt
import os
import sys
from dataclasses import dataclass
from typing import Callable

import requests

from common import gemini, images

OK, WARN, FAIL, SKIP = "OK", "WARN", "FAIL", "SKIP"
TIMEOUT = 60


@dataclass
class Check:
    name: str
    status: str
    detail: str


def named(label: str):
    """Label used when the check itself crashes."""
    def wrap(fn):
        fn.label = label
        return fn
    return wrap


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


# --- Gemini -----------------------------------------------------------------

@named('Gemini: key and models')
def check_gemini_models(http: requests.Session) -> Check:
    """Key is valid, and at least one configured model is still served."""
    name = check_gemini_models.label
    if not env("GEMINI_API_KEY"):
        return Check(name, SKIP, "GEMINI_API_KEY not set")
    res = http.get(f"{gemini.ENDPOINT}?pageSize=1000",
                   headers={"x-goog-api-key": env("GEMINI_API_KEY")}, timeout=TIMEOUT)
    if res.status_code != 200:
        return Check(name, FAIL, f"HTTP {res.status_code}: {gemini.error_message(res.text)}")
    served = {m["name"].removeprefix("models/") for m in res.json().get("models", [])}
    wanted = gemini.models_from_env()
    present = [m for m in wanted if m in served]
    if not present:
        newest = sorted(m for m in served if m.startswith("gemini-") and "flash" in m)[-5:]
        return Check(name, FAIL, f"none of {wanted} are served. Flash models now: {newest}")
    if present[0] != wanted[0]:
        return Check(name, WARN, f"{wanted[0]} is gone; falling back to {present[0]}. Update GEMINI_MODEL.")
    return Check(name, OK, f"{', '.join(present)} available")


# --- Supabase ---------------------------------------------------------------

def _supabase_headers() -> dict:
    # The apikey header alone is enough for both the legacy anon key (a JWT)
    # and the newer publishable key (sb_publishable_..., not a JWT, so it must
    # not be sent as a Bearer token).
    return {"apikey": env("SUPABASE_ANON_KEY")}


def _today_jst() -> dt.date:
    """Content dates are Japan dates (the routine, the migrations and the app use them)."""
    return dt.datetime.now(dt.timezone(dt.timedelta(hours=9))).date()


@named('Supabase: database and content')
def check_supabase_content(http: requests.Session) -> Check:
    """Project is up, and the content the app shows is current."""
    name = check_supabase_content.label
    if not (env("SUPABASE_URL") and env("SUPABASE_ANON_KEY")):
        return Check(name, SKIP, "SUPABASE_URL / SUPABASE_ANON_KEY not set")
    base = env("SUPABASE_URL").rstrip("/") + "/rest/v1"
    today = _today_jst().isoformat()
    try:
        daily = http.get(f"{base}/daily_columns", params={"select": "display_date", "display_date": f"eq.{today}"},
                         headers=_supabase_headers(), timeout=TIMEOUT)
    except requests.RequestException as e:
        return Check(name, FAIL, f"unreachable (project paused?): {e}")
    if daily.status_code != 200:
        return Check(name, FAIL, f"HTTP {daily.status_code} (project paused or key changed?): {daily.text[:150]}")

    problems = []
    if not daily.json():
        problems.append("no Today's Art for today")
    events = http.get(f"{base}/events", params={"select": "id", "end_date": f"gte.{today}", "limit": "1"},
                      headers=_supabase_headers(), timeout=TIMEOUT)
    if events.status_code == 200 and not events.json():
        problems.append("no current exhibitions")
    week_ago = (_today_jst() - dt.timedelta(days=7)).isoformat()
    news = http.get(f"{base}/trending_articles",
                    params={"select": "id", "created_at": f"gte.{week_ago}", "limit": "1"},
                    headers=_supabase_headers(), timeout=TIMEOUT)
    if news.status_code == 200 and not news.json():
        problems.append("no news in the last 7 days")
    if problems:
        return Check(name, WARN, "; ".join(problems) + " (check the daily content routine and DB Migrations runs)")
    return Check(name, OK, "reachable, content is current")


@named('Supabase: content images')
def check_content_images(http: requests.Session) -> Check:
    """Images the app is showing now actually load (as stored, for old app versions too)."""
    name = check_content_images.label
    if not (env("SUPABASE_URL") and env("SUPABASE_ANON_KEY")):
        return Check(name, SKIP, "SUPABASE_URL / SUPABASE_ANON_KEY not set")
    base = env("SUPABASE_URL").rstrip("/") + "/rest/v1"
    today = _today_jst().isoformat()
    queries = [
        ("daily_columns", {"select": "title,image_url", "display_date": f"lte.{today}",
                           "order": "display_date.desc", "limit": "7"}),
        ("trending_articles", {"select": "title,image_url", "is_published": "eq.true",
                               "order": "created_at.desc", "limit": "10"}),
    ]
    broken, checked = [], 0
    for table, params in queries:
        res = http.get(f"{base}/{table}", params=params, headers=_supabase_headers(), timeout=TIMEOUT)
        if res.status_code != 200:
            return Check(name, FAIL, f"{table}: HTTP {res.status_code}")
        for row in res.json():
            if not row.get("image_url"):
                continue
            checked += 1
            if images.image_status(row["image_url"], http) == "broken":
                broken.append(row["title"])
    if broken:
        return Check(name, WARN, f"{len(broken)}/{checked} images do not load: {', '.join(broken[:5])} "
                                 "(the source file may have moved; fix the row with a migration)")
    return Check(name, OK, f"{checked} images load")


@named('Edge Function: curator')
def check_curator_function(http: requests.Session) -> Check:
    """End to end, the way the app does it: anonymous sign-in, then the function."""
    name = check_curator_function.label
    if not (env("SUPABASE_URL") and env("SUPABASE_ANON_KEY")):
        return Check(name, SKIP, "SUPABASE_URL / SUPABASE_ANON_KEY not set")
    base = env("SUPABASE_URL").rstrip("/")
    try:
        auth = http.post(f"{base}/auth/v1/signup", json={}, headers=_supabase_headers(), timeout=TIMEOUT)
    except requests.RequestException as e:
        return Check(name, FAIL, f"auth unreachable: {e}")
    token = auth.json().get("access_token") if auth.status_code == 200 else None
    if not token:
        return Check(name, FAIL, f"anonymous sign-in failed: HTTP {auth.status_code} {auth.text[:150]}")
    res = http.post(f"{base}/functions/v1/curator",
                    json={"task": "chat", "message": "「睡蓮」で知られる画家は誰ですか？一言で。"},
                    headers={**_supabase_headers(), "Authorization": f"Bearer {token}"},
                    timeout=TIMEOUT)
    if res.status_code != 200:
        return Check(name, FAIL, f"HTTP {res.status_code}: {res.text[:150]} (see function logs)")
    text = (res.json() or {}).get("text", "")
    if not text:
        return Check(name, FAIL, "empty answer")
    return Check(name, OK, f"answered ({len(text)} chars)")


CHECKS: list[Callable[[requests.Session], Check]] = [
    check_gemini_models,
    check_supabase_content,
    check_content_images,
    check_curator_function,
]


def run(checks=CHECKS, http: requests.Session | None = None) -> list[Check]:
    http = http or requests.Session()
    results = []
    for check in checks:
        try:
            results.append(check(http))
        except Exception as e:  # a crashing check is a failed check
            label = getattr(check, "label", check.__name__)
            results.append(Check(label, FAIL, f"{type(e).__name__}: {e}"))
    return results


def report(results: list[Check]) -> str:
    icon = {OK: "✅", WARN: "⚠️", FAIL: "❌", SKIP: "⏭️"}
    lines = ["| | Check | Detail |", "| :- | :- | :- |"]
    for r in results:
        detail = r.detail.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {icon[r.status]} | {r.name} | {detail} |")
    return "\n".join(lines)


def main() -> int:
    results = run()
    table = report(results)
    print(table)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## EnCura health check\n\n" + table + "\n")
    return 1 if any(r.status == FAIL for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
