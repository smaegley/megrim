# Megrim — where things stand

_Last updated: 2026-10-09: v1.0.7 released on GitHub and the App Store (iOS build 13); F-Droid catching up (1.0.6 built, 1.0.7 queued); store screenshots refreshed with the new automated capture._

A resume-here snapshot: what is shipped, what is in flight, and what the open threads are.
`docs/SPEC.md` §12 remains the detailed running history; this file is the short version.

## Next steps (as of 2026-10-08)

**Finish the 1.0.7 release**
1. **iOS 1.0.7 (13) is released** (approved by 2026-10-09). If not yet done, check on a real
   iPhone: app lock's Face ID prompt (H1),
   the blank app-switcher card with "Hide in recent apps" on (H2), and the "Log migraine" shortcut.
   Scripts: `.claude/test-app-lock.md` Part H, `.claude/test-app-shortcut.md` Part E.
2. **F-Droid**: 1.0.6 is built and publishing; 1.0.7's entries are in (2026-10-09) and it builds in
   the next cycle, expected served around 2026-10-14/15. Nothing to do unless a build fails. Check
   with the `curl` commands under *Done: F-Droid inclusion* below (`build.json` lists
   `successfulBuildIds` / `failedBuilds`).

**Next iOS update: upload the new screenshots.** App Store Connect only takes screenshots for a
version in preparation, so they couldn't go on the already-released 1.0.7. With the next version:
6.9" iPhone ← `screenshots/ios/iphone-6.9`, 6.3" ← `iphone-6.3`, 13" iPad ← `ipad-13` (on Steve's
Mac under `~/megrim/screenshots/ios/`), replacing the old ones. Retake first if `--stale` says
screens changed. (Also raised automatically at release prep from `.claude/reminders/release.md`.)

**Store screenshots: refreshed 2026-10-09** with the new automated capture: 10 shots (Log with the
backup line, Analytics overview with migraine days per month, factors, a chart, History list and
calendar, entry detail, Settings › Privacy, two dark) for Android phone + Pixel Fold (F-Droid,
committed) and iPhone 6.9" / 6.3" / iPad 13" (uploaded in App Store Connect). The old F-Droid set,
which showed Steve's real last-migraine date, is gone. To retake: `tools/screenshots.sh <target>`
(guide `.claude/test-store-screenshots.md`); `tools/screenshots.py --stale` says whether screens
changed since. iPhone Duo sets wait for a Duo Simulator in Xcode (`MEGRIM_SIM_DUO`).

**Backlog still open** (details in `docs/BACKLOG.md`)
- **#16** "No migraine today" check-ins: the biggest analytics improvement (a real baseline for
  self-reported triggers); medium–large.
- **#18** Acute-medication days and a medication-overuse notice (ICHD-3 thresholds; wording needs
  review); medium.
- **#19** Preventive medications and non-drug relief; **#20** symptoms; **#21** opt-in menstrual
  cycle log; **#22** impact on the day (questionnaire licensing to check first).
  #16 and #18–#22 all need schema v4: batch them into one release.
- **#23 steps 2–3**: a home-screen widget (Android about half a day; iOS 1–2 days, needs the Mac)
  and an iOS Live Activity. Steve chose the shortcut only for now.
- **#15** remembering the export location / automatic backups: still deferred.

**Housekeeping (optional)**
- The erased commit `a056b55` (a personal export committed by mistake, removed from history
  2026-10-08) can still be fetched from GitHub by its exact id until GitHub's own cleanup; GitHub
  Support can purge it on request. Steve judged this not worth doing.
- Merged branches still on GitHub (`feat/app-lock`, `fix/android-backup`,
  `feat/monthly-migraine-days`, `fix/factor-onset-days`, `feat/app-shortcut`,
  `docs/readme-refresh`, `chore/release-1.0.7` if pushed) can be deleted whenever convenient.
- `tools/report.html` is a community contribution marked as unmaintained in `docs/REPORT.md`; no
  action planned.

## `v1.0.7` (versionCode 12, tagged 2026-10-08)

Android: **released 2026-10-08** (`release.yml` green, APK/AAB published, not draft/prerelease;
the published APK verified: versionCode 12, versionName 1.0.7, signed `CN=Steve Maegley` SHA-256
`c316cce2…`, permissions INTERNET, ACCESS_NETWORK_STATE, USE_BIOMETRIC, USE_FINGERPRINT). F-Droid
follows by itself. **iOS 1.0.7 (build 13): submitted to App Review
2026-10-08, APPROVED and released by 2026-10-09** (What's New = the release notes minus the
Android-only lines; Face ID explained in the review notes).

**F-Droid pipeline, checked 2026-10-09:** still serving 1.0.5. 1.0.6: bot entries 2026-10-06,
**built** in the 2026-10-07→08 build run (111/112/113, no failures), publishing run in progress
since 2026-10-08 09:22 UTC. 1.0.7: bot entries added 2026-10-09 07:25 UTC, after that build run
started, so it builds in the next cycle; expected to be served around 2026-10-14/15 (1.0.5 took
about six days tag-to-served). Both versions will be published; clients offer the newest. Each item below
had a manual test script on the emulator (and a real phone where native code changed), all
passed.

- **Android backup actually includes the diary.** The database is `app_flutter/megrim.sqlite`
  (path_provider's documents directory), which only the `root` backup domain covers; the API 31+
  rules listed only database/sharedpref/file, so Android 12+ Google backup and device transfer
  carried no events. Now `root` + `app_flutter/megrim.sqlite` (the file only: the whole folder
  includes debug `flutter_assets/` and exceeded the 25 MB quota). Verified with a `bmgr` backup →
  uninstall → restore on the emulator.
- **App lock (backlog #24).** Settings › Privacy: the phone's own fingerprint/face/PIN via
  `local_auth`, "Lock after" (immediately/1/5/15 min, default 1), and "Hide in recent apps"
  (Android `FLAG_SECURE`, iOS blank overlay). **Adds `USE_BIOMETRIC` and `USE_FINGERPRINT`**
  (install-time, no prompt); PRIVACY and the F-Droid description updated. `MainActivity` is now a
  `FlutterFragmentActivity`. iOS checks (Face ID prompt, switcher) still to do in TestFlight.
  Encryption at rest was reviewed and is **not planned**.
- **Migraine days per month (backlog #17)** on Analytics (after Summary) and in the PDF report:
  last 30 days, average over the last 3 complete months, a bar per month since the first entry.
  Export gains `migraine_days_*`.
- **Suspected Factors corrections.** Migraine-days are onset days, and days 2+ of a multi-day
  migraine leave the comparison (`excluded_mid_attack_days` in the export). The pressure factor
  now reads both sides from the cached daily-mean series (it compared hourly onset deltas with a
  daily-mean baseline, which inflated the extreme buckets: OR 41 → 0.6 on the sample data). Users'
  odds ratios will change; say so in the release notes. Rationale in `docs/METHODS.md`.
- **"Log migraine" app-icon shortcut (backlog #23 step 1)**, Android and iOS (iOS checked in the
  Simulator). No plugin, no permission.

## Shipped: iOS App Store (2026-09)

**APPROVED and LIVE** —
[Megrim: Migraine Diary](https://apps.apple.com/us/app/megrim-migraine-diary/id6808385548)
(Apple ID `6808385548`), approved the week of 2026-09-07 after one Guideline 2.1
information-request round (details below). US storefront only, free. **Current store build: 1.0.6 (12),
approved 2026-10-06** (submitted 2026-10-05). Previous: **1.0.5 (11),
approved and released 2026-09-30** (submitted 2026-09-29 — about a day in review). Previous: **1.0.4 (10),
approved and released 2026-09-27** (submitted 2026-09-22 — a bug-fix update to an approved app, no
questions asked). Previous: **1.0.3 (9),
approved and released 2026-09-20** — a bug-fix update to an approved app cleared in about a day with no
questions.
Post-launch note (2026-09-11): App Store *search* takes days to index a new app, and "Megrim"
fuzzy-matches "Megillah" until real installs teach the brand term — seeding installs/ratings via
the direct link is the fix; README now carries the store link so web search picks it up too.

## The submission trail (2026-09-03)

**Megrim is now a two-platform Flutter app.** The iOS port (`app/ios/`, merged same day it was
scaffolded) runs the identical Dart codebase; at the time the only iOS-specific code was the
iPadOS share-sheet anchor (since then: the app-lock blank overlay and Face ID string, and the
app-icon shortcut handler in `AppDelegate.swift`, all on `main`). Build **1.0.2 (8)** was submitted to App Review 2026-09-03 5:52 PM (submission ID
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
| Latest release | **`v1.0.7`** (versionCode 12, tagged 2026-10-08): app lock, migraine days per month, the "Log migraine" shortcut, the Android backup fix and the Suspected Factors corrections (see the section above); no schema change. Previous: **`v1.0.6`** (versionCode 11, tagged 2026-10-05), signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.6); the published APK verified as signed with the real release key (`CN=Steve Maegley`, SHA-256 `c316cce2…`) with the permission list unchanged. Contents: the in-app PDF report (backlog #12) and the opt-in backup reminder (#14). No schema change. Previous: **`v1.0.5`** (versionCode 10, tagged 2026-09-29), signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.5); the published APK verified as signed with the real release key (`CN=Steve Maegley`, SHA-256 `c316cce2…`). Contents: the recent-locations picker (#18), the away-from-home share and the "Travel" trigger (backlog #13, schema **v3**, additive). Previous: **`v1.0.4`** (versionCode 9, tagged 2026-09-22), signed APK + AAB on the [GitHub release](https://github.com/smaegley/megrim/releases/tag/v1.0.4); the published APK verified as signed with the real release key (`CN=Steve Maegley`, SHA-256 `c316cce2…`). Contents: #14 end-date shift, #16 analytics block, #11 report page, #17 event time zones (schema v2, additive). F-Droid picks the tag up automatically |
| Signing | Release keystore `CN=Steve Maegley`, SHA-256 `c316cce2…`; the four CI secrets live on the repo. Tagging `v*` builds and publishes automatically |
| Distribution | **F-Droid** (accepted 2026-08-23) and GitHub Releases; Obtainium tracks the repo for auto-updates |
| Permissions | `INTERNET`, `ACCESS_NETWORK_STATE` (connectivity_plus), and since v1.0.7 `USE_BIOMETRIC` + `USE_FINGERPRINT` (local_auth / androidx.biometric, for the optional app lock; install-time, no prompt). No location permission at all |
| Verification bar | `flutter analyze` clean, **312 tests** green (on `main`, 2026-10-08) under both UTC and `TZ=America/Denver`, release APK builds. Release builds are minified (R8), so on-device checks should use the release APK, not a debug build |

Everything in the original spec is implemented, plus the accessibility pass, documented import
format, and the opt-in privacy work below. `docs/BACKLOG.md` is closed out apart from **#15,
remembering the export location / automatic backups** — deferred, because `file_picker` discards
the real save destination and the automatic half would need background-work permissions.
#12 (in-app PDF report) and #14 (backup reminder) shipped in v1.0.6. The 2026-10 competitor review
added #16–#24; #17, #23 step 1 and #24 are done (shipped in v1.0.7, above), the rest proposed.

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
  duration); the author reworked it to the delta rule. Shipped in v1.0.4.
- **[Issue #15](https://github.com/smaegley/megrim/issues/15) (zatteo)** — show the 3 most recent
  distinct past-entry locations in the Recorded-location dialog, hidden once the user types.
  Assessed as ~150 lines + tests, no schema/permission change; the author sent PR #18, merged and
  shipped in v1.0.5 (below).
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
  the in-app PDF report followed in v1.0.6 (backlog #12).
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
- **[Issue #15](https://github.com/smaegley/megrim/issues/15) / [PR #18](https://github.com/smaegley/megrim/pull/18)
  (zatteo) — MERGED 2026-09-29** (`f4a3fee`) after two review rounds: a location taken from the new
  "Recent" list bypassed the 2-decimal coordinate rounding (stored, never transmitted — the
  Open-Meteo client rounds independently), and the card only hid 400 ms after the last keystroke.
  Both fixed and verified.
- **Backlog #13 — MERGED 2026-09-29** (`ab29137`): the away-from-home share, plus "Travel" in the
  default triggers (schema v3). Steve ran the 18-step emulator script covering the v3 upgrade, the
  picker, the card and the export — all passed. Deliberately descriptive-only, not a suspected
  factor.
- **Release plan:** v1.0.6 = backlog #12 + #14; no schema change. **Android released 2026-10-05**
  (`release.yml` green, APK/AAB published, signature and permissions verified); **iOS build 12
  submitted to App Review 2026-10-05, APPROVED 2026-10-06.** The generated-changelog CI check ran green on its first
  real release. Note the APK grows ~22 → 23.5 MB
  (arm64) for the report's bundled fonts — quote the per-ABI figure, not the universal APK, whose
  jump is three ABIs of the same code. Previously: v1.0.5 = PR #18 + backlog #13. **Android released 2026-09-29** (`release.yml`
  green, APK/AAB published, not draft/prerelease, signature verified). **iOS 1.0.5 (build 11): submitted 2026-09-29, APPROVED and released 2026-09-30.**
  Archived from `~/megrim/app` with `--build-number=11`, uploaded via the Xcode Organizer.
  **F-Droid published 1.0.5 by 2026-10-05**, completing the release on all three channels. v1.0.4 = #14 + #16 + #11 + #17 (Steve chose to bundle #17 rather than pay a second
  App Review cycle; the migration is additive and was exercised on the emulator). #15 was still open
  with no PR, so it moves to v1.0.5. **Android released 2026-09-22** (`release.yml` green, APK/AAB published, not
  draft/prerelease). **iOS 1.0.4 (build 10): submitted 2026-09-22, APPROVED and released 2026-09-27** — archived from
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
  generates the per-ABI build entries itself. **Tagging is the whole job.**
- **Changelogs are generated, not hand-copied** (since 2026-10-05). Write the notes once in
  `docs/release-notes/<version>.txt` (500 characters max) and run `tools/sync_changelogs.py`; it
  reads the version from `app/pubspec.yaml` and writes the three per-ABI files F-Droid expects
  (`111/112/113.txt` for versionCode 11, per the recipe's `VercodeOperation`). CI runs it with
  `--check`, so a drifted hand-edit fails the build. Earlier releases also carry an un-suffixed
  `<code>.txt` — those match **no** F-Droid build and nothing reads them (the GitHub release
  workflow doesn't use changelogs); they're left as history and no new ones are written.
- The canonical recipe now lives in `fdroiddata`; the copy under `fdroid/` is a historical
  reference and will drift as the bot appends entries.
- **Publication lags the tag by days, in two stages.** The bot appends the build entries (pinned to
  the tagged commit) within hours; F-Droid's build server then compiles each ABI on its own
  schedule and publishes. `v1.0.4` was tagged 2026-09-22 and served by 2026-09-30. To check where a
  release is without guessing:

  ```bash
  # what the repo actually SERVES right now
  curl -s https://f-droid.org/api/v1/packages/org.maegley.megrim
  # whether the bot has picked the tag up yet (CurrentVersion + the per-ABI entries)
  curl -s "https://gitlab.com/api/v4/projects/fdroid%2Ffdroiddata/repository/files/metadata%2Forg.maegley.megrim.yml/raw?ref=master"
  # did a build run fail? (megrim in failedBuilds)
  curl -s https://f-droid.org/repo/status/build.json
  ```

- **A client showing an older version has two causes, and the F-Droid app tells you which.** A
  stale index (pull down on Latest/Updates to refresh) — or a signature mismatch, which refreshing
  can never fix. Every F-Droid build of Megrim is *built and signed by F-Droid*, so an install that
  came from the GitHub-release APK (directly or via Obtainium) carries Steve's key instead and
  F-Droid cannot update over it. The tell is **"No versions with compatible signer"** at the bottom
  of the app's page; the version shown beside the name in search results is then the *installed*
  one, not what the repo offers. **This happened to Steve's own phone** (diagnosed 2026-09-30): it
  sat at 1.0.2 while the repo served 1.0.4. The cause was the 2026-09-19 session, *before* debug
  builds got their own application id: `flutter run` uninstalled the F-Droid copy and installed the
  **debug APK** in its place under the same id (`org.maegley.megrim`, versionName 1.0.2,
  versionCode 7, signed with the debug key). He then restored his data into it, so his daily driver
  was a debug build for 11 days. The `.debug` suffix added later that day is what makes this
  impossible to repeat.
- **Recovering means export → uninstall → reinstall from one source → import.** The uninstall wipes
  the database, so the export is not optional (see the 2026-09-19 incident). Pick a lane and stay
  in it: **GitHub + Obtainium** gets each release minutes after the tag (the same APK CI signs and
  we verify), **F-Droid** lags by roughly a week. They cannot be mixed on one device.
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
- **Encryption at rest: reviewed 2026-10-07, not planned.** The phones already encrypt app
  storage; app lock covers someone holding an unlocked phone. Reasoning in `docs/BACKLOG.md` #24.
- **`tools/report.html` no longer computes exactly like the app when it has to compute.** Since
  the onset-day and daily-pressure changes, only its block-first path (reading an export's
  `analytics` block) matches; its own fallback still counts the old way. See `docs/REPORT.md`.
- Minification is on, so a plugin-level regression would only show in a release build. Smoke-test
  file picker, share sheet, save-to-file, the external links, and Analytics online/offline before
  each release.

## Working notes

- Build environment, toolchain paths and gotchas: see the dev-environment notes (source
  `~/.megrim_env.sh` before any flutter/gradle command on the VM).
- Store screenshots are generated, not hand-taken (since 2026-10-09): `tools/screenshots.sh <target>`
  drives the app through `app/integration_test/shots.dart` on a Simulator/emulator and
  `tools/screenshots.py` sorts them (Android: `fastlane/.../phoneScreenshots/` and
  `sevenInchScreenshots/`, filename order = carousel order; iOS: `screenshots/ios/<display>/`,
  gitignored, uploaded by hand). Made-up sample data, New York decoy home. On the Mac, pushing the
  PNGs over HTTPS needed `git config http.postBuffer 524288000` + `http.version HTTP/1.1`.
- Changelogs: write `docs/release-notes/<version>.txt` and run `tools/sync_changelogs.py`, which
  generates the per-ABI files F-Droid reads (see *Done: F-Droid inclusion* above). Don't hand-write
  files under `fastlane/.../changelogs/`.
