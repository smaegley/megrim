<p align="center">
  <img src="app/assets/logo.png" alt="Megrim logo" width="128">
</p>

<h1 align="center">Megrim: Migraine Log</h1>

<p align="center">
  <strong>Offline Migraine Log</strong><br>
  Smart migraine tracking that stays on your device.
</p>

**Megrim** is a privacy-first, offline-first migraine diary for Android. It automatically
enriches each logged migraine with weather, barometric-pressure, and astronomical context —
computed and stored **entirely on your device** — and surfaces personal descriptive analytics
plus odds-ratio "suspected factors" correlations.

- **No accounts, no server, no telemetry.** The app's only network traffic is to
  [Open-Meteo](https://open-meteo.com) to fetch weather for the approximate (~1 km rounded)
  location and date of entries you create.
- **Your data stays yours.** On-device SQLite only; full export/import (JSON + CSV). The
  import format is [documented](docs/IMPORT.md) (with a [JSON Schema](docs/megrim-export.schema.json))
  so you can migrate history in from any other tracker.
- **Free and open source** (GPL-3.0-or-later), built for F-Droid.

> *"Megrim"* is an archaic English word literally meaning *migraine*.

## Status

**`v1.0.0`** — first stable release. App id `org.maegley.megrim`.
Built against [`docs/SPEC.md`](docs/SPEC.md); see that document (§12) for the full product
definition and running implementation status.

`v1.0.0` caps the 0.x series (one-tap logging, offline enrichment, on-device analytics with
suspected-factor correlations, light/dark theme, Medications, tap-to-edit History Calendar,
JSON/CSV export) with an **accessibility pass** (tap-target sizes, WCAG text contrast,
screen-reader labels, verified by automated guideline tests in both themes) and a **fully
documented import format** ([`docs/IMPORT.md`](docs/IMPORT.md) +
[JSON Schema](docs/megrim-export.schema.json)) for migrating history from any other tracker.

**Next milestone:** the F-Droid [`fdroiddata`](https://gitlab.com/fdroid/fdroiddata) MR
(recipe ready in [`fdroid/`](fdroid/)).

## Installing

Megrim is distributed outside the big app stores, in keeping with its privacy-first, FOSS goals.
Pick whichever suits you:

- **Direct APK (available now).** Download the signed `app-release.apk` from the
  [Releases page](https://github.com/smaegley/megrim/releases) and install it. You may need to allow
  installing from your browser/file manager. Releases are signed with the maintainer's key.
- **Obtainium (recommended for auto-updates).** [Obtainium](https://github.com/ImranR98/Obtainium)
  installs and **auto-updates** apps straight from their GitHub releases. Add
  `https://github.com/smaegley/megrim` as an app in Obtainium and it will track new releases for you
  — Play-store-style updates, no account or store required.
- **F-Droid (submission underway).** An [`fdroiddata`](https://gitlab.com/fdroid/fdroiddata) build
  recipe is prepared (see [`fdroid/`](fdroid/)) and targets `v1.0.0`. Once the MR merges,
  Megrim will be installable and auto-updating through the F-Droid client. Note that the F-Droid
  build is signed with F-Droid's key, so it has a different signature than the GitHub-release APK —
  install from one source and stick with it.

There is no Google Play listing (and it isn't required — the options above cover installation and
automatic updates).

## Repository layout

```
app/       Flutter application (single codebase, Android target)
docs/      SPEC.md, PRIVACY.md, screenshots
fastlane/  F-Droid / Play listing metadata
fdroid/    F-Droid build recipe + submission notes
.github/   CI workflow, funding
```

## Building

Requires the Flutter SDK (3.44+) and the Android SDK (API 36).

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Drift code
flutter analyze
flutter test
flutter build apk --release
```

## Privacy

See [`docs/PRIVACY.md`](docs/PRIVACY.md). Short version: all data stays on your device; we operate
no servers and collect nothing.

## Medical disclaimer

Megrim is a personal diary and is **not a medical device**. It does not diagnose, treat, cure, or
prevent any condition. "Suspected factors" are statistical associations in *your own log* —
association is not causation. Always consult a qualified healthcare professional about your
migraines and before making any treatment decisions.

## Contributing

This is a hobby project with no SLA — see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

[GPL-3.0-or-later](LICENSE). Weather data by [Open-Meteo.com](https://open-meteo.com) (CC-BY 4.0).
