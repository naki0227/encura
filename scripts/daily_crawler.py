#!/usr/bin/env python3
"""Exhibition crawler (daily).

Finds art exhibitions in Japan with Gemini + Google Search, and stores only
the ones whose official page actually names the exhibition. Venues get their
coordinates from the GSI address search, not from the model.

    python scripts/daily_crawler.py [--dry-run]
"""
from __future__ import annotations

import datetime as dt
import sys
from dataclasses import dataclass

from common import db, gemini, geo, web

LOOKAHEAD_DAYS = 45
MAX_EVENT_DAYS = 400

SYSTEM = """あなたは日本の美術展の情報を調べる編集者です。
必ず Google 検索で公式情報を確認し、確認できたものだけを答えます。
記憶や推測で展覧会・会期・会場を作ってはいけません。"""

PROMPT = """今日は {today} です。日本国内で、今日開催中、または今日から {days} 日以内に始まる
美術展・博物館の企画展を、地域が偏らないように最大 15 件調べてください。

条件:
- 美術館・博物館などの公式サイトで、展覧会名と会期を確認できたものだけ
- 会期の終了日が {today} 以降
- official_url は主催館の公式ページの URL（ニュースサイトやまとめサイトは不可）
- summary は公式情報に書かれている内容だけで 100 字程度にまとめる

JSON 配列だけを出力してください。
[
  {{
    "title": "展覧会名（公式表記どおり）",
    "venue": "会場名（公式表記どおり）",
    "venue_address": "会場の住所（都道府県から）",
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD",
    "official_url": "https://...",
    "summary": "概要"
  }}
]"""


@dataclass
class Candidate:
    title: str
    venue: str
    venue_address: str
    start_date: dt.date
    end_date: dt.date
    official_url: str
    summary: str


def _date(value) -> dt.date | None:
    try:
        return dt.date.fromisoformat(str(value).strip())
    except ValueError:
        return None


def parse_candidates(items, today: dt.date) -> list[Candidate]:
    """Keep well-formed, current entries; drop everything else."""
    out = []
    if not isinstance(items, list):
        return out
    for item in items:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or "").strip()
        venue = str(item.get("venue") or "").strip()
        start, end = _date(item.get("start_date")), _date(item.get("end_date"))
        if not title or not venue or not start or not end:
            continue
        if end < today or start > end or (end - start).days > MAX_EVENT_DAYS:
            continue
        if start > today + dt.timedelta(days=LOOKAHEAD_DAYS):
            continue
        out.append(Candidate(
            title=title,
            venue=venue,
            venue_address=str(item.get("venue_address") or "").strip(),
            start_date=start,
            end_date=end,
            official_url=str(item.get("official_url") or "").strip(),
            summary=str(item.get("summary") or "").strip(),
        ))
    return out


def match_venue(name: str, venues: list[dict]) -> dict | None:
    key = web.normalize(name)
    for venue in venues:
        if web.normalize(venue.get("name") or "") == key:
            return venue
    return None


def ensure_venue(client, cand: Candidate, venues: list[dict], dry_run: bool) -> dict:
    venue = match_venue(cand.venue, venues)
    coords = None
    if venue is None or not venue.get("location"):
        coords = geo.geocode(cand.venue_address) if cand.venue_address else None

    if venue is None:
        data = {"name": cand.venue, "address": cand.venue_address or None}
        if coords:
            data["location"] = geo.to_wkt(*coords)
        print(f"  new venue: {cand.venue} ({'located' if coords else 'no location'})")
        if dry_run:
            venue = {"id": None, **data}
        else:
            venue = client.table("venues").insert(data).execute().data[0]
        venues.append(venue)
    elif coords and not venue.get("location"):
        print(f"  adding location to venue: {cand.venue}")
        if not dry_run:
            client.table("venues").update({"location": geo.to_wkt(*coords)}).eq("id", venue["id"]).execute()
        venue["location"] = geo.to_wkt(*coords)
    return venue


def upsert_event(client, cand: Candidate, source_url: str, venue: dict, dry_run: bool) -> None:
    data = {
        "title": cand.title,
        "venue": cand.venue,
        "venue_id": venue.get("id"),
        "start_date": cand.start_date.isoformat(),
        "end_date": cand.end_date.isoformat(),
        "description_json": {"summary": cand.summary},
        "source_url": source_url,
    }
    if venue.get("location"):
        data["location"] = venue["location"]

    existing = []
    if not dry_run and venue.get("id"):
        existing = client.table("events").select("id, title").eq("venue_id", venue["id"]).execute().data
    key = web.normalize(cand.title)
    match = next((e for e in existing if web.normalize(e["title"]) == key), None)

    print(f"  {'update' if match else 'insert'}: {cand.title} ({cand.start_date} - {cand.end_date})")
    if dry_run:
        return
    if match:
        client.table("events").update(data).eq("id", match["id"]).execute()
    else:
        client.table("events").insert(data).execute()


def main(dry_run: bool = False) -> int:
    today = dt.date.today()
    client = None if dry_run else db.client()

    result = gemini.generate(
        PROMPT.format(today=today.isoformat(), days=LOOKAHEAD_DAYS),
        system=SYSTEM,
        search=True,
    )
    print(f"Gemini ({result.model}) used {len(result.sources)} web sources.")
    candidates = parse_candidates(gemini.extract_json(result.text), today)
    print(f"{len(candidates)} well-formed candidates.")

    source_urls = [s.uri for s in result.sources]
    venues = [] if dry_run else client.table("venues").select("id, name, location").execute().data

    stored = 0
    for cand in candidates:
        print(f"- {cand.title} @ {cand.venue}")
        # The exhibition must be named on its official page, or failing that,
        # on one of the pages the search actually used.
        verified = web.find_page_mentioning(cand.title, [cand.official_url] + source_urls)
        if not verified:
            print("  skipped: no page confirms this exhibition")
            continue
        try:
            venue = ensure_venue(client, cand, venues, dry_run)
            upsert_event(client, cand, verified, venue, dry_run)
            stored += 1
        except Exception as e:  # keep going; one bad row should not drop the rest
            print(f"  error: {e}")

    print(f"Stored {stored} verified exhibitions.")
    # A run that stores nothing is a failure worth seeing in Actions.
    return 0 if stored else 1


if __name__ == "__main__":
    sys.exit(main(dry_run="--dry-run" in sys.argv))
