#!/usr/bin/env python3
"""
Insert Raden's Hakone Glass Forest Museum article into trending_articles
"""
import os
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client, Client

# Load .env from project root
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

def main():
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not supabase_url or not supabase_key:
        print("Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.")
        return

    supabase: Client = create_client(supabase_url, supabase_key)

    # Check if article already exists
    existing = supabase.table('trending_articles').select('id').eq('title', '【らでん音声ガイド】箱根ガラスの森美術館「香りの装い～香水瓶をめぐる軌跡～」').execute()
    
    if existing.data:
        print("Article already exists, skipping.")
        return

    data = {
        "title": "【らでん音声ガイド】箱根ガラスの森美術館「香りの装い～香水瓶をめぐる軌跡～」",
        "summary": "学芸員VTuber・儒烏風亭らでんが音声ガイドを担当する特別企画展。3000年の香りの歴史を辿る。",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Ren%C3%A9_Lalique_-_Perfume_Bottle_-_Walters_47628_-_View_A.jpg/640px-Ren%C3%A9_Lalique_-_Perfume_Bottle_-_Walters_47628_-_View_A.jpg",
        "source_url": "https://www.hakone-garasunomori.jp/",
        "keyword": "VTuber×美術館",
        "content": "箱根ガラスの森美術館で開催中の特別企画展「香りの装い～香水瓶をめぐる軌跡～」では、学芸員資格を持つVTuber・儒烏風亭らでんさんが音声ガイドを担当しています。水晶や瑪瑙で制作された古代の香水瓶から、神話や愛を表現したアール・ヌーヴォー期の香水瓶まで、約80点が展示。会期は2025年1月13日まで。スマートフォンでQRコードを読み込むだけで、らでんさんの解説を無料で楽しめます。",
        "is_published": True
    }

    try:
        result = supabase.table('trending_articles').insert(data).execute()
        print("Article inserted successfully!")
        print(f"ID: {result.data[0]['id']}")
    except Exception as e:
        print(f"Error inserting article: {e}")

if __name__ == "__main__":
    main()
