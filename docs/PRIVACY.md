# Megrim Privacy Policy

_Last updated: 2026-08-03_

**All data stays on your device.** We operate no servers and collect nothing — no accounts, no
analytics, no identifiers, no crash reporting.

## The only network traffic — and it's opt-in

Weather enrichment is **off by default**. Unless you explicitly enable it (during onboarding or
in Settings › Weather enrichment), **the app makes no automatic network requests**. The one
user-initiated exception: searching for your home location sends the place name you type to
Open-Meteo's geocoding API to look up coordinates — it happens only when you actively search,
and involves no GPS (the app never reads device location).

If you enable it, the app's only network traffic is to **Open-Meteo.com**, to fetch weather,
barometric pressure, and air-quality data for the **approximate (~1 km rounded)** location and
date of entries you create. No other host is ever contacted. See
[Open-Meteo's privacy policy](https://open-meteo.com/en/terms). You can turn it off again at any
time; already-fetched weather stays stored locally with your entries.

Location coordinates are **rounded to two decimal places (~1 km) before they ever leave the
device**, and precise coordinates are never stored.

Astronomical context (sunrise/sunset, daylight hours, moon phase) is computed **locally on the
device** with no network call.

## Location permission

Location access is **optional** and used only to tag where a migraine happened as a convenience.
The app is fully functional with the permission denied — it falls back to your configured home
location. No background location is used.

## Backups

Standard Android device backup applies (to *your* Google account, controlled by you in Android
settings). Manual export files (JSON/CSV) go wherever *you* choose to save them via the system
share sheet. If you object to OS-level backup, disable it in Android settings; manual
export/import remains the canonical migration path.

## Your controls

- Export all data to a JSON (full-fidelity) or CSV file at any time.
- Import from a Megrim JSON export (merge or replace).
- Delete any entry, or all data, on the device.

## Contact

This is an open-source project; report concerns via the public issue tracker.
