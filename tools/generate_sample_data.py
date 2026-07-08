#!/usr/bin/env python3
"""Generate a megrim-export JSON file with realistic dummy data for demos / import testing.

Derived factors (season, day-of-week, time-of-day, moon phase/illumination) are computed with the
SAME math as the app (astro.dart / calendar_factors.dart) so imported rows need no re-enrichment.
Migraines are deliberately biased toward certain weekdays, winter, and full moons so the
correlations "Top Suspected Factors" card shows real elevated odds ratios.
"""
import json
import math
import random
from datetime import datetime, timedelta, timezone

random.seed(42)

# Home location used for the sample (Mountain time). Local = UTC-7 (DST ignored; harmless here).
HOME = {"lat": 39.96, "lon": -105.05, "label": "Boulder, Colorado, United States"}
TZ_OFFSET_HOURS = -7

EPOCH = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
SYNODIC = 29.530588853

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


def daylight_hours(day_of_year, lat=39.96):
    # Simple, adequate daylight approximation for a demo.
    decl = 23.44 * math.cos(math.radians(360 / 365 * (day_of_year + 10)))
    lat_r, decl_r = math.radians(lat), math.radians(decl)
    x = -math.tan(lat_r) * math.tan(decl_r)
    x = max(-1, min(1, x))
    return round(2 * math.degrees(math.acos(x)) / 15, 1)


def day_weight(d):
    """Bias migraine likelihood: Mon/Fri high, winter high, near full moon high."""
    w = 1.0
    if d.weekday() == 0:      # Monday
        w *= 3.0
    if d.weekday() == 4:      # Friday
        w *= 2.2
    if d.month in (12, 1, 2):  # winter
        w *= 1.8
    f = moon_frac(datetime(d.year, d.month, d.day, 12, tzinfo=timezone.utc))
    if 0.44 <= f < 0.56:      # near full moon
        w *= 2.5
    return w


def main():
    start = datetime(2024, 1, 1)
    end = datetime(2026, 6, 30)
    all_days = [start + timedelta(days=i) for i in range((end - start).days + 1)]
    weights = [day_weight(d) for d in all_days]
    chosen = set()
    picks = []
    while len(picks) < 55:
        d = random.choices(all_days, weights=weights, k=1)[0]
        key = d.date()
        if key in chosen:
            continue
        chosen.add(key)
        picks.append(d)
    picks.sort()

    events = []
    for i, d in enumerate(picks):
        # Local hour biased toward morning/evening onset.
        local_hour = random.choices(
            [6, 7, 8, 9, 10, 14, 16, 18, 19, 21],
            weights=[3, 4, 4, 3, 2, 2, 2, 3, 3, 2], k=1)[0]
        local_min = random.choice([0, 15, 30, 45])
        local_dt = datetime(d.year, d.month, d.day, local_hour, local_min)
        started = local_dt - timedelta(hours=TZ_OFFSET_HOURS)  # -> UTC
        started = started.replace(tzinfo=timezone.utc)

        duration_h = random.choice([2, 3, 4, 5, 6, 8, 10, 12, 18, 24])
        ended = started + timedelta(hours=duration_h)

        severity = random.randint(4, 9)
        f = moon_frac(started)
        doy = started.timetuple().tm_yday

        # Weather: bias pressure change negative (drops precede many migraines).
        pdelta24 = round(random.gauss(-4, 6), 1)
        pdelta48 = round(pdelta24 + random.gauss(-1, 4), 1)
        pressure = round(random.gauss(1013, 8), 1)
        temp = round(random.gauss(12, 10), 1)
        humidity = round(max(15, min(95, random.gauss(55, 18))), 0)

        n_trig = random.randint(1, 3)
        n_loc = random.randint(1, 2)
        meds = []
        if random.random() < 0.7:
            meds.append({
                "name": random.choice(MEDS),
                "dose": random.choice(["50mg", "100mg", "200mg", "400mg", "10mg"]),
                "helped": random.choice([True, True, False, None]),
            })

        events.append({
            "id": f"sample-{i:03d}-{d.strftime('%Y%m%d')}",
            "started_at": started.isoformat().replace("+00:00", "Z"),
            "ended_at": ended.isoformat().replace("+00:00", "Z"),
            "severity": severity,
            "location_head": random.sample(HEAD_LOCATIONS, n_loc),
            "aura_present": random.choice([True, False, False, None]),
            "aura_description": "shimmering zigzag" if random.random() < 0.2 else None,
            "meds_taken": meds,
            "triggers_suspected": random.sample(TRIGGERS, n_trig),
            "sleep_hours_prior": round(random.gauss(6.5, 1.3), 1),
            "stress_level": random.randint(1, 5),
            "foods_notable": random.sample(["Cheese", "Red wine", "Chocolate", "Citrus"],
                                           random.randint(0, 2)),
            "notes": random.choice(["", "", "rough day", "started at work",
                                    "woke up with it", "worse than usual"]),
            "geo_lat": HOME["lat"],
            "geo_lon": HOME["lon"],
            "geo_label": HOME["label"],
            "created_at": started.isoformat().replace("+00:00", "Z"),
            "updated_at": started.isoformat().replace("+00:00", "Z"),
            "derived": {
                "day_of_week": local_dt.weekday(),
                "season": season(local_dt.month),
                "time_of_day_bucket": tod_bucket(local_hour),
                "daylight_hours": daylight_hours(doy),
                "sunrise_utc": None,
                "sunset_utc": None,
                "moon_phase": moon_name(f),
                "moon_illumination": round((1 - math.cos(2 * math.pi * f)) / 2, 3),
                "temp_c": temp,
                "humidity_pct": humidity,
                "pressure_hpa": pressure,
                "precipitation_mm": round(max(0, random.gauss(0.5, 2)), 1),
                "pressure_delta_24h": pdelta24,
                "pressure_delta_48h": pdelta48,
                "aqi": random.randint(15, 90),
                "enriched_at": started.isoformat().replace("+00:00", "Z"),
                "enrich_error": None,
            },
        })

    doc = {
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

    out = "/home/aiuser/megrim-sample-data.json"
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=2)
    print(f"wrote {out} with {len(events)} events "
          f"({len(set(e['started_at'][:10] for e in events))} distinct days)")


if __name__ == "__main__":
    main()
