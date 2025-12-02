-- 1. 一度テーブルを削除
DROP TABLE IF EXISTS trending_articles;

-- 2. エラーに出ているカラム名をすべて網羅して再作成
CREATE TABLE trending_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    
    -- エラーで要求されたカラム
    summary TEXT,           -- 概要
    image_url TEXT,         -- サムネイル画像
    source_url TEXT,        -- 元記事URLなど
    published_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- 仕様書やアプリ側で必要になる可能性が高いカラム
    keyword TEXT,           -- トレンドキーワード
    content TEXT,           -- 詳細本文
    
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. データ投入（新しいカラム名に合わせて修正済み）
INSERT INTO trending_articles (title, summary, image_url, keyword, content, is_published, published_at)
VALUES (
    '【急上昇】なぜ今、「明治の超絶技巧」が熱いのか？',
    'SNSで話題の明治工芸。その精緻な技術は現代でも再現困難と言われています。',
    'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Twelve_Bronze_Falcons_by_Suzuki_Chokichi.jpg/640px-Twelve_Bronze_Falcons_by_Suzuki_Chokichi.jpg',
    '超絶技巧',
    '最近、SNSで話題の「明治の工芸」。その精緻な技術は、現代の3Dプリンタですら再現不可能と言われています。特に注目すべきは正阿弥勝義や鈴木長吉といった作家たちです...',
    TRUE,
    NOW()
);
