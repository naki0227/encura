"""Fetching pages and checking that a claim actually appears on them."""
from __future__ import annotations

import html
import re
import unicodedata
from urllib.parse import urlparse

import requests

USER_AGENT = "EnCuraCrawler/2.0 (+https://enludus.com; contact@enludus.com)"
TIMEOUT = 20
MAX_BYTES = 3_000_000

_TAGS = re.compile(r"<(script|style)\b.*?</\1>|<[^>]+>", re.S | re.I)
# Characters that differ between how a model writes a title and how a site
# prints it: spaces, brackets, quotes, dashes, middle dots.
_NOISE = re.compile(r"[\s「」『』【】〈〉《》()（）\[\]\"'“”‘’・･\-‐‑–—―~〜～:：!！?？,，、。.]")


def normalize(text: str) -> str:
    return _NOISE.sub("", unicodedata.normalize("NFKC", text)).lower()


def html_to_text(raw: str) -> str:
    return html.unescape(_TAGS.sub(" ", raw))


def is_http_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return False
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def fetch(url: str, session: requests.Session | None = None) -> tuple[str, str] | None:
    """Return (final_url, page_text) or None when the page is not reachable."""
    if not is_http_url(url):
        return None
    http = session or requests.Session()
    try:
        res = http.get(
            url,
            headers={"User-Agent": USER_AGENT, "Accept-Language": "ja,en;q=0.8"},
            timeout=TIMEOUT,
            allow_redirects=True,
            stream=True,
        )
        if res.status_code != 200:
            return None
        if "html" not in res.headers.get("content-type", "html").lower():
            return None
        raw = res.raw.read(MAX_BYTES, decode_content=True)
        encoding = res.encoding if res.encoding and res.encoding.lower() != "iso-8859-1" else None
        body = raw.decode(encoding or res.apparent_encoding or "utf-8", errors="replace")
        return res.url, html_to_text(body)
    except requests.RequestException:
        return None


def title_keys(title: str) -> list[str]:
    """Strings, any of which on a page counts as the page naming the title.

    Exhibition titles often carry a subtitle that sites shorten or format
    differently ("〇〇展 ―△△―"), so the main part alone is also accepted
    when it is long enough to be specific.
    """
    keys = [normalize(title)]
    main = re.split(r"[―—–~〜～:：|｜]", unicodedata.normalize("NFKC", title))[0]
    main_key = normalize(main)
    if len(main_key) >= 4 and main_key not in keys:
        keys.append(main_key)
    return [k for k in keys if k]


def mentions(page_text: str, title: str) -> bool:
    page = normalize(page_text)
    return any(key in page for key in title_keys(title))


def find_page_mentioning(
    title: str,
    urls: list[str],
    session: requests.Session | None = None,
) -> str | None:
    """First URL (after redirects) whose page names `title`, else None."""
    seen = set()
    for url in urls:
        if not url or url in seen:
            continue
        seen.add(url)
        page = fetch(url, session)
        if page and mentions(page[1], title):
            return page[0]
    return None
