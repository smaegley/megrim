# Megrim — where things stand

_Last updated: 2026-08-04, after releasing `v1.0.1`._

A resume-here snapshot: what is shipped, what is in flight, and what the open threads are.
`docs/SPEC.md` §12 remains the detailed running history; this file is the short version.

## Shipped

| | |
|---|---|
| Latest release | **`v1.0.1`** (versionCode 6), tagged on `4618339`, signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.1) |
| Signing | Release keystore `CN=Steve Maegley`, SHA-256 `c316cce2…`; the four CI secrets live on the repo. Tagging `v*` builds and publishes automatically |
| Distribution today | GitHub Releases; Obtainium tracks the repo for auto-updates |
| Permissions | `INTERNET` only (plus `ACCESS_NETWORK_STATE` from connectivity_plus). No location permission at all |
| Verification bar | `flutter analyze` clean, **144 tests** green under both UTC and `TZ=America/Denver`, release APK builds. Release builds are minified (R8), so on-device checks should use the release APK, not a debug build |

Everything in the original spec is implemented, plus the accessibility pass, documented import
format, and the opt-in privacy work below. `docs/BACKLOG.md` is fully closed out.

## In flight: F-Droid inclusion

**Merge request: [fdroiddata!43692](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/43692)**
("New app: Megrim"). Reviewer: **linsui**.

- Fork: `steve518/fdroiddata`, branch `org.maegley.megrim`. GitLab username is **`steve518`**
  (`smaegley` was taken).
- The recipe in [`fdroid/metadata/org.maegley.megrim.yml`](../fdroid/metadata/org.maegley.megrim.yml)
  is the source of truth and is mirrored byte-for-byte onto the MR branch. It targets the
  `v1.0.1` tag commit with per-ABI versionCodes **61/62/63**.
- **State (2026-08-14): queued for a volunteer tester.** Labels are `New App` +
  `review-requested`. linsui's maintainer review is finished and passed; on 2026-08-07 they said
  the MR is "mostly ready", that they will test it later and merge if it works, and that the
  queue is long (~99 MRs carry `review-requested`, oldest from February; Megrim sits around #62).
  The last upstream CI run (2026-08-05, after linsui rebased the branch onto current master)
  passed **every** job. Standing instruction from linsui: **only update this MR when a new
  version is released.**

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

**Deliberately not done yet:** the MR is in a known-good, fully CI-green state that a maintainer
has blessed, and linsui asked for updates only on new releases. Bundle this with the recipe
update that accompanies the next release.

### Unsolicited third-party "reviews"

`andrewpozdnakov7` posted a "PASS WITH NOTES" static review on 2026-08-13. It is **not** the
F-Droid tester review and does not advance the MR: they are not a member of `fdroiddata`, the
comment itself states no build or device/network test was performed (which is the whole substance
of a Tester Review), and they were posting the same templated format across 15+ new-app MRs in a
couple of days. Harmless, and its findings happen to corroborate the privacy claims, but it
changed no labels and carries no procedural weight. Do not mistake it for a passed test.

### Reading the CI emails

Pipelines belonging to the **fork** (`steve518/fdroiddata`) always fail instantly with **0 jobs** —
a new GitLab account has no shared-runner access, and per F-Droid's own MR template we did not
give GitLab payment/phone verification. **Ignore any failure notice that says "0 failed jobs" or
names the fork.** A real signal is either a comment from a maintainer or a pipeline under
`fdroid/fdroiddata` with named jobs (`fdroid build`, `check apk`, `checkupdates`, …).

### When the MR merges

Steve revokes the GitLab personal access token, and the copy on the dev VM (`~/.gitlab_pat`) gets
deleted. Megrim then appears in the F-Droid client within their next index cycle. Note the
F-Droid build is signed with **F-Droid's** key, so it is a separate install lineage from the
GitHub APK — users pick one source and stay with it.

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
