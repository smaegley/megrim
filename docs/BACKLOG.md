# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

## Bugs

### 7. Home-location label doesn't refresh after changing it *(fix next update)*
**Symptom:** In Settings, after changing the Home location, the on-screen value (the `Home location`
tile subtitle) keeps showing the old location. It only updates after navigating away and back to
Settings. Found by Steve 2026-07-09.
**Likely cause:** the Settings screen reads `repo.homeLocation` once (e.g. a `FutureBuilder` built at
screen creation) and isn't re-run when the change dialog returns. Needs a `setState`/refresh after the
home-location picker completes so the tile rebuilds against the new value (same pattern as the vocab
"Manage" tiles, which re-`_load()` on return).
**Where:** `app/lib/screens/settings_screen.dart` — the Home location `ListTile` + `_changeHome()`.

## UI / UX

### 8. Support light theme + follow the system setting *(open)*
**Now:** the app is **dark-only** — `app/lib/theme.dart` defines only `megrimDarkTheme()`, and the app
forces dark (no light theme, no `ThemeMode.system`). It ignores the phone's light/dark preference.
**Want:** a proper light theme and `themeMode: ThemeMode.system` so Megrim follows the OS setting
(with an optional in-app Light/Dark/System override in Settings later).
**Scope / gotchas:**
- Add a light `ColorScheme.fromSeed(seedColor: purple, brightness: light)` theme; wire `theme:` +
  `darkTheme:` + `themeMode: ThemeMode.system` in the root `MaterialApp`.
- **Audit hard-coded colors** — there are several `Colors.redAccent/orangeAccent/white70`, chart label
  colors, etc. that assume a dark surface; move them to `Theme.of(context).colorScheme` roles.
- **Re-validate the chart palettes for a light surface.** The categorical `_seriesColors`, the
  sequential `_seqPurple` magnitude ramp, and `onStatusColor` were validated for the **`#1E1E1E` dark
  card** only. Light mode needs its own validated steps (run the `dataviz` validator with
  `--mode light` against the light card surface) — not an automatic flip.
- Check the donut in-slice label contrast and the severity-badge colors in light mode.
Requested by Steve 2026-07-09.

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
