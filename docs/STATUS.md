# Megrim — where things stand

_Last updated: 2026-09-03, after submitting the iOS app to App Store review._

A resume-here snapshot: what is shipped, what is in flight, and what the open threads are.
`docs/SPEC.md` §12 remains the detailed running history; this file is the short version.

## In flight: iOS App Store submission (2026-09-03)

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
| Latest release | **`v1.0.2`** (versionCode 7), signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.2) |
| Signing | Release keystore `CN=Steve Maegley`, SHA-256 `c316cce2…`; the four CI secrets live on the repo. Tagging `v*` builds and publishes automatically |
| Distribution | **F-Droid** (accepted 2026-08-23) and GitHub Releases; Obtainium tracks the repo for auto-updates |
| Permissions | `INTERNET` only (plus `ACCESS_NETWORK_STATE` from connectivity_plus). No location permission at all |
| Verification bar | `flutter analyze` clean, **147 tests** green under both UTC and `TZ=America/Denver`, release APK builds. Release builds are minified (R8), so on-device checks should use the release APK, not a debug build |

Everything in the original spec is implemented, plus the accessibility pass, documented import
format, and the opt-in privacy work below. `docs/BACKLOG.md` is fully closed out.

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
