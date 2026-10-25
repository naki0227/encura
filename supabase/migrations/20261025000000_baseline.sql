-- EnCura baseline schema (fresh project, 2026-10).
--
-- Replaces the hand-run scripts that used to live in supabase/*.sql.
-- Content rows are never written by the app: they arrive as content
-- migrations (supabase/migrations/*_content_*.sql) applied by CI, so every
-- table is read-only for clients except venue_maps, which signed-in
-- (anonymous) users may post to.

create extension if not exists postgis with schema extensions;

-- Venues ---------------------------------------------------------------------
create table public.venues (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    address text,
    location extensions.geography(point),
    website_url text,
    created_at timestamptz not null default now()
);

-- Exhibitions ----------------------------------------------------------------
create table public.events (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    venue text not null,
    venue_id uuid references public.venues(id) on delete set null,
    location extensions.geography(point),
    start_date date not null,
    end_date date not null,
    description_json jsonb,
    source_url text not null,
    created_at timestamptz not null default now(),
    constraint events_dates check (start_date <= end_date),
    constraint events_title_venue unique (title, venue)
);
create index events_end_date on public.events (end_date);
create index events_venue_id on public.events (venue_id);

-- Today's Art ----------------------------------------------------------------
create table public.daily_columns (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    artist text not null,
    image_url text not null default '',
    content text not null,
    display_date date not null unique,
    affiliate_url text,
    created_at timestamptz not null default now()
);

-- Art news and seasonal features ------------------------------------------------
create table public.trending_articles (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    summary text,
    image_url text not null default '',
    source_url text unique,
    published_at timestamptz not null default now(),
    keyword text,
    content text,
    is_published boolean not null default true,
    created_at timestamptz not null default now()
);
create index trending_articles_published on public.trending_articles (published_at desc) where is_published;

-- User-posted floor maps ---------------------------------------------------------
create table public.venue_maps (
    id uuid primary key default gen_random_uuid(),
    -- Ended exhibitions are kept, but if one is removed its maps stay with the venue.
    event_id uuid references public.events(id) on delete set null,
    venue_id uuid references public.venues(id) on delete cascade,
    image_url text not null,
    is_verified boolean not null default false,
    created_at timestamptz not null default now()
);
create index venue_maps_venue_id on public.venue_maps (venue_id);

-- Row level security -------------------------------------------------------------
alter table public.venues enable row level security;
alter table public.events enable row level security;
alter table public.daily_columns enable row level security;
alter table public.trending_articles enable row level security;
alter table public.venue_maps enable row level security;

create policy "Public read" on public.venues for select using (true);
create policy "Public read" on public.events for select using (true);
create policy "Public read" on public.daily_columns for select using (true);
create policy "Public read published" on public.trending_articles for select using (is_published);
create policy "Public read" on public.venue_maps for select using (true);
-- The app signs in anonymously first, so posts come from the authenticated role.
create policy "Signed-in users post maps" on public.venue_maps
    for insert to authenticated with check (true);

-- Storage for floor maps -----------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('venue_maps', 'venue_maps', true)
on conflict (id) do nothing;

create policy "Public read venue maps" on storage.objects
    for select using (bucket_id = 'venue_maps');
create policy "Signed-in users upload venue maps" on storage.objects
    for insert to authenticated with check (bucket_id = 'venue_maps');
