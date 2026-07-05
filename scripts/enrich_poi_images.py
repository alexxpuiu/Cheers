#!/usr/bin/env python3
"""
Enrich `public.pois.photos` with free Wikimedia / Wikipedia thumbnail URLs.

Pipeline per POI (no API key required):
  1. Wikipedia geosearch near lat/lng → pick best name match → thumbnail
  2. Wikipedia title lookup by POI name (en + ca)
  3. Wikidata coordinate search for P18 (image) → Commons FilePath URL

Emits idempotent UPDATE migration to stdout. Same pattern as
`scripts/enrich_pois.py`.

Usage:
  python3 scripts/enrich_poi_images.py \\
      > supabase/migrations/20260705190000_enrich_poi_images.sql
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import unicodedata
import urllib.parse

SEED_MIGRATION = "supabase/migrations/20260705160000_seed_real_pois.sql"
CACHE_FILE = ".enrich_poi_images.cache.json"
USER_AGENT = "Cheers/1.0 (Barcelona trip planner; local dev script)"
GEO_RADIUS_M = 150
THUMB_WIDTH = 800
SLEEP_BETWEEN = 2.5  # Wikimedia rate-limits aggressive bursts; stay polite.
INTER_CALL_SLEEP = 0.8
# Wikipedia's cooldown after a rate-limit block is often ~60s. Backoff
# schedule (seconds) between retries — errs on the long side to avoid
# thrashing the API further.
BACKOFF_SCHEDULE = (30, 60, 90, 120, 180)
WIKI_LANGS = ("en", "ca")

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


def normalize_name(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = s.encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"[^a-z0-9 ]", " ", s.lower())
    return " ".join(s.split())


def name_score(poi_name: str, candidate: str) -> float:
    a = set(normalize_name(poi_name).split())
    b = set(normalize_name(candidate).split())
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def curl_json(url: str) -> dict:
    for attempt, wait in enumerate((0,) + BACKOFF_SCHEDULE):
        if wait:
            print(f"  rate limited — sleeping {wait}s…", file=sys.stderr)
            time.sleep(wait)
        args = [
            "curl", "-sS", "--max-time", "25",
            "-H", f"User-Agent: {USER_AGENT}",
            "-H", "Accept: application/json",
            "-w", "\n%{http_code}",
            url,
        ]
        out = subprocess.check_output(args, stderr=subprocess.PIPE).decode()
        body, _, code = out.rpartition("\n")
        code = code.strip()
        if code == "429":
            continue
        if not code.startswith("2"):
            raise RuntimeError(f"HTTP {code}: {body[:200]}")
        body = body.strip()
        if not body:
            raise RuntimeError("empty response body")
        return json.loads(body)
    raise RuntimeError("rate limited after all retries")


def wiki_api(lang: str, params: dict) -> dict:
    base = f"https://{lang}.wikipedia.org/w/api.php"
    q = urllib.parse.urlencode({**params, "format": "json"})
    data = curl_json(f"{base}?{q}")
    time.sleep(INTER_CALL_SLEEP)
    return data


def geosearch(poi: dict, lang: str = "en") -> dict | None:
    params = {
        "action": "query",
        "generator": "geosearch",
        "ggscoord": f"{poi['lat']}|{poi['lng']}",
        "ggsradius": GEO_RADIUS_M,
        "ggslimit": 5,
        "prop": "pageimages|info",
        "piprop": "thumbnail",
        "pithumbsize": THUMB_WIDTH,
        "inprop": "url",
    }
    data = wiki_api(lang, params)
    pages = (data.get("query") or {}).get("pages") or {}
    best: dict | None = None
    best_score = 0.0
    for page in pages.values():
        thumb = page.get("thumbnail")
        if not thumb or not thumb.get("source"):
            continue
        title = page.get("title") or ""
        score = name_score(poi["name"], title)
        if score > best_score:
            best_score = score
            best = {
                "title": title,
                "url": thumb["source"],
                "width": thumb.get("width"),
                "height": thumb.get("height"),
                "via": f"{lang} geosearch",
                "score": score,
            }
    if best and best_score >= 0.15:
        return best
    # If only one nearby result with an image, take it for sightseeing.
    if poi["category"] == "sightseeing" and pages:
        for page in pages.values():
            thumb = page.get("thumbnail")
            if thumb and thumb.get("source"):
                return {
                    "title": page.get("title") or "",
                    "url": thumb["source"],
                    "width": thumb.get("width"),
                    "height": thumb.get("height"),
                    "via": f"{lang} geosearch (sightseeing)",
                    "score": best_score,
                }
    return None


def page_image_by_title(lang: str, title: str) -> dict | None:
    params = {
        "action": "query",
        "titles": title,
        "prop": "pageimages",
        "piprop": "thumbnail",
        "pithumbsize": THUMB_WIDTH,
    }
    data = wiki_api(lang, params)
    pages = (data.get("query") or {}).get("pages") or {}
    for page in pages.values():
        if page.get("missing") is not None:
            continue
        thumb = page.get("thumbnail")
        if thumb and thumb.get("source"):
            return {
                "title": page.get("title") or title,
                "url": thumb["source"],
                "width": thumb.get("width"),
                "height": thumb.get("height"),
                "via": f"{lang} title",
            }
    return None


def opensearch_titles(poi_name: str, lang: str) -> list[str]:
    params = {
        "action": "opensearch",
        "search": poi_name,
        "limit": 5,
        "namespace": 0,
    }
    data = wiki_api(lang, params)
    if isinstance(data, list) and len(data) >= 2 and isinstance(data[1], list):
        return [t for t in data[1] if isinstance(t, str)]
    return []


def search_by_name(poi: dict) -> dict | None:
    """Try opensearch + pageimages on en.wikipedia (max 2 titles)."""
    candidates: list[str] = [poi["name"]]
    candidates.extend(opensearch_titles(poi["name"], "en")[:2])
    seen: set[str] = set()
    best: dict | None = None
    best_score = 0.0
    for title in candidates:
        key = title.casefold()
        if key in seen:
            continue
        seen.add(key)
        hit = page_image_by_title("en", title)
        if not hit:
            continue
        score = name_score(poi["name"], hit["title"])
        if score > best_score:
            best_score = score
            best = {**hit, "score": score}
        if score >= 0.5:
            return best
    return best if best_score >= 0.25 else None


def wikidata_image(poi: dict) -> dict | None:
    # Point(lng lat) per Wikidata geo convention.
    sparql = f"""
SELECT ?image ?itemLabel WHERE {{
  SERVICE wikibase:around {{
    ?item wdt:P625 ?loc .
    bd:serviceParam wikibase:center "Point({poi['lng']} {poi['lat']})"^^geo:wktLiteral .
    bd:serviceParam wikibase:radius "{GEO_RADIUS_M / 1000.0}" .
  }}
  ?item wdt:P18 ?image .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en,ca". }}
}}
LIMIT 8
""".strip()
    url = (
        "https://query.wikidata.org/sparql?"
        + urllib.parse.urlencode({"query": sparql, "format": "json"})
    )
    data = curl_json(url)
    time.sleep(INTER_CALL_SLEEP)
    bindings = (data.get("results") or {}).get("bindings") or []
    best: dict | None = None
    best_score = 0.0
    for row in bindings:
        image_uri = (row.get("image") or {}).get("value")
        label = (row.get("itemLabel") or {}).get("value") or ""
        if not image_uri:
            continue
        # P18 values are full Commons URLs or http://commons.wikimedia.org/...
        filename = image_uri.rsplit("/", 1)[-1]
        filename = urllib.parse.unquote(filename)
        file_url = (
            "https://commons.wikimedia.org/wiki/Special:FilePath/"
            + urllib.parse.quote(filename.replace(" ", "_"))
            + f"?width={THUMB_WIDTH}"
        )
        score = name_score(poi["name"], label)
        if score > best_score:
            best_score = score
            best = {
                "title": label,
                "url": file_url,
                "width": THUMB_WIDTH,
                "height": None,
                "via": "wikidata P18",
                "score": score,
            }
    if best and (best_score >= 0.15 or poi["category"] == "sightseeing"):
        return best
    return None


def find_image(poi: dict) -> dict | None:
    hit = geosearch(poi, "en")
    if hit:
        return hit
    time.sleep(SLEEP_BETWEEN)

    hit = geosearch(poi, "ca")
    if hit:
        return hit
    time.sleep(SLEEP_BETWEEN)

    hit = search_by_name(poi)
    if hit:
        return hit
    time.sleep(SLEEP_BETWEEN)

    return wikidata_image(poi)


def photo_payload(hit: dict) -> dict:
    return {
        "source": "wikimedia",
        "url": hit["url"],
        "width": hit.get("width"),
        "height": hit.get("height"),
        "attribution": "Wikimedia Commons",
    }


def emit_update(poi: dict, hit: dict) -> str:
    photos = json.dumps([photo_payload(hit)], separators=(",", ":"))
    return (
        f"-- {poi['name']} ({hit['via']}: {hit.get('title', '')})\n"
        f"update public.pois\n"
        f"   set photos = '{sql_escape(photos)}'::jsonb,\n"
        f"       enriched_at = now()\n"
        f" where id = '{poi['id']}';"
    )


def load_cache() -> dict:
    try:
        with open(CACHE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_cache(cache: dict) -> None:
    tmp = CACHE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cache, f, indent=2, sort_keys=True)
    import os
    os.replace(tmp, CACHE_FILE)


def main() -> None:
    # Optional category filter: `--category sightseeing` (etc.) limits which
    # rows we hit the API for. Cached POIs of other categories are still
    # emitted in the final SQL — the filter only affects fetching.
    category_filter: str | None = None
    args = sys.argv[1:]
    while args:
        arg = args.pop(0)
        if arg == "--category" and args:
            category_filter = args.pop(0).lower()
        else:
            sys.exit(f"Unknown arg: {arg}")

    pois = read_pois()
    cache = load_cache()

    for i, poi in enumerate(pois, 1):
        if category_filter and poi["category"] != category_filter:
            # Not the category we're focused on — still show its cache status
            # for clarity but don't fetch.
            entry = cache.get(poi["id"])
            if entry is None:
                status = "skipped (filtered)"
            elif entry.get("hit"):
                status = "HIT (cached)"
            else:
                status = "miss (cached)"
            print(f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} {status}",
                  file=sys.stderr)
            continue

        cached = cache.get(poi["id"])
        if cached is not None:
            status = "HIT (cached)" if cached.get("hit") else "miss (cached)"
            print(f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} {status}",
                  file=sys.stderr)
            continue

        try:
            hit = find_image(poi)
        except subprocess.CalledProcessError as e:
            stderr = (e.stderr or b"").decode(errors="replace")[:200]
            print(f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} error: {stderr[:60]}",
                  file=sys.stderr)
            # Don't cache errors — user should retry.
            time.sleep(SLEEP_BETWEEN)
            continue
        except (json.JSONDecodeError, RuntimeError) as e:
            print(f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} error: {e}",
                  file=sys.stderr)
            time.sleep(SLEEP_BETWEEN)
            continue

        cache[poi["id"]] = {"hit": hit}
        save_cache(cache)  # save after every POI so partial runs stick
        if hit:
            print(
                f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} HIT ({hit['via']})",
                file=sys.stderr,
            )
        else:
            print(f"[{i:>3}/{len(pois)}] {poi['name']!s:<45} miss",
                  file=sys.stderr)
        time.sleep(SLEEP_BETWEEN)

    updates: list[str] = []
    misses: list[str] = []
    for poi in pois:
        cached = cache.get(poi["id"])
        if cached and cached.get("hit"):
            updates.append(emit_update(poi, cached["hit"]))
        else:
            reason = "not yet fetched" if cached is None else "no Wikimedia image found"
            misses.append(f"{poi['name']} — {reason}")

    header = f"""-- ============================================================================
-- Cheers — Wikimedia photo enrichment for `public.pois`
-- ----------------------------------------------------------------------------
-- Apply after `20260705180000_enrich_pois.sql`.
--
-- Auto-generated by `scripts/enrich_poi_images.py`. Regenerate with:
--   python3 scripts/enrich_poi_images.py > <this file>
--
-- Matched: {len(updates)} / {len(pois)} POIs
-- Misses ({len(misses)}):
"""
    for m in misses:
        header += f"--   • {m}\n"
    header += "-- ============================================================================\n\n"

    sys.stdout.write(header + "\n\n".join(updates) + ("\n" if updates else ""))


if __name__ == "__main__":
    main()