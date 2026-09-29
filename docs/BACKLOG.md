
# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

> **Status (2026-09-22):** #1–11 are **DONE** and merged to `main` (see [`SPEC.md` §12](SPEC.md)),
> kept here as a record. **#12 is OPEN**; #13 shipped in `v1.0.5`. Add new items as they come up.

## UI / UX

### 9. History Calendar: tap a date to edit or start a past entry — **DONE**

**Was:** the Calendar view's day cells (`_dayCell` in `history_screen.dart`) were static — tapping
did nothing. Reaching an entry meant switching to the List view; adding a past entry meant the
FAB, which starts "now" and requires manually re-setting the date in Event Detail afterward.
**Done:** day cells are now wrapped in an `InkWell` calling `_onCalendarDayTap(date, dayEvents)`:
zero entries that day starts a new past entry pre-dated to noon on the tapped day (via a new
`_addManualForDate`, reusing `_addManual`'s create-then-edit pattern) and opens it in Event Detail;
exactly one entry opens it directly; **multiple** entries show a bottom-sheet picker (severity
badge + time per row, tap one to open it — decided 2026-07-10). A new `eventsByLocalDay` helper
(alongside the existing `severityByLocalDay`) groups the actual event objects per local day, not
just counts. Covered by `app/test/history_calendar_tap_test.dart` (all three tap outcomes) and unit
tests for `eventsByLocalDay` in `history_calendar_severity_test.dart`.

## Bugs

### 7. Home-location label doesn't refresh after changing it — **DONE**

**Was:** In Settings, after changing the Home location, the tile subtitle kept showing the old
location until you left and reopened the screen. Found by Steve 2026-07-09. Cause: `SettingsScreen`
was a `StatelessWidget` whose home-location `FutureBuilder` never re-ran after `_changeHome`.
**Done:** converted `SettingsScreen` to a `StatefulWidget` holding the home-location `Future` in
state; after `setHomeLocation` succeeds, `_changeHome` calls `setState` to re-fetch it so the tile
updates immediately. Smoke test in `app/test/settings_home_location_test.dart`.

## UI / UX

### 8. Support light theme + follow the system setting — **DONE**

**Was:** the app was **dark-only** — `theme.dart` defined only `megrimDarkTheme()` and the app forced
dark, ignoring the phone's light/dark preference.
**Done:**

- `theme.dart` now builds both `megrimLightTheme()` and `megrimDarkTheme()` from the same purple seed;
  `app.dart` wires `theme:` + `darkTheme:` + `themeMode: ThemeMode.system`, so Megrim follows the OS
  setting. (An in-app Light/Dark/System override in Settings is still a possible future add.)
- The chart card surface is pinned per mode (`kDarkCardSurface` `#1E1E1E`, `kLightCardSurface`
  `#FCFCFB`) so the chart palettes have a known background.
- **Chart palettes are theme-aware and each dataviz-validated for its surface:** categorical
  `_seriesColorsDark/Light` and the sequential purple magnitude ramp `_seqPurpleDark/Light` (light
  runs pale→deep, low→high; ordinal checks pass, surface-adjacent end clears 2:1). `onStatusColor`
  already picks its own contrast, so donut labels adapt automatically.
- **Hard-coded accent colors moved to theme roles:** destructive text/buttons → `colorScheme.error`
  /`onError` (Delete, Discard, Replace, swipe-delete, MIGRAINE ENDED); the meds "helped" glyph →
  fixed `StatusColors` + `onSurfaceVariant`; the enrichment-error text → `colorScheme.error`; the
  trigger-frequency bar → `colorScheme.tertiary`; the Log app-bar subtitle → `onSurface`@70%.
- Severity badges + the days-since card already used the fixed `StatusColors` + adaptive
  `onStatusColor`, so they work in both modes unchanged.
  Requested by Steve 2026-07-09. `flutter analyze` clean, theme wiring test added. Visual pass in both
  modes is Steve's on-device check (can't render light mode on the build VM).

### 1. Make the Analytics summary + suspected factors more visual — **DONE**

**Was:** Summary was a plain key/value list; Top Suspected Factors a text list of `factor: condition — OR n`.
**Done:**

- Summary is now a **2×3 grid of stat tiles** (big figure over a muted label, tabular figures): Events, Years tracked, Avg severity, Avg duration, Avg interval, Per year. Null stats show an em dash so the grid stays fixed.
- Suspected factors render as **horizontal bars** (one per factor) whose length encodes the odds ratio relative to the strongest shown factor, shaded by the same magnitude. The OR value + caveats are kept — the bar is an addition, not a replacement.

### 2. Show counts on the bar charts — **DONE**

**Was:** `by day / season / time-of-day / pressure / moon / daylight` bars showed no value.
**Done:** each bar now prints its **count directly above it** (always-on, chrome-less fl_chart tooltips; touch stays enabled). `maxY` gains 25% headroom so labels don't clip; zero-count bars omit the label to avoid a "0" on the baseline. Donuts already show in-slice counts.

### 3. Color-code bars by significance — **DONE**

**Was:** all bars a single blue.
**Done:** bars are shaded by a **sequential single-hue purple ramp** (`_seqPurple`, dim→bright = low→high magnitude), keyed to relative count on the descriptive charts and to odds ratio on the suspected-factor bars. Donuts stay **categorical** (they encode identity, not magnitude). The ramp is validated for the `#1E1E1E` dark card surface with the dataviz validator (ordinal: monotone lightness, single hue, dim end clears the 2:1 floor at 2.20:1). The collapsed-card mini sparkline was retinted to the same family.

### 6. Add a medications UI to Event Detail *(real gap, not a bug)* — **DONE**

**Was:** the schema (`meds_taken` = `[{name, dose, time, helped}]`), the `medication` vocab (managed in Settings), and export/import **all supported meds — but there was no screen to add them to an event.** Event Detail only had Head-location and Suspected-trigger chip sections.
**Done:** Event Detail now has a Medications section (below Suspected triggers). Each entry is a card showing name + optional dose/time and a thumb-up/down/? "helped" glyph, with tap-to-edit and a remove button. "Add medication" opens a sub-form dialog: name (Autocomplete over the `medication` vocab, or free text — new names are learned into the vocab), optional dose, optional time (time picker anchored to the event's date, stored ISO-8601 UTC), and a Yes/No/Unknown "helped?" tri-state. Writes the `meds_taken` JSON that export/CSV already emit. Quick Log reaches this via its existing "Add more details" → Event Detail link. Covered by `app/test/event_detail_meds_test.dart` (add/learn, remove, encode round-trip).

### 10. History: weekday-aligned calendar grid + multi-day migraines — **DONE** *(Steve 2026-09-03)*

**Was:** month grids were a plain `Wrap` of day dots with no weekday alignment; a multi-day
migraine only marked its start day; only months containing events rendered, which compressed the
gaps between migraines.
**Done** (merged 2026-09-03, tested by Steve on the iOS simulator):

* Each month renders as a real day-of-week grid (weekday header row, leading/trailing blanks).
  First day of week derives from the device locale via `MaterialLocalizations.firstDayOfWeekIndex`
  — no in-app setting; English-only today resolves Sunday-first.
* A multi-day migraine colors every day it spans (`localDaysSpanned`, DST-safe constructor-
  normalised day stepping); tapping any covered day resolves to it; severity-colored **connector
  bars** tie the run together, meeting at cell edges and linking across row wraps and month
  boundaries (`spanLinkKeys`).
* **Every month back to the first entry renders**, migraine-free ones included, so gaps read at
  true length; built lazily (`ListView.builder`, ~190 cards for 15 years). List rows label
  multi-day entries with their day count. `HistoryScreen.todayOverride` test seam pins the clock
  in widget tests. Covered in `history_multiday_grid_test.dart` + expanded unit tests.

### 11. Analytics: donut chart colors — **DONE** *(Steve 2026-09-03)*

**Was:** donuts used the 8-hue rainbow categorical palette — felt off-theme.
**Done** (merged 2026-09-03, tested by Steve in both themes): purple-led 4-slot palette — violet +
magenta lead, deep teal + amber keep slices apart. Purple-only and purple+grey sets were tried
first and **fail the dataviz distinguishability floors** (violet↔blue collapses under protanopia,
magenta↔green under deuteranopia, true grey fails the chroma floor), so this is the closest
theme fit that stays readable. Both modes validated all-pairs against their card surfaces
(donuts wrap, so every slice pair is adjacent).

### 12. In-app "Export report (PDF)" — **OPEN** *(raised by Steve 2026-09-22)*

**Want:** a printable, clinician-ready report generated **on the phone**, offered next to
Export (JSON) and Export (CSV) in Settings.

**Why:** `tools/report.html` (PR #11, shipped in `v1.0.4`) renders exactly this, but only on a
computer — the user must export JSON, move the file to a desktop, and open the page in a browser.
Steve hit the friction himself while trying to check the report from the iOS TestFlight build: the
only route was AirDrop to the Mac. Every ordinary user's workflow is phone-only, so today there is
no way to hand a doctor a PDF from the app.

**Shape:**

- A third action in the Settings export group, reusing the **Share vs Save-to-device** choice the
  other two already have (SPEC §7.1; `_exportContent`/`_saveToFile` in `settings_screen.dart`).
  Nothing leaves the device except by the user's own share action. The iPadOS share-sheet anchor
  is already handled there — it is the app's one piece of iOS-specific code.
- Build the document from `DashboardResult` + `CorrelationResult` **directly** — the same objects
  that feed the Analytics tab and the `analytics` export block (#16). No re-derivation, so the
  PDF, the tab, and the block can never disagree. A `ReportModel` (pure, testable) between the
  analytics results and the layout keeps the page code dumb.
- Content: take the layout decisions already reviewed in `tools/report.html` rather than
  re-litigating them — summary cards, the descriptive charts as plain drawn bars (rectangles;
  no dependency on the on-screen chart widgets), the medication table with helped/didn't/unknown,
  the suspected-factor tables **with the caveat block**, the full event log, and the medical
  disclaimer.

**Costs / gotchas:**

- **New dependency:** the `pdf` package — pure Dart, BSD-licensed, no native code and no Google
  libraries, so F-Droid and the CI `dependency-ban` job are unaffected. Confirm both before
  committing to it.
- **A bundled font is required.** The built-in PDF base-14 fonts have no glyphs for characters the
  app's own labels use — `≥` in the daylight buckets (`≥ 14 h`), `Δ` in `Pressure Δ 24h (hPa)`,
  the `·` separators. Bundle a Noto/Roboto TTF (a few hundred KB) and **add its license to the
  generated licenses page**.
- **Pressure factor may be absent.** It only exists when a pressure baseline is cached (built the
  first time Analytics runs online with weather enrichment on). A report generated on a phone that
  has never built one should say so in a footnote rather than silently omit the row — the same
  honesty rule `docs/IMPORT.md` states for the export block.
- Page-break behaviour is the fiddly part: tables must repeat their headers, and the factor and
  event-log sections should start on fresh pages (what the HTML page's print stylesheet does).

**Verification:** unit tests on `ReportModel` (it is pure); for the document itself, assert page
count and extracted text rather than golden bytes; then a real check on both platforms — Android
share + Save-to-device, iOS share sheet — since this is the first binary the app hands out.

**Does not replace `tools/report.html`.** That stays the desktop path for anyone holding an export
without the phone, and it keeps reading the #16 block, so the two agree by construction.

**Estimate:** ~2–3 days. A feature, not a fix — ship as **v1.1**, not a patch.

### 13. Make travel visible: an away-from-home share + a default "Travel" trigger — **DONE** *(shipped in `v1.0.5`)*

**Want:** two small, honest additions that let a traveller see travel in their own data.

1. A descriptive **"Away from home"** card on Analytics: how many entries were logged more than
   ~100 km from the home location, as a count and a share, with the away places listed.
2. **"Travel"** added to the default trigger vocabulary, so it can be self-reported like any
   other trigger.

**Why:** `@nfd9001` raised it while reviewing PR #11 — travel plausibly associates with several
real triggers at once (sleep change, pressure change, dehydration, skipped meals) and it is
exactly the situation #17's per-event time zones now record properly. The data is already in the
events (`geo_lat`/`geo_lon` + `settings.home_location`); nothing new is collected.

**Explicitly NOT an odds ratio.** A suspected-factor row needs to know where the user was on
**non-migraine** days too, and the app deliberately never collects location in the background.
So this belongs with `triggerFrequency` as descriptive-only — same rule, same caveat wording:
a tall bar means "more migraines were logged there", nothing more. Do not put it in the
`Suspected factors` card.

**Depends on / pairs with #15 (PR #18).** Every entry defaults to the home location, so today the
away count is 0 for almost everyone. The recent-locations picker is what makes recording a
different location practical, which is what gives this card anything to show. Ship them together.

**Shape:**

- `distanceKm()` (haversine, pure) — no such helper exists yet; `astro.dart` has `_deg2rad` to
  match style against. Coordinates are stored rounded to 2 decimals (~1 km), which is far below a
  100 km threshold, so rounding is a non-issue.
- `EventStat` gains `geoLat`/`geoLon`; `computeDashboard` gains `homeLat`/`homeLon` (optional,
  same as `computeCorrelations` already takes) and returns an `AwayFromHome?` — null when there is
  no home location or no located events, so the card simply doesn't render.
- Report **located** entries as the denominator, not all entries, and say so: entries with no
  coordinates are in neither the numerator nor the denominator. Showing `0 of N` is a fine,
  informative answer — don't hide the card just because the user doesn't travel.
- The `analytics` export block (#16) must carry it too, or the block stops being "what the tab
  computes"; document it in `docs/IMPORT.md`. Additive, so `tools/report.html` ignores it until
  someone chooses to render it.
- The **"Travel" trigger needs a schema bump (v3)** to reach existing users: `_seedVocabularies`
  only runs on `wasCreated`. A one-time `onUpgrade` insert with `InsertMode.insertOrIgnore` is
  right — it can't duplicate a "Travel" the user already made, and it can't resurrect a deleted
  one later (which seeding on every open would).

**Verification:** unit tests for `distanceKm` against known city pairs and the antimeridian; the
`AwayFromHome` computation including the null cases; the v2→v3 migration adding "Travel" exactly
once and leaving a user-renamed vocabulary alone.

**Done** (2026-09-29): built as planned — `analytics/geo_distance.dart`, `AwayFromHome` on
`DashboardResult`, the Analytics card, `away_from_home` in the export block, and schema v3 for the
"Travel" trigger. Shipped alongside PR #18, which is what gives the card anything to show. Two
things learned while building it, worth remembering: a guessed haversine reference distance in a
test was wrong (Boulder→Paris is 7854 km, not 7737 — verify reference values against an independent
implementation), and asserting an *exact* distance threshold is unstable in floating point
(100 km expressed in degrees comes back as 100.00000000000038), so the test asserts either side of
it instead.

## Release / infra

### 4. Donations — decide and wire up — **DONE**

**Was:** the in-app Donate tile linked to a placeholder `https://liberapay.com/megrim`; `.github/FUNDING.yml` was fully commented out.
**Done:** picked **Ko-fi** (chosen because donations are expected from app users — migraine sufferers — not the FOSS/dev community; Ko-fi takes one-time tips with **no donor account**, 0% platform fee, and needs no in-app payment SDK). Real page: `https://ko-fi.com/smaegley`. Wired in both places — the Settings › Donate tile (`_launch('https://ko-fi.com/smaegley')`, opens in the browser, F-Droid-clean) and `.github/FUNDING.yml` (`ko_fi: smaegley`, which also renders GitHub's Sponsor button). Liberapay/GitHub Sponsors left commented for a future revisit.

### 5. "Source code" link must open the repo — **DONE (bug found + fixed)**

**Was:** Settings › Source code (and the newly-wired Donate tile) launched via a `_launch()` helper that gated on `canLaunchUrl()`. On **Android 11+ (API 30+)** `canLaunchUrl("https://…")` returns **false** unless the app declares a `<queries>` browser intent — and the manifest only had the Flutter-template `PROCESS_TEXT` query. So `canLaunchUrl` was false → the `if` never fired → **both tiles silently no-opped on essentially every modern device.** (Not just cosmetic — the link genuinely didn't work.)
**Done:**

- Added the browser query to `AndroidManifest.xml`: `<intent><action VIEW/><data scheme="https"/></intent>` inside `<queries>` — so `canLaunchUrl`/package-visibility resolves a browser.
- Hardened `_launch()` to call `launchUrl()` directly (a web `ACTION_VIEW` is exempt from package-visibility) and to show a "Could not open …" SnackBar on failure, so it can **never fail silently again**.
- Verified the merged manifest in the built release APK contains the `VIEW`/`https` query. Definitive on-device tap remains a quick manual check, but the root cause is fixed in code.

**Not done (deferred):** surfacing the Source-code link more prominently than Settings + About — left as a minor future polish.
