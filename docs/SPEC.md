# Megrim — Specification & Build Plan

**Name (final, decided 2026-07-07, supersedes "Tallyhead"):** **Megrim** — an archaic English
word literally meaning *migraine*. Store title/subtitle: **"Megrim — Migraine Tracker &
Diary"** (quick collision check 2026-07-07 found no Play/F-Droid app of that name — only the
dictionary word and a flatfish; re-verify before first publish).
**Status:** Draft v0.2, 2026-07-02. **Origin:** ground-up rebuild of
the private `migraine-tracker` app for public, open-source distribution. The private app and its
spec (`migraine-tracker/docs/spec.md`) are the template; this document is self-contained and is
the handoff artifact for implementation.

---

## 1. Product definition

A **privacy-first, offline-first migraine diary for Android** that automatically enriches each
logged migraine with weather, barometric-pressure, and astronomical context — computed and stored
**entirely on the device** — and surfaces personal descriptive analytics plus odds-ratio
"suspected factors" correlations. No accounts, no server, no telemetry. Data is fully portable
via export/import.

**Positioning (from market research, 2026-07):** Migraine Buddy owns the community/cloud niche;
Pressure Pal / WeatherX / MigrAid own weather alerts (mostly iOS, all cloud-backed); the only
privacy-respecting FOSS option (Migraine Log on F-Droid) is a bare-bones diary with no enrichment
or analytics. **The empty quadrant this app fills: privacy-respecting + automatic enrichment +
real personal analytics.** A published study (PMC6347475) documents widespread privacy problems in
headache apps — "we collect nothing" is the differentiator, not a limitation.

### 1.1 Core decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Source model | **Open source**, public repo | Required for F-Droid; enables trust story |
| License | **GPL-3.0-or-later** (decided 2026-07-02) | Prevents closed-source forks of a health app; standard on F-Droid |
| Backend | **None. Ever.** | No hosting cost, no data custody, no liability surface |
| Data location | On-device SQLite only | Concern #3: user owns everything |
| Monetization | **Free + donate button** | Concern #4; also required: Open-Meteo free tier is non-commercial-only |
| Telemetry / crash SDK | **None** (no Firebase/Crashlytics — banned on F-Droid anyway) | Privacy story; add a "copy error details" button instead |
| First distribution | **GitHub Releases → F-Droid**; Play optional later | Simplest FOSS path; defers Play's org-account / health-declaration burden |
| Platform | Android only for v1 (Flutter keeps iOS possible) | Matches existing expertise and code |

### 1.2 Identity / publishing

**Decision (2026-07-08): published under the author's own identity — the earlier pseudonym /
anonymity plan was dropped.** Concretely:

- **GitHub:** [`github.com/smaegley/megrim`](https://github.com/smaegley/megrim) (public); commits
  authored as Steve Maegley <steve@maegley.com>.
- **Application id:** `org.maegley.megrim` — reverse-domain of `maegley.org` (a domain the author
  controls via Cloudflare); independent of the GitHub handle and of the `maegley.com` email domain.
  Immutable once published.
- **Signing:** a dedicated release keystore (RSA-2048, alias `megrim`, CN=Steve Maegley), kept only
  on the author's Mac + password manager. The four signing values are stored as repo Actions
  secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`); tagging `v*` builds
  a signed APK + AAB via `release.yml`.
- **F-Droid:** submission is a merge request to `fdroiddata` (post-1.0).
- **Google Play (if ever):** optional later phase; individual accounts display the legal name and
  Health-category apps may require an Organization account. Not pursued for now.
- **Donations:** optional; wire `.github/FUNDING.yml` + the in-app Donate URL to a platform if/when
  desired (no payment SDK in-app).

### 1.3 Non-goals (v1)

No cloud sync, no accounts, no multi-device sync, no community/social features, no push
notifications, no migraine *prediction* claims (only retrospective correlation), no iOS, no
in-app purchases, no wearable integration, no Health Connect (adds Play policy burden for little
value — revisit later).

---

## 2. Architecture

```
┌────────────────────────────── Android device ──────────────────────────────┐
│  Flutter app (single codebase, lib/main.dart only — no web entry point)    │
│                                                                            │
│  UI: QuickLog · History (list+calendar) · EventDetail · Analytics ·        │
│      Settings · Onboarding · ManageVocab · About/Licenses                  │
│           │                          │                                     │
│  ┌────────▼─────────┐   ┌───────────▼─────────────┐                        │
│  │ Drift / SQLite   │   │ Analytics engine (Dart)  │                       │
│  │ events, derived, │◄──│ dashboard aggregates +   │                       │
│  │ settings, vocab  │   │ odds-ratio correlations  │                       │
│  └────────▲─────────┘   └──────────────────────────┘                       │
│           │                                                                │
│  ┌────────┴─────────────────────────┐    ┌──────────────────────────┐      │
│  │ Enrichment engine (Dart)         │    │ Export/Import (JSON/CSV) │      │
│  │ · astro: computed locally (math) │    │ via share sheet / SAF    │      │
│  │ · weather: Open-Meteo HTTPS ─────┼──► └──────────────────────────┘      │
│  │ · offline retry queue            │         only network calls:          │
│  └──────────────────────────────────┘         open-meteo.com APIs          │
└────────────────────────────────────────────────────────────────────────────┘
```

**The entire backend of the private app is replaced by three on-device components:** the
enrichment engine (§5), the analytics engine (§6), and export/import (§7). Network access is
used **only** for Open-Meteo (geocoding, weather archive/forecast, air quality). No other host
is ever contacted. This is a checkable, advertised property.

### 2.1 Dependency policy (F-Droid constraint — enforce from day one)

Allowed: FOSS-licensed pub.dev packages with no Google Play Services / Firebase / proprietary
transitive dependencies.

Baseline set (all carried over from the private app, all FOSS-clean):
`drift`, `sqlite3_flutter_libs`, `path_provider`, `path`, `uuid`, `http`,
`shared_preferences`, `intl`, `provider`, `fl_chart`, `url_launcher`, `file_picker` or
`share_plus` (for export — verify GMS-free; both are community standards on F-Droid apps).

**Location:** `geolocator` defaults to Google's fused location provider on Android. Either set
`AndroidSettings(forceLocationManager: true)` on every call, or use a plain-LocationManager
package. GPS is **optional** (quick-log convenience only); the app must be fully functional with
the permission denied.

**Banned:** Firebase (all), Crashlytics, Google Maps SDK, Play Services location/ads/analytics,
any closed-source SDK. CI should fail if `com.google.firebase` or `com.google.android.gms`
appears in the merged dependency graph (simple gradle-deps grep step).

---

## 3. Data model (Drift/SQLite, schema v1)

Carried from the private app with server-sync fields removed and vocab made user-editable.
All timestamps stored UTC (ISO-8601 in exports); all display in local time.

### 3.1 `migraine_events`

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUIDv4, client-generated |
| started_at | INTEGER (epoch ms UTC) | required |
| ended_at | INTEGER nullable | null = ongoing |
| severity | INTEGER 1–10 nullable | |
| location_head | TEXT nullable | JSON array of strings (vocab §3.4) |
| aura_present | INTEGER (bool) nullable | tri-state yes/no/unknown |
| aura_description | TEXT nullable | |
| meds_taken | TEXT nullable | JSON `[{name, dose, time, helped}]` |
| triggers_suspected | TEXT nullable | JSON array of strings (vocab §3.4) |
| sleep_hours_prior | REAL nullable | |
| stress_level | INTEGER 1–5 nullable | |
| foods_notable | TEXT nullable | JSON array of strings |
| notes | TEXT nullable | |
| geo_lat / geo_lon | REAL nullable | rounded to 2 decimals (~1 km) **at capture time** — never store precise coords |
| geo_label | TEXT nullable | human-readable place |
| created_at / updated_at | INTEGER | epoch ms UTC |

Dropped from private app: `legacy_incident_no`, `deleted_at` (no sync → hard delete is fine; keep
a Snackbar-undo grace instead of tombstones), `needs_review`, `synced_to_server`.

### 3.2 `derived_factors` (1:1 with events, computed, never user-edited)

| Column | Type | Source |
|---|---|---|
| event_id | TEXT PK → events | |
| day_of_week | INTEGER 0=Mon..6=Sun | local date of started_at |
| season | TEXT | meteorological, hemisphere-aware from latitude |
| time_of_day_bucket | TEXT | morning 05–11 / afternoon 12–16 / evening 17–20 / night 21–04 (local) |
| daylight_hours | REAL | computed (§5.2) |
| sunrise_utc / sunset_utc | INTEGER nullable | computed |
| moon_phase | TEXT (8 phases) | computed |
| moon_illumination | REAL 0–1 | computed |
| temp_c, humidity_pct, pressure_hpa, precipitation_mm | REAL nullable | Open-Meteo (§5.1) |
| pressure_delta_24h / pressure_delta_48h | REAL nullable | computed from hourly series |
| aqi | INTEGER nullable | Open-Meteo air quality, best-effort |
| enriched_at | INTEGER nullable | null/partial ⇒ row is in the retry queue |
| enrich_error | TEXT nullable | last failure reason, surfaced in UI |

### 3.3 `app_settings` (key/value, values JSON)

`home_location {lat, lon, label}` (required, set in onboarding) ·
`pressure_baseline {from, to, lat, lon, buckets…}` (correlations cache, §6.2) ·
`disclaimer_accepted_at` · `schema_version` · UI prefs.

### 3.4 `vocabularies` — user-editable option lists

One table `vocab(kind TEXT, value TEXT, sort INTEGER, PRIMARY KEY(kind, value))`, seeded on
first run. Kinds: `trigger` (the 11 defaults from the private app), `head_location` (the 9
defaults), `medication` (empty; learned from entries as suggestions). Manage screens = the
"Manage triggers" pattern already built in the private app (add/rename/delete; renames do **not**
rewrite historical events; chips shown = vocab ∪ values present on the open event).

---

## 4. Screens & UX

Port the private app's screens (same layouts; the theme now supports **both light and dark and
follows the system setting** — see §12 Session-3, backlog #8) with these changes:

1. **Onboarding (new, first run):** welcome → **medical disclaimer** (must accept; text in §9)
   → home-location search (Open-Meteo geocoder, same `LocationPickerField` pattern) → optional
   GPS permission with plain-language explanation ("only to tag where a migraine happened; never
   leaves your device except as rounded coordinates sent to the weather service"). No skipping
   home location — enrichment needs it as fallback.
2. **Quick Log:** identical to private app (LOG MIGRAINE → active view with elapsed timer,
   severity slider, notes, cancel-X, MIGRAINE ENDED). GPS capture with 5 s timeout →
   fallback to home location (read **locally** from settings — the private app's HTTP fallback
   to the server disappears). Coordinates rounded to 2 decimals before storing.
3. **History:** list + month-grid calendar toggle (both already built in the private app —
   port as-is). Swipe-to-delete becomes hard delete with Snackbar undo (5 s).
4. **Event Detail:** editable start/end date-time + recorded location; head-location and
   suspected-trigger chips; a **Medications section** (per-med name/dose/time/"helped?", backlog #6);
   the re-enrich-on-location-change call is a local enqueue instead of an API POST.
5. **Analytics:** computed locally (§6). Summary is a **2×3 stat-tile grid**; Top Suspected Factors
   are **horizontal odds-ratio bars** (with caveats); descriptive charts (day-of-week, season,
   time-of-day, daylight, pressure-delta buckets, moon phase) show **per-bar counts** and a
   **purple magnitude shade**; season & time-of-day are donuts. Plus a "days since last migraine"
   card and a "Most-tagged triggers" frequency card. Includes the required "Weather data by
   Open-Meteo.com" attribution footer (CC-BY 4.0).
6. **Settings:** home location (change → confirm → bulk re-enrich), vocab management, export /
   import (§7), **donate (Ko-fi URL → browser)**, About (version, license, source link, bundled
   licenses page via `showAboutDialog`'s LicenseRegistry, privacy summary, disclaimer re-read).
7. **Removed vs private app:** sync button/status, OTA update checker (stores handle updates),
   web entry point (`web_main.dart`), all of `api_service.dart` except nothing — it's deleted.

---

## 5. Enrichment engine (on-device)

Runs as a Dart service; triggered on event save/end, on location edit, on home-location change
(bulk), and on import (bulk). A `pending` queue = rows where `enriched_at IS NULL`; retried on
app start and on connectivity regain. Weather enrichment of an *ongoing* event happens at start;
re-checked at end (cheap; same day).

### 5.1 Weather (Open-Meteo, keyless HTTPS)

- **Historical (event older than ~7 days):** `https://archive-api.open-meteo.com/v1/archive?
  latitude={lat}&longitude={lon}&start_date={D-2}&end_date={D}&hourly=temperature_2m,
  relative_humidity_2m,surface_pressure,precipitation&timezone=UTC` — fetch a 3-day hourly
  window ending on the event date.
- **Recent (≤7 days, archive lags ~5 days):** `https://api.open-meteo.com/v1/forecast?...
  &past_days=7&hourly=...` same variables.
- From the hourly series: value at the hour of onset; `pressure_delta_24h` = P(onset) −
  P(onset−24 h); `_48h` likewise. Store raw values used so recomputation isn't needed.
- **AQI (best-effort):** `https://air-quality-api.open-meteo.com/v1/air-quality?...&hourly=us_aqi`
  — historical coverage is limited (CAMS era, ~2013+ and shorter for some fields); on miss,
  leave null, don't error.
- Coordinates in every request: **rounded to 2 decimals** (privacy: ~1 km cell). Timeout 15 s;
  exponential backoff ×3; then leave queued with `enrich_error`.
- **Terms:** free tier is **non-commercial** use — the app must remain free (donations OK per
  their FAQ posture; re-verify at release). Attribution required (§4.5). Rate limit 10 k
  calls/day — a bulk re-enrich of even 1 000 events is ~2 000 calls; throttle bulk jobs to
  ~2 req/s and show progress.

### 5.2 Astro (pure local math — no network, no dependency risk)

Implement in `lib/enrichment/astro.dart`, unit-tested against golden values:
- **Sunrise/sunset/daylight:** NOAA solar calculation (Meeus-based; ~80 lines of Dart). Accuracy
  ±1–2 min is ample.
- **Moon phase & illumination:** compute lunar age from a known new-moon epoch
  (e.g. 2000-01-06 18:14 UTC, synodic month 29.530588853 d) → illumination
  `= (1 − cos(2π·age/29.5306))/2` → map to the 8 named phases. Accuracy is fine for bucketing.
- **Golden tests:** generate ~40 reference rows (varied dates 2011–2026, lat 40 N + edge cases
  lat 0/60 N/winter) from the private app's Python `astral`/`ephem` output; assert Dart results
  within tolerance (daylight ±5 min, illumination ±0.02, phase exact).

### 5.3 Calendar factors

Trivial local computation (dow, season with southern-hemisphere flip when `lat < 0`, ToD bucket).

---

## 6. Analytics engine (on-device port of `analytics.py` + `correlations.py`)

`lib/analytics/dashboard.dart` and `lib/analytics/correlations.dart`, pure functions over the
Drift DB → same JSON-shaped structures the existing chart widgets already consume (minimizes UI
changes). A few hundred events is trivial; run in `compute()` isolate only if profiling says so.

### 6.1 Dashboard aggregates
Direct port: summary (totals, years tracked, avg severity/duration/interval, first/last event),
counts by year, month-of-year, day-of-week, time-of-day, season, pressure-delta buckets
(<−10, −10..−5, −5..0, 0..5, 5..10, >10 hPa), moon phase, calendar list (date+severity).

### 6.2 Correlations (Top Suspected Factors)
Port the exact algorithm:
- Study window = first event date → today. Migraine-days = distinct local dates with ≥1 event.
- Per factor bucket build the 2×2 contingency (migraine-days vs non-migraine-days, in-bucket vs
  not) and compute the odds ratio with **Haldane–Anscombe correction** (+0.5 to all cells when
  any cell is 0).
- Baselines for non-migraine days: **calendar factors analytically** (every date has a known
  dow/season/month); **moon phase analytically** (uniform over the synodic cycle);
  **pressure buckets need real history** → one bulk fetch of daily-level pressure stats for the
  full window at home location (Open-Meteo archive, `daily=surface_pressure_mean` or hourly
  chunked by year), bucketed and cached in `app_settings.pressure_baseline`; refresh only when
  the window grows by >30 days or home location changes. Show a one-time "computing baseline…"
  progress state.
- Output: factors sorted by OR, filtered (n_days ≥ 3 in bucket, OR ≥ 1.5), with
  migraine_days/total_days/rate per bucket + the caveats list (small sample, multiple
  comparisons, correlation ≠ causation) — same card UI as private app.
- **Golden tests:** run the Python implementation on 3 synthetic datasets (tiny/sparse/dense) and
  on an anonymized copy of the real 39-event dataset; store outputs as JSON fixtures; assert the
  Dart port matches (OR within 0.01).

---

## 7. Export / Import (the portability contract)

### 7.1 JSON export (full fidelity — the backup format)
Single file `megrim-export-YYYYMMDD.json`:
```json
{
  "format": "megrim-export",
  "format_version": 1,
  "exported_at": "2026-07-02T12:00:00Z",
  "app_version": "1.0.0",
  "settings": { "home_location": {...} },
  "vocabularies": { "trigger": [...], "head_location": [...] },
  "events": [ { ...all §3.1 fields, ISO-8601 timestamps..., "derived": { ...§3.2... } } ]
}
```
Delivered via the system **share sheet** (user picks Drive/Dropbox/email/files — that's the
"user's cloud" story with zero integration) and via SAF "Save to file". Derived factors are
included so an import never *requires* network.

### 7.2 CSV export (analysis-friendly)
One row per event, arrays joined with `;`, derived columns flattened. For spreadsheets/doctors.

### 7.3 Import
- JSON (format_version-checked): **merge** (skip existing ids) or **replace all** (destructive,
  double-confirm). Missing `derived` ⇒ rows enqueued for enrichment.
- v1 imports **only** this JSON format. (Generic-CSV import and Migraine Buddy converters are
  explicitly v2 candidates.)

### 7.4 Android Auto Backup
Enable (`android:allowBackup` + full-backup content including the DB). Documented in the privacy
policy ("device-encrypted backup to the user's own Google account, controlled by Android
settings"). Users who object can disable OS-level backups; export/import remains the canonical
migration path.

### 7.5 Steve's migration
One-off script (private repo, not shipped): pull events+derived from the personal server API →
emit `megrim-export` JSON → import on phone. ~50 lines of Python against
`GET /api/sync/pull`.

---

## 8. Repo, CI, release engineering

- **Repo layout:** `app/` (Flutter), `docs/` (this spec, PRIVACY.md, screenshots),
  `fastlane/metadata/android/en-US/` (F-Droid/Play listing texts: `full_description.txt`,
  `short_description.txt`, `changelogs/`, `images/`), `.github/workflows/ci.yml`,
  `.github/FUNDING.yml`, `LICENSE`, `README.md`, `CONTRIBUTING.md` (set expectations: hobby
  project, no SLA — concern #2).
- **CI (GitHub Actions):** `flutter analyze` + `flutter test` on PR/push; release workflow builds
  a signed APK on tag and attaches it to a GitHub Release. Keystore in GH secrets (base64).
  **Generate a brand-new keystore for this app** (do not reuse the private app's debug keystore;
  new identity, and the public app must not share signatures with anything personal).
- **Versioning:** semver `x.y.z` + monotonically increasing `versionCode`. Tag = release.
- **F-Droid submission (after 1.0):** merge request to `fdroiddata` with the build recipe;
  Flutter is accepted (prebuilt-SDK carve-out in their inclusion policy). Expect review
  iterations on the recipe. Optionally publish reproducible builds so F-Droid ships your
  signature.
- **Target/min SDK:** target = current Play requirement (API 35+ in 2026, ratchets yearly — this
  is the main recurring maintenance task); minSdk 26 (Android 8.0) is a sane floor.
- **Permissions manifest (complete list):** `INTERNET`, `ACCESS_COARSE_LOCATION` +
  `ACCESS_FINE_LOCATION` (optional feature, `<uses-feature android:required="false">`). Nothing
  else. No background location, no notifications (v1), no storage permission (SAF handles it).

---

## 9. Legal & policy artifacts (draft text — refine, not legal advice)

- **Medical disclaimer (onboarding + About + store listing):** "Megrim is a personal diary
  and is **not a medical device**. It does not diagnose, treat, cure, or prevent any condition.
  'Suspected factors' are statistical associations in *your own log* — association is not
  causation. Always consult a qualified healthcare professional about your migraines and before
  making any treatment decisions."
- **Privacy policy (PRIVACY.md, linked in app + listing):** "All data stays on your device. We
  operate no servers and collect nothing — no accounts, no analytics, no identifiers, no crash
  reporting. The app's only network traffic is to Open-Meteo.com to fetch weather for the
  approximate (~1 km rounded) location and date of entries you create; see Open-Meteo's privacy
  policy. Backups: standard Android device backup to *your* Google account (you control it in
  Android settings); manual export files go wherever you choose to save them."
- **In-analytics caveats:** keep the private app's caveat list verbatim on the correlations card.
- **Play-only extras (deferred until/if Play):** Health apps declaration form, data-safety form
  ("no data collected/shared"), possible Organization-account requirement (verify in Console).

---

## 10. Build phases

| Phase | Deliverable | Notes |
|---|---|---|
| 0 | Repo scaffold: license, README, CI (analyze+test), theme, GitHub account + git identity (§1.2), release keystore | Half a day |
| 1 | Data layer: Drift schema v1, vocab seeding, settings; Quick Log + History (list+calendar) + Event Detail + vocab manage screens ported from private app | Largest UI port; most code reusable with sync/API surgery |
| 2 | Enrichment engine: astro math + golden tests; Open-Meteo client + hourly-series extraction + retry queue; wiring to save/edit/import | The genuinely new code |
| 3 | Analytics engine: dashboard port + correlations port + pressure baseline cache; golden tests vs Python fixtures; Analytics screen wiring | Fixtures generated from private app **before** starting |
| 4 | Export/import (JSON + CSV + share/SAF), onboarding flow, disclaimer gate, Settings (donate, About/licenses, privacy) | Portability contract |
| 5 | Hardening: multi-device/emulator matrix (small phone, tablet, API 26/30/35), empty-state & error UX, a11y pass (TalkBack, contrast, touch targets), perf check on 1k synthetic events | Concern #1 |
| 6 | Release: signed GitHub Release APK, dogfood 2–4 weeks (Steve migrates via §7.5), then F-Droid `fdroiddata` MR. Play = separate later decision | |

**Testing strategy:** unit tests for astro (golden), correlations (golden vs Python), export→
import round-trip (property: DB → JSON → fresh DB is identity), pressure-delta extraction from
canned API responses (mock HTTP); widget tests for onboarding gate and log→end flow. No network
in tests.

## 11. Decided + open questions

**Decided (2026-07-02):**
- Name: **Megrim** (decided 2026-07-07; supersedes "Tallyhead" from 2026-07-02) · listing title
  "Megrim — Migraine Tracker & Diary".
- License: **GPL-3.0-or-later**.

**Still open (decide before the phase that needs them):**
1. ~~Application id~~ — **decided: `org.maegley.megrim`** (shipped in v0.1.0; see §1.2).
2. Donation platform(s) (Liberapay / Ko-fi / GitHub Sponsors) — optional (just a URL).
3. Ever do Play? If yes: org account vs personal-name exposure; revisit after F-Droid traction.
4. Med-list vocab: seed with common abortives (sumatriptan…) or start empty? — Phase 1 (leaning empty + learn-from-entries).

---

## 12. Implementation status (2026-07-09)

First implementation pass complete: a buildable Flutter app under `app/`, `flutter analyze`
clean, **55 tests passing**, and a **signed release APK** produced (release signing path verified
with a throwaway keystore, not just the debug fallback). **The app has been run on an Android
emulator** (on Steve's Mac) through onboarding, logging, history, and analytics.

**Done:** Phase 0 (scaffold, CI incl. FOSS dependency-ban check, license/README/privacy, fastlane
metadata) · Phase 1 (Drift schema v1 + seeding + all screens) · Phase 2 (enrichment: astro golden
tests, Open-Meteo client, retry queue) · Phase 3 (analytics: dashboard + correlations + pressure
baseline, golden tests) · Phase 4 (JSON+CSV export / JSON import with round-trip test, onboarding,
disclaimer gate, settings) · Phase 6 (signed release workflow on tag) · adaptive launcher icon.

**Session-1 run-in fixes/additions (2026-07-08):** fixed the Analytics tab not recomputing on open
(it lives in an IndexedStack; now refreshes on tab-open + pull-to-refresh + a refresh button);
added a descriptive **"Most-tagged triggers"** frequency card (explicitly not a correlation); added
a **sample demo dataset** (`tools/generate_sample_data.py` → `app/test/fixtures/sample-data.json`)
plus an import→analytics verification test. Dev loop: build/test happen on the Linux VM; Steve runs
the app on his Mac and pulls changes via a regenerated git bundle (see the memory notes).

**Session-2 review changes (2026-07-08):** a batch of post-review UI improvements —
- **Delete/discard.** History rows keep swipe-to-delete; Event detail gains a delete action (with
  undo); the in-progress Quick Log view gains a **Discard** action to stop and delete a mistaken
  entry.
- **History list.** A coloured **severity badge** (green→red circle with the 1–10 number) leads each
  row; the List/Calendar toggle is now a persistent **segmented picker**; a **"Add past entry"**
  FAB creates an entry and opens the editor for recreating a migraine after the fact.
- **Editable entries.** Event detail now edits **start/end date-time** and the **recorded
  location** (re-enqueues enrichment on change), so an un-logged migraine can be fully recreated.
- **Analytics layout.** New **"days since last migraine"** card at the top, colour-coded by how the
  current gap compares to the mean interval μ ± SD σ (green `d<μ−σ` → red `d≥μ+σ`, i.e. redder =
  more "overdue"; comparison documented in code for easy inversion). Order is now days-since →
  summary → **Top suspected factors** (collapsed to the strongest condition per factor category,
  expand for the full list + caveats) → **Most-tagged triggers** (top 5, expand for all + the
  not-a-correlation disclaimer) → charts. Every chart is a **collapsible** card showing a one-line
  "Most: …" summary when minimised. Added **By-season** and **By-time-of-day donut** charts (fl_chart
  `PieChart`; dark-validated categorical palette with a direct-labelled legend).
- **Two review questions answered (no code needed).** *Export share targets:* already uses the
  Android system share sheet (`share_plus`), which lists every installed app that can receive the
  file — nothing to add. *Check-for-updates:* intentionally omitted — in-app self-update is an
  F-Droid anti-feature; the store client handles updates and the About dialog shows the version.

**Session-2 refinements (2026-07-08, second pass):**
- Calendar view now uses the same bucketed green→red **severity colours** as the List badge (was a
  saturation ramp); a day with no recorded severity is grey.
- Collapsed Analytics chart cards show a **mini sparkline** of the distribution for visual interest.
- Season & time-of-day **donuts label the slices in-place** (name + count) and drop the legend.
- Moon-phase chart uses **moon-emoji glyphs** on the axis instead of truncated text.
- The delete/undo **snackbar is cleared on tab change** (plus its existing 5 s timeout).
- The **"days since last migraine" card is now a shared widget** (`widgets/days_since_card.dart`),
  also shown on the otherwise-blank idle **Log** screen.
- Streak-card colour valence kept as green (recent) → red (overdue) after discussion; the far-overdue
  tail is the spot to revisit if it feels punishing.
- Added a **Daylight-hours** suspected factor (photoperiod / SAD hypothesis): daylight length is
  computed per day from latitude + date (the app's NOAA `sunTimes`) and bucketed, so it forms an
  analytic baseline like the calendar/moon factors. It is deliberately *distinct from season* —
  spring and autumn share daylight lengths. Surfaces in Top Suspected Factors and gets its own
  descriptive "By daylight hours" chart. Themed fixture `06-daylight-short.json` demonstrates it.

**Session-3: post-`v0.1.0` review backlog closed (2026-07-09).** After the `v0.1.0` release, a
running "would-be-nice" list was tracked in [`docs/BACKLOG.md`](BACKLOG.md); **all eight items are
now done and merged to `main`** (test suite now **70 tests**, `flutter analyze` clean, signed
release APK builds ~67 MB). Summary:
- **Analytics visual refresh (#1–3).** Summary is now a **2×3 grid of stat tiles**; Top Suspected
  Factors render as **horizontal bars** whose length encodes each factor's odds ratio (OR value +
  caveats kept). Every descriptive bar prints its **count** above it, and bars are shaded by a
  **sequential single-hue purple magnitude ramp**. Donuts stay categorical (identity, not
  magnitude). All chart palettes are **theme-aware and dataviz-validated per card surface**.
- **Medications UI (#6)** — a real feature gap: the `meds_taken` schema/vocab/export existed but had
  no entry screen. Event Detail now has a **Medications section** (per-med card with name + optional
  dose/time + a Yes/No/Unknown "helped?" glyph) and an add/edit dialog (name Autocomplete over the
  `medication` vocab, learned from entries). Writes the existing `meds_taken` JSON.
- **Donations (#4)** — chose **Ko-fi** (`https://ko-fi.com/smaegley`), wired into the Settings Donate
  tile and `.github/FUNDING.yml`. Rationale: donors are expected to be app users, and Ko-fi takes a
  one-time tip with no donor account, 0% fee, no in-app payment SDK.
- **Source-code / Donate links (#5)** — found and fixed a **real Android 11+ bug**: `_launch()`
  gated on `canLaunchUrl()`, which returns false for `https` unless the manifest declares a
  `<queries>` browser intent (it only had the Flutter-template `PROCESS_TEXT` query). Both links
  silently no-opped on modern devices. Fixed by adding the `VIEW`/`https` query and hardening
  `_launch()` to call `launchUrl()` directly + surface a "Could not open…" SnackBar on failure.
- **Home-location label refresh (#7)** — the Settings tile kept the old location until you left and
  returned. First fix (a state-held `FutureBuilder`) was wrong: its DB re-read got queued behind the
  slow `reEnrichAll()`. Real fix: display the location from a plain state field set **directly from
  the picked value** (no DB re-read), so it updates instantly.
- **Light/dark theme (#8)** — the app was dark-only. `theme.dart` now builds both themes from the
  purple seed and `app.dart` wires `ThemeMode.system`, so Megrim follows the phone's setting. Chart
  card surfaces are pinned per mode (`#1E1E1E` / `#FCFCFB`); the categorical and sequential-purple
  chart palettes have theme-aware, dataviz-validated variants; hard-coded accents moved to
  `colorScheme` roles (destructive → `error`, etc.).

**F-Droid submission prepared (2026-07-09).** A draft `fdroiddata` recipe + submission playbook live
in [`fdroid/`](../fdroid/) (recipe validated with `fdroid lint`); **seven phone screenshots** were
added to `fastlane/metadata/android/en-US/images/phoneScreenshots/`; the README gained an
**Installing** section (direct APK · Obtainium auto-updates · F-Droid planned). Decision: **debut on
F-Droid at `v1.0.0`** — the recipe is pinned to `v0.1.0` as a working placeholder and its version
fields get bumped when `v1.0.0` is tagged, at which point the GitLab MR to `fdroiddata` is opened.
**Google Play was evaluated and declined** for now — the ~20-tester/14-day closed-test gate for new
personal developer accounts isn't worth it for a solo FOSS app; F-Droid + GitHub-Releases-via-
Obtainium already provide install *and* auto-update.

**Deliberate deviations from this spec, and why (each is noted in code too):**

1. **`geolocator` dropped → GPS auto-capture deferred.** The `geolocator` Android implementation
   links `com.google.android.gms:play-services-location`, which violates the day-one F-Droid
   constraint in §2.1 ("CI should fail if `com.google.android.gms` appears"). Since GPS is
   explicitly optional and the app must work without it, v1 uses the onboarding home location for
   all enrichment. `lib/services/` keeps a seam for a future GMS-free `LocationManager` provider.
   The manifest still declares the (optional) location permissions for later use.
2. **`flutter_plugin_android_lifecycle` pinned to 2.0.24** via `dependency_overrides`. The current
   release (2.0.35) sets an AAR `minCompileSdk` of 36 that breaks the build under Flutter 3.44.1
   (file_picker's metadata check fails). Revisit when Flutter's default compileSdk reaches 36.
3. **`compileSdk = 36`** pinned in `app/android/app/build.gradle.kts` (some transitive plugins
   require it); `minSdk 26`, `targetSdk` from Flutter, per §8.
4. **Correlations match the reference Python, not the §6.2 prose**, in two places (documented in
   `lib/analytics/correlations.dart`): the study window ends at the **last event** (prose says
   "today"), and the Top-Factors filter is **OR > 1.0** (prose says "≥ 1.5"). Chosen so the golden
   tests validate against the actual `correlations.py`. Reconcile deliberately if the prose is the
   intended behaviour.
5. **Application id finalized as `org.maegley.megrim`** (was a placeholder; see §1.2). Shipped in
   `v0.1.0`; immutable from here.
6. **Golden fixtures hand-computed.** The spec calls for generating fixtures from the private
   app's Python (`astral`/`ephem`); that stack isn't runnable in this environment, so astro and
   correlations goldens assert against independently hand-computed values and physical invariants
   instead. Regenerating from Python remains a good future cross-check.

### Barometric pressure in the correlations — DONE

Dropped after the first review, then **reinstated 2026-07-08** at the user's request (his imported
migraine-tracker data showed a pressure signal). `AnalyticsScreen` now passes a
`PressureBaselineService` into `repo.correlations()`; a fast local connectivity check gates the
one-time Open-Meteo baseline fetch (`allowFetch`) so the tab never blocks offline (it uses the
cached baseline or omits the factor). The baseline is cached in `app_settings.pressure_baseline`
keyed by window+location. So "Pressure Δ 24h" now appears in Top Suspected Factors alongside the
descriptive pressure bar chart.

**Suspected-factor set (current):** Day of week · Season · Month · Moon phase · **Daylight hours**
(photoperiod / SAD, added at the user's request) · **Pressure Δ 24h**. Self-reported triggers are
deliberately not correlated (no non-migraine baseline) — shown descriptively as "Most-tagged".

**Remaining follow-ups (all post-`v0.1.0`, gated on cutting `v1.0.0`):** bump the drafted F-Droid
recipe's version fields to the `v1.0.0` tag and open the `fdroiddata` MR (recipe + playbook already
in [`fdroid/`](../fdroid/)); add a `fastlane/.../changelogs/2.txt` for the new versionCode.
*(Done since first pass: generated licenses page; connectivity-triggered enrichment retry;
barometric-pressure factor; daylight factor; the full Session-3 review backlog above; F-Droid recipe
drafted + store screenshots.)*

**Known-bug fixes worth noting:** a DST day-stepping bug in `computeCorrelations` dropped migraine
days after a spring-forward in DST timezones (fixed 2026-07-08; CI now also runs under
`TZ=America/Denver`). The `migraine-tracker` exporter corrects timestamps that its own importer had
stored as local-clock-mislabeled-as-UTC (6–7h early).
