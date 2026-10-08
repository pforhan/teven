# teven_app

Flutter client for the Teven API. Web-first; native packaging is deferred.

Conversion of the React SPA in `../frontend` is tracked in
[`../FLUTTER-CONVERT.md`](../FLUTTER-CONVERT.md). The React app remains the
live application until task 10.3 of that plan.

## Status

**Early scaffolding — not yet a working app.** Running this shows a placeholder
screen. The app is not wired to the API yet, and the React frontend in
`../frontend` remains the live application. See
[`../FLUTTER-CONVERT.md`](../FLUTTER-CONVERT.md) for progress.

## Running locally

```bash
flutter pub get
flutter run -d chrome
```

The web build is served from the same origin as the API, so requests use
relative URLs and no configuration is needed. See `lib/core/config/api_config.dart`.

Note that Docker still builds the React frontend, not this one. Flutter enters
the Docker pipeline in Phase 0, tasks 0.12–0.14.

## Analysis and tests

```bash
flutter analyze
dart format .
flutter test
```

Code generation (`freezed`, `json_serializable`, `riverpod_generator`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Structure

| Path | Purpose |
|---|---|
| `lib/core/config/` | Build-time configuration (`ApiConfig`) |
| `lib/core/theme/` | Theme, carrying over Bootstrap values from the React app |
| `lib/screens/` | Screens |