import os
import json
import urllib.request
import urllib.parse
import google.generativeai as genai
from supabase import create_client, Client

def get_wikimedia_image_url(query):
    if not query:
        return ""
    # Clean query
    query = query.replace("File:", "").replace("_", " ")
    # Remove extension if present (simple check)
    if "." in query:
        query = query.rsplit(".", 1)[0]
        
    base_url = "https://commons.wikimedia.org/w/api.php"
    params = {
        "action": "query",
        "generator": "search",
        "gsrnamespace": "6", # File namespace
        "gsrsearch": query,
        "gsrlimit": "5", # Fetch more to filter out PDFs etc
        "prop": "imageinfo",
        "iiprop": "url|mime",
        "iiurlwidth": "800", # Request thumbnail width
        "format": "json"
    }
    url = f"{base_url}?{urllib.parse.urlencode(params)}"
    try:
        # Add User-Agent to avoid being blocked
        req = urllib.request.Request(url, headers={'User-Agent': 'EnCura/1.0 (http://example.com/encura; support@example.com)'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            pages = data.get("query", {}).get("pages", {})
            
            # Iterate through results to find a valid image
            for page_id in pages:
                image_info = pages[page_id].get("imageinfo", [])
                if image_info:
                    # Use thumburl if available, otherwise url
                    file_url = image_info[0].get("thumburl", image_info[0]["url"])
                    mime = image_info[0].get("mime", "")
                    
                    # Filter for valid image types
                    if mime.startswith("image/") and not mime.endswith("tiff") and not mime.endswith("pdf"):
                         # Double check extension just in case
                         lower_url = file_url.lower()
                         if lower_url.endswith(".jpg") or lower_url.endswith(".jpeg") or lower_url.endswith(".png") or lower_url.endswith(".webp"):
                             return file_url
    except Exception as e:
        print(f"Error searching Wikimedia for '{query}': {e}")
    return ""

def main():
    # 1. Configuration
    gemini_api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not gemini_api_key or not supabase_url or not supabase_key:
        print("Error: Missing environment variables.")
        return

    genai.configure(api_key=gemini_api_key)
    supabase: Client = create_client(supabase_url, supabase_key)

    # 2. Fetch existing data to avoid duplicates
    print("Fetching existing topics to avoid duplicates...")
    try:
        existing_data = supabase.table('trending_articles').select('title').execute()
        existing_titles = [item['title'] for item in existing_data.data]
        print(f"Found {len(existing_titles)} existing topics.")
    except Exception as e:
        print(f"Error fetching existing topics: {e}")
        existing_titles = []

    exclusion_text = ""
    if existing_titles:
        # Limit to last 50 to avoid cluttering prompt too much if list is huge, 
        # or send all if reasonable. Gemini 2.5 Flash has large context, so sending all is likely fine for now.
        # Let's send all for now.
        exclusion_list = ", ".join(existing_titles)
        exclusion_text = f"以下のトピックは既に存在するため、絶対に生成しないでください: {exclusion_list}"

    # 3. Prompt Gemini
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = f"""
    「実は怖い絵画」「画家の意外な副業」「修復の失敗事例」など、SNSでバズりそうな美術ミステリーやトリビアを10個作成してください。
    
    {exclusion_text}

    各トピックについて、以下のJSON形式で出力してください。
    JSON以外の余計なテキストは含めないでください。

    JSON形式:
    [
      {{
        "title": "キャッチーなタイトル",
        "summary": "興味を惹く短い概要（50文字程度）",
        "content": "詳細な解説本文（200文字程度）",
        "image_search_query": "Wikimedia Commonsで画像を検索するためのキーワード（例: The Last Supper Leonardo da Vinci）。",
        "keyword": "ミステリー、雑学、悲劇、など"
      }}
    ]
    """

    print("Fetching trending topics from Gemini...")
    try:
        response = model.generate_content(prompt)
        text = response.text
        # Clean up markdown code blocks if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        topics = json.loads(text.strip())
        print(f"Got {len(topics)} topics.")
    except Exception as e:
        print(f"Error fetching/parsing from Gemini: {e}")
        return

    # 4. Insert to Supabase
    # Removed clearing logic to preserve history
    
    for topic in topics:
        try:
            print(f"Processing: {topic['title']}")
            
            # Check for duplicate title again just in case
            if topic['title'] in existing_titles:
                print(f"Skipping duplicate: {topic['title']}")
                continue

            # Search Wikimedia for image URL
            search_query = topic.get('image_search_query', topic['title'])
            image_url = get_wikimedia_image_url(search_query)
            
            if not image_url:
                print(f"  - No image found for '{search_query}', trying title...")
                image_url = get_wikimedia_image_url(topic['title'])

            print(f"  - Image URL: {image_url}")

            data = {
                "title": topic['title'],
                "summary": topic['summary'],
                "content": topic['content'],
                "image_url": image_url,
                "keyword": topic['keyword'],
                "is_published": True
            }

            supabase.table('trending_articles').insert(data).execute()
                
        except Exception as e:
            print(f"Error inserting trending topic {topic.get('title')}: {e}")

    print("Trending topics seeding completed.")

if __name__ == "__main__":
    main()
