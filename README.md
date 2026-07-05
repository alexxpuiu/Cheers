# Cheers 🥂

A collaborative trip planner. Drop places on a map, hit **Generate**, and get a routed day-by-day plan anchored at your accommodation. Built in Flutter with a warm dusk-lit UI, soft aurora backdrop, and frosted-glass panels.

Based on the Cheers MVP PRD — this repo is the mobile/web front-end. State is kept locally (Riverpod) with a Barcelona POI seed so the whole flow runs offline. Swap in Supabase later per the PRD.

## What's inside

- **Home** — animated list of your trips
- **Create trip** — name / city / dates / Solo · Group toggle
- **Map canvas** — Mapbox tiles, category chips (Stay · Eat · See · Night), tap markers to add, set your stay as the anchor
- **Itinerary** — day tabs, timeline of stops, arrival times, category colouring
- Glassmorphism, staggered fades, cupertino page physics, shimmer on the primary CTA

## Prerequisites

- Flutter **≥ 3.27** with Dart **≥ 3.5**
- A Mapbox **public access token** (`pk.…`) — [account.mapbox.com/access-tokens](https://account.mapbox.com/access-tokens/)

The app degrades gracefully without a token: you'll see a stylised map backdrop with animated POI pins so the demo still works.

## First-time setup

This repo ships the Dart source, `pubspec.yaml`, and `web/`. Generate the iOS / Android platform folders once:

```bash
flutter create --platforms=ios,android,web --org com.cheers .
flutter pub get
```

`flutter create` will **not** overwrite existing files (`lib/`, `pubspec.yaml`, `web/index.html`).

### Mapbox — Android

Add your **secret** download token (`sk.…`, scope `DOWNLOADS:READ`) to `~/.gradle/gradle.properties`:

```
MAPBOX_DOWNLOADS_TOKEN=sk.your_secret_download_token
```

### Mapbox — iOS

Add the same secret token to `~/.netrc`:

```
machine api.mapbox.com
  login mapbox
  password sk.your_secret_download_token
```

Then run `cd ios && pod install`.

### Mapbox — location permissions

- `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`
- `ios/Runner/Info.plist`: add `NSLocationWhenInUseUsageDescription`.

## Running

Put your credentials in a `.env` file at the repo root:

```
MAPBOX_ACCESS_TOKEN=pk.your_public_token
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_publishable_key
```

A template lives at `.env.example` — copy it and drop your values in. The real
`.env` is gitignored and bundled into the app as a Flutter asset at build time
(see `flutter_dotenv` in `pubspec.yaml`).

> **Never** put the `sb_secret_…` / service_role key in `.env` — it bypasses
> Row Level Security and would ship inside the client bundle. Only the
> **publishable** (`sb_publishable_…`) key belongs here. If either Supabase
> value is missing the app still boots, just without the backend.

### Supabase schema

The database schema (trips, members, join codes, RLS policies) lives at
`supabase/migrations/20260705120000_init.sql`. Apply it once via the Supabase
Dashboard's SQL Editor, or `supabase db push` with the CLI. See
[`supabase/README.md`](supabase/README.md) for details.

Photos, star ratings, and review counts come from the **Foursquare Places
API** and are baked into `public.pois` by
`supabase/migrations/20260705180000_enrich_pois.sql`. That file ships as a
placeholder; regenerate it with a Foursquare key when you want live data:

```bash
export FOURSQUARE_API_KEY=fsq3...
python3 scripts/enrich_pois.py \
    > supabase/migrations/20260705180000_enrich_pois.sql
```

The Flutter client never talks to Foursquare directly — it just reads the
cached columns.

Then just run:

```bash
# iOS
flutter run

# Android
flutter run

# Web (Chrome)
flutter run -d chrome
```

`--dart-define=MAPBOX_ACCESS_TOKEN=…` is still honoured and, if set, takes
precedence over the `.env` value. Skip both to run against the fallback
stylised map.

## Project layout

```
lib/
├── main.dart               # entry — reads MAPBOX_ACCESS_TOKEN
├── app.dart                # go_router + custom page transitions
├── theme/                  # colour system + Inter/Playfair typography
├── widgets/
│   ├── aurora_background.dart   # slow drifting gradient blobs
│   └── glass.dart               # GlassContainer + GlassButton
├── models/                 # Trip, Poi, ItineraryStop
├── services/pois_repository.dart  # loads `public.pois` (Mapbox-seeded)
├── providers/              # Riverpod: trips, filters, itinerary generator
└── screens/
    ├── home_screen.dart
    ├── create_trip_screen.dart
    ├── map_screen.dart          # Mapbox + fallback backdrop
    └── itinerary_screen.dart
```

## Design notes

- **Palette** — deep-navy → plum → warm-coral gradient (dusk in Barceloneta), amber accent (`#FFB86B`).
- **Type** — Playfair Display for hero headings, Inter for everything else.
- **Motion** — everything transitions on `Curves.easeOutCubic`. Lists cascade with `flutter_animate`. Only the primary CTA is loud (gradient + shadow + shimmer); everything else stays quiet.
- **Glass** — `BackdropFilter` (σ 22) + ~12–20 % white fill + hairline border. Radii are 20 / 24 / 28 depending on prominence.

## Roadmap (from the PRD)

- Supabase (Postgres + PostGIS + Realtime) for auth, group chat, shared itinerary.
- Server-side itinerary generation via foundation-model Edge Function (this repo has the nearest-neighbour heuristic as a stand-in).
- Community-voted short video layer, VRPTW optimisation, real-time traffic, booking.
