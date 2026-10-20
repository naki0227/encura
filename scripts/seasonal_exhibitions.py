#!/usr/bin/env python3
"""
Seasonal Exhibitions - 毎年恒例の展示会を季節に応じて自動生成
正倉院展、院展、日展などの定期開催展覧会を特集記事化

その年の会期と内容を Google 検索で公式発表から確認できたときだけ記事にする。
まだ発表されていなければ書かない（前年の情報や推測で埋めない）。

    python scripts/seasonal_exhibitions.py [--dry-run]
"""
from __future__ import annotations

import datetime as dt
import sys

from common import db, gemini, web

# 毎年恒例の展示会リスト
SEASONAL_EXHIBITIONS = [
    {
        "name": "正倉院展",
        "month": 10,  # 10-11月
        "venue": "奈良国立博物館",
        "description": "正倉院宝物を年に一度だけ公開する特別展。奈良時代の国宝級宝物が間近で見られる貴重な機会。",
        "official_url": "https://www.narahaku.go.jp/"
    },
    {
        "name": "日展",
        "month": 11,  # 10-12月
        "venue": "国立新美術館",
        "description": "日本最大規模の総合美術展。日本画、洋画、彫刻、工芸、書の5部門で構成される公募展。",
        "official_url": "https://nitten.or.jp/"
    },
    {
        "name": "院展",
        "month": 9,
        "venue": "東京都美術館",
        "description": "日本美術院主催の日本画公募展。横山大観らが創設した伝統ある展覧会。",
        "official_url": "https://nihonbijutsuin.or.jp/"
    },
    {
        "name": "二科展",
        "month": 9,
        "venue": "国立新美術館",
        "description": "1914年創設の歴史ある洋画・彫刻・デザインの公募展。",
        "official_url": "https://www.nika.or.jp/"
    },
    {
        # 名前は公式ページの表記と照合するので、催しの正式名を使う
        "name": "博物館に初もうで",
        "month": 1,
        "venue": "東京国立博物館",
        "description": "国宝・重要文化財を含む干支や新年にちなむ作品を公開する、東京国立博物館の新年恒例の催し。",
        "official_url": "https://www.tnm.jp/"
    },
]


SYSTEM = """あなたは美術館の広報記事を書く編集者です。主催者の公式発表を Google 検索で確認し、
そこに書かれている事実だけを使います。前年の内容や推測で埋めてはいけません。"""

PROMPT = """{year}年の「{name}」（会場の例年: {venue}、公式サイト: {url}）について、
主催者の公式発表を調べてください。

{year}年の会期が公式に発表されていなければ {{"announced": false}} だけを返してください。
発表されていれば、次の JSON だけを返してください。
{{
  "announced": true,
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "venue": "会場名",
  "summary": "今年の見どころを 50 字程度で",
  "content": "会期、会場、公式に発表された主な出品物や見どころを 300〜400 字で",
  "source_url": "公式発表のページの URL"
}}"""


def relevant(exhibitions: list[dict], month: int) -> list[dict]:
    next_month = month % 12 + 1
    return [ex for ex in exhibitions if ex["month"] in (month, next_month)]


def check_announcement(data, year: int) -> dict | None:
    """Accept only an announced edition whose dates fall in `year`."""
    if not isinstance(data, dict) or data.get("announced") is not True:
        return None
    try:
        start = dt.date.fromisoformat(str(data.get("start_date")))
        end = dt.date.fromisoformat(str(data.get("end_date")))
    except ValueError:
        return None
    if start > end or year not in (start.year, end.year):
        return None
    if not all(str(data.get(k) or "").strip() for k in ("summary", "content")):
        return None
    return data


def main(dry_run: bool = False) -> int:
    today = dt.date.today()
    targets = relevant(SEASONAL_EXHIBITIONS, today.month)
    if not targets:
        print("No seasonal exhibitions for this period.")
        return 0

    client = None if dry_run else db.client()
    rows = [] if dry_run else client.table("trending_articles").select("title").execute().data
    existing = {web.normalize(r["title"]) for r in rows}

    failures = 0
    for ex in targets:
        title = f"【特集】{today.year}年 {ex['name']}の見どころ"
        if web.normalize(title) in existing:
            print(f"- exists: {title}")
            continue
        print(f"- {ex['name']}")
        try:
            result = gemini.generate(
                PROMPT.format(year=today.year, name=ex["name"], venue=ex["venue"], url=ex["official_url"]),
                system=SYSTEM, search=True,
            )
            article = check_announcement(gemini.extract_json(result.text), today.year)
        except gemini.GeminiError as e:
            print(f"  error: {e}")
            failures += 1
            continue
        if not article:
            print("  not announced yet; skipped")
            continue
        verified = web.find_page_mentioning(
            ex["name"], [article.get("source_url", ""), ex["official_url"]] + [s.uri for s in result.sources],
        )
        if not verified:
            print("  skipped: no page confirms this year's edition")
            continue
        data = {
            "title": title,
            "summary": article["summary"],
            "content": article["content"],
            "image_url": "",
            "source_url": verified,
            "keyword": "特集",
            "is_published": True,
        }
        print(f"  {article['start_date']} - {article['end_date']} / source: {verified}")
        if not dry_run:
            client.table("trending_articles").insert(data).execute()

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(dry_run="--dry-run" in sys.argv))
