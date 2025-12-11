#!/usr/bin/env python3
"""
Raden Stream Monitor - らでんちゃんの美術配信から作品情報を抽出
※ らでんちゃんの名前は使用せず「ネットで話題」として記事化
"""
import os
import json
from pathlib import Path
from datetime import datetime, timedelta
from dotenv import load_dotenv
import google.generativeai as genai
from supabase import create_client, Client

# Load .env from project root
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

# らでんちゃんのYouTubeチャンネルID
RADEN_CHANNEL_ID = "UCMGfV7TVTmHhtoS6jyN1Sp"


def get_recent_videos(api_key, channel_id, max_results=10):
    """YouTube Data APIで最新動画を取得"""
    import urllib.request
    import urllib.parse
    
    base_url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "key": api_key,
        "channelId": channel_id,
        "part": "snippet",
        "order": "date",
        "maxResults": max_results,
        "type": "video"
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            return data.get("items", [])
    except Exception as e:
        print(f"Error fetching YouTube videos: {e}")
        return []


def is_art_related(title, description):
    """美術関連の配信かどうかを判定"""
    art_keywords = [
        "美術", "アート", "絵画", "画家", "作品", "展覧会", "美術館",
        "博物館", "彫刻", "芸術", "名画", "浮世絵", "西洋画", "日本画",
        "印象派", "ルネサンス", "バロック", "art", "museum", "painting"
    ]
    text = (title + " " + description).lower()
    return any(keyword.lower() in text for keyword in art_keywords)


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

    # Fetch recent videos
    print("Fetching recent videos from Raden's channel...")
    videos = get_recent_videos(gemini_api_key, RADEN_CHANNEL_ID)
    
    if not videos:
        print("No videos found or API error. Exiting.")
        return
    
    print(f"Found {len(videos)} recent videos.")

    # Filter art-related videos
    art_videos = []
    for video in videos:
        snippet = video.get("snippet", {})
        title = snippet.get("title", "")
        description = snippet.get("description", "")
        
        if is_art_related(title, description):
            art_videos.append({
                "title": title,
                "description": description,
                "video_id": video.get("id", {}).get("videoId", ""),
                "published_at": snippet.get("publishedAt", "")
            })
    
    print(f"Found {len(art_videos)} art-related videos.")
    
    if not art_videos:
        print("No art-related videos found. Exiting.")
        return

    # Use Gemini to extract artworks mentioned
    model = genai.GenerativeModel('gemini-2.5-flash')
    
    for video in art_videos[:3]:  # Process up to 3 videos at a time
        print(f"\nAnalyzing: {video['title']}")
        
        prompt = f"""
        以下のYouTube配信タイトルと概要から、紹介されている可能性のある美術作品や展覧会を推測し、
        「ネットで話題」の記事として再構成してください。
        
        【重要】配信者の名前は絶対に使用しないでください。あくまで「話題の作品」として紹介します。
        
        配信タイトル: {video['title']}
        概要: {video['description'][:500]}
        
        もし美術作品や展覧会が特定できる場合、以下のJSON形式で1-2件出力してください。
        特定できない場合は空配列[]を返してください。
        
        JSON形式:
        [
          {{
            "title": "今話題の〇〇（作品名や展覧会名を含む、配信者名は含めない）",
            "summary": "なぜ今話題なのか（50文字程度）",
            "content": "作品の解説や見どころ（200-300文字、配信者への言及なし）",
            "image_search_query": "Wikimedia Commons検索用キーワード（英語推奨）",
            "keyword": "話題"
          }}
        ]
        """
        
        try:
            response = model.generate_content(prompt)
            text = response.text
            
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0]
            elif "```" in text:
                text = text.split("```")[1].split("```")[0]
            
            articles = json.loads(text.strip())
            
            if not articles:
                print("  - No specific artworks identified.")
                continue
                
            print(f"  - Generated {len(articles)} articles.")
            
            # Insert articles
            for article in articles:
                image_url = get_wikimedia_image_url(article.get('image_search_query', ''))
                
                data = {
                    "title": article['title'],
                    "summary": article['summary'],
                    "content": article['content'],
                    "image_url": image_url,
                    "keyword": article['keyword'],
                    "is_published": True
                }
                
                if dry_run:
                    print(f"  [DRY RUN] Would insert: {data['title']}")
                else:
                    try:
                        supabase.table('trending_articles').insert(data).execute()
                        print(f"  - Inserted: {data['title']}")
                    except Exception as e:
                        print(f"  - Error inserting: {e}")
                        
        except Exception as e:
            print(f"  - Error processing video: {e}")

    print("\nRaden stream monitoring completed.")


if __name__ == "__main__":
    import sys
    dry_run = "--dry-run" in sys.argv
    main(dry_run=dry_run)
