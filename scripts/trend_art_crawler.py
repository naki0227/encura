#!/usr/bin/env python3
"""
Trend Art Crawler - SNSやニュースで話題の美術展・作品を自動収集
"""
import os
import json
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai
from supabase import create_client, Client

# Load .env from project root
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)


def get_wikimedia_image_url(query):
    """Wikimedia Commonsから画像URLを取得"""
    import urllib.request
    import urllib.parse
    
    if not query:
        return ""
    
    query = query.replace("File:", "").replace("_", " ")
    if "." in query:
        query = query.rsplit(".", 1)[0]
        
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
                    
                    if mime.startswith("image/") and not mime.endswith("tiff") and not mime.endswith("pdf"):
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

    # Fetch existing titles to avoid duplicates
    print("Fetching existing articles to avoid duplicates...")
    try:
        existing_data = supabase.table('trending_articles').select('title').execute()
        existing_titles = [item['title'] for item in existing_data.data]
        print(f"Found {len(existing_titles)} existing articles.")
    except Exception as e:
        print(f"Error fetching existing articles: {e}")
        existing_titles = []

    exclusion_text = ""
    if existing_titles:
        exclusion_list = ", ".join(existing_titles[-50:])  # Last 50 to avoid huge prompt
        exclusion_text = f"以下のトピックは既に存在するため、生成しないでください: {exclusion_list}"

    # Prompt Gemini for trending art topics
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = f"""
    現在SNSやニュースで話題の美術展・作品・アートトピックを5件作成してください。
    以下のカテゴリから幅広く選んでください：

    1. 注目の展覧会（混雑情報、チケット完売、話題の理由など）
    2. SNSでバズった作品・アーティスト
    3. 美術ミステリー・トリビア（「実は怖い絵画」「隠された意味」など）
    4. 新発見・修復完了・返還された作品
    5. 季節に関連した作品（今の時期にぴったりの名画など）

    {exclusion_text}

    各トピックについて、以下のJSON形式で出力してください。
    JSON以外の余計なテキストは含めないでください。

    JSON形式:
    [
      {{
        "title": "キャッチーなタイトル（【話題】などの接頭辞は不要）",
        "summary": "興味を惹く短い概要（50文字程度）",
        "content": "詳細な解説本文（200-300文字程度）",
        "image_search_query": "Wikimedia Commonsで画像を検索するためのキーワード（英語推奨、例: The Last Supper Leonardo da Vinci）",
        "keyword": "展覧会、SNS話題、ミステリー、修復、季節 のいずれか",
        "source_url": "関連する公式サイトやニュースURL（わかる場合のみ、不明なら空文字）"
      }}
    ]
    """

    print("Fetching trending art topics from Gemini...")
    try:
        response = model.generate_content(prompt)
        text = response.text
        
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        topics = json.loads(text.strip())
        print(f"Got {len(topics)} trending topics.")
    except Exception as e:
        print(f"Error fetching/parsing from Gemini: {e}")
        return

    # Insert to Supabase
    for topic in topics:
        try:
            print(f"Processing: {topic['title']}")
            
            if topic['title'] in existing_titles:
                print(f"  - Skipping duplicate: {topic['title']}")
                continue

            # Get image from Wikimedia
            search_query = topic.get('image_search_query', topic['title'])
            image_url = get_wikimedia_image_url(search_query)
            
            if not image_url:
                print(f"  - No image found for '{search_query}', trying title...")
                image_url = get_wikimedia_image_url(topic['title'])

            print(f"  - Image URL: {image_url[:50]}..." if image_url else "  - No image found")

            data = {
                "title": topic['title'],
                "summary": topic['summary'],
                "content": topic['content'],
                "image_url": image_url,
                "keyword": topic['keyword'],
                "source_url": topic.get('source_url', ''),
                "is_published": True
            }

            if dry_run:
                print(f"  [DRY RUN] Would insert: {data['title']}")
            else:
                supabase.table('trending_articles').insert(data).execute()
                print(f"  - Inserted successfully!")
                
        except Exception as e:
            print(f"Error inserting topic {topic.get('title')}: {e}")

    print("Trend art crawling completed.")


if __name__ == "__main__":
    import sys
    dry_run = "--dry-run" in sys.argv
    main(dry_run=dry_run)
