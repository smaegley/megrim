# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

> **Status (2026-07-10):** #1–9 are **DONE** and merged to `main` (see [`SPEC.md` §12](SPEC.md)
> "Session-3"/"Session-4"), kept here as a record. Add new items as they come up.

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
