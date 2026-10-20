#!/usr/bin/env python3
"""Today's Art (今日の一枚): keep the schedule filled ahead of time.

Fills every date from today to today + DAYS_AHEAD that has no entry yet.
An artwork is used only when its image is found on Wikidata/Commons for that
exact work by that artist; the text is written by Gemini with Google Search
grounding.

    python scripts/seed_daily_art.py [--dry-run]
"""
from __future__ import annotations

import datetime as dt
import sys

from common import db, gemini, images, web

DAYS_AHEAD = 14

SYSTEM = """あなたは美術館の学芸員です。作品の事実（作者、制作年、所蔵先、技法）は
Google 検索で確認し、確認できないことは書きません。"""

PROMPT = """「今日の一枚」として紹介する絵画・版画を {count} 点選んでください。
時代と地域（西洋、日本、東洋、近現代）が偏らないようにし、
作者の没後 70 年以上たっていて画像が自由に使える作品に限ります。
次の作品は既に紹介済みなので選ばないでください: {exclude}

各作品の content は、作品の背景と見どころを 200 字程度の日本語で書きます。
確認した事実だけを書き、所蔵先がわかれば含めます。

JSON 配列だけを出力してください。
[
  {{
    "title": "日本語の作品名",
    "title_en": "英語での作品名",
    "artist": "日本語の作者名",
    "artist_en": "英語での作者名",
    "content": "解説"
  }}
]"""


def missing_dates(existing: set[str], today: dt.date, days: int = DAYS_AHEAD) -> list[dt.date]:
    return [d for d in (today + dt.timedelta(n) for n in range(days + 1)) if d.isoformat() not in existing]


def valid_items(items, known_titles: set[str]) -> list[dict]:
    out = []
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict):
            continue
        if not all(str(item.get(k) or "").strip() for k in ("title", "artist", "content")):
            continue
        key = web.normalize(item["title"])
        if key in known_titles:
            continue
        known_titles.add(key)
        out.append(item)
    return out


def main(dry_run: bool = False) -> int:
    today = dt.date.today()
    client = None if dry_run else db.client()
    rows = [] if dry_run else client.table("daily_columns").select("title, display_date").execute().data
    dates = missing_dates({r["display_date"] for r in rows}, today)
    if not dates:
        print("Schedule is already filled.")
        return 0
    print(f"{len(dates)} dates to fill: {dates[0]} .. {dates[-1]}")

    known = {web.normalize(r["title"]) for r in rows}
    exclude = "、".join(r["title"] for r in rows[-200:]) or "なし"
    # Ask for extra candidates: some will have no verifiable image.
    result = gemini.generate(
        PROMPT.format(count=len(dates) * 2, exclude=exclude), system=SYSTEM, search=True,
    )
    candidates = valid_items(gemini.extract_json(result.text), known)
    print(f"Gemini ({result.model}) proposed {len(candidates)} new artworks.")

    filled = 0
    for item in candidates:
        if filled == len(dates):
            break
        image_url = images.find_artwork_image(
            [item.get("title_en", ""), item["title"]],
            [item.get("artist_en", ""), item["artist"]],
        )
        if not image_url:
            print(f"- skipped (no verified image): {item['title']} / {item['artist']}")
            continue
        date = dates[filled]
        data = {
            "title": item["title"],
            "artist": item["artist"],
            "image_url": image_url,
            "content": item["content"],
            "display_date": date.isoformat(),
        }
        print(f"- {date}: {item['title']} / {item['artist']}")
        if not dry_run:
            client.table("daily_columns").insert(data).execute()
        filled += 1

    print(f"Filled {filled} of {len(dates)} dates.")
    return 0 if filled else 1


if __name__ == "__main__":
    sys.exit(main(dry_run="--dry-run" in sys.argv))
