# Megrim — where things stand

_Last updated: 2026-09-22: v1.0.4 released on Android (tag, CI, signature verified) and submitted to App Review (build 10, Waiting for Review)._

A resume-here snapshot: what is shipped, what is in flight, and what the open threads are.
`docs/SPEC.md` §12 remains the detailed running history; this file is the short version.

## Shipped: iOS App Store (2026-09)

**APPROVED and LIVE** —
[Megrim: Migraine Diary](https://apps.apple.com/us/app/megrim-migraine-diary/id6808385548)
(Apple ID `6808385548`), approved the week of 2026-09-07 after one Guideline 2.1
information-request round (details below). US storefront only, free. **Current store build: 1.0.3 (9),
approved and released 2026-09-20** — a bug-fix update to an approved app cleared in about a day with no
questions.
Post-launch note (2026-09-11): App Store *search* takes days to index a new app, and "Megrim"
fuzzy-matches "Megillah" until real installs teach the brand term — seeding installs/ratings via
the direct link is the fix; README now carries the store link so web search picks it up too.

## The submission trail (2026-09-03)

**Megrim is now a two-platform Flutter app.** The iOS port (`app/ios/`, merged same day it was
scaffolded) runs the identical Dart codebase; the only iOS-specific code is the iPadOS share-sheet
anchor. Build **1.0.2 (8)** was submitted to App Review 2026-09-03 5:52 PM (submission ID
`ed4d3f5e-d1d3-4f5a-bf36-d06655246296`). First response (2026-09-05) was a **Guideline 2.1
"Information Needed"** hold — the standard new-developer questionnaire, not an app rejection.
Replied 2026-09-06 14:05 with the six written answers (kept below in `docs/APP_STORE.md`) plus a
screen recording captured on a physical iPhone via TestFlight internal testing (the app's
first-ever run on real Apple hardware), same text mirrored into the Notes field; **resubmitted,
status Waiting for Review**. TestFlight gotcha for next time: an internal tester added before a
build reaches "Testing" state never receives an invite email, and group re-add didn't resend —
adding the same address as an *individual tester on the build* did. The full release runbook and
listing content live in `docs/APP_STORE.md`; the operational facts:

- **Listing name `Megrim: Migraine Diary`** (bare "Megrim" is taken on the App Store); home-screen
  name stays Megrim. **US-only availability, free** — chosen deliberately so the Ko-fi tile stays
  policy-clean under the post-Epic US guideline 3.1.1. Expanding countries later requires first
  shipping a build that removes/gates the donate tile.
- Apple Developer **individual** membership ($99/yr, enrolled + approved 2026-09-03), team ID
  `96Q4Y32NC5`. Privacy label: **Data Not Collected**. Age rating 12+ (Medical/Treatment:
  Infrequent). Declared not-a-regulated-medical-device. DSA setup skipped (US-only).
- **Signing is MANUAL for Release** (team has no registered devices, so automatic signing cannot
  archive): Apple Distribution cert + "Megrim App Store" provisioning profile, selected in the
  Runner target. Profile expires ~2027-09 — regenerate at developer.apple.com → Profiles.
  Simulator/debug workflows are unaffected.
- Build numbers: iOS build 8 ≠ Android versionCode 7 for the same 1.0.2 (build 7 was rejected at
  ingestion for missing purpose strings — ITMS-90683; fixed by adding NSCamera/NSPhotoLibrary/
  NSLocation usage strings that truthfully say the app doesn't use those APIs, which file_picker's
  bundled media components reference). Passed via `flutter build ipa --build-number=N`.
- Google Play remains **deferred** (12-tester requirement + donation-link removal made it a worse
  deal than Apple for this app; see the memory notes / `docs/APP_STORE.md`).

## Shipped

| | |
|---|---|
| Latest release | **`v1.0.4`** (versionCode 9, tagged 2026-09-22), signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.4); the published APK verified as signed with the real release key (`CN=Steve Maegley`, SHA-256 `c316cce2…`). Contents: #14 end-date shift, #16 analytics block, #11 report page, #17 event time zones (schema v2, additive). F-Droid picks the tag up automatically |
| Signing | Release keystore `CN=Steve Maegley`, SHA-256 `c316cce2…`; the four CI secrets live on the repo. Tagging `v*` builds and publishes automatically |
| Distribution | **F-Droid** (accepted 2026-08-23) and GitHub Releases; Obtainium tracks the repo for auto-updates |
| Permissions | `INTERNET` only (plus `ACCESS_NETWORK_STATE` from connectivity_plus). No location permission at all |
| Verification bar | `flutter analyze` clean, **191 tests** green under both UTC and `TZ=America/Denver`, release APK builds. Release builds are minified (R8), so on-device checks should use the release APK, not a debug build |

Everything in the original spec is implemented, plus the accessibility pass, documented import
format, and the opt-in privacy work below. `docs/BACKLOG.md` holds one open item: **#12, an
in-app "Export report (PDF)"** — a v1.1 feature, written up and ready to pick up, not started.

## Community: first outside issues and PRs (2026-09)

Two issues and two pull requests arrived from F-Droid users in mid-September.

- **Issues [#12](https://github.com/smaegley/megrim/issues/12) and
  [#13](https://github.com/smaegley/megrim/issues/13) (istudyatuni) — FIXED and SHIPPED in
  `v1.0.3` (2026-09-19).** #13: the Calendar lost its scroll position after opening an entry (a per-build
  Drift stream plus no `PageStorageKey`). #12: backing out of an empty calendar day or "Add past
  entry" left an empty record (the row was inserted before the editor opened; Event Detail now has
  a draft mode and writes only on Save). Details in `SPEC.md` §12.
- **[PR #14](https://github.com/smaegley/megrim/pull/14) (zatteo) — MERGED 2026-09-20** (`ec4f158`).
  Moving an entry's start now shifts its end by the same delta unless the end was edited, so a
  backdated past entry needs one date pick instead of two and existing entries keep their
  duration. First round had it snapping the end to the start (collapsed real entries to zero
  duration); the author reworked it to the delta rule. Unreleased — goes out in the next patch.
- **[Issue #15](https://github.com/smaegley/megrim/issues/15) (zatteo)** — show the 3 most recent
  distinct past-entry locations in the Recorded-location dialog, hidden once the user types.
  Assessed as ~150 lines + tests, no schema/permission change; the author was invited to PR it.
- **[PR #11](https://github.com/smaegley/megrim/pull/11) (nfd9001)** adds a model-written offline
  HTML report (`tools/report.html`). Review posted 2026-09-19 requesting changes: its factor
  analysis counts every day a migraine spans as a migraine-day where the app counts start days only
  (55 vs 73 on the sample export, so "computed exactly like the app" is false), and six CSS classes
  are used but never defined. Round 2 (2026-09-20): both fixed; a side-by-side against the app's
  own `computeCorrelations` then showed the **daylight** rows still differ (simplified formula vs
  the app's NOAA 90.833° zenith: 121 vs 76 days under 9.5 h on the sample export) — asked for a
  port of `sunTimes()`, code supplied (posted 2026-09-20). Round 3 (2026-09-21): ported exactly; **MERGED**
  (`65c5d8f`) after verifying all 36 factor rows match `sample-data.analytics.json` on both its own compute
  path and its new block-first path (reads the #16 block when present). Adds `tools/report.html`,
  `docs/REPORT.md` and the fixture `sample-data.with-analytics.json`. **Decision: add the app's computed analytics to the JSON
  export as an `analytics` block** so renderers stop reimplementing the math
  ([#16](https://github.com/smaegley/megrim/issues/16) — **built and MERGED 2026-09-20**, `54812ab`, Steve verified
  export → re-import and an older file's import on his Pixel; ships in v1.0.4; renderers see `docs/IMPORT.md`
  "The analytics block" and the reference `app/test/fixtures/sample-data.analytics.json`);
  an in-app PDF report is a v1.1 candidate.
- **Dev safety:** debug builds now install as a separate app (`org.maegley.megrim.debug`, "Megrim
  dev"). Running a branch on a phone that carried the F-Droid build used to make the Flutter tool
  uninstall it, data included.
- **[Issue #17](https://github.com/smaegley/megrim/issues/17) — BUILT and MERGED 2026-09-22** (`3d83bab`), Steve ran the
  19-step emulator script (migration from a v1 DB, Tokyo zone switch, editor, export/import) — all passed. Was: events are
  UTC and local-calendar buckets use `toLocal()` at *compute* time (correlations, by-month) but at
  *enrichment* time (stored weekday/time-of-day), so a traveller's analytics depend on where the phone is
  when Analytics runs. Plan: per-event UTC offset column, one bucketing helper used everywhere, exports
  carry real offsets. Travel as an odds-ratio factor is not feasible (no daily location baseline); an
  "away from home" descriptive share + default "Travel" trigger is the honest alternative (separate issue).
- **Release plan:** v1.0.4 = #14 + #16 + #11 + #17 (Steve chose to bundle #17 rather than pay a second
  App Review cycle; the migration is additive and was exercised on the emulator). #15 was still open
  with no PR, so it moves to v1.0.5. **Android released 2026-09-22** (`release.yml` green, APK/AAB published, not
  draft/prerelease). **iOS 1.0.4 (build 10) submitted to App Review 2026-09-22, Waiting for Review** — archived from
  `app/` with `--build-number=10`, uploaded via the Xcode Organizer; What's New = the changelog with the
  `tools/report.html` mention trimmed for store readers.

**`v1.0.3` released 2026-09-19:** tag pushed, `release.yml` green (6m41s), APK/AAB published, not
draft/prerelease. **iOS 1.0.3 (build 9): submitted 2026-09-19, APPROVED and released 2026-09-20.** Archived with
`flutter build ipa --build-number=9`, opened via `open build/ios/archive/Runner.xcarchive`, uploaded from Xcode's
Organizer, version added in App Store Connect with the changelog as What's New. Steve exercised build 9 on
his iPhone via TestFlight the same day — looks good. The manual path was: `flutter build ipa --build-number=9` (build 8 was
1.0.2), upload via Xcode/Transporter, submit 1.0.3 in App Store Connect with the changelog as
"What's New".

## Done: F-Droid inclusion

**Merge request: [fdroiddata!43692](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/43692)**
("New app: Megrim"). Reviewer: **linsui**.

- Fork: `steve518/fdroiddata`, branch `org.maegley.megrim`. GitLab username is **`steve518`**
  (`smaegley` was taken).
- **MERGED 2026-08-23** after four maintainer review rounds (linsui) and a volunteer tester pass.
  Megrim is in the F-Droid catalogue.
- **Routine releases no longer need a merge request.** The merged recipe carries
  `AutoUpdateMode: Version`, `UpdateCheckMode: Tags ^v[\d.]+$`, `VercodeOperation` (×10+1/2/3) and
  `UpdateCheckData` reading `app/pubspec.yaml`, so F-Droid's bot picks up each new `v*` tag and
  generates the per-ABI build entries itself. **Tagging is the whole job.** Remember each release
  needs both `<code>.txt` and the per-ABI changelog copies (e.g. `7.txt` plus `71/72/73.txt`).
- The canonical recipe now lives in `fdroiddata`; the copy under `fdroid/` is a historical
  reference and will drift as the bot appends entries.
- The GitLab PAT expired on ~2026-08-06 and was not renewed — public MR data is still readable
  unauthenticated, but posting comments needs a fresh token.

### Review rounds so far

1. Pin `commit:` to a full hash, not a tag; follow `templates/build-flutter.yml`; decide
   reproducible builds **now** → declined permanently, so F-Droid signs with their own key.
2. Set up the ABI split (per-ABI versionCodes via a gradle snippet) → done; and "why is minify
   disabled?" → which turned out to be the fix for the next item.
3. `check apk` flagged Google Play Core class references and a Play dependency-metadata signing
   block → both fixed upstream by **enabling R8 minification** (it tree-shakes Flutter's unused
   deferred-components classes) plus `dependenciesInfo { includeInApk = false }`. `checkupdates`
   wanted `AutoName`.
4. "Why does it require INTERNET permission?" → answered. Then: **"Please make this feature
   opt-in."** → built and shipped as `v1.0.1`.
5. Volunteer tester pass → one finding: the Event Detail Enrichment card showed unrounded
   daylight and pressure-change values. Fixed and shipped as `v1.0.2`.

### Deferred: pin Flutter by commit, not tag

An outside commenter (`andrewpozdnakov7`, **not** an F-Droid member — see the note below)
suggested selecting the Flutter srclib by immutable commit rather than by tag. It is a fair
point and matches F-Droid's own reasoning for requiring a full commit hash on `commit:`.

Actionable whenever the recipe is next touched: `app/.metadata` is tracked and holds
`revision: "924134a44c189315be2148659913dda1671cbe99"` (the exact 3.44.1 engine commit), so the
prebuild could read that instead of extracting `flutter-version` from `.github/workflows/release.yml`,
matching the merged `com.sidhant.watersort` recipe:

```
- git -C $$flutter$$ checkout -f $(sed -n -E "s/.*revision:\ \"(.*)\"/\1/p" .metadata)
```

**Still not done, and now lower priority:** the MR is merged and the bot maintains the recipe, so
this would need its own small follow-up MR to `fdroiddata` rather than riding along with a
release. Worth doing only if the recipe is being touched for some other reason.

### Two things to remember about the F-Droid build

- It is signed with **F-Droid's** key, so it is a separate install lineage from the GitHub APK.
  Users pick one source and stay with it; switching means uninstall/reinstall (export first).
- During the review, one commenter (`andrewpozdnakov7`) posted a templated "PASS WITH NOTES"
  static review across many new-app MRs. It was not the tester review and carried no procedural
  weight. If similar comments appear on future MRs, judge them on whether an actual build and
  device/network test was performed.

## What `v1.0.1` changed (the opt-in release)

Weather enrichment is now **opt-in, default off** — the F-Droid requirement that prompted the
release:

- A dedicated onboarding step (after home location) states exactly what would be sent (the
  entry's date and rounded ~1 km coordinates, to Open-Meteo only) with the switch **off**, plus a
  Settings toggle to change it later. Enabling it backfills weather for existing entries.
- Opted out, the app makes **no automatic network requests**. Local enrichment — season, day of
  week, daylight hours, moon phase — is pure on-device math and always runs. Moon phase needs
  only the date; daylight and season need latitude.
- Weather-dependent surfaces explain *why* they are blank rather than looking broken: the
  "Pressure change (24h)" chart subtitle, a note in the Top Suspected Factors card, and a note in
  Event Detail's enrichment card.
- **Upgrade behaviour:** existing installs have no stored consent value, so enrichment starts off
  for them until they enable it. Deliberate, and called out in the changelog.

Two related changes came out of reviewing that work:

- **Offline home-location entry.** The location field still offers the Open-Meteo place-name
  search, but typing a decimal GPS pair (`40.01, -105.27`) or a full Plus Code (`849VCWC8+R9`) is
  decoded on-device (`lib/services/location_input.dart`, `open_location_code`). Input that even
  looks manual suppresses the geocoder, so a half-typed coordinate is never sent as a query — a
  widget test enforces this with a geocoder fake that fails if it is ever called.
- **Removed `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`** — dead since GPS tagging was
  deferred before 0.1; no code ever requested them.

The one remaining network call is the **place-name search**, and only when the user actively
types one. Wording everywhere says "no *automatic* network requests" for exactly this reason;
please keep that precision if editing the privacy copy.

## Known gaps and deliberate choices

- **No manual TalkBack pass.** The accessibility work was verified by automated guideline tests
  (contrast, 48dp tap targets, labels) in both themes. Driving TalkBack on an emulator with a
  mouse proved unusable, so any manual screen-reader testing should happen on a real phone.
  `AnalyticsScreen` also can't be pumped to settlement in widget tests when enrichment is *on*
  (connectivity_plus has no platform-channel mock) — with enrichment off it now settles fine.
- **No in-app import mapper.** Third-party migration is served by
  [`docs/IMPORT.md`](IMPORT.md) + [`docs/megrim-export.schema.json`](megrim-export.schema.json)
  and an AI assistant or script; generic CSV import stays a v2 candidate.
- **No "skip location" option.** Onboarding still requires a home location. A true skip would
  need one offline question (hemisphere) to keep Season correct, would lose daylight hours, and
  would need enrichment to treat location-less events as complete rather than errored. Not built;
  a privacy-minded user can enter deliberately vague coordinates today.
- **Reproducible builds: declined**, permanently, per the review. F-Droid signs its own builds.
- Minification is on, so a plugin-level regression would only show in a release build. Smoke-test
  file picker, share sheet, save-to-file, the external links, and Analytics online/offline before
  each release.

## Working notes

- Build environment, toolchain paths and gotchas: see the dev-environment notes (source
  `~/.megrim_env.sh` before any flutter/gradle command on the VM).
- Screenshots for the store listing live in
  `fastlane/metadata/android/en-US/images/phoneScreenshots/`, `NN-description.png`, filename order
  is carousel order. Currently 10: 01–08 light (incl. the new Settings and weather opt-in steps)
  and 09–10 dark. They use a **New York decoy** home location on purpose.
- Changelogs are `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`. Each release
  needs the plain code (`6.txt`) **and** the per-ABI copies (`61.txt`, `62.txt`, `63.txt`), since
  F-Droid looks them up by the split versionCodes.
