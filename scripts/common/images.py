"""Find the image of a specific artwork through Wikidata.

The old crawlers took the first Wikimedia Commons search hit for a free-text
query, which often showed a different work. Here an image is accepted only
when a Wikidata item with that title is credited to the expected artist and
carries an image (P18). Commons only hosts freely licensed files.
"""
from __future__ import annotations

import re
import time

import requests

from .web import USER_AGENT, normalize

WIKIDATA_API = "https://www.wikidata.org/w/api.php"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
# Wikimedia only serves these thumbnail widths; others get an HTML 400/429
# page (https://www.mediawiki.org/wiki/Common_thumbnail_sizes).
THUMB_WIDTHS = (20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840)
THUMB_WIDTH = 960

_THUMB = re.compile(r"^(https://upload\.wikimedia\.org/wikipedia/[^?#]+/thumb/[^?#]+/)(\d+)px-([^/?#]+)")


def normalize_image_url(url: str) -> str:
    """Move a Wikimedia thumbnail URL to an allowed width (same rule as the app)."""
    url = (url or "").strip()
    match = _THUMB.match(url)
    if not match:
        return url
    width = int(match.group(2))
    if width in THUMB_WIDTHS:
        return url
    allowed = next((w for w in THUMB_WIDTHS if w >= width), THUMB_WIDTHS[-1])
    return f"{match.group(1)}{allowed}px-{match.group(3)}"


def image_status(url: str, session: requests.Session | None = None) -> str:
    """'ok', 'broken', or 'unknown' (rate limited / network trouble)."""
    if not url:
        return "broken"
    http = session or requests.Session()
    for attempt in range(3):
        try:
            res = http.get(url, headers={"User-Agent": USER_AGENT}, timeout=20, stream=True)
        except requests.RequestException:
            return "unknown"
        try:
            if res.status_code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            if res.status_code == 200 and res.headers.get("content-type", "").startswith("image/"):
                return "ok"
            return "broken"
        finally:
            res.close()
    return "unknown"


def _get(http: requests.Session, url: str, params: dict) -> dict:
    for attempt in range(4):
        res = http.get(url, params={**params, "format": "json"},
                       headers={"User-Agent": USER_AGENT}, timeout=20)
        if res.status_code == 429 or res.status_code >= 500:
            wait = res.headers.get("Retry-After")
            time.sleep(float(wait) if wait and wait.isdigit() else 5 * (attempt + 1))
            continue
        res.raise_for_status()
        return res.json()
    res.raise_for_status()
    return {}


def _labels(entity: dict) -> list[str]:
    values = [v.get("value", "") for v in (entity.get("labels") or {}).values()]
    for aliases in (entity.get("aliases") or {}).values():
        values.extend(a.get("value", "") for a in aliases)
    return [normalize(v) for v in values if v]


def _claim_values(entity: dict, prop: str) -> list:
    out = []
    for claim in (entity.get("claims") or {}).get(prop, []):
        value = ((claim.get("mainsnak") or {}).get("datavalue") or {}).get("value")
        if value is not None:
            out.append(value)
    return out


def _artist_matches(creator_labels: list[str], artists: list[str]) -> bool:
    wanted = [normalize(a) for a in artists if a]
    for label in creator_labels:
        for name in wanted:
            if name and (name in label or label in name):
                return True
    return False


def thumbnail_url(file_name: str, session: requests.Session | None = None) -> str | None:
    http = session or requests.Session()
    data = _get(http, COMMONS_API, {
        "action": "query", "titles": f"File:{file_name}",
        "prop": "imageinfo", "iiprop": "url|mime", "iiurlwidth": str(THUMB_WIDTH),
    })
    for page in (data.get("query") or {}).get("pages", {}).values():
        for info in page.get("imageinfo") or []:
            mime = info.get("mime", "")
            if mime in ("image/jpeg", "image/png", "image/webp"):
                url = info.get("thumburl") or info.get("url") or ""
                return url.split("?", 1)[0] or None  # drop tracking parameters
    return None


def find_artwork_image(
    titles: list[str],
    artists: list[str],
    session: requests.Session | None = None,
) -> str | None:
    """Image URL of the artwork named by any of `titles` by one of `artists`."""
    http = session or requests.Session()
    for title in [t for t in titles if t]:
        for language in ("en", "ja"):
            found = _get(http, WIKIDATA_API, {
                "action": "wbsearchentities", "search": title, "language": language,
                "uselang": language, "type": "item", "limit": "7",
            })
            ids = [hit["id"] for hit in found.get("search", [])]
            if not ids:
                continue
            entities = _get(http, WIKIDATA_API, {
                "action": "wbgetentities", "ids": "|".join(ids),
                "props": "claims|labels|aliases", "languages": "ja|en",
            }).get("entities", {})

            candidates = []
            creator_ids = set()
            for entity_id in ids:
                entity = entities.get(entity_id) or {}
                images = _claim_values(entity, "P18")
                creators = [v.get("id") for v in _claim_values(entity, "P170") if isinstance(v, dict)]
                if images and creators:
                    candidates.append((images[0], creators))
                    creator_ids.update(creators)
            if not candidates:
                continue

            creators = _get(http, WIKIDATA_API, {
                "action": "wbgetentities", "ids": "|".join(sorted(creator_ids)),
                "props": "labels|aliases", "languages": "ja|en",
            }).get("entities", {})
            for image, creator_list in candidates:
                labels = [l for c in creator_list for l in _labels(creators.get(c) or {})]
                if _artist_matches(labels, artists):
                    url = thumbnail_url(image, http)
                    if url:
                        return url
    return None
