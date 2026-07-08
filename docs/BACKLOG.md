# Megrim backlog

Non-blocking improvements captured for later. Not committed to a release; groom as needed.
(Product definition lives in [`SPEC.md`](SPEC.md); this is the running "would be nice" list.)

## UI / UX

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

### 6. Add a medications UI to Event Detail *(real gap, not a bug)*
**Now:** the schema (`meds_taken` = `[{name, dose, time, helped}]`), the `medication` vocab (managed in Settings), and export/import **all support meds — but there is no screen to add them to an event.** Event Detail only has Head-location and Suspected-trigger chip sections.
**Want:** a Medications section in Event Detail (and ideally Quick Log) to add meds to an entry.
**Notes:** More than a chip picker — each med has name (from vocab) + optional dose, time, and "helped?" tri-state. Likely a small add-row sub-form backed by the `medication` vocab, writing the `meds_taken` JSON that export/CSV already emit.

## Release / infra

### 4. Donations — decide and wire up
**Now:** the in-app Donate tile links to a placeholder `https://liberapay.com/megrim`; `.github/FUNDING.yml` is fully commented out.
**Want:** pick a platform (Liberapay / Ko-fi / GitHub Sponsors), then set the real URL in the Donate action **and** `.github/FUNDING.yml`. Keep it a plain URL → browser (no in-app payment SDK, per SPEC §1.3 / F-Droid).

### 5. "Source code" link must open the repo
**Now:** Settings › Source code launches `kSourceUrl` = `https://github.com/smaegley/megrim` (updated during the identity switch).
**Want:** confirm it actually opens the repo on-device; if it doesn't, debug `url_launcher` (intent/`canLaunchUrl`) — and consider surfacing it more prominently (it's currently only in Settings + the About dialog legalese).
