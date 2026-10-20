#!/usr/bin/env python3
"""Seed / repair the venues table (run by hand).

    python scripts/seed_venues.py [--dry-run]     add major museums
    python scripts/seed_venues.py --relocate      recompute every venue's
                                                  coordinates from its address

Coordinates always come from the GSI address search. Earlier versions stored
coordinates written by the model, which were often off by kilometres.
"""
from __future__ import annotations

import sys

from common import db, gemini, geo, web

SYSTEM = "あなたは美術館の情報を調べる編集者です。公式サイトで確認できた情報だけを答えます。"

PROMPT = """日本国内の主要な美術館・博物館を、地域が偏らないように 30 館挙げてください。
名称と住所は各館の公式サイトの表記どおりにします。
JSON 配列だけを出力してください。
[{"name": "館名", "address": "住所（都道府県から）", "website_url": "公式サイトの URL"}]"""


def relocate(client, dry_run: bool) -> int:
    venues = client.table("venues").select("id, name, address").execute().data
    failed = 0
    for venue in venues:
        coords = geo.geocode(venue.get("address") or "")
        if not coords:
            print(f"- no coordinates: {venue['name']} ({venue.get('address')})")
            failed += 1
            continue
        print(f"- {venue['name']}: {coords}")
        if not dry_run:
            location = geo.to_wkt(*coords)
            client.table("venues").update({"location": location}).eq("id", venue["id"]).execute()
            client.table("events").update({"location": location}).eq("venue_id", venue["id"]).execute()
    return 1 if failed else 0


def seed(client, dry_run: bool) -> int:
    result = gemini.generate(PROMPT, system=SYSTEM, search=True)
    items = gemini.extract_json(result.text)
    existing = [] if dry_run else client.table("venues").select("id, name").execute().data
    known = {web.normalize(v["name"]): v for v in existing}

    for item in items if isinstance(items, list) else []:
        name, address = str(item.get("name") or "").strip(), str(item.get("address") or "").strip()
        url = str(item.get("website_url") or "").strip()
        if not name or not address:
            continue
        page = web.fetch(url) if url else None
        if not page or not web.mentions(page[1], name):
            print(f"- skipped (official site does not confirm): {name}")
            continue
        coords = geo.geocode(address)
        data = {"name": name, "address": address, "website_url": page[0]}
        if coords:
            data["location"] = geo.to_wkt(*coords)
        match = known.get(web.normalize(name))
        print(f"- {'update' if match else 'insert'}: {name} {coords or '(no coordinates)'}")
        if dry_run:
            continue
        if match:
            client.table("venues").update(data).eq("id", match["id"]).execute()
        else:
            client.table("venues").insert(data).execute()
    return 0


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    if "--relocate" in sys.argv:
        return relocate(db.client(), dry_run)
    return seed(None if dry_run else db.client(), dry_run)


if __name__ == "__main__":
    sys.exit(main())
