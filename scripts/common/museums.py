"""Artwork images from museums that publish their collections as CC0.

The Metropolitan Museum of Art, the Art Institute of Chicago and the
Cleveland Museum of Art offer public-domain works with open APIs and no key.
Their images are sharper than most Commons copies and their license is plain,
so the content build looks here before Wikidata. A hit must name the same
artist, and a title that matches the one asked for.
"""
from __future__ import annotations

import time

import requests

from .image_info import ImageInfo
from .web import USER_AGENT, normalize

INTERVAL = 0.5
_last = 0.0


def _get(http: requests.Session, url: str, params: dict | None = None) -> dict:
    global _last
    time.sleep(max(0.0, _last + INTERVAL - time.monotonic()))
    _last = time.monotonic()
    res = http.get(url, params=params, headers={"User-Agent": USER_AGENT}, timeout=20)
    res.raise_for_status()
    return res.json()


def _words(text: str) -> set[str]:
    return {w for w in normalize_words(text) if len(w) > 2}


def normalize_words(text: str) -> list[str]:
    import unicodedata
    plain = unicodedata.normalize("NFKD", text or "").encode("ascii", "ignore").decode().lower()
    return [w for w in "".join(c if c.isalnum() else " " for c in plain).split()]


def title_matches(wanted: str, found: str) -> bool:
    a, b = normalize(wanted), normalize(found)
    if a and b and (a in b or b in a):
        return True
    wa, wb = _words(wanted), _words(found)
    return bool(wa) and len(wa & wb) / len(wa) >= 0.6


def artist_matches(wanted: str, found: str) -> bool:
    """The artist's family name (last word) appears in the museum's artist field."""
    words = normalize_words(wanted)
    return bool(words) and words[-1] in normalize_words(found)


def met(title: str, artist: str, http: requests.Session) -> ImageInfo | None:
    base = "https://collectionapi.metmuseum.org/public/collection/v1"
    ids = (_get(http, f"{base}/search", {"hasImages": "true", "q": title}).get("objectIDs") or [])[:8]
    for object_id in ids:
        obj = _get(http, f"{base}/objects/{object_id}")
        image = obj.get("primaryImageSmall") or obj.get("primaryImage")
        if (obj.get("isPublicDomain") and image and artist_matches(artist, obj.get("artistDisplayName", ""))
                and title_matches(title, obj.get("title", ""))):
            return ImageInfo(url=image, license="CC0", credit="The Metropolitan Museum of Art",
                             page=obj.get("objectURL") or f"https://www.metmuseum.org/art/collection/search/{object_id}")
    return None


def aic(title: str, artist: str, http: requests.Session) -> ImageInfo | None:
    data = _get(http, "https://api.artic.edu/api/v1/artworks/search", {
        "q": title, "limit": "8", "fields": "id,title,artist_title,image_id,is_public_domain",
    })
    for hit in data.get("data") or []:
        if (hit.get("is_public_domain") and hit.get("image_id")
                and artist_matches(artist, hit.get("artist_title") or "") and title_matches(title, hit.get("title", ""))):
            return ImageInfo(url=f"https://www.artic.edu/iiif/2/{hit['image_id']}/full/843,/0/default.jpg",
                             license="CC0", credit="The Art Institute of Chicago",
                             page=f"https://www.artic.edu/artworks/{hit['id']}")
    return None


def cleveland(title: str, artist: str, http: requests.Session) -> ImageInfo | None:
    data = _get(http, "https://openaccess-api.clevelandart.org/api/artworks/", {
        "q": title, "has_image": "1", "cc0": "1", "limit": "8",
    })
    for hit in data.get("data") or []:
        creators = " ".join(c.get("description", "") for c in hit.get("creators") or [])
        image = ((hit.get("images") or {}).get("web") or {}).get("url")
        if image and artist_matches(artist, creators) and title_matches(title, hit.get("title", "")):
            return ImageInfo(url=image, license="CC0", credit="The Cleveland Museum of Art",
                             page=hit.get("url") or "https://www.clevelandart.org/")
    return None


def find(title_en: str, artist_en: str, session: requests.Session | None = None) -> ImageInfo | None:
    """The first museum with this work as CC0, or None (also on network trouble)."""
    if not title_en or not artist_en:
        return None
    http = session or requests.Session()
    for source in (met, aic, cleveland):
        try:
            found = source(title_en, artist_en, http)
        except (requests.RequestException, ValueError):
            continue
        if found:
            return found
    return None
