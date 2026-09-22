# Importing data into Megrim

Megrim can import migraine history from any source — another tracking app, a spreadsheet, a
database — as long as the data is converted to Megrim's own JSON export format
(`megrim-export`, version 1). This document specifies that format precisely enough to write a
converter, by hand or with an AI assistant.

A formal, machine-checkable version of this spec lives alongside this file:
[`megrim-export.schema.json`](megrim-export.schema.json) (JSON Schema, draft 2020-12).

**The short version:** an event needs only an `id` and a `started_at` timestamp. Every other
field is optional. Anything Megrim can derive on its own — weather, moon phase, season, day of
week, daylight hours — you should **omit entirely**: the app's enrichment queue computes it
automatically after import. A converter only has to carry over what a human actually recorded.

> **Note:** the CSV export is one-way (for spreadsheets/analysis). Only the JSON format can be
> imported.

## The envelope

```json
{
  "format": "megrim-export",
  "format_version": 1,
  "events": [ ... ]
}
```

| Key | Required | Notes |
|---|---|---|
| `format` | yes | Must be exactly `"megrim-export"`. |
| `format_version` | yes | Must be the integer `1`. |
| `events` | yes | Array of event objects (below). May be empty. |
| `settings` | no | `{"home_location": {"lat": …, "lon": …, "label": "…"}}`. Applied only on a **Replace** import, or when the app has no home location yet. |
| `vocabularies` | no | `{"trigger": [...], "head_location": [...], "medication": [...]}` — string arrays that seed the autocomplete suggestion lists. Merged; duplicates ignored. |
| `exported_at`, `app_version` | no | Written by Megrim's own exports; ignored on import. |
| `analytics` | no | Written by Megrim's own exports: the app's **computed** dashboard and odds-ratio results, for renderers. Ignored on import. See [The `analytics` block](#the-analytics-block-megrim-computed--ignored-on-import). |

Unknown keys anywhere in the document are ignored, and the file must be UTF-8.

## Import semantics

Chosen in the app at Settings → Import:

- **Merge** (default): events whose `id` already exists in the app are skipped; everything else
  is inserted. Stable ids make re-running an import idempotent.
- **Replace**: destructive — wipes all existing events first (double-confirmed in the UI).

The whole import runs in one transaction: if any event is malformed, **nothing** is imported and
the app reports which event failed. Events without a `derived` block are queued for automatic
enrichment (needs the event's `geo_lat`/`geo_lon` or the app's home location, and a network
connection at some point — it retries).

## Event fields

Only `id` and `started_at` are required. Omitted or `null` optional fields are simply empty in
the app.

| Field | Type | Notes |
|---|---|---|
| `id` | string, **required** | Any unique string. Megrim's own exports use UUIDs. Merge-dedup key — keep it stable across re-imports. |
| `started_at` | string, **required** | ISO-8601 timestamp. **Always include a timezone** (`Z` or `±hh:mm`); a bare local timestamp is interpreted in the *importing phone's* current zone, which silently shifts times if the data was recorded elsewhere. |
| `ended_at` | string or null | ISO-8601, same timezone rule. Null/omitted = ongoing. |
| `started_at_offset_minutes` | no | Integer, minutes east of UTC of the zone the event was **logged in** (e.g. `540` for UTC+9, `-360` for UTC−6). Since app v1.0.5 every local-calendar bucket (weekday, migraine-day, time of day, season, the History calendar) uses this, so an entry stays on the day it happened even when Analytics runs in another zone. If omitted, an explicit `+hh:mm`/`-hh:mm` suffix on `started_at` is used; if that is `Z` or absent, the phone's current zone applies (the pre-v1.0.5 behaviour). |
| `ended_at_offset_minutes` | no | Same for `ended_at`; falls back to the start offset. |
| `severity` | integer 1–10 or null | 10 = worst. |
| `location_head` | array of strings | Where on the head, e.g. `["Left temple", "Forehead"]`. Free text. |
| `aura_present` | boolean or null | Null = not recorded (distinct from `false`). |
| `aura_description` | string or null | Free text. |
| `meds_taken` | array of med objects | See below. |
| `triggers_suspected` | array of strings | Self-reported, e.g. `["Stress", "Red wine"]`. Free text. |
| `sleep_hours_prior` | number or null | Hours slept the night before, e.g. `5.5`. |
| `stress_level` | integer 1–10 or null | |
| `foods_notable` | array of strings | Free text. |
| `notes` | string or null | Free text. |
| `geo_lat`, `geo_lon` | number or null | Where the migraine happened (decimal degrees). Used for weather enrichment; omit to fall back to the app's home location. |
| `geo_label` | string or null | Human-readable place name. |
| `created_at`, `updated_at` | string | ISO-8601 record timestamps. Optional — default to the import time. |
| `derived` | object | **Omit for external imports** — Megrim recomputes it. Documented below only for completeness. |

### Med objects (`meds_taken` entries)

```json
{"name": "Sumatriptan", "dose": "50 mg", "time": "2024-06-01T09:30:00Z", "helped": true}
```

`name` is required; `dose` (free text), `time`, and `helped`
(true = helped / false = didn't / null or omitted = unknown) are optional and nullable.
Use ISO-8601 UTC for `time` where you have it — that lets the app's edit dialog prefill its
time picker — but any string (e.g. `"within 5 min"`) is tolerated and displayed as-is.

### The `derived` block (Megrim-computed — omit it)

Written by Megrim's own exports so a backup restores without re-enrichment. If you must
populate it (e.g. migrating enrichment from another system), the fields are:
`day_of_week` (integer, 0 = Monday … 6 = Sunday, in the event's local time),
`season` (`Winter`/`Spring`/`Summer`/`Autumn`, hemisphere-corrected),
`time_of_day_bucket` (`morning`/`afternoon`/`evening`/`night`),
`daylight_hours` (number), `sunrise_utc`/`sunset_utc` (ISO-8601),
`moon_phase` (`New Moon`, `Waxing Crescent`, `First Quarter`, `Waxing Gibbous`, `Full Moon`,
`Waning Gibbous`, `Last Quarter`, `Waning Crescent`), `moon_illumination` (0–1),
`temp_c`, `humidity_pct`, `pressure_hpa`, `precipitation_mm`, `pressure_delta_24h`,
`pressure_delta_48h` (numbers), `aqi` (integer), `enriched_at` (ISO-8601),
`enrich_error` (string). All nullable. A partial or inconsistent `derived` block is worse than
none — when in doubt, leave it out.

### The `analytics` block (Megrim-computed — ignored on import)

Written by Megrim's exports since `v1.0.4` so that anything that renders an export — a printable
report, a PDF, a spreadsheet — can **format** the app's numbers instead of re-implementing the
analytics. It is exactly what the Analytics tab computed at export time; the app recomputes from
`events` on import and never reads this block. Method details: [`METHODS.md`](METHODS.md). A
reference produced from the sample data lives at
[`app/test/fixtures/sample-data.analytics.json`](../app/test/fixtures/sample-data.analytics.json).

```json
"analytics": {
  "computed_at": "2026-09-20T18:00:00.000Z",
  "bucketing": "event-offset",
  "timezone": { "name": "MDT", "offset_minutes": -360 },
  "home_location": { "lat": 39.96, "lon": -105.05, "label": "Boulder, Colorado, United States" },
  "method": "docs/METHODS.md",
  "dashboard": {
    "summary": { "total_events": 55, "first_event": "…", "last_event": "…", "years_tracked": 2.4,
                 "avg_severity": 6.2, "avg_duration_hours": 8.4, "avg_interval_days": 15.7,
                 "interval_std_dev_days": 15.7, "events_per_year": 22.9 },
    "by_year":         [ { "year": 2024, "count": 26, "avg_severity": 5.7 }, … ],
    "by_day_of_week":  [ { "label": "Mon", "count": 13 }, … ],
    "by_time_of_day":  [ … ], "by_season": [ … ], "by_moon_phase": [ … ],
    "by_daylight":     [ … ], "pressure_delta": [ … ],
    "trigger_frequency": [ { "label": "Food", "count": 14 }, … ]
  },
  "correlations": {
    "available": true, "reason": null,
    "total_events": 55, "total_migraine_days": 55, "total_days_in_range": 879, "base_rate_pct": 6.26,
    "top_factors": [ { "factor": "Month", "condition": "Jul", "odds_ratio": 2.95,
                       "migraine_days": 9, "total_days": 62, "migraine_rate_pct": 14.52 }, … ],
    "factors": { "Day of week": [ { "bucket": "Mon", "migraine_days": 9, "total_days": 126,
                                    "migraine_rate_pct": 7.14, "odds_ratio": 1.23 }, … ],
                 "Season": [ … ], "Month": [ … ], "Moon phase": [ … ], "Daylight hours": [ … ],
                 "Pressure Δ 24h (hPa)": [ … ] },
    "caveats": [ "…" ]
  }
}
```

Notes for renderers:

- **Day bucketing is local-calendar** (day of week, season, migraine-days, the study window).
  `bucketing: "event-offset"` (app v1.0.5+) means each event was bucketed in the zone it was logged
  in (its `started_at_offset_minutes`); `timezone` is the phone's zone at export time and applies
  only to events without a stored offset. Re-deriving buckets from `started_at` in a different zone
  can legitimately give different counts for those.
- `correlations.factors` carries **every** bucket row for every factor; `top_factors` is the app's
  gated view (≥ 3 migraine-days and OR > 1, strongest 8). Use the former to reproduce the tab's
  detail tables and the latter for its headline list.
- The **pressure factor** (`Pressure Δ 24h (hPa)`) appears only when the app has a cached pressure
  baseline — built the first time Analytics is opened online with weather enrichment on. It cannot
  be computed from the export alone (the daily pressure history is not exported), so treat its
  absence as "not available", not zero.
- `dashboard` has no per-event calendar: that is the `events` array.
- `available: false` (with a `reason`) means fewer than 5 events; `dashboard` is still present.

## Minimal working example

This is a complete, valid import file:

```json
{
  "format": "megrim-export",
  "format_version": 1,
  "events": [
    {"id": "mig-2024-001", "started_at": "2024-06-01T09:00:00Z"},
    {
      "id": "mig-2024-002",
      "started_at": "2024-06-10T22:15:00-06:00",
      "ended_at": "2024-06-11T04:00:00-06:00",
      "severity": 7,
      "triggers_suspected": ["Stress"],
      "meds_taken": [{"name": "Ibuprofen", "dose": "600 mg", "helped": false}],
      "notes": "Woke up with it."
    }
  ]
}
```

## Validating a file before importing

With the JSON Schema in this folder and any off-the-shelf validator, e.g.
[`check-jsonschema`](https://pypi.org/project/check-jsonschema/) (`pip install check-jsonschema`):

```
check-jsonschema --schemafile docs/megrim-export.schema.json my-converted-data.json
```

The schema is deliberately a bit stricter than the importer (it also checks semantic ranges like
severity 1–10), so a file that passes will both import successfully and make sense in the app.

## Converting with an AI assistant

The practical route for a one-off migration: give an AI assistant this document (or the schema
file) together with a sample of your source data, using a prompt like:

> Here is the import format specification for Megrim, a migraine diary app: *[paste
> IMPORT.md or megrim-export.schema.json]*. Below is an export from my current migraine
> tracker: *[paste CSV rows / JSON / a table]*. Write a script that converts my full export
> into a valid `megrim-export` v1 JSON file. Map only fields my data actually has, omit the
> `derived` block, keep ids stable and unique, and make sure every timestamp carries an
> explicit timezone offset for *[your timezone]*.

Then validate the output with the command above and import it via Settings → Import. Prefer a
**Merge** import into a fresh install first, sanity-check History and Analytics, and keep your
original export until you're satisfied.

A real-world reference converter (Postgres → megrim-export) lives at
[`tools/migraine_tracker_export.py`](../tools/migraine_tracker_export.py).
