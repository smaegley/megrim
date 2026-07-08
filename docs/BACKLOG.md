# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

## UI / UX

### 1. Make the Analytics summary + suspected factors more visual
**Now:** Summary is a plain key/value list; Top Suspected Factors is a text list of `factor: condition — OR n`.
**Want (from migraine-tracker):**
- Summary as **stat cards/tiles** at the top — migraine-tracker used **two rows of three** (e.g. Total, Avg severity, Avg interval, Events/year, Years tracked, …).
- Suspected factors as **horizontal bars**, one per factor, length encoding significance (odds ratio), so relative strength reads at a glance instead of scanning numbers.

**Notes:** Load the `dataviz` skill before building — stat-tile and horizontal-bar specs, and use the app's purple-family palette (not raw primaries). Keep the OR value + caveats; the bar is an addition, not a replacement. The "days since last migraine" card already establishes the card style to build on.

### 2. Show counts on the bar charts
**Now:** `by day / season / time-of-day / pressure / moon / daylight` bars show no value; touch is enabled (`BarTouchData`) but there's no visible count.
**Want:** Either a small count label per bar, or tap-to-reveal the count in a tooltip. The bars look like they have room to widen and fit a number.
**Notes:** fl_chart `BarTouchData` can render a tooltip on tap already — may just need styling/enabling the tooltip text; direct labels are the more glanceable option. Decide per-chart (donuts already show in-slice counts).

### 3. Color-code bars by significance
**Now:** all bars are a single blue.
**Want:** shade bars to convey magnitude/significance — but **not** harsh primary red/orange/yellow/green. Something within a palette that fits the app's purple theme.
**Notes:** A **sequential (single-hue, light→dark) purple ramp** keyed to relative magnitude fits the design language and the `dataviz` guidance (magnitude = sequential, not categorical). For the suspected-factors bars, "significance" = odds ratio; for the descriptive count charts it'd be relative count. Validate the ramp with the dataviz palette validator.

### 6. Add a medications UI to Event Detail *(real gap, not a bug)* — **DONE**
**Was:** the schema (`meds_taken` = `[{name, dose, time, helped}]`), the `medication` vocab (managed in Settings), and export/import **all supported meds — but there was no screen to add them to an event.** Event Detail only had Head-location and Suspected-trigger chip sections.
**Done:** Event Detail now has a Medications section (below Suspected triggers). Each entry is a card showing name + optional dose/time and a thumb-up/down/? "helped" glyph, with tap-to-edit and a remove button. "Add medication" opens a sub-form dialog: name (Autocomplete over the `medication` vocab, or free text — new names are learned into the vocab), optional dose, optional time (time picker anchored to the event's date, stored ISO-8601 UTC), and a Yes/No/Unknown "helped?" tri-state. Writes the `meds_taken` JSON that export/CSV already emit. Quick Log reaches this via its existing "Add more details" → Event Detail link. Covered by `app/test/event_detail_meds_test.dart` (add/learn, remove, encode round-trip).

## Release / infra

### 4. Donations — decide and wire up
**Now:** the in-app Donate tile links to a placeholder `https://liberapay.com/megrim`; `.github/FUNDING.yml` is fully commented out.
**Want:** pick a platform (Liberapay / Ko-fi / GitHub Sponsors), then set the real URL in the Donate action **and** `.github/FUNDING.yml`. Keep it a plain URL → browser (no in-app payment SDK, per SPEC §1.3 / F-Droid).

### 5. "Source code" link must open the repo
**Now:** Settings › Source code launches `kSourceUrl` = `https://github.com/smaegley/megrim` (updated during the identity switch).
**Want:** confirm it actually opens the repo on-device; if it doesn't, debug `url_launcher` (intent/`canLaunchUrl`) — and consider surfacing it more prominently (it's currently only in Settings + the About dialog legalese).
