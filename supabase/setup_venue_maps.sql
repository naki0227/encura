-- Create venue_maps table
CREATE TABLE IF NOT EXISTS venue_maps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE venue_maps ENABLE ROW LEVEL SECURITY;

-- Create policy to allow public read access
CREATE POLICY "Public read access" ON venue_maps
    FOR SELECT USING (true);

-- Create policy to allow authenticated insert (or public if anon key is used for upload)
-- For now, allowing anon insert for simplicity as per requirements, but ideally should be authenticated.
CREATE POLICY "Anon insert access" ON venue_maps
    FOR INSERT WITH CHECK (true);

-- Storage Bucket Setup (Note: This might need to be done via dashboard if SQL doesn't support it directly in all environments, but trying here)
INSERT INTO storage.buckets (id, name, public)
VALUES ('venue_maps', 'venue_maps', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies
CREATE POLICY "Public Access" ON storage.objects
  FOR SELECT USING (bucket_id = 'venue_maps');

CREATE POLICY "Anon Upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'venue_maps');
