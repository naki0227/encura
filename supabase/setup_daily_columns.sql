-- Create daily_columns table if it doesn't exist
CREATE TABLE IF NOT EXISTS daily_columns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    artist TEXT,
    image_url TEXT,
    content TEXT,
    display_date DATE UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert dummy data for today (or update if exists)
INSERT INTO daily_columns (title, artist, image_url, content, display_date)
VALUES
(
    '星月夜',
    'フィンセント・ファン・ゴッホ',
    'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/1280px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg',
    '『星月夜』（ほしづきよ、オランダ語: De sterrennacht）は、オランダのポスト印象派の画家フィンセント・ファン・ゴッホの代表作のひとつ。1889年6月、フランスのサン＝レミ＝ド＝プロヴァンスの精神病院に入院していた際に描かれた。東向きの窓から見える日の出前の村の風景に、想像上の村を加えた構成となっている。',
    CURRENT_DATE
)
ON CONFLICT (display_date) DO UPDATE SET
    title = EXCLUDED.title,
    artist = EXCLUDED.artist,
    image_url = EXCLUDED.image_url,
    content = EXCLUDED.content;
