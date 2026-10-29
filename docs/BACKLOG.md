
# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

> **Status (2026-10-07):** #1–14 are **DONE** (see [`SPEC.md` §12](SPEC.md)), kept here as a
> record. #13 shipped in `v1.0.5`; #12 and #14 shipped in `v1.0.6`. **#15 is DEFERRED.**
> **#16 and #18–#22 are PROPOSED** (2026-10-06, from a competitor feature review — see *Features*
> below); **#17 (monthly migraine days), #23 step (1) (app-icon shortcut) and #24 (app lock) are
> DONE**, shipped in `v1.0.7` (2026-10-08); #23 steps (2)–(3) remain proposed.
> **#25 (move UI text into a message file, prep for translations) is PROPOSED** (2026-10-27, from
> issue #19). **#20 (symptoms), #22(a) (impact) and #26 (attacks without headache) are BUILT**
> together on `feat/attack-details` (schema v4, 2026-10-27); Steve's test passed 2026-10-28, merged 2026-10-29
> (one wording fix, the Impact hint). They ship in **1.0.8**.
> Add new items as they come up.

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

### 12. In-app "Export report (PDF)" — **DONE** *(built 2026-10-05, shipped in `v1.0.6`)*

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

**Done** (2026-10-05). Built as planned: `report_content.dart` is pure and decides every string,
`report_pdf.dart` only draws. Notes from doing it, worth keeping:

- **The `pdf` package is Apache-2.0 and pure Dart** — no plugin section, so no native code, no
  Gradle change, no new permissions, and the CI dependency-ban job is unaffected.
- **The bundled font does not cover `≥`.** Noto Sans (Latin/Greek/Cyrillic) has `Δ`, `·`, `–` and
  every European accent, but not U+2265, which the app's own "≥ 14 h" daylight bucket uses. So
  `kFontTransliterations` maps a few symbols to readable stand-ins (`>=`, `<=`) *before* the "?"
  fallback, and only the fallback counts as a lost character. A test pins this.
- **Unsupported runes render as nothing, silently** — the library maps them to glyph 0 with zero
  width, so a Japanese note would simply vanish. Hence the substitution plus a footnote saying it
  happened, rather than a quietly incomplete report.
- **Size:** the arm64 release APK goes from ~22 MB to 23.5 MB, of which 1.2 MB is the two fonts.
  (The universal APK's larger jump is three ABIs' worth of the same code.)
- **Column widths were tuned against the rendered output**, not guessed: at 8pt the `Duration` and
  `Aura` headers wrap if their columns are any narrower. Verified by extracting a generated
  report's text with `pypdf`; a Dart test can't catch that, so the layout comment says so.
- **It is not a backup.** A PDF cannot be imported back, so it does not touch the #14 reminder —
  the same rule as CSV.

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

### 14. Backup reminder — **DONE** *(merged 2026-10-05, shipped in `v1.0.6`)*

**Want:** tell the user how long it has been since their last backup, and let them opt in to being
warned when it has been too long.

**Why:** nothing in the app has ever said "you have never exported". Steve asked for scheduled
automatic backups (2026-09-30); this is the deliberately cheap half of that — see #15 for what was
deferred and why.

**Decisions taken (Steve, 2026-09-30):**

- **Opt-in, and the opt-in *is* the interval.** One Settings row cycling Off / 7 / 14 / 30 / 90
  days, defaulting to **Off**, so an upgrade changes nothing for anyone. The last-backup *date*
  shows regardless — stating a fact is not nagging; only the warning state and the Log-screen line
  are gated on opting in.
- **A quiet line at the bottom of Quick Log**, only when opted in: a small filled dot, green inside
  the interval and orange past it, with "Last backup: 12 days ago" beside it. Tapping switches to
  the Settings tab. Deliberately a dot rather than the `DaysSinceCard` ring — this is the least
  important thing on that screen.
- **JSON only.** A CSV export cannot be imported back, so it is not a backup.
- **Any completed JSON export counts** — saved to a file, or shared where the sheet reports
  success. A dismissed share does not.
- **No history is invented.** Anyone who exported before this shipped reads "Never" until their
  next one, which is true, rather than being seeded with a made-up date.

**Shape:** `models/backup_status.dart` is pure (no clock, no I/O) and holds all the logic; two
settings keys (`last_backup_at`, `backup_reminder_days`); the Settings row and picker; the Quick
Log line. `HomeShell` bumps a `refreshToken` when the Log tab is opened, because `IndexedStack`
never disposes that page and it would otherwise keep the date it first read.

**No new dependencies and no new permissions** — that was the point of choosing this over #15;
the release APK's permission list is unchanged.

**Done** (2026-10-05): built as described and verified on the emulator — the opt-in, the orange/green
dot, the Settings row, and that CSV and a dismissed share correctly record nothing. 222 tests.

### 15. Remember the export / import location, and back up automatically — **DEFERRED** *(not a small job; see below)*

**Want:** the export and import pickers should reopen where the user last chose, and ideally the
app should write a backup there on a schedule without being asked.

**Why deferred (investigated 2026-09-30):** both need the same thing — *persistent* access to a
user-chosen folder — and `file_picker` does not provide it.

- **The save location cannot even be captured today.** `file_picker`'s Android `saveFile()` runs
  `ACTION_CREATE_DOCUMENT` and then **throws the real destination away**: it returns a fabricated
  `Environment.DIRECTORY_DOWNLOADS + "/" + filename` string regardless of where the user actually
  saved (`FilePickerDelegate.onActivityResult`, `SAVE_FILE_CODE`). Import is no better — it
  returns the path of a private cached *copy*. So there is no valid value to feed back as
  `initialDirectory` next time, even though the plugin does accept one and maps it to
  `DocumentsContract.EXTRA_INITIAL_URI` correctly.
- **Folder access is never persisted.** `getDirectoryPath()` uses `ACTION_OPEN_DOCUMENT_TREE` but
  never calls `takePersistableUriPermission`, so the grant dies with the process — fine for a
  one-shot picker, useless for writing later.

**What it would take:** a fork/PR to `file_picker` to return the real URI, a different plugin, or
our own small platform channel taking a persistable tree permission (plus a security-scoped
bookmark on iOS).

**And the automatic half costs more than that.** A true background schedule means WorkManager on
Android, which merges in manifest permissions beyond `INTERNET` — a guarantee the README, PRIVACY
and the F-Droid listing all make — and iOS cannot do reliable background file writes at all, so it
would be a different feature per platform. A middle option exists: write the backup **on app open
when one is due**, which needs the persistent folder access but no scheduler and no new
permissions. **Steve chose the reminder (#14) for now**; revisit this if reminding proves not to
be enough.

## Features — from the 2026-10 competitor review

Captured 2026-10-06 from a feature comparison against Migraine Buddy, N1-Headache, Migraine
Monitor, Canadian Migraine Tracker, Migraine Attack Diary, Migraine Log (F-Droid) and Bearable.
Megrim's enrichment and correlation analytics are already ahead of most of these; the gaps are
**clinical tracking** and **capture speed**. Everything below fits the locked decisions (no
server, no accounts, no telemetry, on-device only). Items that would break a non-goal are listed
at the end under *Reviewed, not planned* so the reasoning isn't lost.

**Numbering:** these backlog numbers overlap GitHub issue numbers that the docs already cite
(issue #16 = the export `analytics` block, issue #17 = event time zones, issue #18 = the
recent-locations picker). In this section a bare number never appears: it is always
**backlog #N** or **issue #N**.

**Rough priority (revised 2026-10-07):**

1. Backlog #17 — needs **no schema change** (a pure function over existing data), and it's the
   number clinicians ask for first. Can ship alone.
2. Backlog #23 step (1), the app-icon shortcut — small, no schema, no new permission.
3. Backlog #16 and #18 — make the existing analytics more correct and add the medication-overuse
   numbers.
4. Backlog #19–#21 — data-model additions; batch into one v4 bump. *(As it turned out, #20/#22a/#26
   took v4 and #18/#19 took v5.)*
5. Backlog #22, #24, and #23 steps (2)–(3).

**Common to every item that adds data:** a schema bump with an additive, nullable `onUpgrade`
step (same pattern as v2/v3), the field carried in JSON + CSV export and import, documented in
`docs/IMPORT.md` and `docs/megrim-export.schema.json`, and — where Analytics computes something
new — carried in the `analytics` export block so it stays "what the tab computes". Items that
ship in the same release share one bump.

**Permissions:** the Android manifest declares only `INTERNET`. PRIVACY also mentions the
network-state check that ships in the APK. Below, "no new permission" means nothing beyond that
current set. Anything that adds one must update README, PRIVACY and the F-Droid listing in the
same change, verified by inspecting the merged manifest of a release build (as was done for
backlog #5).

### 16. Headache-free days: a one-tap "No migraine today" check-in — **PROPOSED** *(2026-10-06)*

**Want:** a way to record that a day was migraine-free — a one-tap button on Quick Log, plus a
long-press / tap on a past History Calendar day to mark it clear — optionally carrying the same
self-reported fields an event has (sleep, stress, triggers/exposures, notable foods).

**Why:** this is the single biggest analytic improvement available. Today the app assumes every
day without an entry was migraine-free, and it can't tell that apart from a day the user simply
didn't open the app. Worse, self-reported factors exist only on migraine days, which is why
`triggerFrequency` is descriptive-only and the Analytics/report copy has to caveat that "triggers
are only recorded on migraine days". With clear days that carry the same fields, self-reported
triggers, sleep and stress get a real non-migraine baseline and can enter the 2×2 odds-ratio
engine. N1-Headache's whole method is built on daily tracking; Migraine Attack Diary has a
one-tap "No Headache Today".

**Shape:**

- New table `day_checkins` (v4): `local_date` (PK, the wall-clock date in the zone it was logged)
  plus `offset_min` (as issue #17 does for events). A row's presence means "clear". It also
  carries the same nullable self-report fields as `migraine_events` (`triggers_suspected`,
  `sleep_hours_prior`, `stress_level`, `foods_notable`), and `created_at` / `updated_at`. No
  location, no per-row enrichment: calendar and astro factors are computed for every day already,
  and the only weather baseline is the cached home-location pressure histogram
  (`pressure_baseline.dart`), which doesn't need per-day rows.
- A day with an event wins over a check-in for the same date; logging an event on a clear day
  should offer to remove the check-in.
- **Tracked vs untracked days.** Add a "days tracked" figure (event days + check-in days) to the
  summary and the PDF report — clinicians and N1 both show it, and it tells the user how much to
  trust the numbers.
- **Correlations — existing factors:** keep the calendar/astro/pressure factors on the current
  all-days baseline (they don't need check-ins).
- **Correlations — new self-reported set:** a *separate* odds-ratio set computed **only over
  tracked days**, with these rules:
  - **Its own window.** The existing engine's study window runs from the first event to the
    **last event** (`correlations.dart`, kept to match the reference Python), so check-ins after
    the most recent migraine would be dropped. The tracked-days set uses first tracked day →
    last tracked day.
  - **Its own gate.** `kMinEventsForCorrelations` (5) is far too low for a clear-day baseline.
    Start at **≥ 30 tracked days, with ≥ 5 migraine days and ≥ 5 clear days**, and hide the set
    until then.
  - **Bucket the numeric fields.** Sleep hours and stress level need fixed buckets before they
    fit a 2×2 table (e.g. sleep `< 6 h` / `6–8 h` / `> 8 h`; stress `1–2` / `3` / `4–5`). Pin
    them in `docs/METHODS.md`.
  - **State the bias.** Recall bias is the known weakness of this design: people search harder
    for causes after a migraine than on a good day, so triggers can be over-recorded on migraine
    days. Say so in METHODS and in the card's caveat.
- `triggerFrequency` stays as-is for users who never check in.

**Verification:** migration test (v3→v4, existing data untouched); unit tests for the tracked-day
odds ratios against a hand-built 2×2; a test that a check-in after the last event is inside the
tracked window; a fixture dataset in `test/fixtures/datasets/` where a trigger is planted on
migraine days and absent on clear days, asserting it surfaces, plus one where it's equally common
on both and must not.

### 17. Monthly migraine days and their trend — **DONE** *(shipped in `v1.0.7`)*

**Want:** a "migraine days per month" bar chart on Analytics (last 12 months, scrollable back to
the first entry), a "last 30 days" stat tile, and the same chart in the PDF report (backlog #12).

**Why:** monthly migraine/headache days is the outcome measure neurologists use — it's how
preventive treatment is judged, and the first thing asked at an appointment. Megrim currently
breaks the data down by year and by factor, but never by month.

**Shape:**

- **No schema change** — a pure function over existing data, so this can ship on its own.
- Count **distinct local days** with a migraine, not events: a multi-day migraine counts every day
  it spans (reuse `localDaysSpanned` / `eventsByLocalDay` from backlog #10), and two migraines on
  one day count once. Show event count alongside if useful, but days is the headline.
- **Ongoing migraines — decide:** `localDaysSpanned` gives an ongoing event (no end yet) its start
  day only. Either reuse that rule (consistent with History, and safe for entries the user forgot
  to end) or count through today. Recommendation: reuse the History rule, so both screens agree.
- Use each event's own offset (issue #17, `started_at_offset_min`) for the day bucket, like
  everything else.
- When backlog #19 lands, overlay preventive start/stop markers on this chart — that's the "did
  it work?" view.
- Pure function on `DashboardResult` (`byMonth: List<MonthCount>`), so it's unit-testable and
  goes into the export `analytics` block for free.

**Verification:** unit tests for month bucketing across DST changes, month boundaries, a migraine
spanning a month boundary (counts in both), two events on one day (counts once), and an ongoing
event (start day only, per the rule above).

**As built (Steve's choices, 2026-10-08):** the card sits right after Summary; it shows every month
since the first entry, scrolling sideways and opening on the latest 12; it carries both "last 30
days" and "avg/month, last 3 complete months" (blank until 3 complete months exist); days only,
no event count. The current month is drawn lighter and starred. The PDF gets the chart (last 12
months) first under Patterns, plus a "Migraine days, last 30 d" summary tile. The day rule moved
to `daysCovered()` in `event_time.dart`, shared with the History calendar. Export:
`migraine_days_last_30`, `migraine_days_avg_last_3_months`, `migraine_days_by_month`.

### 18. Acute-medication days and a medication-overuse notice — **BUILT** *(2026-10-29, branch `feat/medications` with #19, schema v5; awaiting Steve's test, ships in 1.0.8)*

**Want:** count the days per month on which acute medication was taken, by medication class,
and show a calm, informational notice when the count reaches the levels headache guidelines
associate with medication-overuse headache.

**Why:** medication-overuse headache is common and avoidable, and patients often don't realise
they're near the line. Canadian Migraine Tracker monitors it; N1 summarises medication use by
category. Megrim already records every med per event (`meds_taken`), so the data is there.

**Reference thresholds (ICHD-3, 8.2)** — all require the use to be regular for **more than 3
months**:

| ICHD-3 | class | days/month |
|---|---|---|
| 8.2.1 | ergotamine | ≥ 10 |
| 8.2.2 | triptans | ≥ 10 |
| 8.2.3 | simple analgesics (paracetamol/acetaminophen, NSAIDs, aspirin) | ≥ 15 |
| 8.2.4 | opioids | ≥ 10 |
| 8.2.5 | combination analgesics | ≥ 10 |
| 8.2.6 | **any mix** of the above — **simple analgesics included** — where no single class reaches its own limit | ≥ 10 total |

Gepants and ditans postdate ICHD-3 and are not currently thought to cause medication overuse:
count and show them, but they **never trigger the notice**. Verify all of this against the
current ICHD-3 text before shipping and cite it in `docs/METHODS.md`.

**Shape:**

- Meds need a **class**. Add an optional class to medication vocabulary entries (v4; the
  `vocabularies` table has no attribute column today, so either add a nullable `meta` JSON column
  or a small `medication_classes` table keyed by name). Classes: triptan, gepant, ditan, ergot,
  opioid, combination analgesic, simple analgesic, antiemetic, other. Unclassified, gepant, ditan,
  antiemetic and other meds are counted but never trigger the notice. Ship **no** brand-name drug
  database (keeps the "leaning empty + learn from entries" decision, SPEC open question 4); offer
  the class picker the first time a new med name is entered.
- A med "day" is a distinct local day with at least one dose of that class. Use the med's own
  `time` when present — it's stored as an ISO-8601 **UTC** string (`MedEntry.time`), so convert
  it with the event's `started_at_offset_min` before taking the date — else the event's start day.
- **The notice is based on months, not the last 30 days.** It appears only when the threshold is
  met in **each of the last 3 complete calendar months**, matching the ">3 months" criterion. The
  "last 30 days" figure is shown as a plain count with no notice attached, so one bad month never
  raises it.
- Analytics card: "Acute medication days, last 30 days" with a per-class breakdown and the
  monthly trend (shares backlog #17's month bucketing).
- **Wording matters — not a medical device.** The notice states the count and the reference
  level and suggests discussing it with a clinician; it never says the user *has* medication-
  overuse headache, and never tells them to stop a medication. Have the copy reviewed the same
  way the disclaimer was.
- Include the per-class monthly counts in the PDF report.

**Verification:** unit tests for class-day counting (two doses same day = 1 day; a dose whose UTC
`time` falls on the next local day; mixed classes; unclassified/gepant ignored for the notice);
threshold edge cases at 9/10 and 14/15; the 8.2.6 mixed rule (e.g. 6 triptan + 5 simple-analgesic
days = 11, notice); the 3-month rule (3 qualifying months = notice, 2 then 1 non-qualifying = no
notice); widget test that the notice copy renders and contains no diagnostic phrasing.

**As built (2026-10-29, with #19, schema v5 rather than v4):** classes live in their own
`medication_classes` table keyed by name (not a vocab column), so a rename or delete never loses
the class past entries are counted by. The class picker appears once when a new name is entered
on Event Detail (dismiss or "Not set" to skip); Settings › Medications lists every name with its
class. **ICHD-3 checked 2026-10-29; three corrections to the plan above:** simple analgesics are
ICHD-3's single "non-opioid analgesic" class (paracetamol + ibuprofen days add up); the 8.2.6
total counts **days with any** of the classes, so two classes on one day count once (the 6 + 5 =
11 example holds only on different days), and it needs two or more classes in the month; 8.2.8
("other medication") exists but "other" is deliberately not checked. A dose on a multi-day entry
now records its day (the time picker asks for the day first), since the dialog could only place a
dose on the start day before. The notice copy is a draft for Steve's review. All of this is in
`docs/METHODS.md`.

### 19. Acute vs preventive medications, and non-drug relief — **BUILT** *(2026-10-29, branch `feat/medications` with #18, schema v5; awaiting Steve's test, ships in 1.0.8)*

**Want:** (a) a list of **preventive** medications with start and stop dates (not per-attack),
and (b) a per-event "what else did you try" list for non-drug relief (dark room, sleep,
cold/heat, caffeine, hydration…) with the same helped / didn't / unknown tri-state as meds.

**Why:** preventives are taken daily and judged over months, so logging them per attack is wrong
— they need a regimen record that backlog #17's trend chart can annotate. Non-drug relief is a
standard field in Migraine Buddy and N1 (which splits treatments into acute, preventive and
non-pharmacologic).

**Shape:**

- New table `preventive_regimens` (v4): `id`, `name`, `dose`, `started_on`, `stopped_on`
  (nullable = current), `notes`. Settings › Medications › Preventives, plus the markers on
  backlog #17.
- `migraine_events.relief_tried` (v4): JSON `[{name, helped}]`, new vocab kind `relief` seeded
  with a short default list. Event Detail section mirroring the Medications UI (backlog #6).
- Analytics: a descriptive "what helped" card — per med and per relief method, helped / tried.
  Descriptive only, same caveat style as `triggerFrequency`.

**Verification:** migration test; export/import round-trip of both new structures; unit test for
the helped-rate computation including unknowns.

**As built (2026-10-29):** `preventive_regimens` with `yyyy-MM-dd` dates (no zone), edited in
Settings › Medications; start ▲ / stop ▼ marked above the migraine-days chart and listed under
it. `relief_tried` with 7 seeded relief methods (Dark room, Sleep, Cold pack, Heat, Caffeine,
Hydration, Rest), a "Relief tried" section on Event Detail (not Quick Log). "What helped" covers
medications and relief; the share leaves unknowns out. The PDF gains Acute medication days,
Preventive medications and Relief tried, and its Medications table now comes from the same rows
as the card.

### 20. Symptoms — **BUILT** *(2026-10-27, branch `feat/attack-details`; Steve's test passed 2026-10-28, merged to `main` 2026-10-29, ships in 1.0.8)*

**Want:** a symptom chip set on Event Detail (and optionally on the active Quick Log view):
nausea, vomiting, light sensitivity, sound sensitivity, smell sensitivity, neck pain, dizziness,
fatigue, brain fog — user-editable like triggers.

**Why:** every competitor records symptoms; Megrim has no symptom field at all (only aura). It's
also what a clinician uses to tell migraine from other headache types, so it belongs in the
report.

**Shape:** `migraine_events.symptoms` (v4, JSON array of strings), new vocab kind `symptom`
seeded on create and inserted once on upgrade with `insertOrIgnore` (the backlog #13 "Travel"
pattern). Analytics: descriptive "most common symptoms" frequency card. PDF report: symptom
frequency table.

**Verification:** migration seeds defaults exactly once and leaves user-edited vocab alone;
export/import round-trip; report test asserts the symptom table.

**Note (2026-10-27):** build together with **#26** (attacks without headache) in the same v4
bump. #26 needs vertigo, motion sensitivity and yawning added to the default list above.

**As built (2026-10-27, with #22a and #26):** 12 defaults — Nausea, Vomiting, Light / Sound /
Smell sensitivity, Neck pain / stiffness, Dizziness, Vertigo, Motion sensitivity, Fatigue, Brain
fog, Yawning — seeded on create and once on the v3→v4 upgrade (`insertOrIgnore`, keeps the
user's own). Symptoms chips with Manage on Event Detail (not on Quick Log); a "Most common
symptoms" card built from the shared frequency card (the triggers card's code, generalised); the
PDF gets a symptom chart and a Symptoms column in the entries table. Export: `symptoms` per event,
`vocabularies.symptom`, `symptom_frequency` in the analytics block; CSV column appended.

### 21. Menstrual cycle log (opt-in) — **PROPOSED** *(2026-10-06)*

**Want:** an opt-in setting that adds "Period started" logging (a date, nothing else) and a
perimenstrual factor in the correlations.

**Why:** menstrually related migraine is a major, well-defined subtype, and N1, Migraine Attack
Diary and the Canadian tracker all track cycles. Megrim can do it better than most: because cycle
start dates are known for *every* day, "perimenstrual window" is a proper 2×2 factor — a real
odds ratio, not a descriptive count. And on-device-only matters more here than anywhere: period
data is something many users are especially careful about.

**Shape:**

- Off by default; enabling it adds the logging entry point (History Calendar day action + a
  Settings list). Disabling it hides everything and offers to delete the stored dates.
- New table `cycle_starts` (v4): `local_date` (PK). No flow, symptoms or predictions — keeping it
  minimal is a feature.
- Correlation factor: event day falls in **day −2 to +3** of a cycle start (day 1 = first day of
  bleeding), the ICHD-3 Appendix A1.1 menstrual-migraine window.
- **Only count well-logged cycles.** Gaps in logging would show up as "outside the window" and
  weaken the odds ratio. Include a cycle in the analysis only when the gap to the next logged
  start is plausible (≤ 45 days), and treat days after an over-long gap as untracked for this
  factor. Gate the factor on a minimum number of such cycles (suggest ≥ 3).
- **Every export path is opt-in for cycle data.** JSON/CSV exports end up in cloud drives and
  email, so they omit `cycle_starts` unless the user ticks "Include cycle dates" for that export —
  the same tick box the PDF report gets. Import accepts it when present.

**Verification:** unit tests for the window (cycle start on the 1st, migraine on the previous
month's 30th = day −2, in window); the gap rule (a 70-day gap excludes that cycle); odds ratio on
a planted fixture; export test that cycle dates are absent by default and present when ticked;
disabled-state test that no cycle UI or report section renders.

### 22. Functional impact and an optional disability score — **(a) BUILT** *(2026-10-27, branch `feat/attack-details`; Steve's test passed 2026-10-28, merged to `main` 2026-10-29, ships in 1.0.8)*; (b) **PROPOSED** (licensing first)

**Want:** (a) a per-event "impact" field — *able to function normally / reduced / unable* — and
(b) optionally, a periodic disability questionnaire.

**Why:** impact is what clinicians and insurers ask about ("how many days did you miss?"), and
N1 calculates a monthly MIDAS score. The per-event field alone yields "days with reduced
function / days unable to function" per month, alongside backlog #17.

**Shape:** `migraine_events.impact` (v4, nullable enum). Monthly impact-day counts on Analytics and
in the report.

**Licensing — check before (b):** MIDAS and HIT-6 are copyrighted instruments. HIT-6 requires a
license from its owner; confirm MIDAS's terms for embedding in a GPL app (and whether the
question text can be redistributed) before building it. If neither is clear, ship (a) only — it
needs no license and covers most of the value.

**Verification:** migration + round-trip; monthly impact-day counting reuses backlog #17's day
logic and tests.

**As built (2026-10-27, (a) only, with #20 and #26):** `impact` stores `normal` / `reduced` /
`unable`; Event Detail shows "Impact on the day — How well could you do your usual things?" with
Normal / Reduced / Unable (tap again to clear), and the chosen level's meaning under the buttons
("Unable to function: couldn't do your usual activities"). The first hint, "How much did it stop
you?", made "Unable" read as "unable to stop me" (found in Steve's test, 2026-10-28). Counted in days on the migraine-day rule, each day taking
its worst impact. An Analytics card (unable and reduced days, last 30; 3-month monthly average
once it exists; "impact recorded on N of M migraine days") and the same as one line under the
PDF summary. Export: `impact` per event (unknown values dropped on import) and an `impact` object
in the analytics block.

### 23. Faster capture: app shortcut, home-screen widget, iOS Live Activity — **(1) DONE** *(shipped in `v1.0.7`; tested on Android and the iOS Simulator)*; (2)–(3) **PROPOSED**

**Want:** start a migraine without navigating the app — in increasing cost: (1) long-press app
icon → "Log migraine" / "No migraine today"; (2) a home-screen widget showing days since last
migraine with Log and Clear buttons, and a running timer while a migraine is in progress; (3) a
persistent "migraine in progress" display while one is active, with an End button: on iOS a Live
Activity / Dynamic Island timer, on Android an ongoing notification.

**Requested again (2026-10-28):** GitHub discussion #21 (Krackmou) asked for a home-screen widget
to start a log with one tap, and a constant notification while a headache is ongoing "so that we
don't forget that the timer is on". Steve replied that a widget is planned and that he likes the
timer idea. Steps (2)–(3) are in **group C** with #16 and #27.

**Why:** the moment of logging is the worst moment to navigate an app. Migraine Attack Diary
ships widgets, Live Activities and Dynamic Island; Migraine Buddy and others push quick entry.

**Shape:**

- (1) **As built (2026-10-08):** no plugin. A static Android shortcut (`res/xml/shortcuts.xml`,
  handled in `MainActivity`) and an iOS `UIApplicationShortcutItems` entry (handled by a small
  scene-delegate class in `AppDelegate.swift`, modelled on Flutter's `quick_actions_ios`) both send
  "log_migraine" over one channel. Steve's choices: a tap **starts** the migraine (Discard undoes
  an accidental one); with one in progress it just shows it; with app lock on it waits for the
  unlock; during onboarding it's dropped. It is acted on only once the app is in the foreground,
  after app lock has had the chance to re-lock. No new permission. Debug builds target Megrim dev
  via a debug-only copy of `shortcuts.xml` (the target package must be a literal; a `resValue`
  reference isn't resolved there, which left the dev shortcut showing "App isn't installed"). "No migraine today" waits for backlog #16. Steve chose the
  shortcut only for now; the widget (2) is about another half day on Android, iOS 1–2 days.
- (2) `home_widget` with a native Android `AppWidgetProvider` and an iOS WidgetKit extension.
  Buttons deep-link into the app rather than writing the database from the widget process —
  simpler, and avoids sharing the SQLite file across processes. The "days since" figure the widget shows is a
  single number the app writes to the widget's shared storage, so state in PRIVACY that this one
  value sits outside the database.
- (2) **Timer (added 2026-10-28).** While a migraine is in progress the widget shows elapsed time
  instead of days since. Both platforms count up natively from a start time, so the widget needs no
  background work and doesn't wake the app: Android's `Chronometer` in `RemoteViews` (base set
  from the start instant), iOS `Text(startDate, style: .timer)`. The app writes the start instant
  (or "none") to the widget's shared storage when a migraine starts, ends or is discarded, which
  is one more value outside the database (PRIVACY). With one in progress the Log button becomes
  "Open" (shows it), matching the shortcut. App lock: the widget shows only the timer and no
  details, and the button still goes through the unlock.
- (3) ActivityKit needs a Swift widget extension target and an App Group; iOS-only.
- (3) **Android: an ongoing notification (added 2026-10-28).** Posted when a migraine starts,
  removed when it ends or is discarded: "Migraine in progress" with a native running clock
  (`setUsesChronometer` + `setWhen(start)`, so no foreground service and no background work) and
  an End action that opens the app (End deep-links like the shortcut; it does not write the
  database from the notification). Opt-in, from a Settings row and on first start of a migraine
  once. Needs **`POST_NOTIFICATIONS`** on Android 13+ (runtime prompt), the same permission as #27,
  so build them together and add the permission once. Android 14+ lets users swipe ongoing
  notifications away; that's fine, since it's a reminder, not state. Repost it if the app is
  opened during a migraine and it's missing. Lock screen: `VISIBILITY_PRIVATE` with a public
  version that says only "Megrim", so nothing shows on a locked phone.
- **F-Droid check:** confirm each plugin's license and its transitive Android deps are FOSS and
  that they add no permission beyond the current set (see *Permissions* above).

**Verification:** widget/shortcut deep links covered by integration tests where possible;
manual release-build smoke test on a real device (minification note in STATUS "Known gaps").

### 27. Daily reminder to log (opt-in local notification) — **PROPOSED** *(2026-10-28)*

**Want:** a notification once a day at a time the user picks (e.g. 8:00 AM or 8:00 PM) reminding
them to log the day while they remember it: a migraine, or a "No migraine today" check-in (#16).

**Why:** asked for in GitHub discussion #21 (Krackmou, 2026-10-28), coming from Apo, which has it.
It's also what makes #16 work: a clear-day baseline is only as good as check-in adherence, and the
2026-10-06 review had parked reminders as "revisit after #16" for exactly that reason. Build them
together in **group C**.

**Shape:**

- **Opt-in, off by default** (like the #14 backup reminder): a Settings row, Off or a time of day.
  The notification permission is requested only when the user turns it on.
- **Local only.** No server, no push, no network: the OS schedules it. Likely
  `flutter_local_notifications` (BSD-3); check it and its Android deps for F-Droid.
- **Skip when there's nothing to ask.** If today already has an entry or a check-in, don't
  remind. Simplest: when the app logs one, cancel today's notification and reschedule from
  tomorrow.
- **Actions:** "No migraine today" (once #16 exists) and "Log". Both open the app (deep link, as
  with the shortcut) rather than writing the database from the notification, and go through app
  lock. Notification text is generic ("Megrim: how was today?"), never health details, and private
  on the lock screen.
- **Android timing:** use inexact scheduling (a few minutes late is fine), which avoids
  `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`. Scheduled notifications are lost on reboot. Either
  add `RECEIVE_BOOT_COMPLETED` to reschedule, or reschedule each time the app opens and accept a
  missed day after a reboot. Decide when building; the second avoids a permission.
- **Permissions:** `POST_NOTIFICATIONS` (Android 13+), shared with #23(3)'s ongoing notification;
  possibly `RECEIVE_BOOT_COMPLETED`. Update README, PRIVACY and the F-Droid listing (see
  *Permissions* above). iOS asks for notification permission at runtime; no entitlement needed.

**Verification:** unit tests for "next fire time" (today vs tomorrow, after logging, DST change
days, time-zone change); widget test of the Settings row; manual test on a real Android 13+ phone
(permission prompt, deny path, notification arrives, reboot behaviour, lock-screen privacy) and on
iOS from the Mac build.

### 24. App lock with the phone's own unlock, and hide from the app switcher — **DONE** *(shipped in `v1.0.7`; all Android tests passed, iOS to check in TestFlight)*

**Want:** (a) an optional lock on open that uses **whatever unlock the phone already has** —
fingerprint, face, or the device PIN/pattern/password; (b) the app's content blanked in the
recent-apps switcher.

**Why:** cheap, and it completes the privacy story — the data never leaves the phone, but anyone
holding an unlocked phone can currently read it.

**(a) App lock — device credential, not an app PIN.**

- Settings › Privacy › App lock: off by default; lock on cold start and after N minutes in the
  background.
- `local_auth` with biometrics-only **off**: the system prompt offers the user's enrolled
  biometric and falls back to their device PIN/pattern/password (Android `BiometricPrompt` with
  `BIOMETRIC_STRONG | DEVICE_CREDENTIAL`; iOS `LAPolicy.deviceOwnerAuthentication`). The user
  picks their preference in the phone's settings, not in Megrim.
- **No Megrim PIN means nothing to forget.** The recovery path is the phone's own unlock. The
  earlier PIN-only idea is dropped: a 4–6 digit PIN hashed into `app_settings` can be brute-forced
  by anyone who can read the database, so it would have been weaker than the device lock anyway.
- If the phone has no screen lock, the toggle can't be turned on; a dialog says why. If the
  screen lock is removed later, the lock turns itself off with a one-time explanation rather than
  shutting the user out of their data.
- Turning it on **and** off both need a successful unlock. "Lock after": Immediately / 1 / 5 /
  15 minutes, default 1. The share sheet, file picker and the unlock prompt itself don't count as
  leaving the app. Nothing can be logged from the lock screen (Steve, 2026-10-07).
- Costs: Android `MainActivity` must change from `FlutterActivity` to `FlutterFragmentActivity`
  (regression-test the share/file-picker flows); iOS needs `NSFaceIDUsageDescription` in
  Info.plist; `LaunchTheme` must have an AppCompat parent or the prompt crashes on Android ≤ 8.
  **Permissions:** `local_auth` merges in **`USE_BIOMETRIC`**, and `androidx.biometric` adds
  **`USE_FINGERPRINT`** (fingerprint on API 26–27). Both are normal, install-time permissions with
  no user prompt, but they change the listed set, so PRIVACY and the F-Droid listing are updated
  in the same change (see *Permissions* above).

**(b) Hide from the app switcher.** Android `FLAG_SECURE` (blanks the switcher thumbnail and
blocks screenshots) as its own toggle, since some users want screenshots for their doctor; iOS:
overlay a blank view on `applicationWillResignActive`.

**Encryption at rest — reviewed 2026-10-07, not planned.** SQLCipher with a Keystore/Keychain
key was considered. Android file-based encryption and iOS Data Protection already encrypt
Megrim's storage with the phone's credential, so it would only add a layer against the file being
copied off the device, while costing a native-library swap (F-Droid build question), a possible
App Store export-compliance change, and data loss on phone migration (the key can't follow the
database through OS backup). Steve judged it not worth it.

**Verification:** widget tests for lock gating and timeout; manual check of the switcher and of
the device-credential fallback (no biometric enrolled) on both platforms; manifest inspection of
the release build.

### 26. Attacks without headache ("silent" and vestibular migraine) — **BUILT** *(2026-10-27, branch `feat/attack-details`; Steve's test passed 2026-10-28, merged to `main` 2026-10-29, ships in 1.0.8)*

**Want:** a way to log a migraine attack that had **no headache**: aura only, vertigo/dizziness
only, or the fatigue / brain-fog phase with the pain never arriving. Today every entry
implicitly assumes a headache: the 1–10 slider is labelled "Severity", defaults to 5, and nothing
can say "no pain".

**Why:** Steve gets episodes of marked fatigue with no headache and wants them in the record. Headache-free
attacks are a recognized part of migraine, but the popular names are looser than the clinical
ones (researched 2026-10-27):

- **"Silent" / acephalgic migraine** formally means **ICHD-3 1.2.1.2 Typical aura without
  headache**: a typical aura (visual, sensory, speech; usually 5–60 min) with no headache within
  60 min. Some people have only these; others mix them with ordinary attacks. A first aura after
  age 40, or one that is only "negative" (vision loss), warrants ruling out TIA, so it's worth
  logging for the clinician.
- **Vestibular migraine** (ICHD-3 appendix **A1.6.6**, Bárány Society/IHS criteria): episodes of
  vertigo or head-motion dizziness lasting 5 min–72 h, in someone with a migraine history, with
  migraine features in at least half of them. Roughly 26–30% of patients have **no headache** during
  episodes (about half in the "probable" group).
- **Prodrome / postdrome without headache:** fatigue is among the most common prodromal and
  postdromal symptoms (about 72% postdromal fatigue in one 500-patient sample). In the PRODROME
  trial, about 18% of confident prodromes had no headache within 6 h (about 5% none within 24 h).
  Fatigue *alone* is not a defined migraine type, which is a reason to record the facts and not
  ask the user to name a category.

Sources: [ICHD-3 1.2.1.2](https://ichd-3.org/1-migraine/1-2-migraine-with-aura/1-2-1-migraine-with-typical-aura/1-2-1-2-typical-aura-without-headache/),
[ICHD-3 A1.6.6](https://ichd-3.org/appendix/a1-migraine/a1-6-episodic-syndromes-that-may-be-associated-with-migraine/a1-6-6-vestibular-migraine/),
[Bárány/IHS VM criteria](https://pmc.ncbi.nlm.nih.gov/articles/5204080),
[VM with/without headache](https://ejo.springeropen.com/articles/10.1186/s43163-024-00740-z),
[VM review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7388671),
[postdrome frequency](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3620007/),
[prodrome symptoms](https://www.frontiersin.org/journals/neurology/articles/10.3389/fneur.2019.00199/full),
[PRODROME trial](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12283353/).

**Shape:**

- **Record facts, not a self-diagnosis.** No "type" picker. Instead:
  - New `migraine_events.headache_present`: tri-state bool, same as `aura_present` (true / false /
    null = unknown). Existing rows stay null, and **null is treated as "headache"** everywhere, so
    nothing about existing data or counts changes.
  - Symptoms come from **backlog #20**; build the two together in the same schema bump (v4). #20's
    default list must cover these presentations: fatigue, brain fog, yawning, neck stiffness,
    dizziness, **vertigo**, motion sensitivity, nausea, light / sound / smell sensitivity. Aura
    is already recorded (`aura_present` / `aura_description`).
- **UI:** a "Headache? Yes / No / Not sure" control on Event Detail, and on the active Quick Log
  view. When "No" is chosen, the slider relabels to **overall impact** ("How much did it stop
  you?"; ties into #22) and the head-location field hides.
- **Derived label, shown not stored:** a "No headache" badge on History rows and Event Detail,
  with a qualifier taken from the facts: "with aura" (aura present), "with vertigo" (vertigo /
  dizziness symptom), otherwise just "No headache". Computed at display time, so it can be revised
  without a migration.
- **Analytics (Steve's decisions, 2026-10-27):**
  - **Monthly migraine days (#17): count them**, and say so: "12 migraine days, including 3
    without headache" on the stat tile, and a split (stacked) bar in the monthly chart. Same in
    the export (`migraine_days_without_headache_last_30`, and a per-month field next to
    `migraine_days_by_month`).
  - **Trigger correlations: include them by default**, like any other event. No separate set.
  - **Average severity:** compute it over headache attacks only, because a headache-free entry's
    number means impact, not pain, and mixing the two would skew the average. Note the
    headache-free count beside it. The History calendar keeps colouring by the number either way.
- **PDF report (Steve's decision): list them separately.** An "Attacks without headache" section:
  count and share of all attacks, broken down by with aura / with vertigo or dizziness / other,
  their most common symptoms, and typical duration. A clinician uses exactly this to tell typical
  aura without headache and vestibular migraine apart from other causes.
- **Export:** `headache_present` added to each event as an optional field (allowed under the
  export schema's rules for compatible changes); update `megrim-export.schema.json`. Import of
  older files leaves it null.
- **Not doing:** no diagnosis, wording that implies one, or "this was a silent migraine"
  verdicts. The app records and counts; the clinician interprets.

**Verification:** migration test (v3→v4; existing events read back with `headache_present` null
and are counted exactly as before); unit tests for monthly days with a mix of headache and
headache-free events (both counted, the without-headache split correct, a day with one of each
counts once and, by rule, as a headache day); a correlation test asserting headache-free events
are included; average severity excludes `headache_present == false`; export/import round-trip
including null / true / false; a report test asserting the separate section and its breakdown;
widget test that "No" relabels the slider and hides head location.

**As built (2026-10-27, Steve agreed the design first):** one change from the shape above: built
together with #22a, so choosing "No" **hides** the severity slider and head location (and clears
them on save) instead of relabelling the slider, and the day's burden goes in the Impact field.
That also settles average severity: headache-free attacks have none, and the dashboard skips any
that do (an imported file). New entries (Quick Log, past entries) start at **Yes**; older ones
show **Not sure**. History draws a headache-free entry as an empty grey ring with "No headache ·
with aura / with vertigo"; the calendar day stays grey. Monthly card: "Last 30 days, including N
without headache" and bars in two colours (headache-free days at the bottom). PDF: "Attacks
without headache" right after the summary, Sev "none" in the entries table. Shared rules in
`app/lib/models/attack_details.dart`; method in `docs/METHODS.md`; tests in
`app/test/attack_details_test.dart` and `attack_details_ui_test.dart`.

### Reviewed, not planned *(2026-10-06)*

Seen in competitors, deliberately left out because they conflict with SPEC §1.3 non-goals or the
locked decisions. Recorded so the question isn't re-litigated from scratch:

- ~~**Daily reminders.**~~ Moved to **#27** (2026-10-28), after GitHub discussion #21 asked for one.
- **Apple Health / Health Connect.** Non-goal; Health Connect also brings Play policy burden.
- **Cloud / iCloud sync, multi-device.** Non-goal (no server, ever). Export/import + backlog
  #14/#15 cover backup.
- **Weather-forecast risk alerts** (Migraine Buddy's 7-day pressure forecast). Needs a daily
  background network call and edges into prediction claims; both are non-goals.
- **AI coaching, community, in-app research questionnaires, voice logging.** Out of scope for a
  serverless, telemetry-free app.

## Localization

### 25. Move the UI's English text into a message file (prep for translations) — **PROPOSED** *(2026-10-27)*

**Want:** every user-visible English string pulled out of the Dart code into a Flutter ARB file
(`app_en.arb`), using the standard `flutter_localizations` + `gen-l10n` setup. **No visible
change** — the app still ships English only. This is the groundwork that makes any later language a
matter of adding one file.

**Why:** issue #19 (2026-10-17) asks for Simplified Chinese. Not committing to that, but today
there is **no** localization setup at all: no `flutter_localizations`, no `l10n.yaml`, and roughly
360 English strings hard-coded across 47 files under `app/lib/`. Until those are extracted, *any*
translation means touching every screen. This step is worth doing once, regardless of which
language (if any) comes next. Needs a dedicated block of time, not a side task — it touches nearly
every screen.

**Shape:**

- **Setup:** add `flutter_localizations` (SDK) to `pubspec.yaml`, `generate: true`, an
  `l10n.yaml` (`arb-dir: lib/l10n`, template `app_en.arb`), and wire `localizationsDelegates` /
  `supportedLocales` into `MaterialApp`. `intl` is already a dependency.
- **Extract by file, heaviest first** — `settings_screen.dart` (~58 strings),
  `event_detail_screen.dart` (~53), `analytics_screen.dart` (~52), then `report_content.dart` /
  `report_pdf.dart`, `onboarding_screen.dart`, `quick_log_screen.dart`, `legal.dart`, and the
  rest. One commit per screen keeps it reviewable.
- **Use ICU placeholders and plurals, not string-building.** e.g. `'Need at least $n events…'`
  becomes a message with a `{count}` placeholder; `'1 day' / '3 days'` becomes a `plural`.
  Concatenated sentence fragments must become one whole message (word order differs by language).
- **Stored values stay English — translate at display only.** This is the main trap.
  `kDefaultTriggers` / `kTravelTrigger` (`database.dart`), and the season, moon-phase and
  day-of-week factor labels (`astro.dart`, `calendar_factors.dart`, `correlations.dart`) are
  **data**: they are written to the database, compared as keys, and appear in the JSON export
  (`export_format.dart`, `analytics_export.dart`, `megrim-export.schema.json`). Keep the English
  value as the key and map it to a display string at render time. User-typed custom triggers are
  never translated. The export format must not change.
- **Dates:** `DateFormat('EEE d MMM yyyy, HH:mm')` etc. (`history_screen.dart`,
  `event_detail_screen.dart`) hard-code the field order. Switch to locale-aware skeletons
  (`DateFormat.yMMMEd(locale)`, `DateFormat.Hm(locale)`) — check the English output still looks the
  way it does today, or accept the small change deliberately.
- **Legal text** (`legal.dart`, privacy/disclaimer): extract it, but any translation of it later
  should be marked as unofficial, with English as the version that counts.
- **Out of scope here:** the store listings (fastlane metadata, App Store) and any actual
  translation.

**Later, if a language is added** (e.g. zh-CN for #19): one `app_zh.arb`, a machine-translated
first pass reviewed by a native speaker (the #19 requester could be asked; ship it marked
"community translation"), plus `CFBundleLocalizations` in `ios/Runner/Info.plist`. Two known
gotchas for Chinese: the **PDF report embeds `NotoSans-Regular/Bold.ttf`, which has no CJK
glyphs** — Chinese would print as empty boxes — so it needs a Noto Sans SC (or similar) fallback
font, which adds several MB to the app; and missing keys fall back to English, so new strings
drift untranslated unless someone keeps the file current. On-screen CJK text uses the system font
and needs nothing.

**Verification:** `flutter analyze` clean; the full test suite passes. ~21 test files use
`find.text('…')` against English strings, so the tests need a `localizationsDelegates`-aware test
wrapper and should keep passing with no assertion changes. Re-run the store-screenshot flow
(`test/screenshot_flow_test.dart`) and compare: the shots should come out identical. Export a
JSON file before and after and diff it — it must be byte-for-byte the same apart from timestamps.
Generate a PDF report and check it matches. Optional check: a throwaway pseudo-locale ARB
(e.g. every string wrapped in `⟦…⟧`) run once on a device shows any string that was missed.

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
