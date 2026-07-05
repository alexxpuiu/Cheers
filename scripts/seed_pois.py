#!/usr/bin/env python3
"""
Seed `public.pois` with real Barcelona POIs pulled from the Mapbox Search
Box API. Emits an idempotent Supabase migration to stdout.

Design goals:
  • Diversity: sweep a bbox around Barcelona (not just Plaça de Catalunya)
    with multiple canonical categories per app-category, so results aren't
    dominated by whatever is nearest one anchor point.
  • Quality:  filter out noise — single-word names, all-caps / non-Latin
    strings, sub-3-char names, and known low-signal tokens (tour operator,
    guide, sculpture caption strings) that Mapbox mixes in.
  • Idempotency: uuid5 over Mapbox's `mapbox_id` — safe to re-run.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import urllib.parse
import uuid

MAPBOX_URL = "https://api.mapbox.com/search/searchbox/v1/category/{cat}"

# app PoiCategory -> list of (mapbox canonical_id, avg_visit_minutes)
CATEGORY_MAP: dict[str, list[tuple[str, int]]] = {
    "accommodation": [("hotel", 720)],
    "dining":        [("restaurant", 90), ("cafe", 45)],
    "sightseeing":   [
        ("tourist_attraction", 75),
        ("museum", 90),
        ("landmark", 45),
        ("park", 60),
    ],
    "nightlife":     [("bar", 90), ("nightclub", 120)],
}

# Barcelona bbox — spans the Eixample, Ciutat Vella, Gràcia, Poble Sec, and
# Barceloneta. Wide enough for a diverse catalog without pulling in suburbs.
BBOX = (2.1300, 41.3620, 2.2050, 41.4200)  # W, S, E, N
LIMIT_PER_CALL = 25
PER_APP_CATEGORY_CAP = 18

NS = uuid.UUID("6f6c88fe-6cfe-4a8b-9a1a-c4eef500a1de")

# Reject these tokens (case-insensitive substring) — Mapbox mixes in tour
# operators and one-off sculpture captions that are not places you'd visit.
NOISE_TOKENS = [
    "tour", "guide", "excursii", "excursion",
    "walking tour", "free tour", "private tour",
]


def token() -> str:
    with open(".env") as f:
        for line in f:
            if line.startswith("MAPBOX_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip()
    sys.exit("MAPBOX_ACCESS_TOKEN not found in .env")


def fetch(cat: str, tok: str) -> list[dict]:
    q = urllib.parse.urlencode({
        "access_token": tok,
        "bbox": ",".join(str(v) for v in BBOX),
        "limit": LIMIT_PER_CALL,
        "language": "en",
    })
    url = f"{MAPBOX_URL.format(cat=cat)}?{q}"
    out = subprocess.check_output(
        ["curl", "-sSf", "--max-time", "15", url],
        stderr=subprocess.PIPE,
    )
    return json.loads(out).get("features", [])


def sql_escape(s: str) -> str:
    return s.replace("'", "''")


LATIN_NAME = re.compile(r"^[A-Za-z0-9À-ÿ' \-&·.,()/]+$")


def is_quality_name(name: str) -> bool:
    if len(name) < 3:
        return False
    if not LATIN_NAME.match(name):
        return False   # non-Latin script — likely a foreign-language listing
    lower = name.lower()
    for bad in NOISE_TOKENS:
        if bad in lower:
            return False
    # Reject "all caps random string" and single-word ambiguities.
    if name.isupper() and len(name.split()) == 1:
        return False
    return True


def coerce(feature: dict, app_cat: str, avg: int) -> dict | None:
    props = feature.get("properties", {})
    geom = feature.get("geometry", {})
    coords = geom.get("coordinates")
    if not coords or len(coords) < 2:
        return None
    lng, lat = coords[0], coords[1]
    name = (props.get("name") or "").strip()
    if not is_quality_name(name):
        return None
    mapbox_id = props.get("mapbox_id") or f"{name}|{lat}|{lng}"
    address = (
        props.get("full_address")
        or props.get("place_formatted")
        or props.get("address")
        or ""
    )
    address = re.sub(r",\s*Spain$", "", address).strip()
    return {
        "id": str(uuid.uuid5(NS, mapbox_id)),
        "name": name,
        "category": app_cat,
        "lat": float(lat),
        "lng": float(lng),
        "address": address,
        "avg_visit_minutes": avg,
    }


def main() -> None:
    tok = token()
    all_rows: list[dict] = []
    seen_ids: set[str] = set()
    seen_names: set[str] = set()

    for app_cat, canonicals in CATEGORY_MAP.items():
        rows_for_cat: list[dict] = []
        for canonical, avg in canonicals:
            feats = fetch(canonical, tok)
            for feat in feats:
                r = coerce(feat, app_cat, avg)
                if not r:
                    continue
                # Cross-category dedup by uuid + name (a hotel and its
                # in-house restaurant sharing a name would confuse users).
                name_key = r["name"].lower()
                if r["id"] in seen_ids or name_key in seen_names:
                    continue
                seen_ids.add(r["id"])
                seen_names.add(name_key)
                rows_for_cat.append(r)
                if len(rows_for_cat) >= PER_APP_CATEGORY_CAP:
                    break
            if len(rows_for_cat) >= PER_APP_CATEGORY_CAP:
                break
            time.sleep(0.15)  # polite pacing
        all_rows.extend(rows_for_cat)

    all_rows.sort(key=lambda r: (r["category"], r["name"].lower()))

    header = """-- ============================================================================
-- Cheers — real POI seed (Barcelona, Mapbox Search Box)
-- ----------------------------------------------------------------------------
-- Apply after `20260705150000_bucket_list_sync.sql`.
--
-- Replaces the `lib/data/mock_pois.dart` catalog. Pulled from the Mapbox
-- Search Box category endpoint across a Barcelona bbox and filtered for
-- quality (Latin names, no tour-operator noise, cross-category dedup).
-- Deterministic uuid5 ids over Mapbox's `mapbox_id` make the migration
-- idempotent — safe to re-run when the catalog needs a refresh.
--
-- Regenerate with `python3 scripts/seed_pois.py > <this file>`.
-- ============================================================================

insert into public.pois (id, name, category, lat, lng, address, avg_visit_minutes)
values
"""
    values = []
    for r in all_rows:
        values.append(
            "  ('{id}', '{name}', '{cat}', {lat}, {lng}, '{addr}', {mins})".format(
                id=r["id"],
                name=sql_escape(r["name"]),
                cat=r["category"],
                lat=r["lat"],
                lng=r["lng"],
                addr=sql_escape(r["address"]),
                mins=r["avg_visit_minutes"],
            )
        )
    body = ",\n".join(values)
    tail = """
on conflict (id) do update set
  name              = excluded.name,
  category          = excluded.category,
  lat               = excluded.lat,
  lng               = excluded.lng,
  address           = excluded.address,
  avg_visit_minutes = excluded.avg_visit_minutes;
"""
    # NB: the `on conflict` clause is part of the same INSERT statement, so
    # the semicolon must come *after* it — not between VALUES and ON CONFLICT.
    sys.stdout.write(header + body + tail)


if __name__ == "__main__":
    main()
