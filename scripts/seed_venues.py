import os
import json
import google.generativeai as genai
from supabase import create_client, Client

def main():
    # 1. Configuration
    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if not gemini_api_key or not supabase_url or not supabase_key:
        print("Error: Missing environment variables.")
        print("Please ensure GEMINI_API_KEY, SUPABASE_URL, and SUPABASE_SERVICE_ROLE_KEY are set.")
        return

    genai.configure(api_key=gemini_api_key)
    supabase: Client = create_client(supabase_url, supabase_key)

    # 2. Prompt Gemini
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = """
    日本国内（東京、大阪、京都、愛知、金沢など）の主要な美術館・博物館を30ヶ所リストアップしてください。
    以下のJSON形式で出力してください。JSON以外の余計なテキストは含めないでください。

    JSON形式:
    [
      {
        "name": "美術館名",
        "address": "住所",
        "lat": 35.1234,
        "lon": 139.5678,
        "website_url": "https://example.com"
      }
    ]
    """

    print("Fetching venue data from Gemini...")
    try:
        response = model.generate_content(prompt)
        text = response.text
        # Clean up markdown code blocks if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        venues = json.loads(text.strip())
        print(f"Got {len(venues)} venues.")
    except Exception as e:
        print(f"Error fetching/parsing from Gemini: {e}")
        return

    # 3. Upsert to Supabase
    for venue in venues:
        try:
            print(f"Processing: {venue['name']}")
            
            # Check if venue exists by name
            existing_venue = supabase.table('venues').select('id').eq('name', venue['name']).execute()
            
            data = {
                "name": venue['name'],
                "address": venue['address'],
                "location": f"POINT({venue['lon']} {venue['lat']})", # PostGIS format
                "website_url": venue['website_url']
            }

            if existing_venue.data and len(existing_venue.data) > 0:
                # Update
                venue_id = existing_venue.data[0]['id']
                print(f"  Updating existing venue (ID: {venue_id})")
                supabase.table('venues').update(data).eq('id', venue_id).execute()
            else:
                # Insert
                print(f"  Inserting new venue")
                supabase.table('venues').insert(data).execute()
                
        except Exception as e:
            print(f"Error upserting venue {venue.get('name')}: {e}")

    print("Venue seeding completed.")

if __name__ == "__main__":
    main()
