"""Who made an image, under which license, and where it is described.

Wikimedia Commons hosts only freely licensed files, but "free" is not one
thing: faithful photos of old paintings are public domain, while a photo of
a sculpture or a building usually belongs to its photographer under CC BY or
CC BY-SA, which require a credit. The app shows the credit next to the image;
anything that is not public domain, CC0, CC BY or CC BY-SA is left out.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import unquote

import requests

from .images import COMMONS_API, _get
from .web import html_to_text

COMMONS_FILE_PAGE = "https://commons.wikimedia.org/wiki/File:"


@dataclass(frozen=True)
class ImageInfo:
    url: str
    license: str  # "Public domain", "CC0", "CC BY-SA 4.0", ...
    credit: str  # who to credit (photographer, museum); may be empty for PD
    page: str  # where the image and its license are described


# Public domain (any "PD-..." tag), CC0, or CC BY / CC BY-SA of any version.
# NC and ND licenses are not allowed: the app is a commercial product, and
# its images are resized.
_ALLOWED = re.compile(r"^(public domain.*|pd( .*)?|cc0( .*)?|cc by( sa)?( \d(\.\d)?)?)$")


def is_allowed(license: str) -> bool:
    return bool(_ALLOWED.match(" ".join((license or "").replace("-", " ").lower().split())))


def needs_credit(license: str) -> bool:
    return (license or "").lower().startswith(("cc by", "cc-by"))


_THUMB = re.compile(r"/wikipedia/commons/thumb/[0-9a-f]/[0-9a-f]{2}/([^/]+)/[^/]+$")
_ORIGINAL = re.compile(r"/wikipedia/commons/[0-9a-f]/[0-9a-f]{2}/([^/]+)$")


def commons_file_name(url: str) -> str | None:
    """'Mona_Lisa.jpg' from an upload.wikimedia.org / thumb.wikimedia.org URL."""
    path = (url or "").split("?", 1)[0]
    match = _THUMB.search(path) or _ORIGINAL.search(path)
    return unquote(match.group(1)) if match else None


def _meta(ext: dict, key: str) -> str:
    raw = ((ext.get(key) or {}).get("value") or "")
    return " ".join(html_to_text(str(raw)).split())


def commons_info(url: str, session: requests.Session | None = None) -> ImageInfo | None:
    """License and credit of a Commons image, or None when unknown."""
    name = commons_file_name(url)
    if not name:
        return None
    try:
        data = _get(session or requests.Session(), COMMONS_API, {
            "action": "query", "titles": f"File:{name}", "prop": "imageinfo",
            "iiprop": "extmetadata", "iiextmetadatafilter": "LicenseShortName|Artist|Credit|AttributionRequired",
        })
    except requests.RequestException:
        return None
    for page in (data.get("query") or {}).get("pages", {}).values():
        for info in page.get("imageinfo") or []:
            ext = info.get("extmetadata") or {}
            license = _meta(ext, "LicenseShortName")
            if not license:
                return None
            if license.lower().startswith("public domain") or license.upper().startswith("PD"):
                license = "Public domain"
            credit = ""
            if _meta(ext, "AttributionRequired").lower() == "true" or needs_credit(license):
                credit = _meta(ext, "Artist")[:200]
            return ImageInfo(url=url, license=license, credit=credit,
                             page=COMMONS_FILE_PAGE + name.replace(" ", "_"))
    return None
