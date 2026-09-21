# Exporting a shareable report (HTML + PDF)

`tools/report.html` is a **single-file, fully offline static webapp** that turns a Megrim
`megrim-export` v1 JSON file into a clean, printable report you can hand to a clinician or
specialist — through an upload portal, on a USB stick, or on a laptop with no internet at all.

## Privacy model

The page makes **zero network requests** and **stores nothing**: no CDN scripts, no web fonts,
no analytics, no cookies, no localStorage. Your export is parsed in memory inside the tab and
vanishes when the tab closes. Verify by opening your browser's network inspector while using it,
or by loading it with Wi-Fi turned off.

What it does *not* contain: the full daily pressure history, so the app's pressure-change
correlation is omitted (everything else about the odds-ratio analysis is reproduced faithfully —
migraine-days, study window, Haldane–Anscombe correction, the same buckets and display gates).

## Use

1. Copy `tools/report.html` anywhere (it is self-contained; no server needed).
2. Open it in any modern browser (`file://` is fine).
3. Drop in your export (Megrim app → Settings → Export → JSON).
4. **HTML:** you're already looking at it — hand over the laptop, or right-click → Save Page As.
5. **PDF:** click **Print / Save as PDF** (or Ctrl/Cmd-P) and choose "Save as PDF" as the
   destination. The print stylesheet paginates the report; tables repeat their headers and
   sections start on fresh pages.

## What it renders

- Summary cards (events, migraine-days, study window, median severity/duration, most-reported
  trigger, aura count)
- Events-per-month timeline (bar color = average severity), severity distribution
- Patterns: weekday, time of day, season (hemisphere-corrected), moon phase, daylight length,
  duration histogram, sleep and stress summaries, self-reported trigger/food/head-location
  tallies
- Medication table with helped / didn't-help / unknown outcomes
- **Suspected factors**: odds ratios over migraine-days, computed exactly like the app
  (`correlations.dart`: ≥3 migraine-days per bucket, OR > 1, strongest 8 shown) — with the same
  read-this-first caveats
- Full event log, newest first

## Notes

- **App-computed figures when available.** Exports from app v1.0.4 embed an `analytics` block
  — the exact numbers the app's Analytics tab computed at export time, including the pressure
  factor and the timezone they were computed in. This page formats that block directly and the
  masthead says so; its own compute path is only a fallback for older exports and external
  files. Each factor shows every bucket (★ marks the app's headline top-8); if the in-browser
  recompute disagrees with the block — normally a compute-timezone difference — a note says so
  and the block wins. (A standalone `*.analytics.json` companion file is not an export — the
  page will tell you to open the full export instead.)
- Timestamps with an explicit offset are converted to *your* browser's local time; bare local
  timestamps are read as local time (same rule as the app's importer).
- The report re-derives weekday/season/time-of-day from the raw timestamps, and moon phase and
  daylight are computed with the same astronomy as the app (`astro.dart`: NOAA algorithm,
  90.833° zenith) using the export's `settings.home_location` (falling back to the median of
  per-event `geo_lat`/`geo_lon`) — so daylight buckets match the app exactly, and external
  imports that omit the `derived` block work too. A latitude is needed for
  moon/daylight/season buckets.
- Migraine-day semantics match the app exactly (`correlations.dart`): each event contributes
  one migraine-day — its local start date — and multi-day migraines count once, not for their
  full span. Migraine rates are rounded to two decimals like the app.
- Malformed input produces a warning banner rather than a broken page; unreadable events are
  skipped and listed.