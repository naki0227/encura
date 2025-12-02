-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prefecture_code VARCHAR(2), -- 居住地
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Sessions Table
CREATE TABLE chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT, -- 自動生成される会話タイトル
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat Messages Table
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('user', 'model')),
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Events Table (PostGIS)
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    venue TEXT,
    location GEOGRAPHY(POINT), -- 緯度経度
    start_date DATE,
    end_date DATE,
    description_json JSONB,
    source_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trending Articles Table
CREATE TABLE trending_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    summary TEXT,
    image_url TEXT,
    source_url TEXT,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Policies (Templates)

-- Users: Users can only access their own data
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view own data" ON users FOR SELECT USING (auth.uid() = id);
-- CREATE POLICY "Users can update own data" ON users FOR UPDATE USING (auth.uid() = id);

-- Chat Sessions: Users can only access their own sessions
-- ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view own sessions" ON chat_sessions FOR SELECT USING (auth.uid() = user_id);
-- CREATE POLICY "Users can insert own sessions" ON chat_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Chat Messages: Users can only access messages from their sessions
-- ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view own messages" ON chat_messages FOR SELECT USING (
--   EXISTS (SELECT 1 FROM chat_sessions WHERE id = session_id AND user_id = auth.uid())
-- );

-- Events: Publicly readable
-- ALTER TABLE events ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Events are public" ON events FOR SELECT USING (true);

-- Trending Articles: Publicly readable
-- ALTER TABLE trending_articles ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Trending articles are public" ON trending_articles FOR SELECT USING (true);
