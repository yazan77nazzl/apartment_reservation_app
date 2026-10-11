-- Run in your Supabase project's SQL Editor after enabling the Firebase
-- third-party auth integration for apartment-reservation-ap-d7a35.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('housing-images', 'housing-images', true, 8388608,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Firebase UIDs are strings, not UUIDs: use auth.jwt()->>'sub', not auth.uid().
-- Firebase tokens without a role claim run as anon. Policies deliberately
-- cover anon AND authenticated, but only a verified token from OUR Firebase
-- project with the matching UID grants access. An anonymous API key fails.
create or replace function public.housing_image_upload_allowed(object_name text)
returns boolean language sql stable security invoker
set search_path = ''
as $$
  select coalesce(
    auth.jwt()->>'iss' = 'https://securetoken.google.com/apartment-reservation-ap-d7a35'
    and auth.jwt()->>'aud' = 'apartment-reservation-ap-d7a35'
    and length(auth.jwt()->>'sub') > 0
    and (storage.foldername(object_name))[2] = auth.jwt()->>'sub'
    and (
      ((storage.foldername(object_name))[1] = 'profiles'
        and cardinality(storage.foldername(object_name)) = 2)
      or
      ((storage.foldername(object_name))[1] = 'apartments'
        and cardinality(storage.foldername(object_name)) = 3
        and (storage.foldername(object_name))[3] ~ '^[A-Za-z0-9_-]+$')
    )
    and storage.filename(object_name) ~ '^[0-9]+-[a-f0-9]{32}[.](jpg|png|webp)$',
    false);
$$;

drop policy if exists "housing_images_insert_own" on storage.objects;
create policy "housing_images_insert_own"
on storage.objects for insert to anon, authenticated
with check (bucket_id = 'housing-images'
            and public.housing_image_upload_allowed(name));

drop policy if exists "housing_images_select_own" on storage.objects;
create policy "housing_images_select_own"
on storage.objects for select to anon, authenticated
using (bucket_id = 'housing-images'
       and public.housing_image_upload_allowed(name));

-- No client UPDATE/DELETE policy and x-upsert=false: existing photos cannot
-- be overwritten. Public delivery is intentional for listing/profile photos.
commit;
