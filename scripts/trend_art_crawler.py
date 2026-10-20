#!/usr/bin/env python3
"""Art news (トレンド): recent, sourced topics.

Every article must come from a page found by Google Search that names the
topic. Articles are written only from those sources; topics the model cannot
source are dropped instead of being made up.

    python scripts/trend_art_crawler.py [--dry-run]
"""
from __future__ import annotations

import datetime as dt
import sys

from common import db, gemini, images, web

KEYWORDS = ("展覧会", "新発見・修復", "美術館", "作品・作家")

SYSTEM = """あなたは美術ニュースの編集者です。Google 検索で見つけた報道や公式発表に
書かれている事実だけを使って記事を書きます。推測、誇張、出典のない数字は書きません。"""

PROMPT = """今日は {today} です。過去 {days} 日間に日本語で報じられた、美術に関する話題を
最大 5 件選んでください（大きな展覧会の発表や来場者数、作品の新発見・修復・返還、
美術館の開館・リニューアル、作家の受賞など）。
次の話題は既に記事にしたので除きます: {exclude}

各話題について:
- source_url: その話題を報じた記事か公式発表のページの URL
- subject: 話題の中心の固有名詞（展覧会名・作品名・館名・作家名のどれか）を出典の表記どおりに
- content: 出典に書かれている事実だけで 200〜300 字
- artwork: 特定の作品が話題の中心なら、その作品の英語名と作者の英語名。なければ null
- keyword: {keywords} のどれか

JSON 配列だけを出力してください。
[
  {{
    "title": "見出し（30 字以内、誇張しない）",
    "summary": "50 字程度の要約",
    "content": "本文",
    "source_url": "https://...",
    "subject": "固有名詞",
    "keyword": "展覧会",
    "artwork": {{"title_en": "...", "artist_en": "..."}}
  }}
]"""

RECENT_DAYS = 14


def valid_topics(items, known_titles: set[str], known_urls: set[str]) -> list[dict]:
    out = []
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict):
            continue
        if not all(str(item.get(k) or "").strip() for k in ("title", "summary", "content")):
            continue
        key = web.normalize(item["title"])
        url = str(item.get("source_url") or "").strip()
        if key in known_titles or (url and url in known_urls):
            continue
        if item.get("keyword") not in KEYWORDS:
            item["keyword"] = "美術館"
        known_titles.add(key)
        out.append(item)
    return out


def anchor_phrase(item: dict) -> str:
    """The phrase a source page must contain.

    The headline is the model's own wording and rarely appears verbatim, so
    the proper noun the story is about is checked instead.
    """
    subject = str(item.get("subject") or "").strip()
    return subject if len(web.normalize(subject)) >= 3 else item["title"]


def main(dry_run: bool = False) -> int:
    today = dt.date.today()
    client = None if dry_run else db.client()
    rows = [] if dry_run else client.table("trending_articles").select("title, source_url").execute().data
    known_titles = {web.normalize(r["title"]) for r in rows}
    known_urls = {r["source_url"] for r in rows if r.get("source_url")}

    result = gemini.generate(
        PROMPT.format(
            today=today.isoformat(), days=RECENT_DAYS,
            exclude="、".join(r["title"] for r in rows[-50:]) or "なし",
            keywords="、".join(KEYWORDS),
        ),
        system=SYSTEM,
        search=True,
    )
    topics = valid_topics(gemini.extract_json(result.text), known_titles, known_urls)
    print(f"Gemini ({result.model}) proposed {len(topics)} new topics from {len(result.sources)} sources.")
    source_urls = [s.uri for s in result.sources]

    stored = 0
    for item in topics:
        print(f"- {item['title']}")
        verified = web.find_page_mentioning(anchor_phrase(item), [item.get("source_url", "")] + source_urls)
        if not verified:
            print("  skipped: no source page confirms this topic")
            continue
        art = item.get("artwork") or {}
        image_url = ""
        if art.get("title_en") and art.get("artist_en"):
            image_url = images.find_artwork_image([art["title_en"]], [art["artist_en"]]) or ""
        data = {
            "title": item["title"],
            "summary": item["summary"],
            "content": item["content"],
            "image_url": image_url,
            "keyword": item["keyword"],
            "source_url": verified,
            "is_published": True,
        }
        print(f"  source: {verified}" + ("" if image_url else " (no image)"))
        if not dry_run:
            client.table("trending_articles").insert(data).execute()
        stored += 1

    print(f"Stored {stored} sourced articles.")
    return 0 if stored or not topics else 1


if __name__ == "__main__":
    sys.exit(main(dry_run="--dry-run" in sys.argv))
