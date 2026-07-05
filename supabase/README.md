# Supabase — Cheers backend

This folder holds the SQL you need to spin up the Cheers backend on Supabase.

## What's in the schema

| Table | Purpose |
|---|---|
| `profiles` | 1-per-user row, auto-created from `auth.users` |
| `pois` | Points of interest (shared catalog) |
| `trips` | A planned trip; carries a short `join_code` for sharing |
| `trip_members` | Which users belong to which trip |
| `bucket_list_items` | POIs saved to a trip |
| `itinerary_stops` | Generated day-by-day plan |
| `messages` | Group chat (P1) |

Plus a few helpers:

- `generate_trip_code(len)` — 6-char code from an unambiguous alphabet (no 0/O/1/I/L).
- `set_trip_join_code` trigger — assigns a unique code on every new trip.
- `add_owner_as_member` trigger — the creator is auto-added to `trip_members` as `owner`.
- `is_trip_member(trip_id)` — used by RLS policies so members can read/write trip data.
- `join_trip_with_code(code)` — RPC that lets any signed-in user join a trip by pasting its code.

## Migrations

Apply in filename order. Each is idempotent — re-runs are safe.

| File | What it does |
|---|---|
| `20260705120000_init.sql`            | Tables, triggers, base RLS policies, realtime publication |
| `20260705140000_create_trip_rpc.sql` | `create_trip` `SECURITY DEFINER` RPC + defensive re-create of `trips` policies (works around partial-apply gaps in the init) |
| `20260705150000_bucket_list_sync.sql`| Retypes `bucket_list_items.poi_id` and `trips.anchor_poi_id` to `text` so the client can persist arbitrary POI ids, re-creates bucket policies, enables `REPLICA IDENTITY FULL` for full realtime payloads, adds `set_trip_anchor` RPC |
| `20260705160000_seed_real_pois.sql`  | Seeds `public.pois` with real Barcelona POIs pulled from the Mapbox Search Box API. Regenerate with `python3 scripts/seed_pois.py > supabase/migrations/20260705160000_seed_real_pois.sql` |
| `20260705170000_place_details_columns.sql` | Adds `fsq_id`, `review_count`, `photos jsonb`, and `enriched_at` columns to `public.pois` so the app can render hero images and rating chips |
| `20260705180000_enrich_pois.sql`     | Enrichment `UPDATE`s pulled from Foursquare Places (rating, review count, up to 5 photos per POI). Ships as a placeholder until you regenerate it locally with `FOURSQUARE_API_KEY=... python3 scripts/enrich_pois.py > supabase/migrations/20260705180000_enrich_pois.sql` |

### Option A — Dashboard (fastest)

1. Open the [Supabase SQL Editor](https://supabase.com/dashboard/project/hsyhldsqcyaoigdexwgp/sql/new).
2. Paste each migration file in order and hit **Run**.

### Option B — Supabase CLI

```bash
brew install supabase/tap/supabase
supabase link --project-ref hsyhldsqcyaoigdexwgp
supabase db push
```

## Joining a trip from the client

```dart
// After the user signs in:
final tripId = await Supabase.instance.client
    .rpc('join_trip_with_code', params: {'p_code': 'ABC123'});
```

The RPC:
- validates the caller is signed in,
- looks up the trip by code (case-insensitive, trims whitespace),
- inserts a `trip_members` row if the user isn't already a member,
- returns the trip UUID.

Once joined, standard RLS lets the user see the trip, its bucket list, itinerary, and messages.

## Security notes

- The `sb_secret_…` / service_role key MUST NOT ship in the Flutter client. Only the `sb_publishable_…` (anon) key belongs in `.env`.
- `pois` is world-writable-by-authed-users for MVP simplicity. Tighten this before public launch.
- `join_trip_with_code` is `SECURITY DEFINER` — that's intentional (the joiner can't `SELECT` the trip before joining, so RLS would otherwise hide it). It only inserts a membership row for the *calling* `auth.uid()`, so it can't be abused to add other users.
