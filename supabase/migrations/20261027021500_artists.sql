-- Artists: who painted the works in the library, and who the movements
-- are about. Read-only for clients like the other content tables; rows arrive
-- as content migrations (scripts/content/build_migration.py checks that the
-- source page names the artist).
--
-- `name` is written exactly as in artworks.artist, so the app joins on it.
-- `short_name` is how exhibitions usually call the artist ("モネ", "北斎");
-- the app uses it to find exhibitions where their works can be seen.
-- `movement_slugs` places artists whose works are not in the library
-- (still under copyright) in the movements they belong to.
create table public.artists (
    name text primary key,
    name_en text not null,
    short_name text,
    born integer,
    died integer,
    region text not null check (region in ('west', 'japan', 'east_asia')),
    movement_slugs text[] not null default '{}',
    summary text not null,
    body text not null,
    source_url text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint artists_years check (born is null or died is null or died >= born)
);

alter table public.artists enable row level security;

create policy "Public read" on public.artists for select using (true);
