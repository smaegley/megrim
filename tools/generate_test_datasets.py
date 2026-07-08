#!/usr/bin/env python3
"""Generate several small, *themed* megrim-export files for hands-on testing.

Each file is deliberately biased so ONE thing is easy to see in the app:

  01-weekday-monday.json      migraines cluster on Mondays        -> "Day of week: Mon" factor
  02-season-winter.json       migraines cluster in winter         -> "Season: Winter" factor
  03-moon-fullmoon.json       migraines cluster near full moons   -> "Moon phase: Full Moon" factor
  04-mixed-no-signal.json     spread evenly, no bias              -> "nothing stands out" state
  05-sparse-below-threshold.json  only 4 events                   -> correlations "need >= 5 events"

Derived factors (day-of-week / season / time-of-day / moon phase + illumination) are computed with
the SAME math as the app (astro.dart / calendar_factors.dart) and written into each event, so the
files import fully offline with no re-enrichment. Weather is light synthetic filler (unbiased) just
so the descriptive charts render; it carries no signal.

Run:  python3 tools/generate_test_datasets.py
Files land in app/test/fixtures/datasets/ (committed; the same folder the tests read).
"""
import json
import math
import os
import random
from datetime import date, datetime, timedelta, timezone

# Home location (northern hemisphere -> meteorological winter = Dec/Jan/Feb). Mountain time.
HOME = {"lat": 39.96, "lon": -105.05, "label": "Boulder, Colorado, United States"}
TZ_OFFSET_HOURS = -7

EPOCH = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
SYNODIC = 29.530588853

# Anchor the datasets to end a few days before "now" (2026-07-08) so the days-since card is small.
END = date(2026, 7, 5)

TRIGGERS = ["Stress", "Sleep change", "Bright light", "Exercise", "Weather / pressure",
            "Alcohol", "Caffeine", "Food", "Hormonal", "Strong smell", "Screen time"]
HEAD_LOCATIONS = ["Left temple", "Right temple", "Behind left eye", "Behind right eye",
                  "Forehead", "Top of head", "Back of head", "Neck", "Both sides"]
MEDS = ["Sumatriptan", "Rizatriptan", "Ibuprofen", "Naproxen", "Acetaminophen"]


def moon_frac(dt_utc):
    days = (dt_utc - EPOCH).total_seconds() / 86400.0
    f = (days % SYNODIC) / SYNODIC
    return f + 1 if f < 0 else f


def moon_name(f):
    if f < 0.0625 or f >= 0.9375:
        return "New Moon"
    if f < 0.1875:
        return "Waxing Crescent"
    if f < 0.3125:
        return "First Quarter"
    if f < 0.4375:
        return "Waxing Gibbous"
    if f < 0.5625:
        return "Full Moon"
    if f < 0.6875:
        return "Waning Gibbous"
    if f < 0.8125:
        return "Last Quarter"
    return "Waning Crescent"


def season(month):
    if month in (12, 1, 2):
        return "Winter"
    if month in (3, 4, 5):
        return "Spring"
    if month in (6, 7, 8):
        return "Summer"
    return "Autumn"


def tod_bucket(hour):
    if 5 <= hour <= 11:
        return "morning"
    if 12 <= hour <= 16:
        return "afternoon"
    if 17 <= hour <= 20:
        return "evening"
    return "night"


def daylight_hours(d, lat=39.96):
    """Hours of daylight for date d at latitude lat — the SAME NOAA math as the app (astro.dart),
    so the stored value matches what the correlation engine recomputes. Longitude cancels out of the
    day length, so it is omitted."""
    doy = d.timetuple().tm_yday
    diy = 366 if (d.year % 4 == 0 and (d.year % 100 != 0 or d.year % 400 == 0)) else 365
    g = (2 * math.pi / diy) * (doy - 1 + 0.5)
    decl = (0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g)
            - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g)
            - 0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g))
    lat_r = math.radians(lat)
    zenith = math.radians(90.833)
    cos_ha = (math.cos(zenith) / (math.cos(lat_r) * math.cos(decl))
              - math.tan(lat_r) * math.tan(decl))
    if cos_ha > 1:
        return 0.0
    if cos_ha < -1:
        return 24.0
    ha_deg = math.degrees(math.acos(cos_ha))
    return round(8 * ha_deg / 60.0, 1)


def is_full_moon(d):
    f = moon_frac(datetime(d.year, d.month, d.day, 12, tzinfo=timezone.utc))
    return 0.4375 <= f < 0.5625


def build_event(rng, i, d):
    """Build one event dict for calendar date d, with realistic seeded detail."""
    # Keep onset local hour in [5, 16] so the event's UTC calendar date == its local date
    # (tz offset is -7); this keeps the day-of-week / season / moon signal timezone-stable.
    local_hour = rng.choice([6, 7, 8, 9, 10, 11, 13, 14, 15, 16])
    local_min = rng.choice([0, 15, 30, 45])
    local_dt = datetime(d.year, d.month, d.day, local_hour, local_min)
    started = (local_dt - timedelta(hours=TZ_OFFSET_HOURS)).replace(tzinfo=timezone.utc)
    ended = started + timedelta(hours=rng.choice([2, 3, 4, 5, 6, 8, 10, 12, 18, 24]))

    f = moon_frac(started)

    meds = []
    if rng.random() < 0.7:
        meds.append({
            "name": rng.choice(MEDS),
            "dose": rng.choice(["50mg", "100mg", "200mg", "400mg", "10mg"]),
            "helped": rng.choice([True, True, False, None]),
        })

    def iso(dt):
        return dt.isoformat().replace("+00:00", "Z")

    return {
        "id": f"{i:03d}-{d.strftime('%Y%m%d')}",
        "started_at": iso(started),
        "ended_at": iso(ended),
        "severity": rng.randint(3, 9),
        "location_head": rng.sample(HEAD_LOCATIONS, rng.randint(1, 2)),
        "aura_present": rng.choice([True, False, False, None]),
        "aura_description": "shimmering zigzag" if rng.random() < 0.2 else None,
        "meds_taken": meds,
        "triggers_suspected": rng.sample(TRIGGERS, rng.randint(1, 3)),
        "sleep_hours_prior": round(rng.gauss(6.5, 1.3), 1),
        "stress_level": rng.randint(1, 5),
        "foods_notable": rng.sample(["Cheese", "Red wine", "Chocolate", "Citrus"],
                                    rng.randint(0, 2)),
        "notes": rng.choice(["", "", "rough day", "woke up with it", "worse than usual"]),
        "geo_lat": HOME["lat"],
        "geo_lon": HOME["lon"],
        "geo_label": HOME["label"],
        "created_at": iso(started),
        "updated_at": iso(started),
        "derived": {
            "day_of_week": local_dt.weekday(),  # Mon=0..Sun=6
            "season": season(local_dt.month),
            "time_of_day_bucket": tod_bucket(local_hour),
            "daylight_hours": daylight_hours(local_dt.date(), HOME["lat"]),
            "sunrise_utc": None,
            "sunset_utc": None,
            "moon_phase": moon_name(f),
            "moon_illumination": round((1 - math.cos(2 * math.pi * f)) / 2, 3),
            # Unbiased synthetic weather so the descriptive charts render (no signal).
            "temp_c": round(rng.gauss(12, 10), 1),
            "humidity_pct": round(max(15, min(95, rng.gauss(55, 18))), 0),
            "pressure_hpa": round(rng.gauss(1013, 8), 1),
            "precipitation_mm": round(max(0, rng.gauss(0.5, 2)), 1),
            "pressure_delta_24h": round(rng.gauss(0, 5), 1),
            "pressure_delta_48h": round(rng.gauss(0, 6), 1),
            "aqi": rng.randint(15, 90),
            "enriched_at": iso(started),
            "enrich_error": None,
        },
    }


def doc_for(events):
    return {
        "format": "megrim-export",
        "format_version": 1,
        "exported_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "app_version": "1.0.0",
        "settings": {"home_location": HOME},
        "vocabularies": {
            "trigger": TRIGGERS,
            "head_location": HEAD_LOCATIONS,
            "medication": MEDS,
        },
        "events": events,
    }


def days_back(pool_days, predicate, count, rng):
    """Pick `count` distinct days (most recent first) from pool_days matching predicate."""
    picks = [d for d in pool_days if predicate(d)]
    return picks[:count]


def make_events(signal_days, noise_days, seed):
    rng = random.Random(seed)
    days = sorted(set(signal_days) | set(noise_days))
    return [build_event(rng, i, d) for i, d in enumerate(days)]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(here, "..", "app", "test", "fixtures", "datasets")
    os.makedirs(out_dir, exist_ok=True)

    # A long descending pool of candidate days ending at END.
    pool = [END - timedelta(days=i) for i in range(0, 365 * 3)]

    written = []

    def write(name, events):
        path = os.path.join(out_dir, name)
        with open(path, "w") as fh:
            json.dump(doc_for(events), fh, indent=2)
        rel = os.path.relpath(path, os.path.join(here, ".."))
        written.append((rel, len(events)))

    # 01 — Monday signal: 22 Mondays + 8 non-Monday days for baseline.
    mondays = days_back(pool, lambda d: d.weekday() == 0, 22, None)
    non_mon = days_back(pool, lambda d: d.weekday() in (2, 4, 6), 8, None)
    write("01-weekday-monday.json", make_events(mondays, non_mon, seed=1))

    # 02 — Winter signal: 22 winter-month days + 8 non-winter days (needs multiple winters).
    winter = days_back(pool, lambda d: d.month in (12, 1, 2), 22, None)
    non_winter = days_back(pool, lambda d: d.month in (5, 7, 9), 8, None)
    write("02-season-winter.json", make_events(winter, non_winter, seed=2))

    # 03 — Full-moon signal: 18 full-moon-window days + 10 non-full-moon days spread across the
    # year (spaced out so they don't accidentally cluster on one weekday/season/phase).
    full = days_back(pool, is_full_moon, 18, None)
    spread_noise = [END - timedelta(days=18 * i + 9) for i in range(24)]
    non_full = [d for d in spread_noise if not is_full_moon(d)][:10]
    write("03-moon-fullmoon.json", make_events(full, non_full, seed=3))

    # 04 — No signal: 40 days spread evenly (every ~18 days) across ~2 years.
    spread = [END - timedelta(days=18 * i) for i in range(40)]
    write("04-mixed-no-signal.json", make_events(spread, [], seed=4))

    # 05 — Below the correlation threshold: only 4 events.
    sparse = [END - timedelta(days=i) for i in (2, 16, 33, 51)]
    write("05-sparse-below-threshold.json", make_events(sparse, [], seed=5))

    # 06 — Daylight (photoperiod) signal: cluster migraines on short-daylight days in the
    # "9.5-11 h" band. At this latitude that band falls in BOTH late autumn and late winter, so with
    # picks spread across the sub-bands and years the signal shows up as a Daylight-hours factor
    # while the Season is split (autumn + winter) — the point that daylight is not the same as
    # season. 8 long-daylight (summer) days give the baseline contrast.
    def spread(candidates, count, min_gap_days):
        picked = []
        for d in candidates:
            if all(abs((d - p).days) >= min_gap_days for p in picked):
                picked.append(d)
                if len(picked) >= count:
                    break
        return picked

    band = [d for d in pool if 9.5 <= daylight_hours(d, HOME["lat"]) < 11.0]
    short_day = spread(band, 22, 10)
    long_day = days_back(pool, lambda d: daylight_hours(d, HOME["lat"]) >= 14.0, 8, None)
    write("06-daylight-short.json", make_events(short_day, long_day, seed=6))

    for rel, n in written:
        print(f"wrote {rel:48s} {n} events")


if __name__ == "__main__":
    main()
