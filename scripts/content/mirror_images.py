#!/usr/bin/env python3
"""Copy every published image into our own Supabase Storage bucket.

The app first loads <SUPABASE_URL>/storage/v1/object/public/art-images/
<sha1 of image_url>.jpg and falls back to image_url itself, so it keeps
working when Wikimedia rate-limits it or a museum moves a file. This script
finds the images that have no copy yet, downloads each one politely (one at
a time, identified, with retries), resizes it to at most 1280 px on the long
side and uploads it as JPEG.

Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (the workflow reads the key
from the Management API at run time; it is never stored in the repository).

    python scripts/content/mirror_images.py [--limit N]
"""
from __future__ import annotations

import argparse
import hashlib
import io
import os
import sys
import time
from pathlib import Path

import requests
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.images import normalize_image_url  # noqa: E402
from common.web import USER_AGENT  # noqa: E402

BUCKET = "art-images"
MAX_SIDE = 1280
TABLES = ("artworks", "daily_columns", "trending_articles")
INTERVAL = 1.0


def object_name(image_url: str) -> str:
    """Same rule as the app (lib/core/utils/image_url.dart) and the widget."""
    return hashlib.sha1(image_url.encode("utf-8")).hexdigest() + ".jpg"


def resized_jpeg(data: bytes) -> bytes:
    image = Image.open(io.BytesIO(data))
    image = image.convert("RGB")
    image.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    out = io.BytesIO()
    image.save(out, "JPEG", quality=85, optimize=True, progressive=True)
    return out.getvalue()


class Storage:
    def __init__(self, base: str, key: str):
        self.base = base.rstrip("/")
        self.http = requests.Session()
        self.http.headers["apikey"] = key
        # Legacy service_role keys are JWTs and go in Authorization too; the
        # newer "sb_secret_" keys are sent as apikey only.
        if not key.startswith("sb_"):
            self.http.headers["Authorization"] = f"Bearer {key}"

    def image_urls(self) -> set[str]:
        urls = set()
        for table in TABLES:
            res = self.http.get(f"{self.base}/rest/v1/{table}", params={"select": "image_url"}, timeout=30)
            res.raise_for_status()
            urls.update(r["image_url"] for r in res.json() if r.get("image_url"))
        return urls

    def existing(self) -> set[str]:
        names, offset = set(), 0
        while True:
            res = self.http.post(f"{self.base}/storage/v1/object/list/{BUCKET}",
                                 json={"prefix": "", "limit": 1000, "offset": offset}, timeout=30)
            res.raise_for_status()
            page = res.json()
            names.update(o["name"] for o in page)
            if len(page) < 1000:
                return names
            offset += 1000

    def upload(self, name: str, body: bytes) -> None:
        res = self.http.post(f"{self.base}/storage/v1/object/{BUCKET}/{name}", data=body,
                             headers={"Content-Type": "image/jpeg", "x-upsert": "true",
                                      "Cache-Control": "max-age=31536000"}, timeout=60)
        res.raise_for_status()


def download(url: str, http: requests.Session) -> bytes | None:
    for attempt in range(4):
        try:
            res = http.get(normalize_image_url(url), headers={"User-Agent": USER_AGENT}, timeout=60)
        except requests.RequestException:
            time.sleep(5 * (attempt + 1))
            continue
        if res.status_code == 429 or res.status_code >= 500:
            wait = res.headers.get("Retry-After")
            time.sleep(float(wait) if wait and wait.isdigit() else 10 * (attempt + 1))
            continue
        if res.status_code == 200 and res.headers.get("content-type", "").startswith("image/"):
            return res.content
        return None
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=0, help="copy at most N images (0 = all)")
    args = parser.parse_args()
    storage = Storage(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"])
    have = storage.existing()
    todo = sorted(u for u in storage.image_urls() if object_name(u) not in have)
    if args.limit:
        todo = todo[:args.limit]
    print(f"{len(have)} copies exist; copying {len(todo)}")
    http, failed = requests.Session(), []
    for url in todo:
        time.sleep(INTERVAL)
        data = download(url, http)
        try:
            if data is None:
                raise ValueError("download failed")
            storage.upload(object_name(url), resized_jpeg(data))
            print(f"ok   {object_name(url)}  {url}")
        except (requests.RequestException, ValueError, OSError) as e:
            failed.append(url)
            print(f"FAIL {url}: {e}")
    print(f"\ncopied {len(todo) - len(failed)}, failed {len(failed)} (they are tried again next run)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
