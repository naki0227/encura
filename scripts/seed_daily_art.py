import os
import json
import datetime
import urllib.request
import urllib.parse
import google.generativeai as genai
from supabase import create_client, Client

def get_wikimedia_image_url(query):
    if not query:
        return ""
    # Clean query
    query = query.replace("File:", "").replace("_", " ")
    # Remove extension if present
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
    # ... (Configuration)
    gemini_api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not gemini_api_key or not supabase_url or not supabase_key:
        print("Error: Missing environment variables.")
        return

    genai.configure(api_key=gemini_api_key)
    supabase: Client = create_client(supabase_url, supabase_key)

    # 2. Fetch existing data and last date
    print("Fetching existing data to avoid duplicates and determine start date...")
    start_date = datetime.date.today() + datetime.timedelta(days=1)
    existing_titles = []
    
    try:
        # Fetch titles
        existing_data = supabase.table('daily_columns').select('title').execute()
        existing_titles = [item['title'] for item in existing_data.data]
        print(f"Found {len(existing_titles)} existing art pieces.")

        # Fetch max date
        # Note: Supabase/PostgREST doesn't support max() directly in select without rpc or complex query sometimes.
        # We can order by display_date desc limit 1.
        last_date_data = supabase.table('daily_columns').select('display_date').order('display_date', desc=True).limit(1).execute()
        if last_date_data.data:
            last_date_str = last_date_data.data[0]['display_date']
            # Parse YYYY-MM-DD
            last_date = datetime.datetime.strptime(last_date_str, "%Y-%m-%d").date()
            if last_date >= datetime.date.today():
                start_date = last_date + datetime.timedelta(days=1)
                print(f"Found future schedule. Starting from {start_date}")
    except Exception as e:
        print(f"Error fetching existing data: {e}")

    exclusion_text = ""
    if existing_titles:
        exclusion_list = ", ".join(existing_titles)
        exclusion_text = f"以下の作品は既に存在するため、絶対に生成しないでください: {exclusion_list}"

    # 3. Prompt Gemini
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = f"""
    西洋・日本を含む世界の名画を30作品選んでください。有名どころ（ゴッホ、モネ、北斎など）を中心に。
    
    {exclusion_text}

    各作品について、以下のJSON形式で出力してください。
    JSON以外の余計なテキストは含めないでください。

    JSON形式:
    [
      {{
        "title": "作品名",
        "artist": "画家名",
        "image_search_query": "Wikimedia Commonsで画像を検索するためのキーワード（例: The Starry Night Van Gogh）。",
        "content": "なぜ名画なのかを解説する200文字程度の文章"
      }}
    ]
    """

    print("Fetching daily art data from Gemini...")
    try:
        response = model.generate_content(prompt)
        text = response.text
        # Clean up markdown code blocks if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        arts = json.loads(text.strip())
        print(f"Got {len(arts)} art pieces.")
    except Exception as e:
        print(f"Error fetching/parsing from Gemini: {e}")
        return

    # 4. Upsert to Supabase
    
    for i, art in enumerate(arts):
        try:
            display_date = start_date + datetime.timedelta(days=i)
            print(f"Processing: {art['title']} for {display_date}")
            
            # Check duplicate title locally
            if art['title'] in existing_titles:
                print(f"Skipping duplicate: {art['title']}")
                continue

            # Search Wikimedia for image URL
            search_query = art.get('image_search_query', f"{art['title']} {art['artist']}")
            image_url = get_wikimedia_image_url(search_query)
            
            if not image_url:
                print(f"  - No image found for '{search_query}', trying title...")
                image_url = get_wikimedia_image_url(art['title'])

            print(f"  - Image URL: {image_url}")

            data = {
                "title": art['title'],
                "artist": art['artist'],
                "image_url": image_url,
                "content": art['content'],
                "display_date": display_date.isoformat()
            }

            # Upsert based on display_date
            supabase.table('daily_columns').upsert(data, on_conflict='display_date').execute()
                
        except Exception as e:
            print(f"Error upserting daily art {art.get('title')}: {e}")

    print("Daily art seeding completed.")

if __name__ == "__main__":
    main()
