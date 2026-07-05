-- ============================================================================
-- Cheers — initial schema
-- ----------------------------------------------------------------------------
-- Apply via one of:
--   • Supabase Dashboard → SQL Editor → paste this file → Run
--   • Supabase CLI:  supabase db push        (from repo root)
--
-- Field names/enums mirror the Dart models in `lib/models/*.dart` so the
-- Supabase client can map rows straight to `Trip`, `Poi`, `ItineraryStop`.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Extensions
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;
-- PostGIS is on the PRD roadmap; skipped here to keep MVP light. Add it once
-- you need spatial queries (e.g. "POIs within 500 m of the anchor").
-- create extension if not exists postgis;


-- ---------------------------------------------------------------------------
-- 2. Enums (match Flutter enums)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.poi_category as enum ('accommodation','dining','sightseeing','nightlife');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.trip_mode as enum ('solo','group');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.member_role as enum ('owner','member');
exception when duplicate_object then null; end $$;


-- ---------------------------------------------------------------------------
-- 3. profiles  (one row per auth.users, auto-created on sign-up)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------------
-- 4. pois
-- ---------------------------------------------------------------------------
create table if not exists public.pois (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  category          public.poi_category not null,
  lat               double precision not null,
  lng               double precision not null,
  address           text,
  rating            numeric(3,2) default 4.5,
  avg_visit_minutes integer not null default 60,
  opens_at          smallint not null default 9,
  closes_at         smallint not null default 22,
  blurb             text not null default '',
  created_at        timestamptz not null default now()
);

create index if not exists pois_category_idx on public.pois (category);


-- ---------------------------------------------------------------------------
-- 5. Trip join codes  (short, human-shareable, unambiguous alphabet)
-- ---------------------------------------------------------------------------
create or replace function public.generate_trip_code(len integer default 6)
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';  -- no 0/O/1/I/L
  code text := '';
  i integer;
begin
  for i in 1..len loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return code;
end;
$$;


-- ---------------------------------------------------------------------------
-- 6. trips
-- ---------------------------------------------------------------------------
create table if not exists public.trips (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references auth.users(id) on delete cascade,
  name           text not null,
  city           text not null,
  mode           public.trip_mode not null default 'solo',
  start_date     date not null,
  end_date       date not null,
  anchor_poi_id  uuid references public.pois(id) on delete set null,
  cover_gradient smallint not null default 0,
  join_code      text unique,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint trips_dates_check check (end_date >= start_date)
);

create index if not exists trips_owner_idx on public.trips (owner_id);

-- Auto-assign a unique join_code before insert; widen the alphabet after
-- 10 collisions (astronomically unlikely with 6 chars @ 31 symbols = ~887M).
create or replace function public.set_trip_join_code()
returns trigger
language plpgsql
as $$
declare
  candidate text;
  attempts  integer := 0;
begin
  if new.join_code is not null and new.join_code <> '' then
    new.join_code := upper(new.join_code);
    return new;
  end if;
  loop
    candidate := public.generate_trip_code(6);
    exit when not exists (select 1 from public.trips where join_code = candidate);
    attempts := attempts + 1;
    if attempts > 10 then
      candidate := public.generate_trip_code(8);
      exit;
    end if;
  end loop;
  new.join_code := candidate;
  return new;
end;
$$;

drop trigger if exists trips_set_join_code on public.trips;
create trigger trips_set_join_code
  before insert on public.trips
  for each row execute function public.set_trip_join_code();

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trips_touch_updated_at on public.trips;
create trigger trips_touch_updated_at
  before update on public.trips
  for each row execute function public.touch_updated_at();


-- ---------------------------------------------------------------------------
-- 7. trip_members  (many-to-many: users <-> trips)
-- ---------------------------------------------------------------------------
create table if not exists public.trip_members (
  trip_id   uuid not null references public.trips(id) on delete cascade,
  user_id   uuid not null references auth.users(id)   on delete cascade,
  role      public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

create index if not exists trip_members_user_idx on public.trip_members (user_id);

-- Owner is automatically the first member (runs as definer so RLS on
-- trip_members doesn't block the insert).
create or replace function public.add_owner_as_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.trip_members (trip_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trips_owner_membership on public.trips;
create trigger trips_owner_membership
  after insert on public.trips
  for each row execute function public.add_owner_as_member();


-- ---------------------------------------------------------------------------
-- 8. bucket_list_items
-- ---------------------------------------------------------------------------
create table if not exists public.bucket_list_items (
  trip_id  uuid not null references public.trips(id) on delete cascade,
  poi_id   uuid not null references public.pois(id)  on delete cascade,
  added_by uuid references auth.users(id) on delete set null,
  added_at timestamptz not null default now(),
  primary key (trip_id, poi_id)
);


-- ---------------------------------------------------------------------------
-- 9. itinerary_stops
-- ---------------------------------------------------------------------------
create table if not exists public.itinerary_stops (
  id                uuid primary key default gen_random_uuid(),
  trip_id           uuid not null references public.trips(id) on delete cascade,
  poi_id            uuid not null references public.pois(id)  on delete cascade,
  day_number        integer not null check (day_number >= 1),
  sequence_order    integer not null,
  added_by          uuid references auth.users(id) on delete set null,
  planned_arrival   timestamptz,
  planned_departure timestamptz,
  votes             integer not null default 0,
  created_at        timestamptz not null default now(),
  unique (trip_id, day_number, sequence_order)
);

create index if not exists itinerary_stops_trip_idx
  on public.itinerary_stops (trip_id, day_number, sequence_order);


-- ---------------------------------------------------------------------------
-- 10. messages  (group chat — P1 from the PRD)
-- ---------------------------------------------------------------------------
create table if not exists public.messages (
  id            uuid primary key default gen_random_uuid(),
  trip_id       uuid not null references public.trips(id) on delete cascade,
  sender_id     uuid not null references auth.users(id) on delete cascade,
  body          text,
  shared_poi_id uuid references public.pois(id) on delete set null,
  created_at    timestamptz not null default now(),
  check (body is not null or shared_poi_id is not null)
);

create index if not exists messages_trip_idx on public.messages (trip_id, created_at);


-- ---------------------------------------------------------------------------
-- 11. RPC: join_trip_with_code
-- ----------------------------------------------------------------------------
-- The joiner isn't a member yet, so RLS on `trips` would hide the row. This
-- function runs as SECURITY DEFINER, looks up the trip by its code, inserts
-- a membership row, and returns the trip id.
-- ---------------------------------------------------------------------------
create or replace function public.join_trip_with_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip_id uuid;
  v_user    uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select id into v_trip_id
  from public.trips
  where join_code = upper(trim(p_code));

  if v_trip_id is null then
    raise exception 'No trip found for code %', p_code
      using errcode = 'P0002';
  end if;

  insert into public.trip_members (trip_id, user_id, role)
  values (v_trip_id, v_user, 'member')
  on conflict do nothing;

  return v_trip_id;
end;
$$;

grant execute on function public.join_trip_with_code(text) to authenticated;


-- ---------------------------------------------------------------------------
-- 12. Realtime — enable change-streams for co-planners
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'trips',
    'trip_members',
    'bucket_list_items',
    'itinerary_stops',
    'messages'
  ]
  loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I', t
      );
    exception when duplicate_object then
      null;  -- already in the publication; ignore
    end;
  end loop;
end $$;


-- ---------------------------------------------------------------------------
-- 13. Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.pois              enable row level security;
alter table public.trips             enable row level security;
alter table public.trip_members      enable row level security;
alter table public.bucket_list_items enable row level security;
alter table public.itinerary_stops   enable row level security;
alter table public.messages          enable row level security;

-- Helper: SECURITY DEFINER so it can query trip_members without triggering
-- RLS recursion when a trip_members policy references it.
create or replace function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trip_members
    where trip_id = p_trip_id and user_id = auth.uid()
  );
$$;

grant execute on function public.is_trip_member(uuid) to authenticated;


-- profiles --------------------------------------------------------------------
drop policy if exists profiles_read_all   on public.profiles;
drop policy if exists profiles_update_own on public.profiles;

create policy profiles_read_all on public.profiles
  for select to authenticated using (true);

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());


-- pois ------------------------------------------------------------------------
-- Read: any authed user (POI catalog is shared).
-- Insert: any authed user (users can add custom pins). Tighten later if needed.
drop policy if exists pois_read_all   on public.pois;
drop policy if exists pois_insert_all on public.pois;

create policy pois_read_all on public.pois
  for select to authenticated using (true);

create policy pois_insert_all on public.pois
  for insert to authenticated with check (true);


-- trips -----------------------------------------------------------------------
drop policy if exists trips_select_member on public.trips;
drop policy if exists trips_insert_self   on public.trips;
drop policy if exists trips_update_owner  on public.trips;
drop policy if exists trips_delete_owner  on public.trips;

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


-- trip_members ----------------------------------------------------------------
drop policy if exists trip_members_select        on public.trip_members;
drop policy if exists trip_members_owner_modify  on public.trip_members;
drop policy if exists trip_members_leave         on public.trip_members;

create policy trip_members_select on public.trip_members
  for select to authenticated
  using (public.is_trip_member(trip_id));

-- Owner can add/remove members directly. (Self-join uses the RPC instead.)
create policy trip_members_owner_modify on public.trip_members
  for all to authenticated
  using (
    exists (select 1 from public.trips t
            where t.id = trip_id and t.owner_id = auth.uid())
  )
  with check (
    exists (select 1 from public.trips t
            where t.id = trip_id and t.owner_id = auth.uid())
  );

-- Any member can leave (delete their own row).
create policy trip_members_leave on public.trip_members
  for delete to authenticated
  using (user_id = auth.uid());


-- bucket_list_items -----------------------------------------------------------
drop policy if exists bucket_list_select on public.bucket_list_items;
drop policy if exists bucket_list_insert on public.bucket_list_items;
drop policy if exists bucket_list_delete on public.bucket_list_items;

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


-- itinerary_stops -------------------------------------------------------------
drop policy if exists itin_select on public.itinerary_stops;
drop policy if exists itin_insert on public.itinerary_stops;
drop policy if exists itin_update on public.itinerary_stops;
drop policy if exists itin_delete on public.itinerary_stops;

create policy itin_select on public.itinerary_stops
  for select to authenticated
  using (public.is_trip_member(trip_id));

create policy itin_insert on public.itinerary_stops
  for insert to authenticated
  with check (
    public.is_trip_member(trip_id)
    and (added_by is null or added_by = auth.uid())
  );

create policy itin_update on public.itinerary_stops
  for update to authenticated
  using (public.is_trip_member(trip_id))
  with check (public.is_trip_member(trip_id));

create policy itin_delete on public.itinerary_stops
  for delete to authenticated
  using (public.is_trip_member(trip_id));


-- messages --------------------------------------------------------------------
drop policy if exists msg_select     on public.messages;
drop policy if exists msg_insert     on public.messages;
drop policy if exists msg_delete_own on public.messages;

create policy msg_select on public.messages
  for select to authenticated
  using (public.is_trip_member(trip_id));

create policy msg_insert on public.messages
  for insert to authenticated
  with check (
    public.is_trip_member(trip_id) and sender_id = auth.uid()
  );

create policy msg_delete_own on public.messages
  for delete to authenticated
  using (sender_id = auth.uid());


-- ============================================================================
-- Done.
-- Verify with:
--   select id, name, join_code from public.trips;
--   select public.join_trip_with_code('ABC123');
-- ============================================================================
