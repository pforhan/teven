# teven_app

Flutter client for the Teven API. Web-first; native packaging is deferred.

Conversion of the React SPA in `../frontend` is tracked in
[`../FLUTTER-CONVERT.md`](../FLUTTER-CONVERT.md) — the task checklist — with
progress in [`../FLUTTER-CONVERT-NOTES.md`](../FLUTTER-CONVERT-NOTES.md). The
React app remains the live application until task 10.3 of that plan.

## Status

**In progress.** Auth, the responsive shell, and the customer, inventory, and
organization lists are ported and working against the backend; most routes still
render a placeholder naming the path. The React frontend in `../frontend`
remains the live application. See [`../FLUTTER-CONVERT.md`](../FLUTTER-CONVERT.md)
for the task list and [`../FLUTTER-CONVERT-DESIGN.md`](../FLUTTER-CONVERT-DESIGN.md)
for the parity matrix.

## Running locally

From the repo root, use the task runner — it handles the prebuild and the
origins:

```bash
../teven up        # build the bundle, then serve from the real backend
../teven dev       # hot reload, against a backend you already started
../teven verify    # analyze, format-check, test
```

By hand, if you need to:

```bash
flutter pub get
dart run build_runner build   # required after every clone; see below
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:2022
```

**Both flags on that last line are load-bearing.** Without
`API_BASE_URL` the app uses relative URLs, which resolve against whatever origin
served the page — against the Flutter dev server that means `/api` returns a 404
rather than reaching the backend. Without a fixed `--web-port` the dev server
picks a random port that the backend's CORS allow-list cannot name.
`../teven dev` sets both.

**`build_runner` is a required setup step.** Generated files (`*.freezed.dart`,
`*.g.dart`) are gitignored, so they are absent from a fresh clone. Until
`build_runner` has run, `flutter analyze` reports unresolved constructors and
`flutter run` will not compile — every model class redirects to a constructor
that exists only in generated code.

Re-run it after changing anything in `lib/models/`, or after pulling commits
that add or modify a model.

**In production, no configuration is needed.** The web build is served from the
same origin as the API, so requests use relative URLs. The `--dart-define` above
is only needed because the Flutter *dev server* is a different origin from the
backend. See `lib/core/config/api_config.dart`.

## Building for Docker

**The Docker image does not build this app.** It copies a bundle you build
first. This is deliberate — Flutter publishes no `linux/arm64` SDK, so an
in-container build means emulating amd64 (a ~1.5 GB SDK download plus a slow
emulated compile). See task 0.12 in [`../FLUTTER-CONVERT.md`](../FLUTTER-CONVERT.md).

**Prefer the wrapper.** `./teven up` from the repo root builds the bundle and
then packages it, so the prebuild step can't be forgotten:

```bash
./teven up          # build Flutter, then start the stack
./teven up -f       # same, but stream logs in the foreground
./teven up-react    # start with the React frontend (builds inside Docker)
```

The build fails loudly if the prebuilt bundle is missing, rather than silently
producing an image that serves nothing. The trade-off is the reverse hazard: the
image can contain a **stale** bundle if you skip the rebuild after changing code.
`./teven up` prevents that by always rebuilding first.

`WEB_SOURCE` defaults to `react`, which builds the React app in `../frontend`
inside Docker and needs no prebuild step.

## Flutter version

Pinned to **3.47.2** locally. `environment: sdk: ^3.13.2` in `pubspec.yaml` is
a *Dart* constraint; the Flutter version is recorded only by your local install,
so keep the two in step when upgrading.

## Analysis and tests

```bash
flutter analyze
dart format .
flutter test
```

Or run `./teven verify` from the repo root to do all three.

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