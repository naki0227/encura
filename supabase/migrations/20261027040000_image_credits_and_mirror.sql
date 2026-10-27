-- Image licenses and our own copies of the images.
--
-- Every image comes from Wikimedia Commons or a museum's open-access
-- collection. Public-domain and CC0 images need nothing, but CC BY / CC BY-SA
-- photos (often of sculptures and buildings) must credit the photographer:
-- the app shows image_credit and links image_page next to the image.
alter table public.artworks
    add column image_license text,
    add column image_credit text,
    add column image_page text;
alter table public.daily_columns
    add column image_license text,
    add column image_credit text,
    add column image_page text;
alter table public.trending_articles
    add column image_license text,
    add column image_credit text,
    add column image_page text;

-- Copies of the images, resized, so the app does not depend on Wikimedia
-- staying reachable (it rate-limits busy clients). Objects are named
-- <sha1 of image_url>.jpg and written only by the mirror workflow
-- (.github/workflows/mirror_images.yml) with the service role; anyone may
-- read them through the public URL. The app falls back to image_url when a
-- copy is missing.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('art-images', 'art-images', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;
