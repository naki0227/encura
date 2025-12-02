-- Create venues table
CREATE TABLE IF NOT EXISTS venues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    location GEOGRAPHY(POINT),
    website_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for venues
ALTER TABLE venues ENABLE ROW LEVEL SECURITY;

-- Public read access for venues
CREATE POLICY "Public read access" ON venues
    FOR SELECT USING (true);

-- Add venue_id to events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES venues(id);

-- Update venue_maps to reference venue_id instead of event_id
-- First, add the column
ALTER TABLE venue_maps ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES venues(id);

-- (Optional) Migration logic: If we had data, we'd want to populate venue_id in events and venue_maps.
-- For now, we'll leave it as is, assuming the crawler will populate new data correctly.

-- Make venue_id nullable for now to avoid breaking existing rows, 
-- but ideally it should be NOT NULL after migration.

-- Update venue_maps RLS if needed (it was public read, so it's fine)
