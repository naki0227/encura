#!/usr/bin/env python3
"""
Seasonal Exhibitions - 毎年恒例の展示会を季節に応じて自動生成
正倉院展、院展、日展などの定期開催展覧会を特集記事化
"""
import os
import json
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
import google.generativeai as genai
from supabase import create_client, Client

# Load .env from project root
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

# 毎年恒例の展示会リスト
SEASONAL_EXHIBITIONS = [
    {
        "name": "正倉院展",
        "month": 10,  # 10-11月
        "venue": "奈良国立博物館",
        "description": "正倉院宝物を年に一度だけ公開する特別展。奈良時代の国宝級宝物が間近で見られる貴重な機会。",
        "official_url": "https://www.narahaku.go.jp/",
        "image_query": "Shosoin treasure Japan"
    },
    {
        "name": "日展",
        "month": 11,  # 10-12月
        "venue": "国立新美術館",
        "description": "日本最大規模の総合美術展。日本画、洋画、彫刻、工芸、書の5部門で構成される公募展。",
        "official_url": "https://nitten.or.jp/",
        "image_query": "Nitten art exhibition Japan"
    },
    {
        "name": "院展",
        "month": 9,
        "venue": "東京都美術館",
        "description": "日本美術院主催の日本画公募展。横山大観らが創設した伝統ある展覧会。",
        "official_url": "https://nihonbijutsuin.or.jp/",
        "image_query": "Inten Japanese painting exhibition"
    },
    {
        "name": "二科展",
        "month": 9,
        "venue": "国立新美術館",
        "description": "1914年創設の歴史ある洋画・彫刻・デザインの公募展。",
        "official_url": "https://www.nika.or.jp/",
        "image_query": "Nika art exhibition Japan"
    },
    {
        "name": "東京国立博物館 新春特別公開",
        "month": 1,
        "venue": "東京国立博物館",
        "description": "国宝・重要文化財を含む特別な作品を新年に公開する恒例行事。",
        "official_url": "https://www.tnm.jp/",
        "image_query": "Tokyo National Museum treasure"
    },
]


def get_wikimedia_image_url(query):
    """Wikimedia Commonsから画像URLを取得"""
    import urllib.request
    import urllib.parse
    
    if not query:
        return ""
    
    base_url = "https://commons.wikimedia.org/w/api.php"
    params = {
        "action": "query",
        "generator": "search",
        "gsrnamespace": "6",
        "gsrsearch": query,
        "gsrlimit": "5",
        "prop": "imageinfo",
        "iiprop": "url|mime",
        "iiurlwidth": "800",
        "format": "json"
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'EnCura/1.0'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            pages = data.get("query", {}).get("pages", {})
            
            for page_id in pages:
                image_info = pages[page_id].get("imageinfo", [])
                if image_info:
                    file_url = image_info[0].get("thumburl", image_info[0]["url"])
                    mime = image_info[0].get("mime", "")
                    
                    if mime.startswith("image/") and not mime.endswith(("tiff", "pdf")):
                        lower_url = file_url.lower()
                        if any(lower_url.endswith(ext) for ext in [".jpg", ".jpeg", ".png", ".webp"]):
                            return file_url
    except Exception as e:
        print(f"Error searching Wikimedia for '{query}': {e}")
    return ""


def main(dry_run=False):
    # Configuration
    gemini_api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not gemini_api_key or not supabase_url or not supabase_key:
        print("Error: Missing environment variables.")
        return

    genai.configure(api_key=gemini_api_key)
    supabase: Client = create_client(supabase_url, supabase_key)

    current_month = datetime.now().month
    next_month = (current_month % 12) + 1

    print(f"Current month: {current_month}, Next month: {next_month}")
    print("Checking for seasonal exhibitions...")

    # Check existing articles
    try:
        existing_data = supabase.table('trending_articles').select('title').execute()
        existing_titles = [item['title'] for item in existing_data.data]
    except Exception as e:
        print(f"Error fetching existing articles: {e}")
        existing_titles = []

    # Filter exhibitions for current or next month
    relevant_exhibitions = [
        ex for ex in SEASONAL_EXHIBITIONS 
        if ex['month'] in [current_month, next_month]
    ]

    if not relevant_exhibitions:
        print("No seasonal exhibitions for this period.")
        return

    print(f"Found {len(relevant_exhibitions)} relevant exhibitions.")

    # Use Gemini to generate detailed articles
    model = genai.GenerativeModel('gemini-2.5-flash')
    year = datetime.now().year

    for exhibition in relevant_exhibitions:
        article_title = f"【特集】{year}年 {exhibition['name']}の見どころ"
        
        if article_title in existing_titles:
            print(f"Skipping (already exists): {article_title}")
            continue

        print(f"Generating article for: {exhibition['name']}")

        prompt = f"""
        {year}年の「{exhibition['name']}」について、以下の情報をもとに詳細な記事を作成してください。

        会場: {exhibition['venue']}
        概要: {exhibition['description']}
        公式サイト: {exhibition['official_url']}

        以下のJSON形式で出力してください：
        {{
          "title": "{article_title}",
          "summary": "今年の見どころを50文字程度で",
          "content": "今年の開催情報、注目の展示品、混雑予想、おすすめの鑑賞ポイントなど300-400文字で詳しく解説"
        }}
        """

        try:
            response = model.generate_content(prompt)
            text = response.text
            
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0]
            elif "```" in text:
                text = text.split("```")[1].split("```")[0]
            
            article = json.loads(text.strip())

            # Get image
            image_url = get_wikimedia_image_url(exhibition['image_query'])

            data = {
                "title": article['title'],
                "summary": article['summary'],
                "content": article['content'],
                "image_url": image_url,
                "source_url": exhibition['official_url'],
                "keyword": "特集",
                "is_published": True
            }

            if dry_run:
                print(f"  [DRY RUN] Would insert: {data['title']}")
            else:
                supabase.table('trending_articles').insert(data).execute()
                print(f"  - Inserted: {data['title']}")

        except Exception as e:
            print(f"  - Error generating article: {e}")

    print("\nSeasonal exhibitions update completed.")


if __name__ == "__main__":
    import sys
    dry_run = "--dry-run" in sys.argv
    main(dry_run=dry_run)
