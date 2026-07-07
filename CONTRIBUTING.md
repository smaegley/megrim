# Contributing to Megrim

Thanks for your interest. A few expectations up front:

- **This is a hobby project.** There is no service-level agreement, no guaranteed response time,
  and no roadmap commitment. Issues and PRs are read when time allows.
- **Privacy is the whole point.** Any change that adds a network call to a host other than
  Open-Meteo, adds analytics/telemetry/crash reporting, or pulls in a Google Play Services /
  Firebase dependency will be rejected. CI enforces the dependency ban.
- **Scope.** See `docs/SPEC.md` §1.3 for explicit non-goals (no cloud sync, no accounts, no
  prediction claims, etc.). Please open an issue before building a large feature.

## Development

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze          # must be clean
flutter test             # must pass; no network in tests
```

## Commit conventions

Small commits with a type prefix: `feat:`, `fix:`, `test:`, `docs:`, `chore:`, `spec:`.

## Code of conduct

Be decent. Harassment or abuse gets you blocked.
