-- Art knowledge: movements, how they connect, and public-domain artworks.
--
-- Read-only for clients, like the other content tables. Rows arrive as
-- content migrations written by scripts/content/build_migration.py, which
-- checks each movement against its source page and each artwork against
-- Wikidata/Commons (image credited to the same artist).

-- Movements (styles, schools, periods) ------------------------------------------
create table public.art_movements (
    slug text primary key check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    name_ja text not null,
    name_en text not null,
    region text not null check (region in ('west', 'japan', 'east_asia')),
    start_year integer not null,
    end_year integer,
    summary text not null,
    body text not null,
    source_url text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint art_movements_years check (end_year is null or end_year >= start_year)
);

create index art_movements_start_year on public.art_movements (start_year);

-- How movements connect -------------------------------------------------------------
-- led_to: grew out of the earlier one; reaction: rose against it;
-- influence: carried across time or regions (e.g. ukiyo-e -> impressionism).
create table public.movement_links (
    id uuid primary key default gen_random_uuid(),
    from_slug text not null references public.art_movements(slug) on delete cascade,
    to_slug text not null references public.art_movements(slug) on delete cascade,
    kind text not null check (kind in ('led_to', 'reaction', 'influence')),
    note text not null,
    created_at timestamptz not null default now(),
    constraint movement_links_pair unique (from_slug, to_slug),
    constraint movement_links_not_self check (from_slug <> to_slug)
);

create index movement_links_to_slug on public.movement_links (to_slug);

-- Public-domain artworks ----------------------------------------------------------
create table public.artworks (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    title_en text,
    artist text not null,
    artist_en text,
    year integer,
    movement_slug text references public.art_movements(slug) on delete set null,
    collection text,
    image_url text not null,
    content text not null,
    created_at timestamptz not null default now(),
    constraint artworks_title_artist unique (title, artist)
);

create index artworks_movement_slug on public.artworks (movement_slug);
create index artworks_artist on public.artworks (artist);

alter table public.art_movements enable row level security;
alter table public.movement_links enable row level security;
alter table public.artworks enable row level security;

create policy "Public read" on public.art_movements for select using (true);
create policy "Public read" on public.movement_links for select using (true);
create policy "Public read" on public.artworks for select using (true);
