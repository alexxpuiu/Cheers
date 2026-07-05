-- ============================================================================
-- Cheers — bucket list sync (text POI ids + set_trip_anchor RPC)
-- ----------------------------------------------------------------------------
-- Apply after `20260705140000_create_trip_rpc.sql`.
--
-- The mobile client currently uses a hand-curated `MockPois` catalog whose
-- ids are strings like "p1" — they never map to `public.pois.id` (uuid).
-- So `bucket_list_items.poi_id` (uuid FK to `pois`) could never accept
-- what the client was sending, which is why the bucket list wasn't syncing
-- for anyone. We trade referential integrity for the ability to persist
-- what the client actually has today. When the mobile client switches to
-- the Supabase POI catalog, we'll add the FK back with a data migration.
--
-- What this migration does:
--   1. Retype `bucket_list_items.poi_id` and `trips.anchor_poi_id` to text,
--      dropping the FKs to `public.pois`.
--   2. Nuke-and-recreate RLS on `bucket_list_items` so members can read/
--      insert/delete items on trips they belong to.
--   3. Add `set_trip_anchor(trip_id, poi_ext_id)` — a SECURITY DEFINER RPC
--      that lets any trip member set the anchor (and auto-adds it to the
--      bucket list). Owner-only RLS on `trips` would block a non-owner
--      member otherwise, and we want the anchor to be a shared setting.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Retype poi identifiers to text.
-- ---------------------------------------------------------------------------
alter table public.bucket_list_items
  drop constraint if exists bucket_list_items_poi_id_fkey;

alter table public.bucket_list_items
  alter column poi_id type text using poi_id::text;

alter table public.trips
  drop constraint if exists trips_anchor_poi_id_fkey;

alter table public.trips
  alter column anchor_poi_id type text using anchor_poi_id::text;


-- ---------------------------------------------------------------------------
-- 2. Bulletproof RLS on bucket_list_items (drop all, recreate the canonical
--    three). Same defensive nuke pattern as the trips migration since we've
--    seen Studio-edited projects lose specific named policies.
-- ---------------------------------------------------------------------------
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'bucket_list_items'
  loop
    execute format(
      'drop policy if exists %I on public.bucket_list_items',
      pol.policyname
    );
  end loop;
end $$;

create policy bucket_list_select on public.bucket_list_items
  for select to authenticated
  using (public.is_trip_member(trip_id));

create policy bucket_list_insert on public.bucket_list_items
  for insert to authenticated
  with check (
    public.is_trip_member(trip_id)
    and (added_by is null or added_by = auth.uid())
  );

create policy bucket_list_delete on public.bucket_list_items
  for delete to authenticated
  using (public.is_trip_member(trip_id));


-- ---------------------------------------------------------------------------
-- 3. Full-row realtime payloads so DELETE events carry the `poi_id` and
--    UPDATE events carry the previous `anchor_poi_id`. Without this the
--    client only receives primary-key columns on UPDATE/DELETE.
-- ---------------------------------------------------------------------------
alter table public.bucket_list_items replica identity full;
alter table public.trips             replica identity full;


-- ---------------------------------------------------------------------------
-- 4. set_trip_anchor RPC — any member can pin the accommodation. Runs as
--    SECURITY DEFINER so it side-steps the owner-only UPDATE policy on
--    `trips` while still enforcing membership itself.
-- ---------------------------------------------------------------------------
create or replace function public.set_trip_anchor(
  p_trip_id     uuid,
  p_poi_ext_id  text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip' using errcode = '42501';
  end if;

  update public.trips
     set anchor_poi_id = p_poi_ext_id,
         updated_at    = now()
   where id = p_trip_id;

  if p_poi_ext_id is not null then
    insert into public.bucket_list_items (trip_id, poi_id, added_by)
    values (p_trip_id, p_poi_ext_id, v_user)
    on conflict (trip_id, poi_id) do nothing;
  end if;
end;
$$;

grant execute on function public.set_trip_anchor(uuid, text) to authenticated;


-- ============================================================================
-- Done.
-- ============================================================================
