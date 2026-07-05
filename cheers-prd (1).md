# Cheers — Product Requirements Document

| | |
|---|---|
| **Product** | Cheers |
| **Type** | Collaborative trip planner (mobile-first) |
| **Platform** | Flutter (iOS / Android; web build for demo hosting) |
| **Status** | Hackathon MVP — in build |
| **Team** | 3 engineers |
| **Date** | 5 July 2026 |
| **Version** | 0.1 (MVP) |

---

## 1. TL;DR

Cheers turns a loose list of places you want to visit into an optimized, day-by-day trip itinerary. Every trip starts as a **project** you create as **Solo** or **Group**. Solo is private planning; Group opens a shared space with chat, location sharing, and one collaborative itinerary the whole group builds together. Users drop places onto a map, hit **Generate**, and Cheers produces a routed daily plan anchored at their accommodation.

Built in Flutter for a one-day hackathon. The MVP proves the core loop: **create trip → add places → generate itinerary**. A crowdsourced short-video layer is planned but out of scope for this build.

---

## 2. Problem & Opportunity

Planning a trip means juggling a map, a listings site, a reviews site, and a group chat across several tabs, then manually working out what to do on which day so you're not crossing the city twice. Group trips make it worse: planning scatters across WhatsApp messages, screenshots, and shared notes that never become a real plan.

**Opportunity:** collapse discovery, collaboration, and scheduling into one canvas, where the group conversation and the actual itinerary are directly linked — sharing a place into the chat is one tap away from adding it to the plan.

---

## 3. Goals & Non-Goals

### Goals (this build)
- Prove the core loop: create a trip, add places to a map-based bucket list, generate a sensible day-by-day itinerary.
- Support the Solo/Group project model, with a working group chat + shared itinerary if time allows.
- Ship a live, demoable app by end of day.

### Non-Goals (this build)
- Full mathematical route optimization (VRPTW). A pragmatic generator is enough; the exact solver is roadmap.
- The community video/reel feature in any form.
- Booking, payments, or real-time traffic integration.
- Production-grade auth, GDPR tooling, or scale hardening.

---

## 4. Target Users

**Primary — the group trip organizer.** Plans trips for friends, currently herding everyone in a group chat. Wants one shared plan everyone can contribute to instead of chasing consensus across scattered messages.

**Secondary — the solo traveller.** Wants an efficient day plan for a city break without spending an evening cross-referencing a map and opening hours.

---

## 5. Scope Summary

| Feature | Priority | In this build? |
|---|---|---|
| Create trip as project (name, dates, city) | P0 | Yes |
| Solo vs Group mode selection | P0 | Yes |
| Map with categorized POI markers | P0 | Yes |
| Add/remove POIs to a bucket list | P0 | Yes |
| Set accommodation as trip anchor | P0 | Yes |
| Generate day-by-day itinerary | P0 | Yes |
| View itinerary (list + on map) | P0 | Yes |
| Group chat within a project | P1 | If time allows |
| Share a POI into chat → add to itinerary | P1 | If time allows |
| Collaborative live-editing of the itinerary | P1 | Stretch |
| Reorder / vote on itinerary stops | P2 | Stretch |
| Community-uploaded short videos on POIs | P3 | Roadmap only |
| Full VRPTW optimization | P3 | Roadmap only |

Priority key: **P0** = demo fails without it. **P1** = strongly wanted. **P2** = nice-to-have. **P3** = future.

---

## 6. Functional Requirements

**FR-1 — Trip creation.** A user can create a project with a name, destination city, and start/end dates. On creation they choose Solo or Group.

**FR-2 — Mode behaviour.** Solo projects are private to the owner. Group projects generate a shared space (chat + shared itinerary) and allow inviting members.

**FR-3 — Map canvas.** The project opens on a map centred on the destination city, showing POIs as markers colour-coded by category (Accommodation, Dining, Sightseeing, Nightlife). Categories can be toggled independently.

**FR-4 — Bucket list.** Users tap a marker to add it to the trip's bucket list (a persistent drawer). Items can be removed. The bucket list survives category toggling.

**FR-5 — Anchor.** One accommodation POI is designated the trip anchor; it becomes the start and end point of each day's route.

**FR-6 — Itinerary generation.** From the bucket list, the user triggers generation. The system returns a plan grouped by day, ordered within each day, starting and ending at the anchor, respecting opening hours and avoiding back-to-back same-category stops.

**FR-7 — Itinerary view.** The generated plan is shown as a per-day ordered list and drawn as a route on the map.

**FR-8 — Group chat (P1).** Members of a group project can exchange text messages in real time within the project.

**FR-9 — Share-to-plan (P1).** A member can share a POI into the chat; recipients get a one-tap action to add it to the shared bucket list / itinerary.

**FR-10 — Collaboration (stretch).** Changes to a group project's itinerary propagate live to all members.

---

## 7. User Flows

### 7.1 Solo flow (P0 — the core demo)
1. Open Cheers → **New Trip**.
2. Enter name, city, dates → choose **Solo**.
3. Land on the map for the chosen city.
4. Tap markers to add places to the bucket list; set one as accommodation.
5. Tap **Generate Itinerary**.
6. Review the day-by-day plan on the list and map. Done.

### 7.2 Group flow (P1)
1. **New Trip** → choose **Group** → invite friends.
2. Shared space opens: chat pane + map + shared itinerary.
3. Members drop pins and share POIs into the chat.
4. Anyone taps **Add to itinerary** on a shared POI.
5. Any member hits **Generate**; the shared plan updates live for everyone.

---

## 8. UX / Screens (MVP)

- **Home / My Trips** — list of the user's projects, a New Trip button.
- **Create Trip** — form: name, city, dates, Solo/Group toggle, (Group) invite field.
- **Map canvas** — full-screen map, category filter chips, bucket-list bottom sheet, Generate button.
- **Itinerary view** — day tabs, ordered stop cards (time, name, category), route drawn on map.
- **Group space (P1)** — chat pane, shared itinerary pane, both live.

Keep the visual system simple and consistent — a hackathon UI wins on one clean, coherent flow, not on breadth of screens.

---

## 9. Technical Architecture

```
   +---------------------------------------------+
   |            Flutter App (iOS/Android)         |
   |   Map UI · Project/Chat UI · Itinerary view  |
   |   State: Riverpod   Map: flutter_map/Mapbox  |
   +---------------------------------------------+
                     |            |
        Supabase SDK |            | HTTPS
                     v            v
   +----------------------+   +----------------------------+
   |  Supabase (BaaS)      |   |  Itinerary Function        |
   |  Postgres + PostGIS   |   |  (Edge Function / serverless)|
   |  Auth · Realtime ·    |   |  Calls foundation-model API |
   |  Storage              |   |  → structured itinerary JSON|
   +----------------------+   +----------------------------+
                     |
                     v
   +---------------------------------------------+
   |  POI dataset (pre-scraped: Exa + Firecrawl) |
   |  Loaded into Postgres for the demo city      |
   +---------------------------------------------+
```

**Key decisions:**
- **Flutter** front end for one codebase across iOS/Android; a Flutter **web** build is what gets hosted on Netlify for a shareable demo link (mobile is demoed on device/emulator).
- **Supabase** as the backend: Postgres (+PostGIS), auth, realtime (powers group chat + live itinerary), and storage — all with a first-class Flutter SDK (`supabase_flutter`). Fastest path to realtime without hand-rolling a backend.
- **Itinerary generation runs server-side**, not in the app. A Supabase Edge Function (or small serverless function) calls the foundation-model API so the API key never ships in the Flutter client.
- **POI data is pre-scraped and cached** for the demo city before presenting — no live scraping on stage.

---

## 10. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| App framework | **Flutter** | iOS/Android + web build |
| State management | Riverpod (or Provider) | Team's preference |
| Map | `flutter_map` + Mapbox tiles, or `google_maps_flutter` | flutter_map is lighter/free-tier friendly |
| Backend / DB | Supabase (Postgres + PostGIS) | `supabase_flutter` SDK |
| Auth | Supabase Auth | Email/magic-link is enough for demo |
| Realtime | Supabase Realtime | Chat + shared itinerary |
| Itinerary logic | Foundation-model API via Edge Function | Structured JSON output |
| POI data | Exa (discovery) + Firecrawl (structuring) | Pre-scraped, cached |
| Hosting (web demo) | Netlify (+ unified-cloud for functions) | Live URL from hour one |
| Optional flair | ElevenLabs | Read the itinerary aloud in demo |

---

## 11. Data Model

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE poi_category AS ENUM ('accommodation','restaurant','sightseeing','activity');
CREATE TYPE project_mode  AS ENUM ('solo','group');

CREATE TABLE pois (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category poi_category NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    address TEXT,
    avg_visit_minutes INT DEFAULT 60,
    vendor_ratings JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    mode project_mode NOT NULL DEFAULT 'solo',
    city VARCHAR(255),
    trip_start DATE,
    trip_end DATE,
    origin_poi_id UUID REFERENCES pois(id),      -- accommodation anchor
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE project_members (
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE bucket_list_items (
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    poi_id UUID REFERENCES pois(id),
    added_by UUID,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (project_id, poi_id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    body TEXT,
    shared_poi_id UUID REFERENCES pois(id),      -- null for plain text
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE itinerary_stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    poi_id UUID REFERENCES pois(id),
    day_number INT NOT NULL,
    sequence_order INT NOT NULL,
    added_by UUID,
    votes INT DEFAULT 0,
    planned_arrival TIME,
    planned_departure TIME
);

CREATE INDEX idx_pois_geom ON pois USING GIST (geom);
CREATE INDEX idx_stops_project ON itinerary_stops (project_id, day_number, sequence_order);
CREATE INDEX idx_messages_project ON messages (project_id, created_at);
```

---

## 12. Itinerary Generation Approach

For the hackathon, generation is **LLM-driven, not a solver**. The Edge Function sends the bucket list (each POI with coordinates, category, opening hours, `avg_visit_minutes`) plus trip length and the anchor POI to the foundation-model API, and requests strict JSON:

- Days `1..K` where `K` = trip length.
- Each day starts and ends at the accommodation anchor.
- No back-to-back same-category stops where avoidable.
- Respect opening hours and dwell times; assign rough arrival/departure times.

The function validates the JSON and writes rows into `itinerary_stops`. A simple cluster-by-day + nearest-neighbour heuristic is the offline fallback if the model output is unreliable during the demo. Full VRPTW with OR-Tools is the post-hackathon roadmap.

---

## 13. Build Plan (Hackathon Day)

| Step | Owner | Task |
|---|---|---|
| 0 (30 min) | All | Lock demo flow, pick one demo city, agree data model. |
| 1 | All | Scaffold Flutter app; stand up Supabase; deploy web build to Netlify (live URL early). |
| 2a | Eng A | Map canvas + category filters + bucket-list UI + create-trip flow. |
| 2b | Eng B | Itinerary Edge Function (LLM → JSON) + itinerary view. |
| 2c | Eng C | Pre-scrape POIs (Exa + Firecrawl) → Postgres; group chat + shared itinerary via Realtime. |
| 3 | All | Integrate the core loop end to end. |
| 4 | All | Polish the single demo path; rehearse the click sequence twice. |
| 5 (spare) | Any | Flair: ElevenLabs reads the itinerary aloud. |

---

## 14. Success Criteria (Demo)

- A judge can watch: create trip → add ~6 places on a map → generate → see a coherent 2-day plan anchored at the hotel, on both list and map. No crashes on that path.
- If group mode is in: two devices see the same itinerary update live.
- The app is reachable at a live URL.

---

## 15. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Realtime collaboration eats the whole day | Solo flow is P0 and self-contained; only build group live-edit once solo works. |
| LLM itinerary output is malformed/flaky on stage | Validate JSON server-side; keep the heuristic fallback ready. |
| Live scraping fails mid-demo | Pre-scrape and cache the demo city's POIs beforehand. |
| Map/plugin setup burns hours | Pick `flutter_map` early; don't shop plugins mid-build. |
| Deploy left to the last hour | Deploy an empty app in step 1; ship continuously. |

---

## 16. Out of Scope / Roadmap

- **Community video layer.** Crowdsourced, Waze-style: users upload short videos to a POI; once a video crosses a like/vote threshold it's promoted to the main database and shown to all. Community voting replaces scraping and solves relevance socially — deliberately avoiding TikTok scraping (prohibited by its ToS). Not built in this MVP.
- **Full VRPTW optimization** via OR-Tools.
- **Real-time traffic**, booking, payments, offline mode.
- **GDPR tooling** (data export/deletion) — required before any public, EU-facing launch.

---

## 17. Open Questions

- Is group live-editing in scope for the demo, or shown as solo + a static group mockup?
- Which single city do we pre-load POI data for?
- Map provider: `flutter_map` (free tiles) vs `google_maps_flutter` (richer, needs key)?
- Do we require login for the demo, or run a seeded guest user to save time?
