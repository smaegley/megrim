# Submitting Megrim to F-Droid

This folder is **tooling, not shipped in the app** — it has nothing to do with the Flutter build.
It holds the draft F-Droid build recipe and the steps to get Megrim into the F-Droid catalogue.

F-Droid builds every app **from source on its own servers** and signs it with **F-Droid's** key
(so the F-Droid APK has a *different* signature than the GitHub-release APK — that is expected and
fine for a first inclusion). The catalogue metadata lives in a separate repo,
[`gitlab.com/fdroid/fdroiddata`](https://gitlab.com/fdroid/fdroiddata); you add a recipe there via a
merge request, and their CI bot builds it.

## The recipe

[`metadata/org.maegley.megrim.yml`](metadata/org.maegley.megrim.yml) is the file that goes into
`fdroiddata/metadata/`. It already reflects the real project: package `org.maegley.megrim`,
GPL-3.0-or-later, source on GitHub, the Flutter app in the `app/` subdir, Flutter **3.44.1**, and it
auto-picks up future `v*` tags.

F-Droid also **auto-imports the store listing** from the `fastlane/metadata/android/en-US/` already
in this repo (title, short + full description, changelog) — nothing extra to do there.

## Prerequisites (all on your side)

- A **GitLab account** (this VM is only authed to GitHub; the F-Droid MR is on GitLab).
- `git`, `python3`, JDK 17, the Android SDK (you already have these for Megrim).
- `fdroidserver` for local validation: `python3 -m venv ~/.fdroidvenv && ~/.fdroidvenv/bin/pip install fdroidserver`

## Steps

1. **Fork** `gitlab.com/fdroid/fdroiddata` on GitLab, then clone your fork:
   ```
   git clone https://gitlab.com/<you>/fdroiddata.git && cd fdroiddata
   ```
2. **Copy the recipe** in:
   ```
   cp /path/to/megrim/fdroid/metadata/org.maegley.megrim.yml metadata/
   ```
3. **Normalise + lint** (fix anything it flags):
   ```
   fdroid rewritemeta org.maegley.megrim
   fdroid lint org.maegley.megrim
   ```
4. **Try a build** (heavy — needs the Android SDK; the real build ultimately runs on F-Droid CI):
   ```
   fdroid build -v -l org.maegley.megrim
   ```
   Most Flutter apps need one or two rounds of tweaking the `build:` block here (see Watch-items).
5. **Commit and push** to your fork, then open a **merge request** to `fdroiddata` using the
   "New app" template. F-Droid's CI (`fdroid build` on their buildserver) runs on the MR; iterate
   on the recipe from its logs until it goes green, then a maintainer reviews and merges.
6. After merge, Megrim appears in the F-Droid client within a build cycle, and each future `v*` tag
   is picked up automatically (`AutoUpdateMode`/`UpdateCheckMode` in the recipe).

## Watch-items / likely iteration points

Flutter apps rarely build first-try on F-Droid; these are the spots to expect friction, in rough
order of likelihood:

- **The `build:` block.** The `flutter config / pub get / build apk` sequence may need
  `flutter precache --android` or explicit `PATH`/`--jdk-dir` tweaks depending on the srclib. Adjust
  from the CI log.
- **Bleeding-edge toolchain.** AGP **9.0.1**, Gradle **9.1.0**, Kotlin **2.3.20**, Flutter
  **3.44.1** are all very new; F-Droid's buildserver must supply a compatible JDK/SDK. If the
  buildserver image lags, the build can fail on tool availability rather than on our code.
- **`flutter@3.44.1` srclib.** Confirm the F-Droid `flutter` srclib resolves this tag; if not, it
  may need a `srclibs/flutter.yml` bump in the MR.
- **Debug-signing fallback.** `app/android/app/build.gradle.kts` falls back to debug signing when
  `key.properties` is absent (which it is on F-Droid). F-Droid strips and re-signs, so this is
  normally fine; if the build errors on an already-signed release APK, drop the signingConfig when
  a build env var is set.
- **`UpdateCheckMode: Tags` versionCode detection.** Flutter keeps versionCode in `pubspec`
  (`version: x.y.z+N`), not `build.gradle`. If F-Droid can't extract it for tag auto-detection,
  switch to `AutoUpdateMode: None` and add each `Builds` entry by hand.
- **No screenshots.** Optional but recommended: drop PNGs into
  `fastlane/metadata/android/en-US/images/phoneScreenshots/` in the Megrim repo (captured on the
  emulator) — F-Droid imports them into the listing.

## When to submit — **decided: debut at v1.0.0**

F-Droid will debut Megrim at **v1.0.0**, not v0.1.0. So: **hold the fdroiddata MR** until v1.0.0 is
cut, then bump `versionName` / `versionCode` / `commit` / `CurrentVersion` / `CurrentVersionCode` in
the recipe to the 1.0.0 tag (a one-line-per-field change — the rest is unchanged) and open the MR.

The recipe currently pins **`v0.1.0`** only as a working placeholder so it stays valid/lintable in
the meantime.

## Screenshots — **decided: add them**

F-Droid imports screenshots from `fastlane/metadata/android/en-US/images/phoneScreenshots/` in the
Megrim repo (PNG/JPG, named e.g. `1.png`, `2.png`, …, shown in filename order). Capture them on the
emulator against current `main` (the UI is frozen for v1.0.0, so today's screens are representative).
Recommended set: Log tab, an Event detail with the Medications section, the Analytics tab (stat tiles
+ factor bars + a shaded bar chart), History (List and Calendar), and Settings. See the capture
steps handed off in chat.
