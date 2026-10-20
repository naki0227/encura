#!/usr/bin/env python3
"""Repair stored image URLs (run by hand after restoring Supabase).

    python scripts/fix_image_urls.py            report only
    python scripts/fix_image_urls.py --apply    write the fixes

For every image in daily_columns and trending_articles:
1. Wikimedia thumbnails stored with a width Wikimedia no longer serves
   (640px, 800px, ...) are moved to an allowed width.
2. The URL is fetched; if it still does not return an image, the artwork's
   image is looked up again on Wikidata (Today's Art), or the image is
   cleared so the app shows its placeholder instead of an error.
"""
from __future__ import annotations

import sys

from common import db, images

TABLES = {
    # table: columns to select
    "daily_columns": "id, title, artist, image_url",
    "trending_articles": "id, title, image_url",
}


def repair(row: dict, table: str, check=images.image_status, lookup=images.find_artwork_image) -> str | None:
    """New image_url for the row, or None when it is fine as it is."""
    current = row.get("image_url") or ""
    if not current:
        return None
    candidate = images.normalize_image_url(current)
    status = check(candidate)
    if status == "unknown":
        return None  # could not tell; leave it for the next run
    if status == "ok":
        return candidate if candidate != current else None
    if table == "daily_columns" and row.get("artist"):
        found = lookup([row["title"]], [row["artist"]])
        if found:
            return found
    return ""


def main() -> int:
    apply = "--apply" in sys.argv
    client = db.client()
    changed = cleared = 0
    for table, columns in TABLES.items():
        rows = client.table(table).select(columns).execute().data
        print(f"{table}: {len(rows)} rows")
        for row in rows:
            new = repair(row, table)
            if new is None:
                continue
            if new:
                changed += 1
                print(f"  fix   {row['title']}: {row['image_url']} -> {new}")
            else:
                cleared += 1
                print(f"  clear {row['title']}: {row['image_url']}")
            if apply:
                client.table(table).update({"image_url": new}).eq("id", row["id"]).execute()
    print(f"{changed} fixed, {cleared} cleared" + ("" if apply else " (dry run; add --apply to write)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
