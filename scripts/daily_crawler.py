import os
import json
import datetime
import google.generativeai as genai
from supabase import create_client, Client

def main():
    # 1. Configuration
    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

    if not gemini_api_key or not supabase_url or not supabase_key:
        print("Error: Missing environment variables.")
        return

    genai.configure(api_key=gemini_api_key)
    supabase: Client = create_client(supabase_url, supabase_key)

    # 2. Prompt Gemini
    model = genai.GenerativeModel('gemini-2.5-flash')
    prompt = """
    現在、日本国内（東京・大阪中心）で開催中または開催予定の主要な美術展を20件ピックアップし、以下のJSON形式で出力してください。
    JSON以外の余計なテキストは含めないでください。

    JSON形式:
    [
      {
        "title": "展覧会名",
        "venue": "会場名",
        "start_date": "YYYY-MM-DD",
        "end_date": "YYYY-MM-DD",
        "description_json": "{\"summary\": \"展覧会の概要（100文字程度）\"}"
      }
    ]
    """

    print("Fetching events from Gemini...")
    try:
        response = model.generate_content(prompt)
        text = response.text
        # Clean up markdown code blocks if present
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        
        events = json.loads(text.strip())
        print(f"Got {len(events)} events.")
    except Exception as e:
        print(f"Error fetching/parsing from Gemini: {e}")
        return

    # 3. Upsert to Supabase
    for event in events:
        try:
            # --- Venue Handling ---
            venue_name = event['venue']
            venue_id = None
            
            # Check if venue exists
            existing_venue = supabase.table('venues').select('id').eq('name', venue_name).execute()
            
            if existing_venue.data and len(existing_venue.data) > 0:
                venue_id = existing_venue.data[0]['id']
                print(f"Found existing venue: {venue_name} ({venue_id})")
            else:
                # Insert new venue
                print(f"Inserting new venue: {venue_name}")
                new_venue = supabase.table('venues').insert({
                    'name': venue_name,
                    # 'address': ... # Gemini prompt doesn't ask for address yet, could add later
                }).execute()
                if new_venue.data:
                    venue_id = new_venue.data[0]['id']
            
            # --- Event Handling ---
            # We want to upsert based on title and venue to avoid duplicates.
            
            existing_event = supabase.table('events').select('id').eq('title', event['title']).eq('venue', event['venue']).execute()
            
            data = {
                "title": event['title'],
                "venue": event['venue'],
                "venue_id": venue_id, # Link to venue
                "start_date": event['start_date'],
                "end_date": event['end_date'],
                "description_json": json.loads(event['description_json']) if isinstance(event['description_json'], str) else event['description_json'],
            }

            if existing_event.data and len(existing_event.data) > 0:
                # Update
                event_id = existing_event.data[0]['id']
                print(f"Updating event: {event['title']}")
                supabase.table('events').update(data).eq('id', event_id).execute()
            else:
                # Insert
                print(f"Inserting event: {event['title']}")
                supabase.table('events').insert(data).execute()
                
        except Exception as e:
            print(f"Error upserting event {event.get('title')}: {e}")

if __name__ == "__main__":
    main()
