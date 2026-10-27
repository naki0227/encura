#!/usr/bin/env python3
"""Backfill image licenses and credits for rows published before they were stored.

Reads the published rows through the public REST API, then for each image:

  * artworks held by a museum that publishes CC0 images (the Met, the Art
    Institute of Chicago, the Cleveland Museum of Art) switch to the museum's
    image when the museum names the same work by the same artist;
  * Commons images get their license and credit from the file page;
  * images whose license is unknown or not allowed (not public domain, CC0,
    CC BY or CC BY-SA) are listed for a person to decide; nothing is removed.

Writes supabase/migrations/<UTC timestamp>_image_credits.sql (UPDATEs keyed by
image_url, so the same file works on any copy of the database) and prints a
report. Needs SUPABASE_URL and SUPABASE_ANON_KEY.

    python scripts/content/image_credits.py [--out-dir DIR]
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import museums  # noqa: E402
from common.image_info import ImageInfo, commons_info, is_allowed  # noqa: E402
from content import sql  # noqa: E402

def rows(table: str, columns: str) -> list[dict]:
    url = os.environ["SUPABASE_URL"].rstrip("/") + f"/rest/v1/{table}"
    key = os.environ["SUPABASE_ANON_KEY"]
    res = requests.get(url, params={"select": columns}, headers={"apikey": key, "Authorization": f"Bearer {key}"},
                       timeout=30)
    res.raise_for_status()
    return res.json()


def update(table: str, old_url: str, info: ImageInfo) -> str:
    move = f"image_url = {sql.text(info.url)},\n    " if info.url != old_url else ""
    return (f"update public.{table} set\n    {move}image_license = {sql.text(info.license or None)},\n"
            f"    image_credit = {sql.text(info.credit or None)},\n    image_page = {sql.text(info.page or None)}\n"
            f"where image_url = {sql.text(old_url)};")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(Path(__file__).resolve().parents[2] / "supabase" / "migrations"))
    args = parser.parse_args()

    statements, report, undecided = [], [], []
    seen: dict[str, ImageInfo | None] = {}

    def describe(url: str) -> ImageInfo | None:
        if url not in seen:
            seen[url] = commons_info(url)
        return seen[url]

    # image_license is not read: this runs before the column exists in
    # production, and re-describing a credited image changes nothing.
    for art in rows("artworks", "title,title_en,artist,artist_en,collection,image_url"):
        url = art.get("image_url") or ""
        if not url:
            continue
        label = f"{art['title']} / {art['artist']}"
        info = museums.find(art.get("title_en") or "", art.get("artist_en") or "", art.get("collection"))
        if info:
            report.append(f"- artwork: {label} — museum image ({info.credit})")
        if not info:
            info = describe(url)
            if info:
                report.append(f"- artwork: {label} — {info.license}{' / ' + info.credit if info.credit else ''}")
        if not info or not is_allowed(info.license):
            undecided.append(f"- artwork: {label} — {info.license if info else 'license unknown'} ({url})")
            continue
        statements.append(update("artworks", url, info))

    for table in ("daily_columns", "trending_articles"):
        for row in rows(table, "title,image_url"):
            url = row.get("image_url") or ""
            if not url:
                continue
            info = describe(url)
            if not info or not is_allowed(info.license):
                undecided.append(f"- {table}: {row['title']} — {info.license if info else 'license unknown'} ({url})")
                continue
            report.append(f"- {table}: {row['title']} — {info.license}{' / ' + info.credit if info.credit else ''}")
            statements.append(update(table, url, info))

    print(f"### Credited ({len(report)})")
    print("\n".join(report))
    print(f"\n### Needs a decision ({len(undecided)})")
    print("\n".join(undecided) or "(none)")
    if not statements:
        print("\nNothing to write.")
        return 0
    now = dt.datetime.now(dt.timezone.utc)
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{now:%Y%m%d%H%M%S}_image_credits.sql"
    header = ["-- Image licenses and credits for rows published before they were stored,",
              "-- written by scripts/content/image_credits.py. Keyed by image_url.", ""]
    path.write_text("\n".join(header) + "\n\n".join(statements) + "\n", encoding="utf-8")
    print(f"\nWrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
