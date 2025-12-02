-- Seed dummy events
INSERT INTO events (title, venue, location, start_date, end_date, description_json, source_url)
VALUES
(
    'Impressionist Masterpieces',
    'National Museum of Western Art',
    ST_SetSRID(ST_MakePoint(139.7758, 35.7154), 4326), -- Ueno Park, Tokyo
    '2025-12-01',
    '2026-03-31',
    '{"summary": "A collection of Monet, Renoir, and Van Gogh."}',
    'https://www.nmwa.go.jp/'
),
(
    'Contemporary Art Now',
    'Mori Art Museum',
    ST_SetSRID(ST_MakePoint(139.7292, 35.6604), 4326), -- Roppongi Hills, Tokyo
    '2025-11-15',
    '2026-02-28',
    '{"summary": "Cutting-edge contemporary art from around the world."}',
    'https://www.mori.art.museum/'
),
(
    'Kyoto Traditional Crafts',
    'Kyoto National Museum',
    ST_SetSRID(ST_MakePoint(135.7730, 34.9900), 4326), -- Kyoto
    '2026-01-10',
    '2026-04-15',
    '{"summary": "Exquisite traditional crafts from Kyoto."}',
    'https://www.kyohaku.go.jp/'
);
