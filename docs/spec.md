プロジェクト仕様書：EnCura (P6) - Final Version

Project Name: EnCura (エンキュラ) Subtitle: Your Pocket AI Curator / ポケットの中の専属学芸員 Version: 3.0 (Ready for Dev) Date: 2025/12/01 Developer: Enludus


1. プロジェクト概要 (Executive Summary)

* プロダクト: 美術館内外でユーザーのアート体験を拡張する、対話型AI鑑賞パートナーアプリ。
* コアバリュー:
    * Museum Mode: カメラで作品をスキャンし、深い解説を提供（RAG）。
    * Home Mode: 自宅でもAIと美術談義ができ、トレンドや近隣のイベント情報を得られる。
* ビジネスモデル: 完全無料・広告なし。解説文脈における関連書籍・グッズのアフィリエイト収益モデル。

2. 技術スタック (Technical Stack)

完全無料・高機能・自動化 を実現する構成。
* IDE / Agent: Google Antigravity (AI Agent-driven Development)
* AI Model:
    * Gemini 2.5 Flash: リアルタイム応答（チャット、画像認識、JSON変換）。
    * Gemini 2.5 Pro: 高品質コラム生成（バッチ処理）。
* Frontend: Flutter (iOS / Android)
* Backend: Supabase Edge Functions (Serverless API)
* Database: Supabase (PostgreSQL)
    * PostGIS: 位置情報検索に使用。
    * pgvector: AI解説データのベクトル検索に使用。
* Automation: GitHub Actions (Crawler & Batch Jobs)

3. 機能要件 (Functional Requirements)


3.1. [Core] Anytime Curator (いつでも専属学芸員)

* 概要: 作品がない場所でも、AI学芸員とチャットが可能。
* Strict Domain Filter (厳格なドメイン制御):
    * 許可: 美術、歴史、文化、博物館、芸術家の伝記。
    * 拒否: 上記以外（天気、雑談、人生相談など）はシステムプロンプトで拒絶する。
* Context: 直近20ターンの会話履歴＋過去のスキャン履歴（長期記憶）を保持して対話する。

3.2. [Core] Scan & Guide

* 概要: カメラで作品をスキャンし、Gemini 2.5 Flash Visionで即座に解説。

3.3. [New] AI Event Hunter

* 概要: ユーザーの居住地周辺の展覧会情報を自動収集・レコメンド。
* 仕組み: GitHub Actionsがニュースサイトを巡回 → GeminiがJSON化 → Supabase(PostGIS)で位置情報検索。

3.4. [New] Trending Topics (トレンド・ピックアップ)

* 概要: SNS等で話題の作品（インフルエンサー紹介等）を、名前を出さずに「今、注目のアート」として深掘り解説する。
* 目的: 検索流入の受け皿作りと、ファンへの「わかってる感」の提供。

3.5. [New] Today's Art

* 概要: 毎日更新の「今日の一枚」。季節や画家の誕生日をトリガーに自動生成。アフィリエイト導線を含む。

3.6. [New] AI Map Memory
* 概要: ユーザーがスキャンした館内図をAIが検証し、自動的に共有データベースに蓄積する機能。
* 仕組み:
    * ユーザーが画像をスキャン。
    * Geminiが「これは地図か？」を判定。
    * 地図であれば自動的にSupabase Storageにアップロードし、`venue_maps`テーブルに登録。
    * 他のユーザーもその地図を参照・チャットで利用可能になる。

4. データベース設計 (Schema for Supabase)

Antigravityのエージェントに実装させるためのSQL定義概略。
SQL

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prefecture_code VARCHAR(2), -- 居住地
    settings JSONB DEFAULT '{}'::jsonb
);

-- Chat Sessions (Anytime Curator)
CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    title TEXT, -- 自動生成される会話タイトル
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Messages
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES chat_sessions(id),
    role TEXT CHECK (role IN ('user', 'model')),
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Events (PostGIS)
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    venue TEXT,
    location GEOGRAPHY(POINT), -- 緯度経度
    start_date DATE,
    end_date DATE,
    description_json JSONB,
    source_url TEXT
);

5. 開発開始プロンプト (Kick-off Prompt)

Antigravityを起動し、最初に以下のプロンプトを入力してください。

Prompt for Antigravity:
私は「EnCura (エンキュラ)」というFlutter製モバイルアプリを開発します。
【プロジェクト概要】 Supabase (PostgreSQL) をバックエンドに持ち、Google Gemini 2.5 APIを活用した「AI美術鑑賞パートナーアプリ」です。
【技術スタック】
* Frontend: Flutter
* Backend: Supabase (Auth, Database, Edge Functions)
* AI: google_generative_ai (Gemini 2.5 Flash)
* Map/Location: flutter_map, latlong2
【最初のタスク】
1. Flutterプロジェクトの基本ディレクトリ構成を作成してください。
2. pubspec.yaml に必要なパッケージ（supabase_flutter, google_generative_ai, flutter_markdown, provider 等）を追加してください。
3. Supabaseクライアントの初期化コード (lib/core/services/supabase_service.dart) を作成してください。
