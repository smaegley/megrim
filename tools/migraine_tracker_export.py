#!/usr/bin/env python3
"""Export the private `migraine-tracker` Postgres database to a Megrim import file.

Megrim's Settings -> Import reads a `megrim-export` v1 JSON document. The private app's schema
(migraine_events + derived_factors + app_settings) is nearly 1:1 with Megrim's, so this converter
is a straight field map, with two small normalizations:

  * `season` is lower-cased in the private DB ("winter") but Capitalized in Megrim ("Winter").
  * `sunrise_time` / `sunset_time`  ->  `sunrise_utc` / `sunset_utc`.

Everything else (ids, timestamps, meds_taken JSON, moon phase names, time-of-day buckets, all
weather/astro fields including daylight_hours) passes through unchanged, so Megrim keeps the
private app's more accurate astral/ephem enrichment rather than recomputing it.

Soft-deleted rows (deleted_at IS NOT NULL) are skipped. Vocabularies (triggers, head locations,
medications) are derived from the distinct values actually used, so your chips populate on import.

RUN IT WHERE THE DATABASE IS REACHABLE (e.g. on the backend host / infra). Connection is resolved
in this order:
  1. --database-url "postgresql://user:pass@host:5432/migraine_tracker"
  2. $DATABASE_URL
  3. app.config.settings.database_url  (when run inside the backend dir with its env loaded)

Requires SQLAlchemy + a Postgres driver (both already in the backend venv). Example:

    cd ~/projects/migraine-tracker/backend
    source .venv/bin/activate                     # has sqlalchemy + psycopg2
    set -a; source /path/to/backend.env; set +a   # provides db_password etc.
    python /path/to/megrim/tools/migraine_tracker_export.py -o ~/megrim-from-tracker.json

Then copy the JSON to the phone and use Settings -> Import (Replace).
"""
import argparse
import json
import os
import sys
from datetime import datetime

from sqlalchemy import create_engine, text

SEASON_MAP = {
    "winter": "Winter", "spring": "Spring", "summer": "Summer", "autumn": "Autumn",
}


def resolve_database_url(cli_url):
    if cli_url:
        return cli_url
    if os.environ.get("DATABASE_URL"):
        return os.environ["DATABASE_URL"]
    try:
        # Works when run from the backend dir with its environment loaded.
        from app.config import settings  # type: ignore
        return settings.database_url
    except Exception:
        sys.exit(
            "No database URL. Pass --database-url, set $DATABASE_URL, or run inside the "
            "backend dir with its env loaded (so app.config.settings is importable)."
        )


def iso_utc(v):
    """ISO-8601 in UTC with a 'Z' suffix, matching Megrim's export style."""
    if v is None:
        return None
    if isinstance(v, datetime):
        from datetime import timezone
        return v.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    return str(v)


def as_list(v):
    return list(v) if v else []


def derived_to_json(d):
    if d is None or d["event_id"] is None:
        return None
    season = d["season"]
    return {
        "day_of_week": d["day_of_week"],
        "season": SEASON_MAP.get(season, season.capitalize() if season else None),
        "time_of_day_bucket": d["time_of_day_bucket"],
        "daylight_hours": _f(d["daylight_hours"]),
        "sunrise_utc": iso_utc(d["sunrise_time"]),
        "sunset_utc": iso_utc(d["sunset_time"]),
        "moon_phase": d["moon_phase"],
        "moon_illumination": _f(d["moon_illumination"]),
        "temp_c": _f(d["temp_c"]),
        "humidity_pct": _f(d["humidity_pct"]),
        "pressure_hpa": _f(d["pressure_hpa"]),
        "precipitation_mm": _f(d["precipitation_mm"]),
        "pressure_delta_24h": _f(d["pressure_delta_24h"]),
        "pressure_delta_48h": _f(d["pressure_delta_48h"]),
        "aqi": d["aqi"],
        "enriched_at": iso_utc(d["enriched_at"]),
        "enrich_error": None,
    }


def _f(v):
    return float(v) if v is not None else None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--out", default="megrim-from-tracker.json",
                    help="output JSON path (default: %(default)s)")
    ap.add_argument("--database-url", default=None,
                    help="Postgres URL; else $DATABASE_URL, else app.config.settings")
    ap.add_argument("--include-deleted", action="store_true",
                    help="also export soft-deleted (deleted_at) rows (default: skip)")
    args = ap.parse_args()

    engine = create_engine(resolve_database_url(args.database_url))

    where = "" if args.include_deleted else "WHERE e.deleted_at IS NULL"
    sql = text(f"""
        SELECT e.id, e.started_at, e.ended_at, e.severity, e.location_head,
               e.aura_present, e.aura_description, e.meds_taken, e.triggers_suspected,
               e.sleep_hours_prior, e.stress_level, e.foods_notable, e.notes,
               e.geo_lat, e.geo_lon, e.geo_label, e.created_at, e.updated_at,
               d.event_id AS d_event_id, d.day_of_week, d.season, d.time_of_day_bucket,
               d.daylight_hours, d.sunrise_time, d.sunset_time, d.moon_phase,
               d.moon_illumination, d.temp_c, d.humidity_pct, d.pressure_hpa,
               d.precipitation_mm, d.pressure_delta_24h, d.pressure_delta_48h,
               d.aqi, d.enriched_at
        FROM migraine_events e
        LEFT JOIN derived_factors d ON d.event_id = e.id
        {where}
        ORDER BY e.started_at ASC
    """)

    events = []
    triggers, head_locs, meds_vocab = set(), set(), set()
    home = None

    with engine.connect() as conn:
        for r in conn.execute(sql):
            m = r._mapping
            trig = as_list(m["triggers_suspected"])
            loc = as_list(m["location_head"])
            meds = m["meds_taken"] or []
            triggers.update(trig)
            head_locs.update(loc)
            for md in meds:
                if isinstance(md, dict) and md.get("name"):
                    meds_vocab.add(md["name"])

            derived = derived_to_json({
                "event_id": m["d_event_id"], "day_of_week": m["day_of_week"],
                "season": m["season"], "time_of_day_bucket": m["time_of_day_bucket"],
                "daylight_hours": m["daylight_hours"], "sunrise_time": m["sunrise_time"],
                "sunset_time": m["sunset_time"], "moon_phase": m["moon_phase"],
                "moon_illumination": m["moon_illumination"], "temp_c": m["temp_c"],
                "humidity_pct": m["humidity_pct"], "pressure_hpa": m["pressure_hpa"],
                "precipitation_mm": m["precipitation_mm"],
                "pressure_delta_24h": m["pressure_delta_24h"],
                "pressure_delta_48h": m["pressure_delta_48h"],
                "aqi": m["aqi"], "enriched_at": m["enriched_at"],
            })

            ev = {
                "id": str(m["id"]),
                "started_at": iso_utc(m["started_at"]),
                "ended_at": iso_utc(m["ended_at"]),
                "severity": m["severity"],
                "location_head": loc,
                "aura_present": m["aura_present"],
                "aura_description": m["aura_description"],
                "meds_taken": meds,
                "triggers_suspected": trig,
                "sleep_hours_prior": _f(m["sleep_hours_prior"]),
                "stress_level": m["stress_level"],
                "foods_notable": as_list(m["foods_notable"]),
                "notes": m["notes"],
                "geo_lat": _f(m["geo_lat"]),
                "geo_lon": _f(m["geo_lon"]),
                "geo_label": m["geo_label"],
                "created_at": iso_utc(m["created_at"]),
                "updated_at": iso_utc(m["updated_at"]),
            }
            if derived is not None:
                ev["derived"] = derived
            events.append(ev)

        # Home location from app_settings, if the private app stored one.
        try:
            row = conn.execute(text(
                "SELECT value FROM app_settings WHERE key IN "
                "('home_location','home') LIMIT 1")).first()
            if row and isinstance(row[0], dict):
                v = row[0]
                if "lat" in v and "lon" in v:
                    home = {"lat": float(v["lat"]), "lon": float(v["lon"]),
                            "label": v.get("label", "")}
        except Exception:
            pass

    # Fall back to the first event's geo, so enrichment of any un-enriched rows has a location.
    if home is None:
        for ev in events:
            if ev.get("geo_lat") is not None and ev.get("geo_lon") is not None:
                home = {"lat": ev["geo_lat"], "lon": ev["geo_lon"],
                        "label": ev.get("geo_label") or ""}
                break

    doc = {
        "format": "megrim-export",
        "format_version": 1,
        "exported_at": iso_utc(datetime.now()),
        "app_version": "migraine-tracker-export",
        "settings": ({"home_location": home} if home else {}),
        "vocabularies": {
            "trigger": sorted(triggers),
            "head_location": sorted(head_locs),
            "medication": sorted(meds_vocab),
        },
        "events": events,
    }

    with open(args.out, "w") as fh:
        json.dump(doc, fh, indent=2)

    enriched = sum(1 for e in events if "derived" in e)
    print(f"wrote {args.out}: {len(events)} events "
          f"({enriched} with enrichment, {len(events) - enriched} to be re-enriched on import); "
          f"{len(triggers)} triggers, {len(head_locs)} head locations, {len(meds_vocab)} meds")


if __name__ == "__main__":
    main()
