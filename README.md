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
- **Your data stays yours.** On-device SQLite only; full export/import (JSON + CSV).
- **Free and open source** (GPL-3.0-or-later), built for F-Droid.

> *"Megrim"* is an archaic English word literally meaning *migraine*.

## Status

Pre-release. Implemented against [`docs/SPEC.md`](docs/SPEC.md). See that document for the full
product definition, data model, and build plan.

## Repository layout

```
app/       Flutter application (single codebase, Android target)
docs/      SPEC.md, PRIVACY.md, screenshots
fastlane/  F-Droid / Play listing metadata
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
