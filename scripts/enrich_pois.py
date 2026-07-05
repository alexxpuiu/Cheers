#!/usr/bin/env python3
"""
Enrich `public.pois` with rating + review count + photos from the Foursquare
Places Service API. Emits an idempotent UPDATE migration to stdout.

Design notes:
  • Reads the POI list by regex-parsing the existing seed migration, so we
    enrich exactly what's already in the DB with no duplicate Mapbox calls
    and no need to hit Supabase (no credentials needed).
  • Uses the *new* Places Service API (`places-api.foursquare.com`, launched
    2025) with Bearer auth and the `X-Places-Api-Version` header. Legacy v3
    keys (`api.foursquare.com/v3/places`) will 401.
  • One call per POI: /places/search with `fields=…` asking for
    `fsq_place_id,rating,stats,photos` — the new API lets us pull match +
    premium fields in a single request instead of the old search-then-detail
    two-hop.
  • Foursquare rating is 0-10; we normalize to the 0-5 scale the client UI
    expects (`Poi.rating`). Half-star precision (two decimals).
  • Photos are stored as {id, prefix, suffix, width, height} in jsonb; the
    client builds URLs on the fly as `${prefix}${size}${suffix}`.
  • Idempotent because each row uses `UPDATE ... WHERE id = <uuid>` and
    `enriched_at = now()`. Re-running just refreshes.

Note: `rating`, `stats`, and `photos` are Premium fields. On the freePro tier
the API returns HTTP 429 with a "no API credits remaining" body. The script
still runs and prints an empty migration + a helpful summary; enable billing
on your Foursquare org and re-run when you want live enrichment.

Usage:
  export FOURSQUARE_API_KEY=…   # or add to .env
  python3 scripts/enrich_pois.py \
      > supabase/migrations/20260705180000_enrich_pois.sql
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

FSQ_BASE = "https://places-api.foursquare.com/places"
FSQ_API_VERSION = "2025-06-17"
SEED_MIGRATION = "supabase/migrations/20260705160000_seed_real_pois.sql"

# Radius (metres) for the /search match around the POI's coordinates. Keep
# tight — we already know where the POI is; we want the same venue back, not
# a nearby one with a similar name.
MATCH_RADIUS_M = 200
MAX_PHOTOS = 5
SLEEP_BETWEEN = 0.10  # be polite to Foursquare's free tier
PREMIUM_FIELDS = "fsq_place_id,rating,stats,photos"

# On the freePro tier, `rating`, `stats`, and `photos` all 429 as "Premium
# calls". If we hit that the very first time, drop back to core-only mode
# for the rest of the run so we at least cache `fsq_place_id` — later, once
# billing is enabled, re-running with credits fills in the rich fields
# because the WHERE-clause is keyed on our stable `id` UUID.
_premium_mode = True

# Matches rows in the seed migration:
#   ('<uuid>', '<name>', '<category>', <lat>, <lng>, '<address>', <minutes>)
# Name/address use SQL-style '' escaping for single quotes.
VALUE_RE = re.compile(
    r"\("
    r"'([a-f0-9-]{36})'"
    r",\s*'((?:[^']|'')*)'"
    r",\s*'(accommodation|dining|sightseeing|nightlife)'"
    r",\s*([-\d.]+)"
    r",\s*([-\d.]+)"
    r",\s*'((?:[^']|'')*)'"
    r",\s*\d+"
    r"\)"
)


def api_key() -> str:
    """Read from env, falling back to .env for local dev convenience."""
    key = os.environ.get("FOURSQUARE_API_KEY")
    if key:
        return key.strip()
    try:
        with open(".env") as f:
            for line in f:
                if line.startswith("FOURSQUARE_API_KEY="):
                    return line.split("=", 1)[1].strip()
    except FileNotFoundError:
        pass
    sys.exit(
        "FOURSQUARE_API_KEY not set. Export it or add it to .env.\n"
        "Get a key at https://foursquare.com/developers/."
    )


def sql_unescape(s: str) -> str:
    return s.replace("''", "'")


def sql_escape(s: str) -> str:
    return s.replace("'", "''")


def read_pois() -> list[dict]:
    with open(SEED_MIGRATION) as f:
        text = f.read()
    rows: list[dict] = []
    for m in VALUE_RE.finditer(text):
        rows.append({
            "id": m.group(1),
            "name": sql_unescape(m.group(2)),
            "category": m.group(3),
            "lat": float(m.group(4)),
            "lng": float(m.group(5)),
        })
    if not rows:
        sys.exit(f"No POI rows parsed from {SEED_MIGRATION}.")
    return rows


class NoCreditsError(RuntimeError):
    """The Foursquare account is out of API credits (HTTP 429)."""


def curl_json(url: str, headers: dict[str, str]) -> dict:
    """
    Use curl to sidestep Python 3.13 macOS SSL trust-store issues (same
    workaround `scripts/seed_pois.py` uses for Mapbox). Captures the status
    code so we can bail cleanly on 429 (out of credits) instead of just
    returning empty results and silently pretending nothing matched.
    """
    args = ["curl", "-sS", "--max-time", "15", "-w", "\n%{http_code}"]
    for k, v in headers.items():
        args += ["-H", f"{k}: {v}"]
    args.append(url)
    out = subprocess.check_output(args, stderr=subprocess.PIPE).decode()
    body, _, code = out.rpartition("\n")
    code = code.strip()
    if code == "429" and "no API credits" in body:
        raise NoCreditsError(body.strip())
    if not code.startswith("2"):
        raise RuntimeError(f"HTTP {code}: {body[:200]}")
    return json.loads(body) if body else {}


def _fsq_headers(tok: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {tok}",
        "X-Places-Api-Version": FSQ_API_VERSION,
        "accept": "application/json",
    }


def _search(poi: dict, tok: str, *, premium: bool) -> dict | None:
    """Single Foursquare search hit. Returns the first result or None."""
    query = {
        "ll": f"{poi['lat']},{poi['lng']}",
        "query": poi["name"],
        "radius": MATCH_RADIUS_M,
        "limit": 1,
    }
    if premium:
        query["fields"] = PREMIUM_FIELDS
    url = f"{FSQ_BASE}/search?{urllib.parse.urlencode(query)}"
    data = curl_json(url, _fsq_headers(tok))
    results = data.get("results") or []
    return results[0] if results else None


def enrich(poi: dict, tok: str) -> dict | None:
    """
    Search for the POI and pull whatever fields the account tier allows.

    Tries premium fields (rating/stats/photos) first. On the freePro tier
    that 429s — we catch it, flip the global mode to core-only for the rest
    of the run, and re-issue the same search without `fields=` so we at
    least cache `fsq_place_id`. Returns None when nothing matches.
    """
    global _premium_mode

    try:
        r = _search(poi, tok, premium=_premium_mode)
    except NoCreditsError:
        if not _premium_mode:
            raise  # already downgraded; the 429 is real
        print(
            "! Premium fields blocked (freePro tier). Continuing in "
            "core-only mode — only `fsq_id` will be cached.",
            file=sys.stderr,
        )
        _premium_mode = False
        r = _search(poi, tok, premium=False)

    if not r:
        return None
    fsq_id = r.get("fsq_place_id") or r.get("fsq_id")
    if not fsq_id:
        return None
    rating10 = r.get("rating")
    rating5 = round(rating10 / 2.0, 2) if isinstance(rating10, (int, float)) else None
    stats = r.get("stats") or {}
    review_count = int(stats.get("total_ratings") or 0) if stats else None
    photos_raw = r.get("photos") or []
    photos = [
        {
            "id": p.get("id") or p.get("fsq_photo_id"),
            "prefix": p.get("prefix"),
            "suffix": p.get("suffix"),
            "width": p.get("width"),
            "height": p.get("height"),
        }
        for p in photos_raw[:MAX_PHOTOS]
        if p.get("prefix") and p.get("suffix")
    ]
    return {
        "fsq_id": fsq_id,
        "rating": rating5,
        "review_count": review_count,
        "photos": photos,
    }


def emit_update(poi: dict, data: dict) -> str:
    # Only write columns we actually got data for. Premium-blocked runs will
    # persist just `fsq_id` (+ enriched_at); a later run with credits will
    # overwrite with the rich fields because we key on the UUID.
    parts = [f"fsq_id = '{sql_escape(data['fsq_id'])}'"]
    if data.get("rating") is not None:
        parts.append(f"rating = {data['rating']}")
    if data.get("review_count") is not None:
        parts.append(f"review_count = {data['review_count']}")
    if data.get("photos"):
        photos_json = json.dumps(data["photos"], separators=(",", ":"))
        parts.append(f"photos = '{sql_escape(photos_json)}'::jsonb")
    parts.append("enriched_at = now()")
    set_clause = ",\n       ".join(parts)
    return (
        f"-- {poi['name']}\n"
        f"update public.pois\n"
        f"   set {set_clause}\n"
        f" where id = '{poi['id']}';"
    )


def main() -> None:
    tok = api_key()
    pois = read_pois()

    updates: list[str] = []
    misses: list[str] = []
    aborted: str | None = None
    for i, poi in enumerate(pois, 1):
        try:
            data = enrich(poi, tok)
        except NoCreditsError as e:
            # Only reachable if we're already in core-only mode and even the
            # bare search 429s — treat as a genuine credit exhaustion.
            aborted = str(e)
            print(f"! Aborted at POI #{i}: out of Foursquare credits.",
                  file=sys.stderr)
            break
        except subprocess.CalledProcessError as e:
            stderr = (e.stderr or b"").decode(errors="replace")[:200]
            misses.append(f"{poi['name']} — request failed: {stderr}")
            time.sleep(SLEEP_BETWEEN)
            continue
        except RuntimeError as e:
            misses.append(f"{poi['name']} — request failed: {e}")
            time.sleep(SLEEP_BETWEEN)
            continue
        if not data:
            misses.append(f"{poi['name']} — no Foursquare match within {MATCH_RADIUS_M}m")
        else:
            updates.append(emit_update(poi, data))
        print(
            f"[{i:>3}/{len(pois)}] {poi['name']!s:<45}"
            f" {'HIT' if data else 'miss'}",
            file=sys.stderr,
        )
        time.sleep(SLEEP_BETWEEN)

    mode_note = (
        "-- Mode: FULL (rating + stats + photos populated).\n"
        if _premium_mode else
        "-- Mode: CORE-ONLY. `rating`/`review_count`/`photos` were NOT\n"
        "-- populated because the freePro tier returns 429 on Premium fields.\n"
        "-- Enable billing at https://foursquare.com/developers/orgs and re-run\n"
        "-- to fill them in — the UPDATEs are keyed on stable UUIDs so they'll\n"
        "-- overwrite the rows we're writing now.\n"
    )
    header = f"""-- ============================================================================
-- Cheers — Foursquare enrichment for `public.pois`
-- ----------------------------------------------------------------------------
-- Apply after `20260705170000_place_details_columns.sql`.
--
-- Auto-generated by `scripts/enrich_pois.py`. Regenerate with:
--   python3 scripts/enrich_pois.py > <this file>
--
{mode_note}--
-- Matched: {len(updates)} / {len(pois)} POIs
"""
    if aborted:
        header += (
            "--\n"
            "-- ABORTED: Foursquare returned HTTP 429 on a core-only search —\n"
            "-- the account has no API credits at all. Enable billing at\n"
            "--   https://foursquare.com/developers/orgs\n"
        )
    header += f"-- Misses ({len(misses)}):\n"
    for m in misses:
        header += f"--   • {m}\n"
    header += "-- ============================================================================\n\n"

    sys.stdout.write(header + "\n\n".join(updates) + ("\n" if updates else ""))


if __name__ == "__main__":
    main()
