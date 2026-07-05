-- ============================================================================
-- Cheers — create_trip RPC + trips policy hardening
-- ----------------------------------------------------------------------------
-- Apply after `20260705120000_init.sql`.
--
-- Why this exists:
-- • On production Supabase projects we've seen `trips` INSERT fail with
--   42501 ("new row violates row-level security policy") even when
--   `auth.uid()` clearly matches `owner_id` and the same JWT can happily
--   INSERT into `pois` and UPDATE its own `profiles` row. The most common
--   cause is a partially applied init migration (Studio tab closed mid-run,
--   SQL Editor truncated the paste) or later manual policy edits that
--   removed `trips_insert_self` without recreating it. Users are stuck.
--
-- Two-pronged fix:
--   1. Force-drop ALL existing policies on `public.trips` and recreate the
--      canonical four. `drop policy if exists <name>` in the init file only
--      helps when the policy has the *exact* name we chose, so we iterate
--      `pg_policies` instead.
--   2. Add `public.create_trip(...)` — a SECURITY DEFINER RPC that inserts
--      the row with `owner_id := auth.uid()` and returns the fresh trip.
--      Definer functions bypass RLS on the target table, so trip creation
--      keeps working even if the trips policies later drift again.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Nuke every existing policy on `public.trips`, then re-create ours.
-- ---------------------------------------------------------------------------
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'trips'
  loop
    execute format('drop policy if exists %I on public.trips', pol.policyname);
  end loop;
end $$;

create policy trips_select_member on public.trips
  for select to authenticated
  using (public.is_trip_member(id));

create policy trips_insert_self on public.trips
  for insert to authenticated
  with check (owner_id = auth.uid());

create policy trips_update_owner on public.trips
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy trips_delete_owner on public.trips
  for delete to authenticated
  using (owner_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 2. `create_trip` RPC — SECURITY DEFINER, so it doesn't care about the
--    caller-facing RLS on `trips`. It authenticates via `auth.uid()`, sets
--    owner_id itself, and returns the fully hydrated row (including the
--    trigger-generated join_code).
-- ---------------------------------------------------------------------------
create or replace function public.create_trip(
  p_name           text,
  p_city           text,
  p_mode           public.trip_mode,
  p_start_date     date,
  p_end_date       date,
  p_cover_gradient smallint default 0
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_trip public.trips;
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if p_end_date < p_start_date then
    raise exception 'end_date (%) must be on or after start_date (%)',
      p_end_date, p_start_date
      using errcode = '22007';
  end if;

  insert into public.trips (
    owner_id, name, city, mode, start_date, end_date, cover_gradient
  ) values (
    v_user,
    coalesce(nullif(trim(p_name), ''), 'New trip'),
    coalesce(nullif(trim(p_city), ''), 'Barcelona'),
    p_mode,
    p_start_date,
    p_end_date,
    coalesce(p_cover_gradient, 0)
  )
  returning * into v_trip;

  return v_trip;
end;
$$;

grant execute on function public.create_trip(
  text, text, public.trip_mode, date, date, smallint
) to authenticated;


-- ============================================================================
-- Verify with (as a signed-in user):
--   select * from public.create_trip(
--     'Weekend',              -- p_name
--     'Barcelona',            -- p_city
--     'solo',                 -- p_mode
--     current_date + 7,       -- p_start_date
--     current_date + 10       -- p_end_date
--   );
-- ============================================================================
