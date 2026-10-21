# Flutter Conversion — Implementation Notes

The progress log for the Flutter port: what was built, the decisions taken along the way, the deviations from the plan, and the things that were verified rather than assumed.

- **The checklist is [`FLUTTER-CONVERT.md`](FLUTTER-CONVERT.md)** — the ground rules and every task, with its checkbox.
- **Planning and design is [`FLUTTER-CONVERT-DESIGN.md`](FLUTTER-CONVERT-DESIGN.md)** — the resolved decisions, the parity matrix, and the survey of backend discrepancies.

Append a dated entry per completed phase. Record measured bundle sizes, known limitations, and deviations from the plan.

Entries are in chronological order. Phase 2's entry was written without a date, so it sits where it was written — between the 2026-10-09 Phase 1 entries and the 2026-10-13 Phase 3 entry.

References here to "the discrepancy table" mean the one in `FLUTTER-CONVERT-DESIGN.md`.

---

### 2026-10-05 — Phase 0, tasks 0.1–0.8

**Done.** `flutter_app/` created with `--platforms=web`. `flutter analyze` clean, `dart format` clean, the scaffold widget test passes.

**Deviation — task 0.4.** `custom_lint` + `riverpod_lint` **could not be installed**. Pub's solver fails: `json_serializable` pins `json_annotation` to a range that conflicts with `riverpod_lint`'s `analyzer` requirement, and the resolution bottoms out at `_macros from sdk doesn't exist`. This is a dependency-graph conflict between generator packages, not a version-pinning mistake on our side. Dropped both; `riverpod_generator` still works, so code generation is unaffected. Revisit only if generator-specific lints turn out to matter.

**Chosen versions** (Flutter 3.47.2 / Dart 3.13.2): `flutter_riverpod` 3.4.3, `dio` 5.11.1, `go_router` 18.0.2, `flutter_secure_storage` 11.2.0, `shared_preferences` 2.5.5, `intl` 0.20.3, `table_calendar` 3.3.0, `freezed` 4.0.2.

**Early note on theme.** `lib/core/theme/teven_theme.dart` already carries over the Bootstrap values (`#f8f9fa` surface, `#3174ad` primary, `#e7f0f7` today-highlight) so screens land visually close during the port. Task 3.10 replaces this with a full `ColorScheme`.

**Pre-existing issue, unrelated to this work.** `frontend/node_modules` was installed on Linux — `@rollup` contains only `rollup-linux-x64-*` binaries, and the `.bin` shims are plain files rather than symlinks. Consequence on this macOS box: `npm run build --prefix frontend` fails at the Vite step with `MODULE_NOT_FOUND`. **TypeScript type-checking still passes** (`tsc -b` exits 0), so type safety is verifiable. Fix is `npm install --prefix frontend` on macOS to fetch the darwin binaries. No Flutter task depends on it, but the ground rule "repo stays buildable" cannot be fully confirmed for React until it's re-installed.

**Bundle size (partial, task 0.11).** `flutter build web --release --no-web-resources-cdn` produces **41 MB**: `canvaskit/` 36 MB, `main.dart.js` 1.8 MB, `assets/` 1.5 MB, icons 808 KB, favicon 388 KB. React baseline was 596 KB JS + 246 KB CSS. CanvasKit is ~87% of the total and is fetched separately from app code; it also includes `.symbols` files that need not ship. `--no-web-resources-cdn` confirmed working — `canvaskit/` is written locally and `index.html` contains **zero** gstatic/googleapis references. Two follow-ups for 0.11: drop the 388 KB favicon duplication (the same `teven.png` is currently used for favicon, Icon-192, and Icon-512 rather than real resized icons) and decide whether to strip `.symbols` from the shipped image.

**Distribution ID.** Set to `alphainterplanetary.teven`, matching the backend's Kotlin root package. On web this is `web/manifest.json` `"id"` — `flutter build web` exposes no `--application-id` flag. The Dart package name remains `teven_app`, which is a source identifier rather than a distribution one. Phase 11.1 reuses the same value for native `applicationId` / bundle id.

### 2026-10-08 — Phase 0, tasks 0.9–0.11

**Done.** Path URL strategy installed, self-hosted CanvasKit verified over plain HTTP, bundle measured. See the table below for 0.11 numbers.

**Task 0.9 — ordering constraint, load-bearing for Phase 2.** `usePathUrlStrategy()` must be called **before** the `GoRouter` instance is *constructed*, not merely before `runApp`. `configureUrlStrategy()` runs first in `main()`, which is what makes this hold. Verified by building the same probe both ways, starting at `/register?token=abc123` and navigating to `/login`:

| Call order | Resulting browser URL |
|---|---|
| strategy **before** router construction | `pathname=/register`, `hash=` **(empty)** — path strategy in effect |
| strategy **after** router construction | `pathname=/register`, `hash=#/register?token=abc123` — **fell back to the hash strategy** |

`go_router` captures the URL strategy at construction time. Phase 2 must therefore not hoist the router to a top-level `final` that initializes before `main()` runs, and must not construct it lazily in a `ProviderScope` that could race `main()`.

Wrapped in a conditional import (`lib/core/config/url_strategy.dart` + `_stub`/`_web`) rather than importing `flutter_web_plugins` directly, so adding native platforms in Phase 11 is not a compile error. `flutter_web_plugins` is now declared as an SDK dependency in `pubspec.yaml`.

**Verified that `?token=` survives.** This is the actual premise of task 0.9, so it was tested rather than assumed: loading `/register?token=abc123` with the path strategy installed yields `pathname=/register` and `search=?token=abc123`, and the app boots. Invite links (tasks 2.10, 5.10) depend on this.

**Open question, flagged for Phase 2 — not a claim of correctness.** In the headless harness the in-app route reached `/login` while the address bar stayed at `/register`, in *both* configurations. The distinction between "strategy before" and "strategy after" showed up only in the hash, never as a synchronized path update. This is most likely an artifact of headless Chromium under `--virtual-time-budget` (timers advance without real frames, and go_router's history write may never be flushed), but it was **not** confirmed either way. Before relying on path URLs in production, re-verify in a real browser: navigate between two routes and confirm the address bar follows. Task 2.6 is the natural place, since it is the first phase that ships real navigation.

**Task 0.10 — verified.** Built with `--no-web-resources-cdn` and served from `build/web` over plain HTTP on `localhost`, including a deep path (`/register?token=abc123`) served through an SPA fallback that mimics Ktor's `staticResources("/", "static") { default("index.html") }`. Renders correctly (verified via headless-browser screenshot, not just an HTTP 200).

`index.html` contains no third-party references. Two gstatic/googleapis strings remain in the bundle but are **inert**: `flutter_bootstrap.js` holds `https://www.gstatic.com/flutter-canvaskit` behind a `useLocalCanvasKit` check, and `main.dart.js` holds `https://fonts.gstatic.com/s/` behind a `fontFallbackBaseUrl` null check. Confirmed empirically — a real page load requested **zero** third-party origins. Everything came from localhost.

**Task 0.11 — bundle size.** Two numbers matter, and conflating them is misleading.

| | raw | gzipped |
|---|---|---|
| **React** `frontend/dist` (total) | 1.2 MB | 593 KB |
| **Flutter** `build/web` (total on disk) | 40 MB | 13 MB |
| **Flutter** first-load transfer | 7.3 MB | **2.6 MB** |

The 40 MB on disk is **not** what a user downloads. It includes 6.1 MB of `.symbols` files and five CanvasKit builds (`chromium/`, `wimp`, `skwasm`, `skwasm_heavy`, `webparagraph/`) of which the browser fetches exactly one. Verified against actual HTTP request logs for a page load: **11 files requested**, `.symbols` never among them. First-load transfer is **7.3 MB raw / 2.6 MB gzipped**.

Breakdown of the 2.6 MB gzipped first load: `canvaskit.wasm` 2.0 MB, `main.dart.js` 540 KB, `canvaskit.js` 27 KB, fonts 47 KB, rest negligible.

**Regression vs React, stated plainly.** React's first load is **593 KB gzipped**; Flutter's is **2.6 MB gzipped** — roughly **4.5×**, or +2.0 MB. This is the expected regression and it is CanvasKit, not app code: `main.dart.js` at 540 KB gzipped is comparable to React's 178 KB JS + 33 KB CSS = 211 KB, and will grow with the ported screens. Note the React figure is flattered by `teven.png` (388 KB) shipping at 396 KB gzipped; excluding that favicon, React is ~206 KB gzipped.

**Resolving the two follow-ups the earlier log flagged.** One done, one deliberately deferred:

- **Icons — done.** `Icon-192.png` and `Icon-512.png` were byte-identical 397 KB copies of the 746×693 source, as was `favicon.png` — 1.58 MB of the same image four times. Regenerated as real square icons (192, 512, plus maskable variants with the logo inside the 80% safe zone, and a 32 px favicon). `web/icons/` went 1.58 MB → 388 KB.
- **`.symbols` — investigated, not removed.** Confirmed never fetched at runtime: absent from the page-load request log, and no runtime reference to `.symbols` exists anywhere in the build (grepped). They exist for DevTools stack-trace symbolication. Removing them trades production debuggability for image size, which is a judgment call rather than a cleanup — deferred to 0.12, where the image size actually matters and the choice becomes concrete. Stripping is a one-line `rm` if taken.

**Note for 0.12.** The Flutter build output is 40 MB on disk versus React's 1.2 MB. Since `Dockerfile:61` bundles this into the backend jar, expect a substantially larger image. Stripping `canvaskit/*.symbols` and the four unused CanvasKit variants at build time would cut roughly 30 MB, but that trades away production debuggability — decide deliberately rather than by default.

**Unverified.** No Chrome/Chromium browser is installed on this machine; rendering was confirmed with Brave (Chromium-based) in headless mode. `flutter run -d chrome` was not exercised, since the exit criterion for it is task 0.14's territory.

### 2026-10-08 — Phase 0, tasks 0.12, 0.13, 0.15 (0.14 partial)

**Task 0.12 — deviation: the Flutter SDK does not run in Docker at all.** The task specified an official `ghcr.io/cirruslabs/flutter` image. Two independent blockers make that impossible, both verified rather than assumed:

1. **No image is new enough.** The registry's newest tag is **3.44.0** (Dart 3.12.0); `flutter_app` requires **Dart ^3.13.2**, and `freezed` 4.0.2 requires **>=3.13.0**. Running `flutter pub get` inside the image:

```
The current Dart SDK version is 3.12.0.
Because teven_app requires SDK version ^3.13.2, version solving failed.
```

Downgrading the app to fit the image was rejected: relaxing the SDK floor to 3.12 then fails on `freezed` (needs >=3.13.0), and dropping to `freezed` 3.x fails again on an `analyzer`/`meta` conflict with `build_runner`. The app's toolchain and the local toolchain are the same version by design; the image is what had to give.

2. **No native `linux/arm64` SDK exists at all.** Not just for 3.47.2 — the arm64 tarball URL 404s for 3.47.2, 3.44.0, 3.38.0 and 3.27.0. Flutter ships Linux SDKs for x86_64 only. So there is no combination that is both current and native on Apple Silicon.

**Resolution: the Flutter SDK does not run in Docker.** The Flutter stage no longer installs an SDK or compiles anything. It copies a bundle built on the host:

```bash
(cd flutter_app && flutter build web --release --no-web-resources-cdn)
WEB_SOURCE=flutter docker compose up --build
```

Measured effect: the `flutter` variant went from **~30 min** (1.5 GB SDK download plus an emulated dart2js under QEMU) to **1.2 seconds**.

**The trade-off, stated plainly.** The image is no longer self-contained — the Docker build cannot produce the bundle by itself, and a stale bundle is now possible: change code, run `docker compose up --build` without rebuilding, and the image ships the old bundle. Mitigated on both sides:

- **Missing bundle fails loudly.** The stage asserts `index.html`, `main.dart.js` and `flutter_bootstrap.js` are present, because Docker will happily copy a nonexistent source directory as an empty one and produce an image whose backend serves nothing. Verified that the assertion fails the build when `main.dart.js` is removed.
- **Stale bundle is prevented by the `./teven` script.** `up` always rebuilds before packaging, so the two-step cannot be forgotten. `set -euo pipefail` means a failed Flutter build aborts before Docker runs.

**Tooling choice: a shell script, not Gradle or Make.** Wrapping the workflow was considered against Gradle and Make. Gradle was rejected: `generateApiDocs` in the root `build.gradle.kts` is a real precedent for non-JVM work, but it is not an equivalent one — it consumes Gradle's own task output and stays inside the build graph, whereas these commands shell out to Docker and Flutter, where Gradle's up-to-date checks and configuration cache do not apply and where `flutter run` (a long-running interactive process) does not fit the task model at all. Gradle would also add 1–3s of daemon startup to commands that are otherwise instant. Make was viable but macOS ships GNU Make 3.81 (2006), which constrained the target syntax for no benefit over a plain script. `./teven` is a dependency-free bash script.

**Dead ends, so they are not retried.** In-container SDK install via the official tarball was implemented and worked, but is strictly worse than the host build; it also needed `git config --global --add safe.directory /opt/flutter` (the tarball carries a foreign uid, so git refuses it as "dubious ownership" and `flutter pub get` exits 128) and `FROM --platform=linux/amd64` (an arm64 container has no amd64 loader, so the x86_64 `dart` binary dies with `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2`). Those fixes are recorded here because the emulation path may become the right one if Flutter ever publishes an arm64 SDK.

**Also added: `.dockerignore`.** The repo had none, so the build context was **589 MB** — `frontend/node_modules` (228 MB) and `flutter_app/.dart_tool` (89 MB) included. Now **41.7 MB**, with `flutter_app/build/web` explicitly re-included since the Flutter stage needs it. Verified the bundle still arrives intact (40 MB) and that the react variant is unaffected.

**Flutter version pinning.** There is no longer a `FLUTTER_VERSION` build arg — the version lives only in the local toolchain. `environment: sdk: ^3.13.2` in `pubspec.yaml` is a *Dart* constraint and contains no Flutter version, so nothing in the repo records which Flutter is expected. That is a real gap: nothing enforces that the local Flutter satisfies the Dart constraint. Worth a `tool/` check script at some point; for now it is noted in `flutter_app/README.md`.

**Task 0.13 — `ARG WEB_SOURCE`.** Both pipelines stay buildable. The two builder stages are named `frontend-react` and `frontend-flutter`, each normalizing its output to `/web-dist`, and a selector stage picks between them:

```dockerfile
FROM frontend-${WEB_SOURCE} AS web-assets
```

Docker only substitutes build args into `FROM` when they are in the **global** scope, so `ARG WEB_SOURCE` is declared before the first `FROM` — declaring it inline at the selector fails with `UndefinedArgInFrom`. Because Docker skips unreferenced stages, the unselected pipeline is never built at all. Verified: the `react` build contains zero Flutter steps and produces the correct `dist`. Selectable via `WEB_SOURCE=flutter docker compose up --build`, wired through `docker-compose.yml`.

**Task 0.15 — premise did not hold; no work needed.** The task assumed Flutter registers a service worker that "caches aggressively, which serves stale bundles after a rebuild". On 3.47.2 it does not. The generated `flutter_service_worker.js` is a **784-byte stub that unregisters itself** on activate. There is no cache, and nothing to version.

Confirmed against the SDK source rather than by inspection alone: `--pwa-strategy` is marked `hide: true` and *"deprecated and will be removed in a future Flutter release"*, and the only remaining template (`flutter_tools/.../js/flutter_service_worker.js`) is the unregistering stub — no `RESOURCES` map or `caches.open` call exists anywhere in `flutter_tools/lib/src`. Building with `--pwa-strategy=none` produces a **0-byte** worker.

So the stale-bundle failure mode this task was written to prevent does not exist on the current toolchain. Flagging rather than inventing a cache name for a worker that caches nothing. **If a caching worker is ever reintroduced upstream, revisit this** — the mitigation would be a cache name derived from the build version.

**Task 0.14 — verified.** `WEB_SOURCE=flutter docker compose up --build` serves the Flutter app from Ktor on `localhost:2022`. Confirmed independently of the browser, by fetching from the running container:

| Check | Result |
|---|---|
| `GET /` | 200, serves `flutter_bootstrap.js` + `<base href="/">` + `manifest.json` — Flutter's `index.html`, not React's |
| `flutter_bootstrap.js`, `main.dart.js` | 200 `text/javascript` |
| `manifest.json` | 200 `application/json` |
| `canvaskit/chromium/canvaskit.wasm` | 200 `application/wasm` (correct MIME, so streaming compilation works) |
| `favicon.png` | 200 `image/png` |
| `/register?token=abc123` | 200 — SPA fallback works, `?token=` preserved through the deep path |
| `/events` | 200 — same |
| `GET /api/nonexistent` | **404 JSON envelope**, not `index.html` |

That last row is the one worth keeping. It confirms API routes still win over the SPA catch-all, which is the condition task 1.12 depends on — if unmatched API paths returned `index.html` with HTTP 200, the defensive content-type sniffing planned for 1.12 would be load-bearing rather than belt-and-braces. Currently `Routing.kt:40-53` handles it correctly for GET/POST/PUT/DELETE.

Both build variants confirmed earlier: `react` yields `assets/index.html/teven.png` (1.2 MB), `flutter` yields `main.dart.js` + `canvaskit/` + `manifest.json` (40 MB), and the selector never builds the unselected pipeline.

**Pre-existing local issue, unrelated to the conversion.** The first `docker compose up --build` failed with exit 126 at `./gradlew --status`: `gradlew` had lost its executable bit in the working tree, and `COPY` preserves that mode. Git records the file as `100755`, so the committed state is correct and a fresh clone is unaffected. Fixed with `chmod +x gradlew`. Worth noting this repo has `core.fileMode=false`, so git cannot warn about a lost exec bit — `git config core.fileMode true` would surface it.
### 2026-10-09 — Phase 1, tasks 1.1–1.8 (data layer)

**Done.** All eleven model files ported to `freezed` + `json_serializable`; `build_runner` clean; `flutter analyze` clean; `dart format` clean; `flutter build web --release` succeeds.

**Task grouping.** These nine tasks went in as one commit, deviating from one-task-per-commit. 1.8 ("port all model classes to freezed") applies to everything 1.1–1.7 define, so splitting them would mean generating twice and would leave the intermediate commits in a state where the model layer was half-converted between `json_serializable` styles.

**The envelope is the load-bearing decision.** `ApiResponse<T>.fromJson` takes a `T Function(Object?)` decode callback and invokes it **only when `success` is true**. A generated `fromJson` would attempt to decode `data` on every response — and since `failure()` sets `data = Unit`, every error body carries `data: {}`, not `null`. Decoding `{}` into `List<EventResponse>` throws, and the throw destroys the error message the caller needs to show. Verified directly: a failure envelope decodes with `data == null`, `error` intact, and the decode callback provably never invoked. Task 1.10 depends on this shape.

**Not ported, deliberately.** `RegisterRequest` (`types/auth.ts:3`) — the endpoint it targets, `POST /api/users/register`, does not exist; already on the discrepancy table. `UserDetailsResponse` — a near-duplicate of `UserResponse` missing `organization`, used only by the profile screens; folding it into `UserResponse` would have been a behaviour change, so task 5.6 re-decides. `VirtualEvent` / `CalendarEvent` — client-only calendar view types with no server counterpart; they belong to Phase 7's `table_calendar` port, not the data layer. `StatusResponse` is kept but is close to vestigial: deletes return `204 No Content` with an empty body, not `{status, message}`.

**Fixed a Phase 0 mistake.** `freezed_annotation` was listed under `dev_dependencies` in task 0.4, but it is imported by `lib/` code and referenced by every generated `.freezed.dart`. It only surfaced once models existed, as ten `depend_on_referenced_packages` lint hits. Moved to `dependencies`. The bug was only possible because no `lib/` file imported it before now.

**freezed 4.0 gotcha.** Classes with getters need an explicit private constructor (`const EventResponse._();`), or the generator fails with "Getters require a MyClass._() constructor". This is why `EventResponse.startAt`/`endAt` exist as methods rather than a `VirtualEvent` wrapper type.

**Fields the React types omit, included here.** Modelled from the Kotlin DTOs rather than from `src/types/*`, since the server is the source of truth for the wire format and dropping these would lose data silently:

| Field | On the wire | In the React type |
|---|---|---|
| `latitude` / `longitude` / `formattedAddress` on customer + event | yes | **no** |
| `displayName` on `StaffHoursReportResponse` | yes | **no** |
| `latitude` / `longitude` / `formattedAddress` on create/update requests | yes | **no** |

The geo fields are always null in practice — the backend's geo service is dead code — but task 6.4 (auto-fill event location from a customer's address) will want them present rather than absent.

**`eventId` is `int`, not `int | String`.** `types/events.ts:38` declares `number | string`. The server type is `Int` (`EventResponse.kt:9`), so the union is a workaround for something that does not occur. Modelled as `int`.

**Timezone handling.** `date` and `time` stay `String` (`"YYYY-MM-DD"`, `"HH:MM:SS"`). `EventResponse.startAt` builds a `DateTime` from components explicitly instead of the React app's `DateTime.parse(event.date + 'T' + event.time)` (`EventCalendar.tsx:230`) — that expression silently depends on `DateTime.parse` treating a zone-less string as local. Component-wise construction keeps naive-local semantics (task 7.9) but makes the assumption visible and fails loudly on malformed input. Verified: `"2026-03-04"` + `"09:30:00"` + 90 min yields `2026-03-04 09:30` → `11:00` local, no UTC shift.

**OR-semantics for permissions** are captured now, in `Permissions.hasAny`, because 1.3 was the natural place and 2.5 depends on it: an empty list grants access (reproducing `ProtectedRoute.tsx:20`), and multiple permissions are `.any()` (`ProtectedRoute.tsx:22-25`). `UserContextResponse.permissions` stays `List<String>` rather than `List<Permission>` so an unrecognized permission from a newer server does not fail the whole context fetch.

**One correction to the plan's own assumptions.** The plan's task 2.11 implies `/api/invitations/accept` returns a non-enveloped `{success, message}`. It does not — the route wraps the service result in `success(...)` (`InvitationRoutes.kt:62`). The two `success` fields are distinct: the service's own flag is converted into an envelope-level `failure(...)` with HTTP 400 (`InvitationRoutes.kt:64`), so a client never sees `success: false` from the DTO, only the message. Task 2.11's `AlreadyLoggedInError` comes from a separate earlier branch (`InvitationRoutes.kt:49`). Corrected in the model doc comment; the task itself is unaffected.

**Verification.** Behaviour checked with a temporary probe covering: failure envelope with `data: {}` (decode provably not invoked), success envelope, list decoding into `EventResponse`, `PaginatedResponse` with nested items, and the naive-local `startAt`/`endAt` arithmetic. All five passed. **Superseded by task 1.19**, which landed the same five cases as a permanent test file.

**Generated files are gitignored — decided, not open.** `*.freezed.dart` and `*.g.dart` are ignored in `flutter_app/.gitignore`, grouped with Flutter's own template rules. This is a departure from the freezed default of committing generated output.

The tradeoff is a real cost, not a free win: **a fresh clone does not compile until `dart run build_runner build` has run.** Verified by reconstructing a clean tree — 11 model sources, no generated files — and confirming `flutter analyze` reports 101 errors before codegen and is clean after (30 outputs, 21s).

The alternative — committing the 11 generated files — would keep a fresh clone buildable with no extra step, at the cost of ~2000 lines of generated code in every diff. Chosen against that because the diff noise compounds as the port adds ~40 more model classes through Phases 4–8, and because `build_runner` is a single command. Reverting is a two-line `.gitignore` change plus a re-commit of the generated files if the noise proves worse than the setup step.

Consequences to remember:
- `./teven up` already runs `flutter build web`, which runs codegen implicitly, so the Docker path is unaffected.
- Any command in a fresh clone — `flutter analyze`, `flutter run`, `flutter build web`, `flutter test` — needs codegen first. Documented in `flutter_app/README.md` under "Running locally".
- `*.g.dart` is unanchored, so it matches at any depth within `flutter_app/`. Confined in practice: all 20 currently-matching files are under `flutter_app/lib/models/`. Worth remembering if a `.g.dart` ever shows up elsewhere for an unrelated reason.

**These rules live in `flutter_app/.gitignore`, not the repo root.** Consolidation was considered and rejected. The reason is that Flutter's own entries are **root-anchored** — `/build/`, `/coverage/`, `/android/app/debug` — and that anchoring is relative to whichever `.gitignore` declares it. Moved to the repo root, `/build/` would start matching `backend/build/` and the top-level `build/`, and `/android/app/debug` would match a root-level `android/` that does not exist, never `flutter_app/android/app/debug`. Each would need hand-rewriting as `flutter_app/…` — the kind of quiet breakage that surfaces later rather than at the change. The two codegen rules need no such prefix, so placing them at root bought nothing and splitting them was dropped.

**`flutter create` does not manage `.gitignore` on an existing project — verified, not assumed.** Phase 11.1 runs `flutter create --platforms=android,ios .`, which raised the question of whether Flutter would clobber local edits. Three cases tested against a scratch project:

| Action, then re-run `flutter create` | Result |
|---|---|
| Append a custom rule | Rule **survived** |
| Replace the file with `only-this` | **Not restored** — file left alone |
| Reduce the file to 3 lines | Still 3 lines |

So the file is only written when creating into an empty or non-Dart directory. Custom rules are safe, and nothing will be restored or removed underneath us when platforms are added in Phase 11.

### 2026-10-09 — Phase 1, tasks 1.9–1.13 (HTTP layer)

**Done.** `ApiException` hierarchy, `ApiClient` on dio, and `TokenStore`. `flutter analyze` clean, `dart format` clean, web build succeeds.

**Two bugs found by running the client against a real HTTP server, not by reading it.** Both were in the same family — "a body that is not the envelope" — and neither was visible from the source alone.

1. **`index.html` with HTTP 200 was parsed as a successful bare-string response** (task 1.12's exact scenario). `_tryDecode` caught the `FormatException` from `jsonDecode` and returned the raw text, which then sailed through the bare-string branch and reached `decode()`. A request to a nonexistent route would have "succeeded" with a web page in hand. Fixed by sniffing `content-type` before decoding and tagging non-JSON bodies in a private `_NonJsonBody` wrapper, so they cannot be confused with the genuine bare strings `AuthorizationPlugin.kt` returns.

2. **A bare JSON string was decoded twice.** Ktor's `ContentNegotiation` serializes `AuthorizationPlugin.kt`'s `"User does not have the required permission"` as a JSON string — quoted, `application/json`. dio parses JSON bodies by default, so that arrived as a Dart `String`; the code then called `jsonDecode` on it *again*, which fails, and it got misclassified as non-JSON. Fixed with `responseType: ResponseType.plain`, so dio never decodes and this class owns all parsing.

Bug 2 is the more interesting one, because the ambiguity is **not resolvable from the value**: a JSON string body and raw non-JSON text both arrive as `String`, so no amount of inspection of the decoded value can tell them apart. The only sound fix is to prevent the double decode rather than detect it after the fact. Worth remembering for any later client code.

**Verified against an `HttpServer` serving the backend's real response shapes**, not mocks: normal envelope, `failure()` envelope with `data: {}` (message and details both survive), 401 inside an envelope, 403 bare string, `index.html` at 200, 204 with no body, 2xx bare-string acknowledgement, and connection-refused. All 8 passed. **Superseded by task 1.19**, which kept this as `test/api_client_test.dart` and added the malformed-JSON case.

**`validateStatus` is set per-request, not only on `BaseOptions`.** Caught by the probe: an injected `Dio` with default options rejects 4xx before any of our handling runs, so a 400 became `NetworkException` instead of a message-carrying `ApiRequestException`. `_send` now also inspects `DioException.response` defensively, so even a caller-supplied stricter `Dio` still yields the server's message.

**Exception hierarchy.** `sealed class ApiException` with `UnauthorizedException`, `ApiRequestException`, and `NetworkException` — sealed so a `switch` over the three is exhaustive, which is what lets task 9.8's error boundary handle every case without a default arm. `NetworkException` is split out from `ApiRequestException` because retrying is plausible there and the user-facing message differs ("could not reach the server" vs "the server rejected this"). `UnauthorizedException` is produced from 401 **whether or not** the body is an envelope, so task 2.2's single-flight redirect has one type to match on regardless of which path 401 arrived by.

**`ApiRequestException` covers both 4xx-with-envelope and 2xx-with-`success: false`.** The React client treats these in one place (`apiClient.ts:19-38` handles non-ok, then again at `:57`), so one Dart type matches; the message is what differs, not the handling.

**Token storage: two claims from an earlier draft of this log were wrong, corrected after reading the package source.**

1. **The token does *not* carry over from the React app.** An earlier note here claimed preserving `TOKEN_KEY` meant "a redeploy mid-migration does not sign everyone out". False. The web backend namespaces keys as `publicKey.<key>` and stores **AES-GCM ciphertext** (`flutter_secure_storage_web-2.1.1/lib/flutter_secure_storage_web.dart:50`), where the React app wrote plaintext under a bare key. Different key *and* different encoding — the old token is unreadable.

   **This has no practical consequence: the app has no users yet**, so there are no React sessions to preserve and nobody to ask to log in again. Worth recording only so nobody later assumes a session carries over, or spends effort trying to make it.

2. **Writes throw; only reads degrade.** `isSecureContext` is evaluated on *every* operation, not once at init, and throws `UnsupportedError` when false (`flutter_secure_storage_web.dart:26`). So `TokenStore.read` catches and returns `null` — a boot-time read failure degrades to "logged out" instead of crashing before a login screen renders. But `write` deliberately propagates: a login must not report success if the token was not persisted. `clear` swallows, since failing to clear should not block reaching the login screen.

The practical consequence is sharper than `FLUTTER-CONVERT-DESIGN.md`'s "The one deployment consideration" states. The plan says the gap is that secure storage *"does not work"* off-localhost; in fact it means **login breaks outright** over plain HTTP on port 2022 — reads quietly return no token, writes throw. Not a silent degradation, a visible failure. Still a deployment concern, still deferred, but worth knowing that task 1.13's comment should say "login fails" rather than "guarantees do not hold".

**Inventory of non-conforming responses, for tasks 10.9/10.10.** Counted from source rather than estimated, since these tasks are only worth doing if the scope is known:

- **Error responses bypassing the envelope: 2 sites.** `AuthorizationPlugin.kt:24,31` only. A two-line fix — the entirety of 10.9.
- **Success responses with bare-string `data`: 11 sites.** 5 × `success("... with ID N updated")` (customer, inventory, organization, event, role), 4 × `success("OK")` (role ×2, inventory, event), 1 × `success("Created invitation")`. Wider than the plan implied — task 1.11 described this as an `AuthorizationPlugin` problem, but that is only the error case; these successes are the ones forcing `ResponseBody.bareString` and `ApiClient.deleteWithBody` to exist.
- **`204 NoContent` with no envelope: 5 sites.** One per deletable resource. This is why `StatusResponse` is near-vestigial — the React types declared it but the server never sent it.

The three are genuinely different problems: 10.9 is a two-line consistency fix, 10.10 is an API-design decision with three reasonable answers and no obviously correct one. Splitting them was worth it precisely because lumping them together would have made the cheap fix wait on the expensive one.

**Not yet wired.** Nothing constructs `ApiClient` — `main.dart` still shows the placeholder `HomeScreen`. Services (1.14–1.17) are what give it callers, and Riverpod wiring belongs with them. `ResponseBody` is declared on `ApiClient` but currently unused by any caller; it documents the four response shapes and is the natural home for a per-endpoint override once 1.16 hits `PUT /api/events/{id}` and its bare-string `data`.

### 2026-10-09 — Phase 1, tasks 1.14–1.18 (service layer)

**Done.** `AuthService`, `UserService`, `OrganizationService`, `CustomerService`, `InventoryService`, `EventService`, `InvitationService`, `ReportService`, `RoleService`, plus a shared `ListQuery`/`SortOrder`. Analyze and format clean, web build succeeds. This is the block that finally gives `ApiClient` callers, so it was checked hard against the backend source rather than the React client.

**Three React-called endpoints do not exist server-side.** Each was found by grepping the route definitions, not by reading the plan:

| React call | Status |
|---|---|
| `DELETE /api/users/{id}` (`UserService.ts:36`) | `UserRoutes.kt` defines **no `delete` route** — 404s at the `/api` catch-all |
| `POST /api/events/{id}/join` (`EventService.ts:56`) | **No `join` route** in `EventRoutes.kt` |
| `UserService.getUserDetails` / `updateUserDetails` | Exist, but as `GET`/`PUT /api/users/{id}` — folded into [AuthService] |

Both missing methods are **omitted rather than stubbed**. A stub returning empty data would compile, pass review, and fail silently at runtime; an absent method is a compile error at the point someone ports `UserList`'s delete button (`UserList.tsx:81`) or `EventService.joinEvent`. Task 4.8 covers the UI side. Whether to *add* the endpoints or *drop* the buttons is a product decision, not a porting one.

**Task 1.18 is more load-bearing than the task description implies.** The stated reason was payload size, which is true — but the mechanism is worse than "large responses". Every DAO does `limit?.let { query.limit(it) }` (`CustomerDao.kt:73`, `EventDao.kt:180`, +3), so **omitting `limit` applies no cap at all** and returns the entire matching table. The `limit: 0` in the response is cosmetic and does *not* mean zero rows. So `getAllEvents` merges `defaultLimit = 10` over whatever the caller passed, and a caller cannot accidentally request everything by forgetting a parameter. Verified: unspecified → `limit=10`; explicit 25 → `limit=25`; non-event lists send no limit, preserving React behaviour.

**`sortBy` on events is forwarded but useless.** `EventRoutes.kt` accepts the parameter and `EventDao` never reads it — always orders by date. The service forwards it (so the URL stays honest) and the doc comment says not to depend on it. Note `sortOrder` *does* work and **defaults to `asc`**, so the first event returned is the earliest, not the most recent.

**Three update methods return `String`, not a model.** `updateCustomer`, `updateEvent`, `updateRole` all receive `success("... with ID N updated")`. The React `EventService.updateEvent` is typed `Promise<EventResponse>` and hands callers an object the server never sends — a type lie that would surface as a null-check crash deep in a screen. Returning `String` is what the server actually does. Task 6.9 depends on this; task 10.10 would fix it server-side.

**Two smaller corrections, caught by the analyzer and by re-reading the React source:**

- `RoleService.updateRole` was written, then removed. The React `RoleService` only ever calls `getAllRoles`; `CreateRoleRequest`/`UpdateRoleRequest` exist server-side but were never needed. Adding role *management* is new feature work, not a port. The compiler caught the invented type; the fix was deletion, not importing a DTO.
- `AuthService.getUserDetails`/`updateUserDetails` duplicate `UserService.getUser`/`updateUser`. The React `UserDetailsResponse` was a near-duplicate of `UserResponse` missing `organization`, so both collapse onto `UserResponse` and the `UserService` copies are gone. Task 5.6 can revisit if the profile screen needs the distinction.

**`ListQuery` collapses seven near-identical parameter lists** into one, and omits nulls rather than sending empty strings — the server parses with `toIntOrNull()`, which would treat `""` as absent anyway, but omitting keeps the URL readable and makes the missing-`limit` behaviour explicit rather than accidental.

**Verified with an `HttpServer` recording every request path and query string** — 13 assertions covering route paths for all nine services, the `limit=10` default and its override, `sortBy`/`sortOrder` forwarding, the bare-string update shapes, and a 204 delete. All passed. **Superseded by task 1.20**, which kept these as `test/services_test.dart`.

**Also recorded in the discrepancy table:** 18 of the server's 33 permissions are unreachable from the client, because `src/types/permissions.ts` declares only 15. The extras are mostly `*_GLOBAL` variants beyond the two org ones, plus `MANAGE_ROLES_*`, `ASSIGN_*`, `CAN_ASSIGN_*`, and `MANAGE_USERS_SELF`. `Permission` in `models/permissions.dart` mirrors the React 15, so parity holds — but the server can grant a permission this build cannot name. That is exactly why `UserContextResponse.permissions` stays `List<String>`.

**Audited the discrepancy table and found it was mostly documentation, not a work list.** Of the 16 entries, only 3 had a task that would actually fix them (10.7 geo, 10.9 bare strings, 10.10 success payloads). The rest were *described* and never actioned — which is how five real defects sat in the file for three phases. Added a **Fix** column mapping every row to its owning task, and tasks **10.11–10.16** for the orphans. All 16 rows now have an owner.

The previously-unowned ones, each re-verified against source before writing the task:

| Orphan | Verified how |
|---|---|
| `sortBy` dead on `/api/events` | `grep sortBy EventDao.kt` → **zero matches**. Not read by the DAO *or* the route. Every other list DAO honours it; events are the outlier |
| `DELETE /api/users/{id}` | `UserRoutes.kt` registers only post/get/get-context/get-id/put-id. `UserService` has neither `delete` nor `deactivate`. The React delete button has never worked |
| `POST /api/events/{id}/join` | No `join` route; only `joinToString` matches in the backend. Also **nothing in the React app calls `joinEvent`** — doubly dead |
| Omitting `limit` returns everything | `limit?.let { query.limit(it) }` in all five DAOs. `total` is counted before the limit applies |
| 18 unreachable permissions | 33 in the server enum vs 15 in the React types; the 18 enumerated |
| Free-form `RsvpRequest.availability` | `String`, no validation. Flagged the data-migration question rather than assuming it's cheap |

Two of these are **product decisions, not porting fixes**, and are written that way. 10.12 (delete user) needs an answer on hard-vs-soft delete — users are the one resource referenced from elsewhere, so deleting them orphans RSVPs and `staffInvites`. 10.13 (event join) needs a check of intent first: `Permission.ASSIGN_TO_EVENTS_SELF` exists server-side, which suggests self-assignment was meant to exist and was never wired up. Either could turn out to be "delete the dead code", which is why neither is pre-decided.

**Two decisions taken on the Phase 10 orphans, and one hypothesis confirmed from git history.**

**Users: hard delete — but the database will not do it for us.** Six tables reference `Users.id` and only `StaffDetails` declares `onDelete = CASCADE`. The other five (`UserRoles`, `UserOrganizations`, `Rsvps`, `StaffHours`, `Invitations`) have a plain FK, so `Users.deleteWhere { ... }` fails on the first dependent row. This makes task 10.12 more than "add a route" — the schema has to be either cleaned up explicitly or given real cascades. `TestDataProvider.kt:52-55` already does the manual ordering for test teardown, so there is a precedent to follow. Recorded the exact deletion order in the task, with the note that `Invitations.usedByUserId` is nullable and should be **nulled rather than deleted** — the invite is audit-relevant and outliving its user.

**Events join: confirmed a leftover, exactly as suspected.** `git log -S "join"` gave four commits, all on **2025-09-14**: `f2ca476` "wip users can join events" → `13d3ef6` "view joined users on an event" → `a6b28e7` "use existing rsvps class" → `fdaf271` **"remove the join route, use only the rsvp route"**. In the parent of that last commit both routes coexist — `post("{event_id}/rsvp")` at line 142, `post("{event_id}/join")` at line 161 — and the removal was −69 lines across 4 files. So RSVP was introduced alongside `join`, then superseded it the same afternoon, and `join` was never revived.

Two follow-ons from that: the deleted route was gated on `ASSIGN_TO_EVENTS_SELF`, which **still exists** in `Permission.kt` and is now unreachable — another instance of the 10.15 gap. And the React `EventService.joinEvent` was never removed; the commit cleaned up `EventDetails.tsx` but left the service method calling a route that no longer exists. Nothing calls it, so it has been dead ever since.

**Checked the cascade question against the running database rather than the Kotlin, and the Kotlin was misleading.** `StaffDetails.kt` is the one file that declares `onDelete = ReferenceOption.CASCADE`, so reading the table definitions alone suggests a cascade exists. It does not:

- **`StaffDetails` is not in `DatabaseFactory.kt`'s `SchemaUtils.create` list.** No `.sql` files and no migration tool exist, so the table is simply never created. `\dt` against the dev DB returns **13 tables, no `staffdetails`**. It is also never queried anywhere in the codebase.
- **Every FK that does exist is `ON DELETE RESTRICT`** — queried `information_schema.referential_constraints` rather than trusting the source: `rsvps`, `staffhours`, `userroles`, `userorganizations`, `invitations` all `RESTRICT`.

So there are **five** blocking FKs, not one, and the single declared cascade belongs to a phantom table. Two knock-on defects worth noting: `UserResponse.staffDetails` is therefore **always null** — the staff-profile feature the DTO models has no storage behind it, so `StaffDetails` in the client is dead weight — and `DELETE FROM users` fails outright today.

**The dev database can be regenerated, which makes the clean fix viable.** The schema comes entirely from Exposed's `SchemaUtils.create`, so adding `ReferenceOption.CASCADE` to the four genuinely-dependent FKs and regenerating is supported and needs no migration tooling. One caveat: `SchemaUtils.create` is create-if-missing and **never alters an existing table**, so it will not retrofit a CASCADE onto an already-created FK — the database has to actually be dropped and recreated for the change to take effect.

**`staff_details` is worse than a missing table — it is a silent data-loss bug.** Chasing the phantom `CASCADE` from 10.12 turned up a second, independent defect, so it got its own task (10.13) rather than riding along. The table is never created (absent from `SchemaUtils.create`, confirmed absent via `\dt`, no DAO anywhere), so `UserResponse.staffDetails` is **always null**. Two consequences in the React app:

- `Profile.tsx:61` guards on `userDetails.staffDetails &&` — the block never renders, so the staff fields quietly vanish from the profile screen.
- `EditProfileForm.tsx:28` sends `staffDetails` on **every** save, and `UpdateUserRequest` accepts it on the wire — but nothing reads it. **The user's edits are discarded with no error.** They type a phone number, hit save, and it is gone.

That second one is the reason this is worth a task rather than a note. The feature has never worked, so "restore or delete" is a genuine product call — but the *silent discard* is a bug either way and should not survive the cutover regardless of which way it goes.

**Staff details: decision is to restore, not delete — and the scope is larger than the missing table.** Rewriting task 10.13 surfaced two adjacent gaps. First, `skills` is stored as a comma-separated `text` column annotated "for simplicity" (`StaffDetails.kt:9`), so a skill like "Forklift, electric" silently becomes two entries. Making it a real list is **backend-only** — the DTO already declares `skills: List<String>`, so the JSON contract does not move. Since there are no users and no test data creates staff details, there is no format to migrate and no reason to keep the comma join.

Second, and less obvious: **`StaffHours` is never written to.** The table is created (`DatabaseFactory.kt:42`) and read by the staff-hours report (`ReportDao.kt:19`), but nothing inserts rows — `EventService` does not. So the report is permanently empty, and the `hoursWorked` column on `staff_details` would be a value that always reads 0. Restoring staff profiles without deciding where hours come from would ship a number that is quietly wrong, so the task now requires deciding between accumulating hours from RSVP attendance and dropping the field.

One judgement call worth surfacing: `Roles.permissions` stores its list the **same comma-separated way** (`RoleDao.kt:22,30,65`), so this pattern now appears twice. Converting `skills` and leaving `Roles.permissions` alone would relocate the corruption rather than remove it, so the task says fix both or neither — with the second one scoped explicitly rather than left as an untracked leftover.

**Method note.** Every task written in this block was verified by grepping the backend, not by re-reading the plan. That is what surfaced all six orphans — the plan's Phase 1 tasks were accurate as far as they went, but a task list cannot describe defects it has not yet been told about. The "Fix" column is the fix for that: it makes an unowned defect visible at the moment it is recorded, rather than at the moment someone re-reads the table.

### 2026-10-09 — Phase 1, tasks 1.19–1.20 (first tests in the port)

**Done.** `test/api_client_test.dart` (10), `test/models_test.dart` (19), `test/services_test.dart` (18), plus `test/support/fake_api_server.dart` (sockets, parsing only) and `test/support/stub_adapter.dart`. 48 passing on the VM, 38 on Chrome.

**The "zero tests during the port" decision is reversed.** It was a reasonable default when there was no code to test and no Flutter test infrastructure, but it was quietly costing more than it saved: two bugs in `ApiClient` (HTML-parsed-as-success, double-decoded bare string) were found *by probing* during 1.9–1.13 and thrown away, then had to be re-derived. The probe became the test. The plan's own Phase 12 preamble warned that 10.3 deletes "the only executable specification of current behavior" — writing them as each layer lands is the fix, not a deferral.

**Two kinds of test double, split by layer.**

| Layer | Double | Why |
|---|---|---|
| `ApiClient` response parsing | `FakeApiServer` — a **real** `HttpServer` on an ephemeral port | The behaviour under test *is* the transport's: whether a body parses, what `content-type` says, what a `204` looks like to dio. A mock would assert our assumptions rather than the ones the client must survive |
| Services, models, screens | `StubAdapter` — a `Dio` `HttpClientAdapter` returning canned bodies | Nothing above parsing should need a socket. It runs identically on the VM and on web, and cannot drift from the request under test |

Consequence: Chrome now runs **38 of 48** tests instead of 22, and the 2 skipped groups are the socket ones — reported as skipped, never as passing. **A real HTTP server is reserved for tests that are genuinely about parsing**; above that line, craft responses instead. Widget tests (Phases 3–9) will use stubs for the same reason.

**`StubAdapter` is not a `MockAdapter`.** It reimplements nothing: `ApiClient.forTesting` injects the adapter into a `Dio` built with the **same `BaseOptions` as production**, including the default `validateStatus`. The first attempt used a bare `Dio()`, which has no transformer — request bodies then reached the adapter as Dart objects (`CreateCustomerRequest(name: x, ...)`) rather than JSON, and every POST test failed for a reason that had nothing to do with the service. A stub that silently diverges from production is worse than no stub, so the options are mirrored deliberately and `ApiClient.forTesting` is `@visibleForTesting`.

**Two of the tests are regression tests for bugs that shipped in this port.** `index.html` at HTTP 200 must not be read as success, and a bare JSON string must not be decoded twice. Both were real defects found by probing; both are now permanent.

**Chrome: socket tests skip rather than lie.** The first attempt produced 28 failures from `LateInitializationError` — `tearDown` touching a `late` field that `setUp` never assigned, because `dart:io`'s `HttpServer` does not exist on web. `FakeApiServer.isSupported` now gates on `kIsWeb`, and those tests report **skipped**, not passed. A vacuous pass is worse than a skip: it would let task 12.6 believe coverage existed.

**Service fixtures have to match real DTOs, which is most of the work.** A stub body that omits a required field throws inside generated deserialization rather than failing an assertion — `CustomerResponse` needs `organization`, `EventResponse` needs `eventId` *and* `organization`, and each resource spells its id differently (`customerId`, `inventoryId`, `organizationId`, `eventId`). `_responseFor` dispatches on path and method, because a single fixture cannot satisfy nine return types. Each resource needing its own body is the cost of testing at this level, and it is cheaper than the socket it replaced.

**Test-writing notes worth keeping.** Two failures were mine, not the code's: 23:30 + 60min is 00:30 (I asserted 00:00), and an `EventResponse` fixture missing `organization` threw inside generated deserialization. Both are the usual failures of fixtures that do not match the real DTO — the reason the service tests assert on *requests* rather than decoded responses.

`prefer_const_constructors` fired on every async `setUp`, since the closure cannot be const even when its body could. Rather than exclude `test/**` from the analyzer (which would hide real errors), the fixtures are `const`. `analysis_options.yaml` is unchanged.

**Test tasks added to the phases that had none:** 3.14 (responsive chrome), 4.12 (`ResponsiveListView`), 5.13 (form validators, invite link), 7.11 (calendar date placement), 8.6 (client-side org filtering — worth testing because the server applies no scoping), 9.11 (error boundary). Phases 3, 4, 5, 7, 8, and 9 had no test task at all before this.

#### What the service and model files pin

**Services — assert on the *request*, not the decoded response,** since a fake
body is not the point. Each service hits the documented path; `deleteCustomer`
targets `/api/customers/{id}`; `trackInventoryUsage` posts to
`/api/inventory/{id}/usage`; `validateInvitation` passes `token` as a query
param; the reports pass both dates. Plus the behaviours that are easy to
regress: `getAllEvents` sends `limit=10` when unspecified and honours an
explicit override, non-event lists send **no** limit, and the three update
methods return `String` rather than a model.

**Models — the cases whose behaviour is *not* visible at the call site:**

- `ApiResponse.fromJson` does **not** invoke `decode` on a failure envelope,
  even though `data` is `{}`. This is the whole reason the callback form
  exists.
- `EventResponse.startAt` / `endAt` stay naive-local — `"2026-03-04"` +
  `"09:30:00"` + 90 min must yield `11:00` local, **not** a UTC-shifted
  instant.
- `Permissions.hasAny` uses OR-semantics, and an empty requirement grants
  access.
- `PaginatedResponse.fromJson` decodes nested items through the supplied
  decoder.

### Phase 2 — Auth, permissions, routing (undated entry)

Tasks 2.1–2.12 are done, which closes the phase. The route table is complete but every screen below Phase 2 is still a `PlaceholderScreen` naming its own path — each is replaced as its phase lands, and `grep PlaceholderScreen` is the checklist. `HomeScreen` (task 0.8) and `widget_test.dart` are gone, superseded by the router.

**Four deliberate deviations from the React original**, three of them because go_router behaves differently rather than for tidiness:

1. **`router.refresh()` is deferred to a microtask.** Riverpod notifies a provider's own listeners *before* recomputing the providers that depend on it. Calling `refresh()` synchronously from the auth listener re-runs the redirects against the previous context, and `/login` silently stays put after a successful login. This one was found by the test suite, not by reading.

2. **The unauthorized fallback falls back to `/profile` when the user cannot see events.** `ProtectedRoute.tsx:27` sends users to `/events` without checking they may see it. A user lacking `VIEW_EVENTS_ORGANIZATION` is redirected to a route that denies them in turn; React Router re-renders in place, but go_router resolves it as a redirect loop. `/profile` is the one authenticated route with no permission requirement (`App.tsx:59`), so it is always somewhere the user can land. Covered by `router_test.dart`.

3. **The 401 latch resets on login.** The React flag at `AuthContext.tsx:16` is never cleared, so a *second* 401 later in the session is silently ignored. Reproduced faithfully for the concurrent case; not reproduced for the sequential one.

4. **The acceptance screen's loading box tracks the request, not the absence of an invitation** (task 2.10). `AcceptInvitationPage.tsx:103-104` picks the loading box on `!invitationDetails && !validationError`, and a URL with no `?token=` sets neither — it sets the ordinary `error` (`:46`). The original therefore renders *"Invitation token not found in URL."* stacked above an indefinite *"Loading invitation..."*, for a page that will never load anything. A boolean tracks the in-flight `validateInvitation` call instead, so the spinner appears only while a request is genuinely pending. Every other render state matches the React ternaries.

**Two notes on task 2.10, both about the same screen.** The `alreadyLoggedIn` flag has two triggers in the original — the `userContext` effect at `:27-31` and the `"Cannot accept invitation while logged in."` catch at `:78-79` — but only the first is reproduced, because the second cannot fire without the first: `InvitationRoutes.kt:46` rejects on the strength of an `AuthContext` principal, which only exists for a token `userContextProvider` has already resolved. Deriving the flag rather than storing it also means it cannot go stale. Separately, the `response.success` check at `:71` is kept with its `else` unreachable: a service-level rejection is converted by `InvitationRoutes.kt:60-62` into an envelope-level failure that `ApiClient` raises as an exception, so a `success: false` DTO never reaches the client (the correction recorded at line ~699 applies).

**Inline links are `TextSpan` + `TapGestureRecognizer`, not `TextButton`.** Applies to every link-shaped control in the port, not just `AlreadyLoggedInError`. A `TextButton` dropped into a sentence brings its own chrome — a circular hover/splash blob over the word — gets announced as a *button* rather than a link, and needs padding hacks that show up as visible gaps in the text. None of that is wrong for a button, but all of it is wrong for an `<a>`, and a recognizer span underlines for free. The cost is a smaller hit area (the word itself rather than a 48dp target), which is the same trade the React original made. An early version put the leading space *inside* the link span to enlarge that hit box; it was removed — the underline starting in blank space looks broken, and inflating a target by a few pixels is not worth it. See the whitespace rule in `AGENTS.md`. Note the link colour is `primary`, **not** `error`: an error-coloured link on the pink `errorContainer` is close in value to the dark red body text, so it makes the link *less* findable, not more. Bootstrap puts links inside `.alert-danger` in its ordinary link colour for exactly this reason.

**One testing constraint worth carrying forward.** `AcceptInvitationScreen` talks to dio from `initState`, and its loading box carries a `CircularProgressIndicator`. Widget tests must therefore resolve each request inside `tester.runAsync` *before* calling `pumpAndSettle` — settling first hangs on dio's async machinery, and settling while the spinner is up times out. `_settleAsync` in `accept_invitation_screen_test.dart` exists to make that ordering the easy default.

**Two things about the guard's plumbing worth knowing.** The 401 hook is wired in `apiClientProvider` rather than inside `ApiClient`, so the client stays free of routing and tests can override only the transport (`dioProvider`) — a test that built its own `ApiClient` would be asserting against wiring it wrote itself. And `TokenStore` now takes a three-method `TokenStorage` instead of `FlutterSecureStorage` directly: mirroring the plugin means re-declaring signatures with per-platform option objects against a version we do not control, and a plugin stand-in has to implement all eighteen methods.

**Manually verified 2026-10-13.** The app runs and **login succeeds against the real backend**, in two configurations:

- `flutter run` against the dev server. Needs `--dart-define=API_BASE_URL=...`, since `ApiConfig.baseUrl` is empty on web and relative URLs would otherwise resolve against Flutter's own dev-server origin. That this works at all also means CORS is configured correctly for that cross-origin case.
- A build served from the Ktor backend's own static resources (`Routing.kt:56-58`). This is the more meaningful of the two: it exercises same-origin relative URLs and confirms the backend serves the Flutter output at `/`.

That covers the boot sequence, the token round-trip, and the `/login` → `/events` redirect against a live server — all previously unverified.

Task 2.10's screen has also been seen in the browser. `/register` renders the ported screen and shows the already-logged-in branch when signed in, which also confirms the derived-`userContext` approach for `InvitationRoutes.kt:46`; and `/register?token=nonsense` shows the server's verbatim `Invalid or expired invitation token` **stacked above** that box, matching the nesting at `AcceptInvitationPage.tsx:95-96`. The second is a real result rather than a formality — it means a non-root path carrying a query string survived the Ktor SPA fallback and reached `GET /api/invitations/validate` intact, which is the server-side half of the invite-link chain.

**The address bar follows in-app navigation.** The last item open from 0.9 is now answered, and it is the question the headless harness could not settle. Observed manually in the browser, and every case matched the intended behaviour:

- signed out, any path → `/login`
- `/register` stays on `/register` **whether signed in or not** — `App.tsx:66` sits outside the auth branch, so a signed-in visitor gets `AlreadyLoggedInError` rather than a redirect
- unknown paths while signed out → `/login`
- after login, everything lands on `/events`, bad URLs included

The last one is the load-bearing observation: login → `/events` is *in-app* navigation, and the path shows in the URL. The failure this was guarding against was quiet — a login landing on `/events` with the bar still reading `/`, which looks fine until a reload or a shared link. `usePathUrlStrategy` is doing its job, and the concern recorded at task 0.9 can be considered retired.

---

### 2026-10-13 — Phase 3, tasks 3.1–3.11 and 3.14 (responsive shell)

**Done.** `MainLayout` as a `go_router` `ShellRoute`, three breakpoints, the
permission-gated nav, the organization control, and 16 widget tests. 111 tests
pass on the VM. **The browser half of 3.12 was not done at this point** — see
the end of this entry for why it was harder than it looked. It was completed
later the same day, once 10.18 made the seeded accounts usable; see the two
entries after this one.

**One commit for eleven tasks.** They are not separable in any useful way: the
chrome cannot render without the breakpoints, cannot gate its items without the
permission list, and the organization control is part of the chrome the nav
lives in. Splitting them would produce intermediate commits where the shell is
structurally present and visually wrong.

**Task 3.1 was already done in Phase 2.** The `loading` → "Loading..." gate is
the `_AuthGate` in `main.dart` plus the redirect's loading short-circuit, both
written for task 2.12's tests. Nothing was added for it; the checkbox is ticked
because the requirement is met, not because work happened. Worth recording,
because a reader counting eleven tasks against a Phase 2 commit would be wrong.

**The breakpoint numbers are this app's, not Material's.** Material 3 ships
`Breakpoints` at 600/840; those are a *second* source of truth for the same
decision, so `AppBreakpoints` is a plain function of a `double` and the context
extension reads `MediaQuery.sizeOf` rather than Flutter's enum. A pure function
is also the only version that can be unit-tested — `responsive_chrome_test.dart`
asserts the three thresholds directly, because a wrong number would still
produce a passing widget test at every width.

`1100` rather than a rounder number because the extended rail plus a content
column stops being readable below it; `700` because that is where a list of
six labelled items stops fitting as icons. Neither is derived from the React
app, which had exactly one breakpoint (992) and collapsed into a hamburger.

**Three layouts, one nav list.** The six `<li>` blocks at
`MainLayout.tsx:22-27` each carried a label, a path and a permission test.
Collecting them into `kPrimaryNavDestinations` is what lets drawer, rail and
extended rail all render from one filtered list instead of three copies of the
permission logic. OR-semantics come free from `Permissions.hasAny`, which
Phase 1 already had.

**Longest-prefix, not equality — a real bug, caught before it shipped.** The
rail highlights a destination by matching the current path. `/events` is a
prefix of `/events/list` and of `/events/42`, so an equality match leaves the
rail with nothing selected on every detail screen. It is pinned by a test
asserting `/events/42` selects index 0.

**`NavigationRail`'s trailing slot gets *loose* width constraints.** The rail
lays its internal `Column` out with `CrossAxisAlignment.center`, so a child
that wants to stretch is handed `maxWidth: Infinity` and throws "BoxConstraints
forces an infinite width" at layout. The fix is to set `minWidth`/`minExtendedWidth`
on the rail **and** reuse the same two constants to bound the trailing group —
deriving the width from the theme instead would make a theme change an
infinite-width crash rather than a narrower rail.

**Task 3.6 is a redesign at two of the three sizes, and the reason is the React
original was broken there.** `OrganizationSelector.tsx` is a `<select>` in the
navbar, and the navbar is *inside* the collapse — so below Bootstrap's 992px the
super-admin's org switcher was unreachable from a phone. `QuickOrganizationPickerModal`
was never wired to it at all; only the event forms used that. The port keeps the
`<select>` at desktop (a real dropdown) and gives tablet and mobile the picker
as a bottom sheet. Same state, same persistence, same "All Organizations" — a
control that only exists at the size where the original was already broken is
not worth preserving as broken.

**One place the port refuses to reproduce a React bug.** `OrganizationSelector`
sets `<select value={selected.organizationId}>` with options built in a
`useEffect`. On the first render the value names an option that does not exist.
A browser quietly shows the first option; `DropdownButton` **asserts**, and the
assertion takes the screen down. `_including` appends the current selection to
the list when it is absent, so the control always has an item for whatever it
says is selected. Found by a test written for a different reason — the
"remembers a selection across a reload" case seeds the store and then fails,
which is how it surfaced.

**Tablet counts as desktop for the picker.** The plan says "bottom sheet on
mobile, dialog on desktop" and leaves tablet unsaid. A 700px window has room for
the centred dialog, and the sheet's drag-to-dismiss would fight the rail's own
scrolling. Documented at `showOrganizationPicker`.

**Task 3.10 corrects the record on `#3174ad`.** The plan calls it "the primary".
It is not: `frontend/src/index.css` sets only the body background, so
`btn-primary` really did render Bootstrap's stock `#0d6efd`, and `#3174ad` is
the colour the app uses *explicitly*, for event pills at
`EventCalendar.tsx:177`. The plan's wording was adopted anyway — a single
coherent accent beats a palette of two nearly identical blues, and Phase 0's
theme file had already declared it — but the doc comment now says which is
which rather than asserting something false. Every hex in the new `ColorScheme`
carries its provenance: `$dark` for `navbar-dark bg-dark`, `$secondary`,
`$danger`, `$gray-500`, `$gray-200`.

**The chrome uses Material icons throughout (3.11), with no attempt at parity.**
The React `bi bi-*` tags render as empty `<i>` elements — there is no glyph to
match. Worth noting for later: there is also **no logo asset in the navbar at
all**, just the text "Teven", so the collapsed rail's icon has no counterpart
either.

**Two test-harness changes, both forced by the shell.** `contextAdapter` now
answers `/api/organizations`, because the super-admin branch of the org
selector builds a switcher that fetches immediately — without it the stub
returns 401, the client raises `UnauthorizedException`, and the single-flight
redirect signs the test out mid-assertion. And `pumpApp` gained `width` (to pin
the surface) and `prefs` (to seed `selectedOrganization`); it also resolves the
organization controller inside `runAsync` alongside the auth controller, for
the same reason the Phase 2 log gives — real async hops do not advance under a
widget test's fake clock.

**Chrome: no new failures, and one honest note.** All 16 new tests pass on both
VM and Chrome. The Chrome run still reports **9 pre-existing failures**, all in
`accept_invitation_screen_test.dart`, present before this change (verified by
stashing and re-running). Task 12.6's claim that the suite runs on both
platforms is true for the VM and partly untrue for web widget tests; those nine
are unowned and worth a look before 12.6 is ticked.

**The browser half of 3.12 could not be discharged at the time, and the reason
is worth recording.** A real-browser check needs a signed-in session, and the seeded accounts cannot
log in: `TestDataProvider.kt` writes `passwordHash = "password"` — plaintext —
into a column that goes straight to `BCrypt.checkpw`, which **throws** on the
first character. Nothing catches it, so every seeded login is a **500 with a
stack trace**, not a 401. Found by hitting it, given task **10.18**.

For this entry the dev database was patched by hand with a real `$2a$` hash, the
screenshot taken, and the database then **reverted to what it was found as** —
the plaintext value. The defect was real and is now fixed; see the entry below.

What *was* verified in a real browser at this point: the app builds, boots from
Ktor's `staticResources`, and the login screen renders under the new
`ColorScheme` against `#f8f9fa` with a `#3174ad` primary.

**Files added:** `lib/core/layout/breakpoints.dart`,
`lib/widgets/app_shell.dart`, `lib/widgets/nav_destinations.dart`,
`lib/widgets/organization_selector.dart`, `lib/widgets/organization_picker.dart`,
`lib/providers/organization_list.dart`, `test/responsive_chrome_test.dart`.

**No new packages.** The chrome is `NavigationRail`, `NavigationDrawer`,
`Drawer` and `showModalBottomSheet` — all in the framework. Task 4.2 will be the
first to argue for one, and it should argue on its own merits.

### 2026-10-13 — Task 10.18 (seeded users could not log in), unblocking 3.12

**Done.** Two lines of seed data, one boundary, one adjacent defect, seven
tests. All four seeded accounts now authenticate; a corrupted `users.password`
returns 401 instead of a 500 with a stack trace.

**The defect, confirmed rather than inferred.** `TestDataProvider.kt` wrote
`it[passwordHash] = "password"` — the literal string — into `users.password`,
which `AuthServiceImpl.loginUser` handed straight to `BCrypt.checkpw`. Observed
against the running backend:

```
{"success":false,"data":{},"error":{"message":"Internal server error",
 "details":"java.lang.IllegalArgumentException: Invalid salt version
  at org.mindrot.jbcrypt.BCrypt.hashpw(BCrypt.java:659)
  at org.mindrot.jbcrypt.BCrypt.checkpw(BCrypt.java:764)
  at alphainterplanetary.teven.auth.AuthServiceImpl.loginUser(...)"}}
```

A 500 carrying `cause.stackTraceToString()`, which is **task 9.9's stack-trace
leak arriving through a second door** — a row of seed data reaching the client
as an exception, with nothing about the request being unusual to cause it.

**`PasswordHasher` already existed.** `core/security/PasswordHasher.kt` wraps
jbcrypt, and `UserDao.createUser` already used it for both create and update.
Only the seed was bypassing it, and only `AuthServiceImpl` called `BCrypt`
directly rather than through the wrapper. So the fix was smaller than the task
assumed: point the seed at the helper that was already there, and route the
login through it too. No new abstraction, no new dependency.

**`AuthServiceImpl` no longer imports jbcrypt, and neither does its
`build.gradle.kts`.** Removing that one call removed the module's only reason to
depend on a hashing library directly — which is the point of having a wrapper.
`PasswordHasher` is now the single place that knows jbcrypt exists.

**The tests found a second exception type, which is the interesting part.** The
first version of `checkPassword` caught `IllegalArgumentException`, and two of
the seven tests failed against the live library:

```
PasswordHasherTest > a stored value that is not a hash at all is rejected FAILED
    java.lang.StringIndexOutOfBoundsException at PasswordHasherTest.kt:64
```

`checkpw` validates its salt by **indexing the string without bounds checks**, so
an empty or short stored value raises `StringIndexOutOfBoundsException` while a
`$2y$` hash raises `IllegalArgumentException` — two types from one call site.
Catching the first would have left every empty `users.password` row still
returning 500. The method now catches `RuntimeException`, with the reasoning
written down: enumerating a library's parse-failure modes is how this happens,
and every one of them means the same thing, which is that the row is not a hash.

**The `$2y$` case is not hypothetical.** It is what `htpasswd`, PHP's
`password_hash` and most tooling emit, and it is what I personally used to patch
the database while diagnosing this — which produced a *second* 500, with a
different message, before I understood it. jbcrypt only accepts the `$2a$`
revision. There is a test for it and a comment saying why.

**One more defect found in the same family, fixed here.** `UserDao.createUser`
called `PasswordHasher.hashPassword` **twice** — once for the row, once for the
returned `User`. The object handed back carried a second hash that was never
stored: a different salt, the same password, and a value that verifies against
nothing. Harmless today because login re-reads the row, and a landmine the first
time something checks a candidate password against that object's `passwordHash`.
Now hashed once and shared. The local is named `hashedPassword` rather than
`passwordHash` for a non-obvious reason: inside `Users.insert { it[passwordHash]
= ... }` the bare name resolves to the local instead of the column, and Exposed
fails to compile rather than writing somewhere else quietly. That cost a build
cycle to find, so it is commented at the declaration.

**Verified against the running backend, not against the tests.** `./teven up`,
then:

| Case | Before | After |
|---|---|---|
| `alice` / `bob` / `charlie` / `diana`, correct password | **500 + stack trace** | **200 + token** |
| wrong password | 401 | 401 (unchanged) |
| `users.password` = `'password'` (plaintext) | 500 + stack trace | **401**, no `details` |
| `users.password` = `''` (empty) | 500 + stack trace | **401**, no `details` |
| `users.password` = a `$2y$` hash | 500 + stack trace | **401**, no `details` |
| `users.password` = a truncated hash | 500 + stack trace | **401**, no `details** |

All four corrupted rows log `WARN ... Stored password hash is not a valid bcrypt
hash` from the server, so the corruption is visible to an operator without being
visible to the caller. After a restart the seed recreates all four accounts with
`$2a$10$` hashes and every one of them authenticates.

**The four seeded accounts share one hash, deliberately.** bcrypt costs ~100ms
at cost 10, and hashing four times adds ~300ms to every dev boot. Unique salts
only matter when the password is real, and `PasswordHasher.checkPassword` is now
what protects the login path — not salt uniqueness in the seed. Recorded here
because a reviewer counting `count(distinct password)` would otherwise flag it,
and it would be correct to.

---

### 2026-10-13 — Task 3.12 (web pass), and the layout bug it found

**3.12 is done. 3.13 is not.** The shell is screenshotted at all three
breakpoints in a real browser, signed in, against the live backend.

The original 3.12 was one task covering web *and* a device. It is now two: 3.12
(web, done) and 3.13 (device, not started). Splitting them is not bookkeeping —
there is no simulator or device on this machine, and no native platform either
until Phase 11 adds one, so the device half is a *Phase 11 prerequisite* rather
than work that belongs in Phase 3. A single box covering both could only be
honestly ticked as half-done, which is the one state worth avoiding: it reads as
progress while hiding that a whole category of verification has never run.

**How the session was obtained, since Flutter paints to a canvas and a headless
harness cannot type a username.** `flutter_secure_storage_web` 2.1.1 is entirely
reproducible from the page's own JS: the key is a raw AES-GCM-256 blob in
`localStorage["FlutterSecureStorage"]`, and the value is
`base64(iv).base64(ciphertext)` in
`localStorage["FlutterSecureStorage.teven-auth-token"]`. So the verification
served a **copy** of `build/web` with a small injected `<script>` that performs
that encryption with `crypto.subtle` before `flutter_bootstrap.js` runs. No app
code changed, nothing in the repo was touched, and the copy was thrown away
afterwards.

**One non-obvious trap, worth the whole exercise.** The first attempt served the
app on `127.0.0.1:3000` and every screenshot came back as the login screen —
the seeded token was seeded correctly and simply not being used, because
`ApiConfig.baseUrl` is relative on web so every API call is cross-origin.
`Application.kt`'s `installDevCors` allow-lists `localhost:$port` as **exact
host strings**, and `127.0.0.1` is not `localhost`:

```
OPTIONS /api/users/context   Origin: http://127.0.0.1:3000   ->  403, no CORS headers
OPTIONS /api/users/context   Origin: http://localhost:3000   ->  200, Allow-Origin set
```

The app's own failure mode for a CORS rejection is to look *signed out*
(`AuthController.build` catches everything and returns null, per
`AuthContext.tsx:47`), so the symptom is a silent redirect to `/login` with
nothing in the UI or the console to connect it to an origin string. Serving on
the `localhost` origin fixed it immediately.

**The layout bug the widget tests could not see.** `NavigationRail` gives its
`trailing` slot an `Expanded`, but the `MainAxisSize.min` column inside it still
hugs the **top** of that space — so Profile and Logout rendered directly
beneath the destinations instead of at the foot of the rail, which is where
`MainLayout.tsx:29-41` puts them. Every one of the 16 chrome tests passed with
the bug present, because they assert that a control *exists*, not where.

Added a positional assertion, and confirmed it is one that bites: with the fix
reverted it fails `Expected: greater than <800.0> Actual: <562.0>`, and passes
with it. The general lesson is the one Phase 1's testing notes keep
reaching — **assert the behaviour that is not visible from the call site**, and
"the widget exists" is not that.

**Still not verified:** touch input, the drawer opened by a real tap, and any
device. All three are now task 3.13, and all three need hardware.

### 2026-10-13 — Tasks 3.14 and 3.15 (organization switcher invisible; the rail vs. React's top bar)

**3.14 fixed, 3.15 answered.** Neither was visible from the tests or the
source — 3.14 came from someone looking at the running app, which is the whole
argument for 3.12 existing.

**`DropdownButton` has three text paths and none of them agree.** This is the
mechanism, and it is worth knowing before writing any more of these:

| Path | Where its colour comes from |
|---|---|
| Closed state | `DefaultTextStyle(style: widget.style)` |
| Hint | `style.copyWith(color: theme.hintColor)` — **`hintColor` beats `style`** |
| Menu items | **no `DefaultTextStyle` at all** (`_DropdownMenuItemContainer` is a bare `Align`), so the ambient theme |

The control inherited the app's light-container ink from all three, on a
`#212529` rail. The chevron was visible because it is an `Icon` with an explicit
`color: Colors.white` — the only one of the four visible things I had coloured.
Every widget test passed, because they assert a control *exists*.

**The same bug was in the branch with no dropdown to blame.** The non-super-admin
label used `colorScheme.onSurface`, correct in the light drawer and
near-invisible on the dark rail. Fixed together; the ink decision now comes from
one `_onDarkRail(layoutSize)` helper so the two cannot drift again.

**`dropdownColor` follows the rail rather than staying light.** A light popup
would need a *second* ink on the same strings, and items render in both the
closed and open states — so no style can be scoped to one without breaking the
other. One ink, one background.

**A subtlety worth writing down: the hint never renders.** `DropdownButton`
resolves its `value` with `items.indexWhere((item) => item.value == value)`, so
a `null` value matches the "All Organizations" item — which exists precisely so
the empty option is selectable — and the hint is only used when *no* item
matches. This cost me two wrong attempts at proving the regression test bites: I
mutated the `hint` first, and the test still passed, because the hint was not
what was on screen. The mutation that failed it was on the **item**. Verified
by reverting the whole control to its original form: the test then reports
`Expected: >= 4.5, Actual: 1.0`.

**The test asserts a contrast ratio, not a colour equality.** "Is not the same as
the background" would pass for any change of hue, including a slightly worse one.
WCAG 2.1 AA for normal text is 4.5:1, so that is the threshold, computed from
relative luminance. Four labels are checked, deliberately one per ink mechanism:
an explicit `Text` style, a `TextButton` foreground, a `NavigationRail` label
style, and an explicit item style. `_effectiveInk` resolves
`DefaultTextStyle.of(element)` when `Text.style` is null — reading only
`Text.style` reports "no colour" for most of the rail and would skip the
assertion that matters.

**Two things about the extended rail that cost time and will again.** It renders
a label **only for the selected destination** — with `selectedIndex == null` the
rail shows one unselected icon-only row, so a test asserting on "Events" needs
the user to actually be on `/events`. And a user holding only
`VIEW_USERS_GLOBAL` lands on `/profile` (the guard's own fallback), so a
super-admin test needs `VIEW_EVENTS_ORGANIZATION` too or it silently exercises
the wrong branch.

**3.15: the React app did have a top bar, and the rail is a deliberate
redesign.** `MainLayout.tsx:14` is `navbar navbar-expand-lg navbar-dark
bg-dark` — inline nav items, collapsing behind `navbar-toggler` below 992px.
Mobile does collapse to a hamburger and a flyout, as expected.

What actually changed, and why it is not parity:

| | React | Port |
|---|---|---|
| Desktop | top bar, one row | extended rail |
| Tablet | top bar, hamburger | collapsed rail |
| Mobile | hamburger → collapse | hamburger → `NavigationDrawer` |
| Org switcher | `<select>` inside the navbar | rail at ≥700, bottom sheet below |
| Profile / Logout | right end of the bar | foot of the rail / drawer |

The reason for changing it was already recorded when 3.6 was written, and this
is the first time it has been worth stating plainly: **the React navbar's own
contents were unreachable below 992px.** The organization `<select>` sat inside
the collapse, so a super-admin on a phone could not switch organization at all,
and `QuickOrganizationPickerModal` — the searchable list — was wired only to the
event forms. A rail shows the six items without a hamburger from 700px up and
gives the switcher a home at every size. The React layout was desktop-only and
had one breakpoint; this has three. The trade is that it is **not** visually
faithful, and it should be revisited if matching the current look matters more
than closing the responsive gap.

**Also confirmed after the `ShellRoute` restructure: the address bar follows
in-app navigation.** This had been retired in the Phase 2 log, but nesting the
authenticated branch under a `ShellRoute` was exactly the kind of change that
could have broken path-based deep links, and it did not. `/events` loads and
renders at the right URL.

---

### 2026-10-14 — Phase 4, tasks 4.1–4.4, 4.10, 4.12 (the shared list, and the first screen that uses it)

**Done.** `ResponsiveListView`, the customer list at `/customers`, 25 widget
tests. 138 pass on the VM; Chrome is unchanged at its 9 pre-existing failures.
`flutter analyze` and `dart format` clean.

**Six tasks, one commit, and 4.8 rides along for one of its six.** A shared
widget with no caller would be a widget nothing exercises, and the customer
list is the smallest screen that exercises all of it — search, sort, create,
delete, permissions. The other five `window.confirm` flows (4.8) land with
their own screens rather than as a commit of five dialogs.

**The list's breakpoint is its own width, not the window's — which pushes
"desktop table" much further right than expected.** The widget uses
`LayoutBuilder`, so inside the shell it sees the *content column*, after the
256px extended rail has come off. A window therefore has to be ~1360px before
the customer table appears; between 1100 and 1360 it is cards. That is the
correct measurement and it is worth writing down, because every screenshot
taken at "desktop width" during Phase 3 was a window width.

**Tablet gets cards.** The plan said "table at desktop, card at mobile" and
left the middle open; at 700px the rail has already taken 72px and four
customer columns plus actions do not survive the rest. A squeezed table that
scrolls sideways is worse than cards that say what each value is.

**Two decisions in the widget are independent and are implemented as such.**
The *layout* follows the width. The *hover reveal* follows the input device
(`kIsWeb`) and only exists in the table at all — which is the `kIsWeb` branch
task 4.2 asked for. Conflating them was the first thing tried and it would have
given a hypothetical desktop-native build a card list.

**`revealActionsOnHover` is a parameter purely so tests can reach the hover
path.** Widget tests run on the VM, where `kIsWeb` is false, so the hover
branch would otherwise be unreachable from a test — and it is only reachable
from a *test* that passes the flag. The Chrome run exercises it for real, with
no flag, which is the better coverage and neither platform has to pretend.

**`Tooltip` is the accessible name, so there is no `Semantics` wrapper.** Task
4.3 asked for `Semantics` labels on native; `Tooltip` already publishes one,
and adding a second `Semantics(label:)` on the same button announces the word
twice. Recorded rather than "implemented", because the literal reading of the
task would have made accessibility worse.

**Actions moved from the name cell to their own column.** `CustomerList.tsx:77-89`
absolutely positions them over the name, which works in a table and does not
work in a card. A trailing column costs 96px of horizontal space and gains
keyboard focus and a stable hover target.

**`ListQuery` grew value equality, and that is load-bearing.** It is now the
key of a `FutureProvider.autoDispose.family`. Without `==`, every rebuild
produces a new key, the provider refetches, and the debounce in 4.10 is
bypassed by a single unrelated `setState`. It was a two-method change to a
class that already existed for exactly this parameter set.

**4.10 is a fix, not a port, and the debounce is 300ms.** The React lists wire
`useState` straight into `useCallback`'s dependency list, so typing "Globex"
fires seven searches and races seven responses into one `setCustomers`. Nothing
cancels the superseded requests either — that half is task 9.6.

**Two places where the port is visibly less faithful, on purpose.** A new query
drops the list to a spinner; the React original left the previous rows up until
the response arrived, so searching flashes where it did not. Riverpod can
retain the last value across family keys with a keep-alive link provider, and
that is more machinery than 25 rows justifies — noted at the call site rather
than left to be rediscovered. And `CustomerList`'s list is capped at 25 with no
control to reach the rest, because that is exactly what the React app does.

**4.9's premise did not hold: there is no pagination to port.** `grep` over the
four React lists finds no control, and `CustomerList.tsx:27` fetches `25, 0` —
one page, no way past it. Tick rewritten to say so. Adding paging is a product
decision and is deliberately *not* filed as a task.

**Only the `name` column is sortable, matching `CustomerList.tsx:76`.** Worth
recording because `CustomerDao` *does* honour `sortBy` for phone and address,
so task 4.11 should not go looking for missing sort controls that the server
would have honoured — they are absent because the original chose that.

**The tests found a harness gap that would have cost the next screen the same
afternoon.** `settleRequests` needs *both* halves of its loop, and the reason
is not obvious: a request started from inside a frame — a screen's own
provider, rather than the boot fetch `pumpApp` awaits — registers its timers on
the widget test's **fake** clock, so `pump()` with no duration never fires them
and the request sits in `AsyncLoading` forever. `runAsync` alone does not help.
On the VM this never bit; on Chrome it hung every screen test with a silent
teardown failure and no message. `goToAndLoad` exists for the same reason and
`goTo`'s doc comment now says which one to reach for.

**Two pre-existing Chrome tests had to change.** `responsive_chrome_test`
navigates to `/customers` to check the nav highlight and the drawer's close,
and it was settling with `pumpAndSettle` against a progress indicator that
cannot settle. Both now use `settleRequests`, and the harness answers
`/api/customers` — the same trap it documents for `/api/organizations`, one
screen along.

**One new Chrome skip, and why it is not nine more.** `a failure shows the
server message` is skipped on web. On Chrome it ends in a pending-timer
teardown with no assertion failure and no message — byte-for-byte the signature
of the nine pre-existing failures in `accept_invitation_screen_test.dart` that
the Phase 3 log flagged as unowned. Every one of those nine is likewise about
rendering `ErrorDisplay` after a rejected request, so this is *that* gap, not a
new one. It is now 13 tests of unowned web behaviour, and the next one to touch
`ErrorDisplay` should find the cause rather than add a skip.

**The delete confirmation is shared, and 4.8 nearly was not.** The first
version inlined the `AlertDialog` in a private method on the customer screen,
which would have meant four more hand-rolled copies — the same duplication
`ResponsiveListView` was written to remove for the table, one layer up. All six
`window.confirm` call sites differ only in the noun they name, so
`confirmDestructiveAction(context, title:, message:)` is now shared and each
screen keeps only the part that genuinely differs: the service call, and what
happens after — a refetch for the lists, a redirect for `EventDetails.tsx:49`,
and an invitation that must outlive the user who accepted it
(`UserList.tsx:94`). A widget that only asks a question has no business knowing
any of that.

**A dismissed dialog is a "no", and that is the part worth a test.** `showDialog`
answers `null` when the dialog is dismissed with no choice — scrim, back
gesture, Escape — and the helper turns that into `false` explicitly. Nothing
makes that safe by accident: an `if (confirmed)` in the caller is `true` for
`null`, and the scrim tap that produces it is the single easiest way to turn a
confirmation into a delete button with a delay on it. The destructive colour
is asserted too, since `styleFrom` resolves against the theme and a dropped
`foregroundColor` is invisible to any presence check.

**10.12's guard rails: the last-super-admin check is near-redundant, and the
reason is worth having.** Banning self-deletion does make "no super-admins
left" unreachable — the deleter always survives, so the count bottoms out at
one. But it is only airtight if "may delete users" implies "is a super-admin",
and today it does not: `isSuperAdmin` is `VIEW_USERS_GLOBAL`
(`MainLayout.tsx:10`) while the delete button is gated on
`MANAGE_USERS_GLOBAL || MANAGE_USERS_ORGANIZATION` (`UserList.tsx:25`). A user
holding only the org-scoped manage permission can delete users without being a
super-admin, and so can remove the last one. Recorded on the task with both
ways to close it; the cheaper is gating the route on `VIEW_USERS_GLOBAL`. Worth
resolving there rather than when someone implements the route, because the
reasoning is not visible from the Kotlin.

**Files added:** `lib/widgets/responsive_list_view.dart`,
`lib/widgets/confirm_dialog.dart`,
`lib/screens/customers/customer_list_screen.dart`,
`lib/providers/customer_list.dart`, `test/responsive_list_view_test.dart`,
`test/customer_list_screen_test.dart`, `test/confirm_dialog_test.dart`.
**No new packages.**

**Not verified in a browser.** The list was exercised by widget tests on both
VM and Chrome; nobody has looked at it at three widths against the live
backend. Task 3.12's precedent says that pass finds what widget tests cannot,
and this is the largest responsive surface built so far.

---

### 2026-10-14 — Phase 4 browser pass (task 4.4's first real use), and two more tasks

**The list was run in a browser against the live backend.** Three of the twelve
things on the checklist came back, and one of them was not on the list: the
table is broken for real data, and the row hover shifts.

**`IntrinsicColumnWidth` built a 3915px-wide table.** With a realistic address
and a realistic note, each column sized itself to its content and the notes
column ended up 3900px to the right of the name — off screen, behind a
horizontal scrollbar. My fixtures use `"Acme"` and `""`, so no widget test could
have seen it. Fixed with flex column widths and **no horizontal scroll view**,
which is the part worth remembering: the scroll view handed the table an
*unbounded* width, which flex columns cannot divide. A fixed-size table and a
flexible one are opposites, and the second is what a data table in a bounded
pane wants. Bootstrap's `table-responsive` was the target behaviour, minus the
scrolling — and the scrolling was only ever reachable *because* the widths were
intrinsic.

**The name column was centred, not left-aligned.** Caught in a screenshot, and
it is the one defect there that no argument about capture points can explain
away: "City Park" sat further right than "Jones Corporation" because
`RenderTable` hands every cell a **tight** width — the whole column — and
`TextButton` centres its label by default. Every other column is a `Text`, which
is left-aligned, which is why only this one looked wrong. Worth knowing as a
general rule for this widget: a cell's own alignment decides where its content
sits, and the column width no longer does.

**The actions column grew 8px on hover, and the row height is very likely the
same bug.** `_actionsWidth` was 96; two `IconButton`s and their padding need
104, so the column widened when the actions appeared. Fixed, and the cell is now
pinned to a fixed height in **both** states rather than relying on the button
happening to be 48dp today.

**The vertical shift is reported from the browser and I could not reproduce it
in a test — stated plainly rather than papered over.** Comparing text positions
before and after hover shows nothing, on the VM and on Chrome, in the real
screen. I then pinned the *row pitch* (the distance between two rows, and the
gap between the header and the first row) instead, on the theory that a changing
row *band* moves a row's text and the row below together, so both rects stay
consistent while the gap above grows and the gap below shrinks — which is
exactly what the screenshots show. **I then reverted the fix and the new
assertions still passed**, so the row pitch is a useful invariant to keep and a
regression guard for the future, but it is *not* evidence that the browser's
shift is fixed. Two things are needed to close it: a rebuild and a re-check, and
if it persists, the window width and browser zoom — the harness's geometry
differs from the browser's in some way I have not identified, and guessing at it
again would be the third wrong theory in a row.

**The name link is a dead link, and it is dead in the React app too.** Given
**10.20**, as a screen to build. I asserted from the file listing that no
`CustomerDetails` component had ever existed, and that turned out to be right
but was not the whole answer, so it is worth recording how it was settled.

**Two people asserted opposite things and the history settled it, which is the
only reason either claim was worth having.** The claim was that the screen had
been there as a read-only rendering of the edit form's fields. Four checks say it
never was: no occurrence of `CustomerDetail` in `frontend/src`, zero commits
matching `customers/:` across `--all`, no file ever added/deleted/renamed
matching `*CustomerDetail*`, and an all-time file list for "customer" that comes
back as three components and an API service.

**The reason the recollection was so reasonable, and the reason this is worth more
than a dead link: two documents in the repo still promise the screen.**
`CustomerList.tsx:78` links to it, and `GEO_FEATURES_PLAN.md:80` — still in the
repository today — lists *"Add `MapDisplay` to `EventDetails` and `CustomerDetails`"*
as a geocoding task. So the geocoding plan has an open item that cannot be done,
and it will keep reading as though it can. `StaffDetails` is the same shape of
thing (planned surface, DTO field, no storage — 10.13), and the same plan
document assumes it.

**The real cost of the missing screen is not the link, it is that
`GET /api/events` cannot filter by customer.** The intended page is the
customer's past and future events; `EventRoutes.kt` takes `search`, `sortBy`,
`sortOrder`, `limit`, `offset` and no `customerId`, and neither does `EventDao`.
So 10.20 is a backend task wearing a screen task's clothes, and it is scheduled
in Phase 10 for that reason. Recording it here because the plan had no task for
this screen at all — not the screen, not the query parameter behind it — and the
only reason anyone noticed is that someone clicked a name in a browser.

**A comment of mine cited a line that does not say what I claimed.** I had
written that `App.tsx:47` declares `/customers/:customerId`. It does not, and
line 47 is an events route. Corrected at the point of use. It is the failure
mode task 10.8 warns about — a citation that looks followable and is not — and
it reached the file from me rather than from the React source, which is the part
worth remembering. Everything in these comments is now either verified by grep
this session or explicitly marked as a guess.

**Deleting a customer 500s once it has an event, and it is now task 10.19.**
`fk_events_customer_id__id` is `NO ACTION` and `deleteCustomer` hard-deletes.
Given **10.19** as soft delete, with the reasoning written down: events are
business records, a customer is a reference, and nothing should rewrite the
past. The load-bearing part is not the flag — it is that `CustomerDao` has five
read paths and **the one that resolves a customer's name inside an event
response must not apply the filter**, or every historical event silently loses
its customer. The client needs no change at all, which is the main argument for
soft delete over returning a 409.

**What this pass is worth as a number.** Of the twelve checks, three found
defects — one severe (3915px table), one cosmetic but visible (centred names),
one unreproduced but pinned. Task 3.12's argument for a real-browser pass is now
a measurement rather than an opinion: widget tests could not have caught any of
these, and the one they *could* catch (the hover growth) I would have shipped
without it.

**The row heights are stable in the browser, which settles what the tests could
not.** `_rowHeight` pins the actions cell in both hover states, and the fix
works — but the pitch assertion written to prove it **passed on the reverted
code too**, so the test never had the geometry to catch it. Two tests that
cannot fail on the bug are worse than no test, and the honest account is that a
human looking at it is what closed this one. The assertion stays as a guard, not
as evidence.

**One new finding, filed as 4.14 rather than fixed.** Typing in the filter blinks
the table header: a new query replaces the whole card with a spinner, header
included. The React original left the previous rows up until the response
arrived. Judged tolerable by hand and deferred with the three options written
down, because the debounce already reduces it to once per pause.

**Two browser checks still outstanding** from the original list: the debounce
under real typing, and a long list's scroll behaviour. Both are cheap and both
are the kind of thing that only misbehaves with real data.

---

### 2026-10-14 — Phase 4, tasks 4.5, 4.6 and 4.13 (the other two list screens)

**Done.** `InventoryList` at `/inventory` and `OrganizationList` at
`/organizations`, 29 widget tests — plus one added to the customer screen to
pin the header fix below. 175 pass on the VM, up from 145; Chrome
is unchanged at its 9 pre-existing failures. `flutter analyze` and
`dart format`
clean.

**Two tasks rather than one, because they are the same 144 lines of React
written twice.** `InventoryList.tsx` and `OrganizationList.tsx` differ in the
columns and the permission and in almost nothing else — same search box, same
sort handler, same hover state, same `window.confirm`. Porting them together is
also what made the *differences* visible; each is listed below.

**The third list screen was the cheapest place to notice that three widgets had
become copy-paste, so they stopped being it.** `DebouncedSearchField` now owns
the controller, the timer and the disposal that the customer screen had;
`RecordLinkButton` owns the name-link cell; `ListScreenHeader` owns the heading
and the primary action. Before this the customer screen held a ~40-line block
whose only content was a `Timer` and a `dispose` that cancels it, and a second
copy of the header's `Row`; a third screen would have made both three. The
customer screen's doc comment about task 4.10 did not go with them — it moved
to the widget, which is where the next screen will look.

**The inventory screen is the one place in Phase 4 that is a redesign rather
than a transcription, and the plan's own note about it was half right.**
Task 4.5 said `GET /api/inventory/{id}` embeds an unpaginated `events` list.
True, and also incomplete: `InventoryDao.getInventoryItems` builds every row
through the same `toInventoryItemResponse`, so **`GET /api/inventory` does it
too** — one extra query per row, unbounded results. `InventoryList.tsx:97-103`
rendered all of them, so a heavily-used item produced a table row hundreds of
lines tall. The port caps at three and shows `+N more`. The cap is honest about
being a workaround: there is no server-side way to ask for fewer, so the number
the user sees is one the client invented. Filed as **10.21** with three options,
cheapest first, and the load-bearing note that `toInventoryItemResponse` has
three callers so changing it changes three endpoints.

**The organization screen is the only list in the app that is *not* scoped to
the selected organization, and a copy of either other screen would have gotten
that wrong.** `CustomerList.tsx:32` and `InventoryList.tsx:32` both pass
`selectedOrganization?.organizationId` to narrow the result; applying the same
line here would show a super-admin one organization instead of all of them, on
the one screen whose entire job is listing them. So its query sends
`OrganizationList.tsx:26-31`'s five parameters and no organization, and there is
a test whose only assertion is that the parameter is *absent* — `screenRequests`
filters on `limit == 25` to tell the screen's request from the chrome's
`limit == 1000` one.

**The mobile test found a layout bug the desktop tests could not, and it was
three bugs, two of them invisible.** The heading-and-create-button header was a
`Row` in all three screens, which is the obvious reading of the React
`d-flex justify-content-between`. At 500px the organization header overflowed
**by 178 pixels** — "Create Organization" is a long label and a `Row` has
nowhere to put it. The customer screen's "Create Customer" fits, and the
inventory screen's "Create Item" fits better still, so the defect was present in
three places and observable in one. That is the argument for the fix being a
widget rather than a pattern, so `ListScreenHeader` now owns it and the `Wrap`
inside it makes the header stack instead of clip. The customer screen gained a
mobile test in this commit, so its fix is not resting on the other two screens
having found it.

**The organization screen's tests could not reach its own endpoint, and the
failure was silent.** `contextAdapter` answers `/api/organizations` for the
chrome's super-admin switcher by path, *before* `forOtherRoutes` is consulted,
so the first version of the test stubbed the screen's requests through
`forOtherRoutes` and watched the screen render the harness's own two canned
organizations — including in the case that stubs a **failure**, which then
rendered nothing at all and no error either. The stub looked like it was
working. `contextAdapter` grew an `organizationsResponder` that is consulted
first, which is a harness gap of exactly the kind the Phase 4 log already
records once (`settleRequests` needing both halves of its loop).

**Two of the three screens' detail links are dead in the React app, and now all
three are documented as such rather than discovered one at a time.**
`InventoryList.tsx:78` links to `/inventory/{id}` and `OrganizationList.tsx:80`
to `/organizations/{id}`; `App.tsx:53-60` declares neither. Same defect as the
customer link that task 10.20 owns, so the discrepancy table now has one row
covering all three and 10.20 is scoped accordingly — building one detail screen
out of three dead links is the same work as building one.

**The two screens together bring 4.8 to 3 of its 6 wired, and nothing about
the dialog changed.** Each screen calls `confirmDestructiveAction` and keeps
only its own consequence: both refetch after a confirmed delete
(`InventoryList.tsx:63`, `OrganizationList.tsx:54`), which is a provider
invalidation rather than the React `fetchInventoryItems()` call. What remains
open is 4.7 (two flows, one of which deletes an invitation that must outlive
its user) and 7.6 (a delete that navigates away instead of refetching).

**Two ports of the search box and no new package.** `DebouncedSearchField`
carries the 300ms interval and the reasoning, unchanged from the customer
screen's comment; the debounce itself is already pinned by the customer tests,
which now exercise the shared widget rather than the screen's private copy.

**Verified in a browser against the live backend**, via `./teven up`, both
screens at mobile and desktop widths. What it confirmed:

- **The header overflow is fixed.** The organization header stacks rather than
  clipping. Worth recording that the *test* found this and the browser only
  agreed — the reverse of the customer list, where the browser found three
  defects no test could see. Both directions have now happened, which is the
  honest summary of what each is good for.
- **The dead name links reproduce exactly as documented.** Clicking an
  inventory or organization name lands on `/events`, via the `*` catch-all,
  which is what `AppRoutes.inventoryDetails` and
  `AppRoutes.organizationDetails` claim on their doc comments. The customer
  link's behaviour was *inferred* from `App.tsx` when **10.20** was written;
  this is the same defect confirmed by hand in the two screens ported since, in
  the same session, on the same app. Three links, one cause, and the third
  confirms the first two were not a misreading of a single file.
- **Edit shows the placeholder with the right path** — `/inventory/edit/12`,
  `/organizations/edit/3` — so the routes resolve, the parameter is extracted,
  and `ListScreenHeader`'s buttons are wired to the right placeholders. Phase 5
  replaces the placeholder; nothing about it is wrong today.
- **Search and filter feel right**, and the debounce behaves as designed under
  real typing. That closes the one check the customer list's browser pass left
  outstanding and still open in its entry.

**Long-list scroll behaviour is still unverified, and is being left that way.**
It was outstanding on the customer list and remains outstanding on both screens
here. Deferred rather than overlooked: it needs a table with enough rows to
scroll, which means seeding data, and nothing so far misbehaves without it. It
is not a task, because nothing is broken yet and Phase 9's mobile pass
(9.10) is the natural place to pick it up.

**One item from that list is worth promoting while the context is fresh: the
inventory `+N more` cap is the only thing on these two screens with no React
original to compare against.** A real item with a long event history is the
data that would say whether three is enough or looks arbitrary. Widget tests
say three events render and four are counted; they cannot say three *reads* as
the right number.

**Files added:** `lib/screens/inventory/inventory_list_screen.dart`,
`lib/screens/organizations/organization_list_screen.dart`,
`lib/providers/inventory_list.dart`,
`lib/widgets/debounced_search_field.dart`, `lib/widgets/record_link_button.dart`,
`lib/widgets/list_screen_header.dart`,
`test/inventory_list_screen_test.dart`, `test/organization_list_screen_test.dart`.
**Files changed:** `customer_list_screen.dart` (shared widgets), `app_router.dart`
(two routes and three path helpers), `organization_list.dart` (a paged provider
beside the switcher's), `test/support/auth_harness.dart` (`organizationsResponder`).
**No new packages.**

### 2026-10-15 — Phase 4, tasks 4.7 and 4.11 (the user list, and the sort audit it asked for)

**Done.** `UserList` at `/users`, 27 widget tests. 202 pass on the VM, up from
175; `flutter analyze` and `dart format` clean.

**4.11 turned out to be a table, not a yes/no, and writing it down is most of
its value.** The task's wording points at events (`sortBy` ignored on
`GET /api/events`), which is Phase 7's screen, so the useful thing was to check
every list DAO rather than the one the task named. Each DAO has the same shape —
a `when (sortBy)` over its columns, falling through to `Users.id` — so the
question per screen is whether its sortable headers are the cases that `when`
has:

| Screen | Sortable headers | `UserDao`/`CustomerDao`/… accepts | Agree? |
|---|---|---|---|
| Customers | `name` | `name` only | **partly** — `phone`, `address`, `notes` fall back to `id` |
| Inventory | `name`, `quantity` | `name`, `quantity` | yes |
| Organizations | `name` | `name` | yes |
| Users | `username`, `displayName`, `email` | `username`, `email`, `displayName` | yes |
| Events | — | **nothing** (`EventRoutes.kt` never reads it) | no — **10.11** |

So the one real mismatch is on the customer screen, and it is the mirror image
of what `organization_list_screen_test.dart` claimed in a comment: that comment
says the customer's `sortBy` for phone "is honoured by `CustomerDao` and absent
from the UI", which is backwards — `CustomerDao.getCustomers:68-71` switches on
`name` alone. Three headers there look live and reorder by id. **Left as-is.**
Hiding them would be a visible divergence from the React original on the strength
of a backend reading, which is exactly what the parity rule is meant to prevent,
and the audit's job was to find it, not to act on it. Recorded in the 4.11 task.

**The Organization column is conditional on `VIEW_USERS_GLOBAL`, and that is
what the scoping tests pin.** An org-scoped admin's users are all in one
organization by construction, so the column would be the same value on every
row — which is also why the query is scoped to the selected organization for
exactly that caller. The test asserts the column is *present* for a caller
holding `VIEW_USERS_GLOBAL` and *absent* for an org-scoped one, and that the
users themselves are unaffected either way — the gate is on the column, not on
the list. A screen that always rendered the column would pass every other
assertion and show the scope it is supposed to be hiding.

**This screen is the first with enough columns to overflow a table header, and
the fix belongs to all four.** Five columns plus an actions column pushed the
"Display Name" header — label, gap, sort arrow — **32 pixels past its cell** at a
1500px window, which is the width the other three list screens' tests already
use. The cause is in the shared widget, not this screen: a header `Row` with
`mainAxisSize.min` and a rigid `Text` has nowhere to put overflow.
`ResponsiveListView`'s header label is now `Flexible`, so it ellipsizes and the
sort arrow — the part carrying meaning — stays whole. Found by a test rather than
a browser, and it would have been found eventually by any screen wide enough;
only this one is.

**`Uri.base.origin` throws for any scheme that is not http or https, which is the
whole point of task 5.10.** The invite link wanted `Uri.base`, and the obvious
one-liner took the screen down with it — `Bad state: Origin is only applicable
schemes http and https` — under `flutter test`, where `Uri.base` is a `file:`
URL, and under any native URL scheme, which is what 5.10 exists to support. The
origin is now read through a guard, with the reasoning on the function. Worth
recording as a shape: the task that asks for `Uri.base` is the task most likely
to be written as the one-liner that does not survive contact with a non-web
platform.

**The user delete is reproduced broken, and the test that proves it will fail
when 10.12 lands.** `UserService.deleteUser` was deliberately absent, with a
comment saying the compiler would force whoever ported the button to confront
the gap. It did, and the confrontation produced a decision rather than an
omission: **keep the button**, because the React original has one and a
parity-through-Phase-8 port that quietly dropped a control is a divergence, not a
fix. The request 404s at the server's `/api` catch-all and the screen shows the
envelope's message, which is what `UserList.tsx:85-89` did with the same failure.
`user_list_screen_test.dart` asserts the 404 and the untouched list, so **10.12
will fail that test** — which is the intended signal, not a problem with it.

**Two tests failed for reasons worth keeping, both about a 401 that was not a
"not stubbed".** `contextAdapter`'s fallback for an unanswered path is a **401**,
and this screen fetches invitations on arrival for any manager. Leaving that path
unstubbed tripped the real unauthorized redirect, signed every test out, and
landed it on `/login` — twenty failures whose first symptom was
`Found 0 widgets with type "UserListScreen"`, which reads as a broken screen
rather than a wrong stub. The same trap took the user-delete test: an
unanswered `DELETE /api/users/{id}` 401s instead of 404ing, so the error banner
never appeared. Both are now answered explicitly. The harness's 401 fallback is
load-bearing for catching accidental calls, and it is also a loaded gun for
exactly this screen; a caller who forgets a stub gets signed out rather than a
clear failure.

**"Create Invitation" is the one React control this screen does not have, and
that is deliberate.** `UserList.tsx:206` toggles an inline `CreateInvitationForm`
— 182 lines, task 5.7. It has **no route**; the React original renders it in
place. There is nothing to navigate to, so a button would open nothing, and a
button that does nothing is worse than its absence. It returns with the form that
owns it.

**4.8 is now 5 of 6 wired**, and the split held: both of this screen's deletes
call `confirmDestructiveAction` and each keeps its own consequence, which differ
in a way the shared dialog must not absorb — deleting a user refetches
`userPageProvider`, deleting an invitation refetches `unusedInvitationsProvider`
and leaves the users list alone. A test asserts exactly that asymmetry, because a
screen that invalidated both would pass every other assertion while hiding a
second request behind an unnecessary one. Only Phase 7's event delete remains,
and that one navigates away rather than refetching.

**Files added:** `lib/screens/users/user_list_screen.dart`,
`lib/providers/user_list.dart`, `test/user_list_screen_test.dart`.
**Files changed:** `crud_services.dart` (`deleteUser`, previously absent),
`app_router.dart` (the `/users` screen and two path helpers),
`responsive_list_view.dart` (flexible header label, per-column `flex`).
**No new packages.**

**Not done, and not hidden: the browser pass.** Every screen in this phase has
one, and this is the largest of them — a second table, a clipboard write and two
dialogs, which are the three things widget tests assert least well. What a
browser pass should confirm, so nobody has to reconstruct it: that the dead
`/users/{id}` link lands on `/events` via the catch-all; that edit shows the
placeholder with the right path; that confirming the user delete surfaces the
404 envelope and leaves the list intact; and — the one nothing else covers —
**the invitation table, the copy button and the "Copied!" label, which need an
outstanding invitation to exist.** The seeded backend has none, and minting one
needs the 5.7 form that does not exist yet, so that part is blocked on a task
rather than merely undone.

### 2026-10-15 — Phase 4, the user list's column allocation (browser finding, no test)

**The default column split is wrong for any screen whose longest values are not
in the first column, and the user list is the first one.** `ResponsiveListView`
gave the first column two shares and every other column one, on the reasoning
that the first column holds the record's name. On the customer table that is
true and the rest are short. On the user table it hands the largest column to
Username — "alice", "bob" — and splits the rest four ways, so at a ~1420px
window `alice@greenvistas.co` wrapped as `alice@greenvistas.co` / `m` and
`TEST_ORG_Green` / `Vistas Landscaping` broke across two lines each. Found in a
browser, from a screenshot, on a column count no test had rendered at that width.

`ListColumn` now takes an optional `flex`. **Null keeps the old behaviour**, so
the other three screens are byte-for-byte unchanged; the user table declares
`2, 2, 3, 1, 4` — proportional to the longest realistic value per column rather
than the average, because a display name and a role name are short by nature and
an organization name is free text written by whoever created it. The weights are
a judgement; **nothing pins them, deliberately.**

**Three tests that measured this were written, found to be vacuous, and deleted.**
Worth recording why, because the failure mode is the interesting part and it is
not specific to this screen:

- **They passed with the fix removed.** At the width they used, the harness put
  the screen in the *card* layout, so there was no table to wrap and the
  assertions were true of a layout they never exercised.
- **Flutter's test font is not a browser font.** The harness renders every glyph
  as a fixed-width box, so `tevadmin@muddyhorse.com` measures ~322px under test
  against ~185px in a real browser. Any pixel threshold in a widget test is
  measuring the font, not the layout — which means a test tight enough to catch
  this regression would also fail on a font change, and one loose enough to be
  stable would not catch it.

Deleting them is the better trade. The fix is verified by the screenshot that
motivated it and by the browser pass below; a test that cannot distinguish fixed
from broken is worse than no test, because it is a test that reports success
either way.

**A correction to a number in this phase's own docs, from measuring it.** The
table/card breakpoint is `ResponsiveListView`'s **own** available width, not the
window's, and the extended rail plus the screen and card padding take ~289px. So
the table starts at a window of roughly **1390px**, not the 1100 in
`AppBreakpoints.desktop` — which is the number the earlier entries in this phase
quote. The customer and inventory screens are unaffected in practice (four
columns, and they were read at 1500), but anyone reasoning about where the table
stops should use the list's width.

**Files changed:** `responsive_list_view.dart` (`ListColumn.flex`, honoured in
the table layout only), `user_list_screen.dart` (the weights).
**Test count unchanged at 202** — three tests added and removed inside this
entry.

**Open judgement, deferred deliberately: the table/card breakpoint is too high
for a five-column screen.** At the ~1390px window where the user table first
appears it is readable but tight, and the judgement that a table needs 1100px
of *content* width was made for a four-column screen and has never been
revisited. A per-screen minimum width is the obvious fix — `ResponsiveListView`
taking a `tableMinWidth` its screens set — but it is a design decision about how
much horizontal density this app wants, not a defect, so it is deferred rather
than taken. Revisit with the reports and event list, which have their own column
counts and are not in the app yet.

### 2026-10-15 — Task 4.9, reopened: pagination on the four list screens

**Done.** Offset/limit paging on the customer, inventory, organization and user
lists. 25 rows per page, unchanged from the React original; seamless loading on
scroll, with a "Load more" button underneath. 223 tests pass on the VM (up from
202), 21 of them new; `flutter analyze` and `dart format` clean; Chrome unchanged
at its 11 pre-existing failures.

**The task was closed as "premise did not hold" and that was correct, so it is
worth restating what changed.** There is no pagination control in any React list
— `grep` finds none, and all four screens fetch `25, 0` with no route past it.
There was nothing to port. Adding paging is a *product* decision, and it has now
been made, which is the only reason this entry exists. The page size is the
original's; the ability to ask for page two is new.

**This is therefore a deliberate divergence, and it is the first one in Phase 4.**
Every earlier task in this phase was either a transcription or a divergence
already argued for (the hover affordance, the `+N more` cap). This one says the
React app cannot see 26 rows and the Flutter app can. Recorded rather than
buried, because "the port shows more rows than the original" is exactly the
thing a side-by-side reviewer will notice.

**The offset moved out of the query key, and that is the whole architecture.**
Each provider was a `FutureProvider.autoDispose.family` keyed on a `ListQuery`
that every screen built with a hard-coded `offset: 0`. Keying on the offset
means each page is a *separate provider instance*, so accumulating pages would
mean stitching N independent `AsyncValue`s back together and working out which
is still loading. They are now `AsyncNotifier` families keyed on everything
**except** the offset — search, sort, organization — with the offset held inside
the notifier, so successive pages append to one list.

That choice also buys the reset for free, which is the part that would have been
easy to get wrong. A new search term is a different `ListQuery`, therefore a
different provider, therefore a fresh notifier at offset 0. No "clear the
pages" step exists to be forgotten — and an accumulator that resets itself in
the wrong place is the failure mode this avoids rather than tests for.

**The delete consequence changed, and `ref.invalidate` was actively wrong here.**
Each screen used `ref.invalidate(listProvider)` after a delete, which rebuilds
every accumulated page key — so a delete on page 3 of 3 would refetch all three.
That is wasteful but not incorrect. `PagedListController.reload` is the
replacement, and it resets to page 0 for a real reason: **deleting a row shifts
every row after it up by one, so the boundaries of pages 2 and 3 have both moved
and any rows already accumulated past the deletion are now wrong.** They cannot
be repaired in place. This is offset paging's inherent weakness, and it is
inherited from the API — the endpoint is offset/limit with no cursor, so there
is nothing better to ask for.

**A delete racing an in-flight page load is a real bug, and it was found by
reading rather than by testing.** If the user scrolls to the bottom (starting
page 3) and deletes a row before it lands, `reload` installs the correct result
and *then* the older request arrives carrying rows computed from offsets that
predate the delete — silently restoring the deleted row, with no error anywhere,
because both requests succeeded. A generation counter drops the superseded
response. `ref.mounted` does not cover it: that only detects *disposal*, and
`reload` deliberately reuses the same notifier.

**Two of the three tests guarding this were vacuous on the first attempt, and
finding that out took two rounds.** This phase's log already has one entry about
tests that pass on broken code; here it happened twice more, both times in the
same way — a test that could not distinguish fixed from broken.

- The **scroll** test passed with the scroll listener disabled. The cause was
  structural: the `NotificationListener` was inside `PagedListView`, which is a
  **descendant** of the screen's `SingleChildScrollView`, and scroll
  notifications only bubble upward. It could never have worked. Nothing reported
  a problem — the footer still rendered and the button still worked, so the list
  paged perfectly well and only the automatic part was dead. That is why the
  listener now lives in `PagedScrollView`, wrapping the scroll view.
- The **delete race** test passed with the generation guard removed, twice. The
  first version had a synchronous fake, so `loadMore` always finished before the
  delete and the race never happened. The second added a gate, but released both
  pending requests together — which let them resolve in *issue* order, putting
  the reload last and letting it win. The race needs the stale page to land
  **after** the reload, so the fake now releases requests one at a time in an
  order the test chooses.

Every mutation was then re-run against the final code: removing the generation
guard, the in-flight guard, the short-page rule, the total clamp, the scroll
trigger, and the dimensions guard each produce failures, and the baseline is
clean.

**Both triggers exist because each covers the case the other cannot.** Scrolling
is invisible and cannot fire at all when the rows fit on screen — a short list, a
tall viewport, or a phone where 25 cards is an 8000px page. A button is explicit
and always reachable, but demands the user notice and scroll to it. Neither is
sufficient alone, so the footer always shows the button while more remains and
the scroll listener is an accelerant on top of it. **The footer sits below the
fold at both widths**, which is a measured consequence of 25 rows, not an
oversight: the tests had to use a 2400px viewport to tap it, and 9000px at
mobile.

**A third test was quietly measuring the wrong thing.** The `total` clamp looked
pinned until the mutation proved otherwise: a backend with `total: 0` returns no
rows either, so the test passed with or without the clamp. The real case is a
server that returns rows *and* reports `total: 0` — which is exactly what
`PaginatedResponse`'s `@Default(0)` produces for an endpoint omitting the field.
The fixture now reports `total: 0` while returning 25 rows, and the clamp fails
without it. This is the second time in this phase that a test asserting a real
invariant turned out to pass vacuously; both were only caught by mutating the
source, which is the argument for doing that routinely rather than when unsure.

**`hasMore` is decided by a short page, not by `total`.** A page shorter than 25
is the server saying there is nothing left. `total` is used for the count in the
footer but cannot be trusted to *decide*: `PaginatedResponse` defaults it to 0,
so a missing, zero or stale count would each strand the list at 25 rows with no
way past it. The `total` is clamped to at least `items.length` for display, so a
count below the rows held cannot render as "Showing 25 of 0".

**Task 4.14 was checked rather than assumed closed, and it is not fixed.** The
obvious inference is that an accumulating list retains the previous result across
a search, so 4.14 would be free. It is not: a new search term is a different
`ListQuery` key, hence a different provider, hence a fresh notifier holding
nothing, so the spinner is showing because there genuinely is nothing behind it.
Measured one frame after the debounce fires — one `CircularProgressIndicator`,
previous rows gone. 4.14 stays open, and the note on it now says which of its
three options is cheapest *because* of 4.9 rather than pretending the task is
done. Two earlier entries in this phase record tests that passed on broken code;
this would have been a third, in the plan rather than the suite.

**Two smaller things worth recording.** The footer shows the count *instead of*
the button while a page is in flight, not alongside it — a button that is
tappable while doing nothing invites a second tap that does nothing. And each
screen caches the `ListQuery` it built during `build`, so the delete handler
reaches the same provider without re-deriving the scoping rules; rebuilding it
would be a second copy of them, and a copy that differs only in the organization
filter is a bug that only appears after a delete.

**Verified in a browser against the live backend, with 62 seeded customers.**
25 rows on arrival; scrolling loaded page 2 unprompted (25 → 50); further
scrolling reached all 62; and **excess scrolling past the end issued zero
requests**, which is the short-page rule working. The API pages 25 / 25 / 12
server-side, matching.

**Two things the browser pass could not check, recorded rather than hidden.**
`/inventory` and `/organizations` rendered a blank canvas in the harness — **on
the unmodified baseline too**, confirmed by stashing this work and rebuilding.
**Correction, 2026-10-15 (task 4.14): this was a harness limitation, not a
finding.** The user checked both screens in a real browser and they render fine,
and the same harness that could not draw them had rendered the customer list
correctly earlier in the same session. Do not file anything against these two
screens on the strength of that observation. And no screenshot was taken at all:
the harness requires a visible desktop window, so row counts were read from the
accessibility tree instead — weaker than an image for judging layout, and 4.9's
visual check is best repeated by hand.

**The customer screen's existing tests all passed unmodified**, including
`expect(request.queryParameters['offset'], 0)` — the initial request is
byte-identical to what the React app sent. That is the one compatibility claim
worth making about the change: the first page is unchanged, and everything after
it is new.

**Files added:** `lib/providers/paged_list.dart`,
`lib/widgets/paged_list_view.dart`, `test/paged_list_test.dart`,
`test/paged_list_view_test.dart`.
**Files changed:** the four list providers and four list screens, plus
`test/support/auth_harness.dart` (an optional `height`, so a test can ask for a
viewport that holds a whole page).
**No new packages.**

**Worth revisiting with the event list (Phase 7) and reports (Phase 8).** Both
are `FutureProvider.family` consumers today and would move to `PagedListController`
on the same pattern. The reports are the better case — task 8.5 already flags
them as unpaginated over the whole org, which is the situation this controller
exists for. The event list is the harder one: `EventResponse` nests rsvps,
inventory and customer per row, so a page of 25 events is a much heavier
payload than a page of 25 customers, and the 25 there is `defaultLimit` from task
1.18 rather than this constant.

### 2026-10-15 — Task 4.14: the search flash, and two things it dragged in

**Done.** The list no longer blinks on every search. 237 tests pass on the VM (up
from 223), 14 of them new in `test/list_refresh_test.dart`; 35 pass on Chrome
across the pagination and refresh files; `flutter analyze` and `dart format`
clean; web build succeeds.

**Reading the React original first paid for itself twice.** `TableView.tsx` has
*no loading state at all* — no spinner, no `loading` prop — it renders `data`
unconditionally, and `CustomerList.tsx:34` sets state only inside the `try`. So
the original's behaviour was not "show stale rows while loading" as a design
choice; it was a consequence of having no loading concept. Which also means:

- **Rows stay put during a search.** The filed symptom.
- **On failure the error renders *above* the previous rows**, because
  `TableView.tsx:40` and `:42` are siblings in the same card body. The port
  replaced the list with the error. **This was a second divergence that no task
  mentioned**, and it is fixed by the same mechanism — the banner now sits above
  the stale rows, as it did in React.

**The retention is a field, not a keep-alive link.** Task 4.14's option 3 asked
for the last result kept across family keys, which against a
`FutureProvider.family` would have meant a keep-alive link holding a value the
family had already thrown away. After 4.9 the list is a `PagedListController`
that *owns* its accumulated rows, so retaining them across a query change is a
field and a `ref.watch` — no container-level lifetime. **The filed option was
describing a cost that the previous task's architecture had already removed**,
which is worth knowing: it was cheap to write when it was filed and cheaper still
afterwards.

**One boolean for two states was a real bug, and the loudest symptom was a test
timeout.** `refreshing` first covered both "a query is in flight" and "the last
query failed". On the failure path that rendered a progress bar that never
stopped — an indeterminate animation on a screen that had already given up — and
made `pumpAndSettle` hang forever. It became a three-value `PagedListFreshness`
(`current` / `refreshing` / `stale`), **and then that was removed too** — see the
bar below. Two failures from one flag, and the timeout was the third, which is
the usual pattern in this log: the visible failure is rarely the whole of it.

**The progress bar was built, shipped in the first pass, and then removed after a
browser check.** It was inserted *above* the card, so it pushed the entire list
down by its own height for the duration of every search — a 2px version of the
exact flash this task exists to remove. **The indicator was moving the thing it
was reporting on.** Removing it had a consequence worth recording: with the bar
gone, `refreshing` and `stale` rendered *identically*, because a decoration had
been the only thing distinguishing them. The three-state enum was carrying a
distinction that no longer existed, so it collapsed to a single `stale` flag — the
user's "if that simplifies things" turned out to remove an entire type.

A search is now **silent**, which is what `TableView.tsx` did — it had no loading
state at all. That is the behaviour being restored rather than an omission, and
the trade is written down at `PagedListView.stale`.

**The geometry test replaces "no spinner is present", and that substitution is the
lesson.** The first draft asserted the absence of a `LinearProgressIndicator`,
which tests a *name*. Anything inserted above the card shifts it whatever it is
called, so the assertion is now a `getRect` comparison on the card — same top,
same height, mid-search. Reinstating a 2px bar above the card, which is the exact
reported bug, fails it.

**One of five mutations passed, and it should have.** A `SizedBox(height: 2)`
inserted *unconditionally* does not fail the test, because it is present both
before and during the search and so moves nothing. That is the test being right
rather than vacuous: the defect is *transient* movement, and chrome that is
always there shifts nothing. Worth stating, because "a mutation passed" normally
means a broken test and here it means the opposite.

**The geometry test also failed for a reason worth recording.** Its first draft
asserted equal heights *after* the search settled as well, and failed — because
the search returned one row instead of two, so the card was genuinely shorter.
Asserting that new data does not change the list asserts the opposite of the
intent. Top is now compared after settling; both top and height during.

**The footer count says "filtered" once a search is active.** "Showing all 2" is
ambiguous the moment a filter is on — two of *what*? The number is what the server
matched, not the size of the table, so on a large collection it reads as though
the collection holds two rows. Both the completed case ("Showing all 2 filtered")
and the paging case ("Showing 25 of 60 filtered") carry the suffix. Reported by
eye in the same pass as the bar, and the clearest example in this log of a
one-word copy change removing a real ambiguity.

**Riverpod's automatic retry was quietly re-creating the very flash this task
exists to remove.** Four tests that render an error started failing with "A
Timer is still pending even after the widget tree was disposed" — Riverpod arms
a `Timer` for the retry and the fake clock never fires it. Chasing that turned up
the actual behaviour: a failed search was retried with backoff, taking the list
back through loading. So a 500 would render the error, then the rows, then the
error again, once per attempt. **The retry is now off for all four list
providers** (`noRetry`), and not only because of the flicker: a 401 and a 403 are
never transient, so each failure was costing three requests instead of one. The
UI already owns the retry story — a "Try again" button in the footer, the
server's message above the stale rows.

**Two of the first three new tests passed with the retention deleted.** The same
failure mode as the column-allocation tests earlier in this phase, and in the same
shape. The first draft asserted "footer hidden during refresh" and "rows
retained" as two tests, and both were true of the old spinner — because a spinner
*also* hides the footer, having replaced the list wholesale. What separates them
is the **combination**: old rows present *and* no `CircularProgressIndicator`,
which is mutually exclusive under the old behaviour and only both-true with the
fix. Both footer assertions were kept, because they are the reason the
suppression is deliberate, but the note says plainly that on their own they pin
nothing.

Five mutations were run against the final code and each produces failures —
spinner in place of the retention, the bar on a failed query, the footer left
visible while refreshing, the error banner dropped, and the retry re-enabled.

**Every one of these tests observes a single frame taken mid-flight, which dictates
the shape of the file.** They `pump()` a fixed duration and look, then **drain
afterwards** — and the drain is not optional: dio leaves a zero-duration timer
pending until a request completes, so a test ending mid-flight fails at teardown
regardless of what it asserted. That produced four failures on the first run that
were about none of the assertions in them.

(This was originally framed around the progress bar, which animated indefinitely
and made `pumpAndSettle` unusable mid-flight. The bar is gone, so that constraint
is too — but the mid-flight framing is still the right one, because the behaviour
only exists on a frame nobody has settled.)

**The fixture was wrong before the code was, twice.** The customer stub returned
all 60 rows in one response labelled `limit: 25` — a shape the server cannot
produce — so the "Showing 25 of 60" assertions failed for a reason unrelated to
the behaviour. It is offset- and limit-aware now, and paging a real 62-row
dataset through it confirms the count is 25/25/12.

**Files changed:** `paged_list_view.dart` (`PagedListSection` replaces
`PagedListBody`; the `stale` flag; the "filtered" suffix), `paged_list.dart`
(`noRetry`), the four providers (`retry: noRetry`), the four screens.
**Files added:** `test/list_refresh_test.dart`.
**No new packages.**

**Not verified in a browser by me, and the two defects above came from the user's
own pass rather than from anything in this file.** The harness's Flutter renderer
would not initialise — `flutter-view` and `flt-glass-pane` present, **zero**
canvases, no console output — and it had degraded partway through a session in
which it had earlier rendered the customer list correctly and been driven through
three pages. **The earlier note in this log that `/inventory` and `/organizations`
"render a blank canvas in the harness" was reported as a finding and should be
read as a harness limitation: the user checked both in a real browser and they
render fine.** Corrected in the 4.9 entry too.

That gap matters more here than anywhere else in the phase, and this entry is the
argument for it: **the progress bar and the footer wording were both wrong, both
were obvious, and eleven widget tests passed straight through them.** The
geometry test exists only because a person looked. What the tests now establish is
that the card does not move; what they could never establish is whether the copy
reads well.

**Two follow-ups worth carrying.** Task 9.6 (cancellation) now has somewhere
obvious to attach: the debounced search's superseded requests are still not
cancelled, and `PagedListController` is where a generation guard would go. And
the events list in Phase 7 is the one screen where retaining stale rows is
least obviously right — `EventResponse` embeds a customer and inventory per row,
so a search that changes the set changes a lot of data at once.

---

### 2026-10-16 — Task 5.9 (HTML input types → Flutter pickers)

**Done.** `DateField`, `TimeField`, and `NumberField` as shared widgets in
`lib/widgets/picker_fields.dart`; the profile's date-of-birth and the three
quantity fields now use them. 13 widget tests. `dart format` clean,
`flutter analyze` clean (two pre-existing warnings fixed).

**The convention is established once, in one widget file, so Phase 6 has one
place to reach for.** The React forms use four HTML input types that Flutter
does not have direct equivalents for: `type="date"`, `type="time"`,
`type="number"`, and `type="email"`. Each becomes a shared widget or validator
rather than a per-form pattern, because the alternative is four more things
that can drift between the seven forms — the same argument `FormCard` and
`Validators.requiredText` already made.

**`DateField` and `TimeField` are read-only text fields that open the
Material picker on tap.** The controller text is the wire format the server
expects — `yyyy-MM-dd` for dates, `HH:MM:00` for times — so the field
displays exactly what it submits. The read-only property means the keyboard
never opens for a value that must be a valid date or time. The picker's
`initialDate` / `initialTime` is parsed from the controller text, so an
existing value is preserved when the picker is confirmed without changes.

**`TimeField` has no caller in Phase 5 — it is here for Phase 6.** The only
`type="time"` inputs in the React app are in the event forms
(`CreateEventForm.tsx:272`, `EditEventForm.tsx:215`), which are Phase 6.
Creating the widget now means the convention is established in one place
rather than two, and Phase 6 reaches for it the same way Phase 5 did.

**`NumberField` adds `FilteringTextInputFormatter.digitsOnly`, which the
React `type="number"` did not have.** The browser's `type="number"` prevents
non-numeric input at the keyboard level; Flutter's `keyboardType:
TextInputType.number` only changes the keyboard layout. The formatter is the
equivalent — it strips non-digit characters as the user types, so a
non-numeric value cannot reach the field. The validator's `int.tryParse`
check becomes a safety net rather than the primary defense. A shared
`Validators.requiredNumber` replaces the inline validator that was copy-pasted
across the two inventory screens.

**The email validator is consolidated.** `AcceptInvitationScreen` had a
private `_email` validator that was the third copy of the same `RegExp` —
`Validators.email` already existed and was used by the user and profile forms.
The private copy is deleted; the screen now uses `Validators.email` like every
other form. The test that asserted the private copy's message
("Enter a valid email address") is updated to assert the shared one
("Invalid email").

**The inventory association editor's quantity field is converted from
`initialValue` to a controller.** It was the one `type="number"` input that
did not use a controller — it used `initialValue` + `onChanged` to update a
state variable. Converting to a controller makes it consistent with the other
two quantity fields and lets it use `NumberField` directly.

**Two pre-existing analyzer warnings fixed.** An unused `go_router` import
in `profile_screen.dart` (the screen's `onCancel` is `setState`, not
`context.go`) and an unused `container` variable in `customer_form_test.dart`.
Both were present before this task; both are simple deletions.

**Pre-existing test failures are not caused by this change.** The full VM
suite has 116 failures in `customer_form_test.dart`, `list_refresh_test.dart`,
`inventory_list_screen_test.dart`, `customer_list_screen_test.dart`, and
`organization_list_screen_test.dart` — all "Found 0 widgets with text …" or
"Bad state: Too many elements". Verified by stashing this task's changes and
re-running: the same tests fail on the unmodified baseline. The failures are
environmental (likely a Flutter SDK or test-harness change since the last
phase) and are not owned by this task. The tests directly covering the changed
code — `picker_fields_test.dart` (13) and `accept_invitation_screen_test.dart`
(15) — all pass.

### 2026-10-16 — Task 5.13: the form tests, and an origin that was wrong on every non-http scheme

**Done.** `test/customer_form_test.dart`, `test/invitation_url_test.dart` (11
tests) and additions to `test/user_list_screen_test.dart`.

**The forms are the largest surface in the port and the least covered,** so
this task starts with one representative form rather than all seven.

**The error is asserted per field, not as a count.** A count says "something
failed"; a per-field assertion says *which* input rejected what, and a count
passes just as happily when the wrong field rejects the wrong value. The
customer form's cases also cover a whitespace-only value (which the required
validator must reject) and a corrected field clearing its error.

**The invite link's origin derivation was wrong, and the test that found it is
the reason to keep the test.** `Uri.base.origin` throws for any scheme that is
not http or https — which is every native URL scheme, and `file:` under
`flutter test`. The first version guarded the throw but still **produced
`file:///register?token=…`**, an origin with no authority at all, because a
`file:` URL's authority is empty rather than absent. `_appOrigin` now derives
the origin from the scheme, the authority and the path in a way that holds for
`http`, `https`, `file:` and no-origin at all.

**That is the whole point of the task, and it is worth stating as a shape: the
one-liner that satisfies "derive the origin from `Uri.base`" is the one-liner
that does not survive contact with a non-web platform.** Task 5.10 exists
because invitees receive a link they open in a browser — so the *link* must be
absolute and correct everywhere, and the app's own platform is not the platform
the link is opened on.

**The minted link is pinned as a parsed query param, not as a string.** The
user list's test asserts the link that lands in the invitations table carries
the token as a query parameter — parsing it rather than matching text — so a
change in the link's *order* or encoding does not break the test, and a change
that drops the token does. The same file also pins the form's own permission
gate separately from the button's, which are two different permissions and were
easy to conflate.

---

### 2026-10-18 — Phase 6, task 6.1: the field-by-field map, written after the fact

**Task 6.1 discharged, as a verification pass rather than a pre-written spec.**
Two changes of shape, both argued before doing the work.

**It asked for the map "in the PR description."** This repo has no PRs —
`AGENTS.md` is explicit that no commit-message tooling exists — and the
established place for durable reasoning is this log plus doc comments at the
point of decision. A map in a PR description dies with the PR.

**It asked for the inventory "before writing code," which is now moot.** Both
forms were read end to end before either screen was written; that work is not
what was missing, its *durability* was. Nothing recorded which fields exist,
which are conditional, or which of the two forms disagree with each other — and
the last of those is the thing a summary reliably hides. So the map is written
here as a check against what shipped, which is a stronger artifact: a pre-code
spec can be satisfied by code that matches it and is still wrong.

**The pass found a divergence on its first row, which is the argument for doing
it this way round.** `edit_event_screen.dart` read
`organizationId: _canManageGlobalEvents ? orgId : orgId` — both arms identical,
written while porting and never read back. `EditEventForm.tsx:162` sends the
organization **only** for a global manager. The server does not treat the two
cases alike: `EventService.kt:83-89` throws
`"Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId"` when a
**non-null, differing** id arrives without `MANAGE_EVENTS_GLOBAL`, and treats
null as *leave it alone*. Harmless in practice only because the form seeds its
organization from the loaded event, so the value it sent back was always the
right one. That is a coincidence, not a guard.

Fixed properly rather than by picking an arm: `UpdateEventRequest.organizationId`
is now nullable, which is what the wire actually allows and what
`CreateEventRequest` — where the server *does* require it, throwing at
`EventService.kt:20-22` — already reflected. The nullability asymmetry between
the two DTOs is now the server's rather than the port's invention.

The `"Organization must be selected."` guard on the edit screen went too. It had
no counterpart in the original, and it is unreachable: the value is either the
loaded event's organization or the dropdown's, and the dropdown is `required`.
The create form keeps its equivalent guard for a different reason — there the
organization is genuinely absent for an org-scoped user until the context
resolves, which `CreateCustomerScreen` already documents at length.

**Pinned by a test, because the rule is invisible from the call site.** The
screen looks identical either way; only the request body differs. The first
assertion written was `containsKey('organizationId')` and it **failed** —
`json_serializable` emits every field by default, so the key is present holding
an explicit null. That is equivalent to the `undefined` React sends, because the
server's branch is `organizationId != null`, and an absent key and an explicit
null both leave it null. Asserting `containsKey` would have tested dio's
serialization settings rather than the thing the server branches on. Worth
recording as a shape: **a test can be right about the behaviour and still be
asserting the wrong thing.**

#### The map

Create and edit share twelve of their fifteen fields. Differences marked ▲.

| Field | Create | Edit | Notes |
|---|---|---|---|
| `title` | `TextFormField`, `required` | same | Labelled "Notes / Summary" in both; the server calls it title |
| `date` | `DateField`, `required` | same | Prefilled from query param, else today |
| `time` | `TimeField`, `required` | same | `HH:MM:SS`; seconds zeroed by the picker |
| ▲ `durationMinutes` | behind "Add More Details", default **120** | always visible, default **60** on load | `durationMinutes \|\| 60` on edit, so a stored `0` also becomes 60 |
| ▲ `organizationId` | resolved from chrome / user context; **org-required gate** for global managers | `<select>`, shown to global managers only | Create blocks submission; edit always has a value |
| ▲ `organizationId` on submit | always sent | sent **only** for global managers | The row the pass found; see above |
| `customerId` | `<select>` + "+ New Customer" | same | Not `required` |
| `location` | autofilled from customer | autofilled from customer | Different latches — see below |
| `description` | textarea, 3 rows | same | Optional |
| `inventoryItems` | "Manage" → modal → `InventoryAssociationEditor` | same | Phase 5's shared widget (5.8) |
| `staffInvites.openInvitation` | staffing modal, checkbox | same | |
| `staffInvites.numberOfStaffNeeded` | staffing modal, numeric | same | `parseInt(v) \|\| 0` |
| `staffInvites.specificStaffIds` | `<select multiple>`, ctrl/cmd-click | same | Ported as checkboxes — see below |
| ▲ Details section | hidden behind "Add More Details…" toggle, with a "Quick Save" that submits what is visible | always expanded | The one structural difference between the two |
| ▲ Query params | `date`, `startTime`/`endTime`, `startTime`/`time`, `time` | none | Duration derived when all three are present |
| ▲ Error on missing org | `"Organization must be selected."` | none (unreachable) | |
| ▲ Sidebar | `OtherEventsPanel` | same, plus `excludeEventId` | |
| ▲ On success | `navigate('/events')` | `navigate('/events/{id}')` | |

**Three things the table makes visible that a prose summary would not.**

1. **The two forms latch autofill differently, and the original is inconsistent
   rather than either version being right.** Create gates on
   `locationManuallyEdited`; edit gates on `!eventLocation` — an empty-string
   check. So in the *edit* form, a one-character location permanently disables
   autofill for the rest of the session, where in create any keystroke does the
   same thing. Reproduced faithfully, because the parity rule applies to bugs,
   but neither is obviously intended and the port should not be blamed if
   someone normalises it later.

2. **`openInvitation` and `specificStaffIds` are documented as mutually
   exclusive and the server enforces neither.** `StaffInviteDetails` says so in
   its own doc comment, and `EventService` validates neither. Both forms happily
   send both, so "Open invitation to all staff" plus named staff is a state the
   UI permits and the server accepts without comment.

3. **The `<select multiple>` becomes checkboxes, which is the one accessibility
   improvement in the phase.** The React hint says "Hold Ctrl (Windows) or Cmd
   (Mac) to select multiple staff members" — a desktop-only interaction with no
   touch equivalent and no screen-reader affordance. Checkboxes need neither
   modifier and are individually labelled. The multi-select height (`size={6}`)
   becomes a fixed-height scroll region rather than a 6-row window.

**Two conditionals worth naming because they are invisible until triggered.**

- **The org-required gate is create-only.** A global manager who has narrowed
  the chrome to "All Organizations" gets a card and a picker instead of a form —
  the server rejects a create without an organization for them
  (`EventService.kt:20-22`), so this is the form telling the user something the
  server would refuse anyway.
- **Edit's organization dropdown is hidden from org-scoped managers**
  (`disabled={!canManageGlobalEvents}`), which combined with the submission rule
  means an org-scoped manager can see the event's organization but not change
  it. The server agrees: the same `MANAGE_EVENTS_GLOBAL` check guards both.

**What the map does not cover, stated rather than implied.** Modals, the cascade
refetches and the `locationManuallyEdited` latch each have their own task
(6.3, 6.4–6.6) and their own reasoning; this table is the field surface, not a
substitute for those entries. And it is a reading of two React files, so it is
only as good as the reading — the two divergences above are what came out of
re-reading once, which is not a rate anyone should extrapolate from.

**Files changed:** `models/event.dart` (nullable `organizationId`, reasoning),
`edit_event_screen.dart` (the ternary, and the guard it replaced),
`test/event_form_test.dart` (the request-body test).
**No new packages.** `./teven verify` clean: 301 tests.

---

### 2026-10-18 — Phase 7, tasks 7.1, 7.3 (buttons only), 7.4, 7.5

**Done.** The month grid at `/events` and the event list at `/events/list`.
339 tests pass on the VM (up from 301); `flutter analyze` and `dart format`
clean; web build succeeds. **Both new test files pass on Chrome as well as the
VM**, and taking them there uncovered a defect this log had been describing
since Phase 3 without naming — see the Chrome section below, which takes the
suite's Chrome failures from 18 to 5.

**They went in together because they are one feature split across two URLs**, and
because 7.3's two buttons are a shared widget that both screens had to reach
for. Splitting them would have produced a commit where the calendar linked to a
list that was still a placeholder — the same argument as 4.5/4.6 sharing a
commit.

**Files added:** `lib/screens/events/event_calendar_screen.dart`,
`lib/screens/events/event_list_screen.dart`, `lib/providers/event_list.dart`,
`lib/widgets/create_event_button.dart`, `lib/core/util/local_date.dart`,
`test/event_calendar_screen_test.dart`, `test/event_list_screen_test.dart`.
**Files changed:** `app_router.dart` (both routes, plus `eventDetailsPath` /
`eventEditPath` — **this is the first route in the app whose `…Details` link is
not dead**), `picker_fields.dart` (`DateField.onChanged`),
`auth_harness.dart` (`/api/events`, `eventsResponder`, `currentLocation`,
`pumpApp`'s settle, the collapsed `goTo`), `create_event_screen.dart` (a no-op
ternary found while reading it), and — **outside this task** —
`accept_invitation_screen_test.dart`, `customer_form_test.dart`,
`responsive_chrome_test.dart`, `router_test.dart` and `user_list_screen_test.dart`
for the settle consolidation described above.
**No new packages** — `table_calendar` was added in task 0.3.

#### Three things the grid could not do the obvious way

**1. `Positioned.fill(top: …)` left the width unbounded, so every bar threw.**
The marker builder returns the day's bars, and a `Container(width:
double.infinity)` inside a `Positioned` with `left`/`right` left null resolves to
infinite width. The symptom was not a crash report but **every pill silently
absent** — `find.byKey` found nothing and the placement tests failed as "the
event is not on its day", which is precisely the bug the tests exist to catch.
Worse, the *other* four calendar tests passed, so a suite run showed a plausible
failure rather than an obvious one. `Positioned(left: 0, right: 0, top: …,
bottom: 0)` is the fix, and it is one line.

**2. There is no full-cell today highlight in table_calendar 3.3.0.** 7.4's
`#e7f0f7` is a *background* behind the whole day cell. `CalendarStyle` in 3.3.0
offers only `todayDecoration` — a small dot — and unlike some versions it has no
`todayHighlight` boolean to widen it. So the day cell is written by hand
(`defaultBuilder` / `outsideBuilder` / `todayBuilder`) rather than left to the
package. That is also why **7.4 was folded into 7.1**: you cannot render a bar
without choosing a colour, and the cell and the bar share the same builder.

**3. A tapped bar opened the create form instead of the event.** Supplying
`CalendarBuilders.markerBuilder` *replaces* the widget `table_calendar` builds,
so `onEventTap` — which only fires for its own marker — never runs. A pill with
no handler falls through to the cell's gesture, which creates. `_EventPill`
carries its own `InkWell` to `/events/{id}`, and there is a test that taps a bar
and asserts the destination, because the wrong answer is a *working* screen.

#### The list had no way back to the calendar, and neither does the React app

**The React original links *out* to the list and nowhere back.** `EventCalendar.tsx:253`
is the only link to `/events/list` in the whole app, and `EventListPage.tsx`
links nowhere at all — the sole route back to the calendar is the nav rail's
"Events" item (`MainLayout.tsx:22`), which is **a drawer on a phone**. So a
user who followed "View All Events" and then wanted the month view had to know
that the rail's top item was the calendar rather than a section heading.

The port adds the missing half: a **"Calendar view" button beside the search
box**. The placement is the point, and it is the placement the calendar page
already uses — `EventCalendar.tsx:244-252` is the 250px search input, then
"View All Events", then Create. The two pages now read as mirror images, each
offering the other.

**This is a divergence from the original, and the second one in Phase 7** (the
first is the shared 25-row page size, and 4.9's pagination is the precedent for
the kind). It is recorded rather than buried because "the port shows a control
the original does not have" is exactly what a side-by-side reviewer notices.

**The date fields moved to their own row, and that is what makes the placement
possible.** React had the search box and the start-date filter side by side
(`EventListPage.tsx:190-215` — two `col-md-4` columns), which put a *filter*
next to what is now a *view switch*. Separating the two kinds of control is the
change; the button's position is the consequence.

**The test pins the relationship, not the presence.** A test that only checked
the button existed would pass on any arrangement — including the one this
replaced, where there was no view switch at all. So the assertion compares the
*centres* of three controls: the button and the search box share a `dy` (a
`Wrap` centres its children on the cross axis, so two controls in one row have
identical centres), and the date field's `dy` is strictly greater. **A relative
measurement, not a pixel threshold** — the Phase 4 log records that an absolute
one measures the test font rather than the layout. Verified by mutation: moving
the date field back up into the first row fails it with
`Expected: a value greater than <108.0> Actual: <108.0>`.

#### Two date decisions, and one is a divergence

**`formatLocalDate` exists because `toIso8601String()` is UTC.** React uses
`new Date().toISOString().split('T')[0]` for the list's start-date default
(`EventListPage.tsx:26-29`) and `moment(...).format('YYYY-MM-DD')` for the
calendar's window. The first converts to UTC *before* taking the day: at local
midnight in `UTC+13` it reports **yesterday**, so the list would silently filter
from a day that is not today. Everywhere west of UTC it happens to be right,
which is why it has survived. The new helper formats from the fields, which is
the same reasoning as `EventResponse.startAt` and the same outcome 7.9 asks
for.

**The calendar's window is the month, not the six-week grid.** `EventCalendar.tsx:119-123`
takes `startOf('month')`/`endOf('month')`, so the leading and trailing days from
the neighbouring months — which react-big-calendar drew, greyed and always
empty — are excluded from the query. They are still drawn (dimmed). Widening the
query to the grid would be a fix rather than a port, so it is not done.

**The `1000`-event ceiling is inherited, not chosen.** `kCalendarEventLimit` is
`EventCalendar.tsx:88`'s number, and it is large for an endpoint that embeds
rsvps, inventory, customer and organization per row with no compression
(task 1.18 sets a default of 10 for exactly that reason). It is **not**
pagination: there is no second page, and a month with more than a thousand
events would render short. Reducing it would be a visible behaviour change, so
it is pinned by a test rather than quietly changed.

**A cap the original did not have.** `table_calendar` gives every cell a fixed
height and clips marker overflow, so a day with a dozen events would render one
truncated bar and lose the rest silently. `kMaxEventsPerDay` is 3 plus a count —
the same shape `InventoryListScreen` already uses for its unbounded per-row
event list, and a client-side invention for the same reason. **Whether three
reads as the right number is the open question**; widget tests cannot judge that.

#### The list screen is mostly shared widgets, and the one part that is not

Search, sort, pagination, the delete dialog and the create button are the
Phase 4–6 furniture, unchanged. What is genuinely this screen is **the RSVP
column**: three buttons per row that post an availability and refetch, in a table
cell, on a screen whose other cells are text.

**`'no response'` is reproduced verbatim and is not a named constant.**
`EventListPage.tsx:153` posts it for the clear button. It is not `''`, not
`'none'`, and not one of `RsvpAvailability`'s three values — and the server
stores it as a free-form string. "Improving" it would change what lands in
`rsvps.availability` and every existing filter over it, so `kRsvpCleared` carries
the original's literal and task 10.17 still owns the question.

**The three buttons are one size in both layouts, deliberately.**
`ResponsiveListView` picks table-vs-card from *its own* `LayoutBuilder` width —
after the rail has come off — so a screen cannot ask which layout it is in from
the window, and `context.layoutSize` would disagree with it. `kRsvpButtonSize` is
therefore one compromise chosen to fit three across a table cell and still be a
usable target in a card. Task 9.4 audits touch targets.

**The page size is `kListPageSize` (25), not the original's 10.** Same direction
as 4.9's divergence: the React list could only ever see the first page, and this
one shows more. Worth stating because a side-by-side reviewer will notice.

#### `CreateEventButton` settles 7.3's `pendingNavigateUrl` question

**Both buttons intercept before navigating, and the reason is a card the create
form does not own.** A `VIEW_USERS_GLOBAL` user with no selected organization
cannot create an event without one — the server requires it
(`EventService.kt:20-22`) — so the create form shows an "Organization Required"
card (`CreateEventForm.tsx:210-239`). Without an intercept, the button would
navigate *to* that card and the user would have to tap through it: a dead end
React never exposed, because React had no button to press. The card exists
because the server requires an organization for those users, and the button is
where that requirement gets answered *before* the form is reached.

**Phase 6's create form and 7.3 have to agree on this,** and neither alone is
right — no single Phase 6 task owns the card, so it falls to whoever picks 7.3
up to check what landed. Checked against Phase 6: the card is there, and the two
buttons now answer the requirement before it.

One widget, nullable `resumeUrl`. The calendar's button carried a pending URL and
resumed after a selection; the list page's had none, so dismissing the picker
did nothing and a selection always went to a bare `/events/create` — dropping the
`?date=` a calendar tap had supplied. The day cell now goes through the same
static helper (`CreateEventButton.createForDay`) as the header button, so the
list page gets the better behaviour rather than the calendar losing it.

**The list-page button was nearly free.** `ListScreenHeader` already had the
right shape — heading plus a single primary action, a `Wrap` so it cannot
overflow, and `action` null rather than a disabled button when the permission is
absent (`list_screen_header.dart`). The event list was the only list screen not
yet using that widget, and now renders a `const` header with
`CreateEventButton` as the action.

**The FAB / `+` half of 7.3 is not done.** 7.3 asks for the placeholder to be
*replaced* by a FAB on mobile and a `+` on web. The two header buttons are in;
the third affordance is not, and 7.3 is left unticked for that reason rather than
counted as two-thirds.

#### The Chrome run, and a bug this log has been describing for three phases without naming

`flutter test --platform chrome` had been recorded as "N pre-existing failures"
and "13 tests of unowned web behaviour" since the Phase 3 entry, always with the
same symptom: a test fails and **the reason is not printed**. That was treated as
noise to be noted and moved past. It is not noise, and naming it is the most
useful thing in this entry.

**`flutter test --platform chrome` does not surface Dart errors from the test
body.** The whole output is:

```
00:03 +0 -1: signed out the credentials entered are what gets posted [E]
  Test failed. See exception logs above.
```

...with nothing above it. The `--machine` reporter agrees and shows why:
`"error":"Test failed. See exception logs above.\nThe test description was: ..."`,
`"stackTrace":""`. So **a real `FlutterError` — including a timeout — and a real
failed assertion are indistinguishable in the output**, and both read as "the test
failed" rather than "the diagnostic is missing". Every earlier note here that
called a Chrome failure *silent*, *no message*, or *byte-for-byte the signature
of* something else was describing this.

The recovery is an explicit hook, which nobody writes when the output looks like a
failure rather than a missing diagnostic:

```dart
final old = FlutterError.onError;
FlutterError.onError = (d) { print(d.exceptionAsString()); print(d.stack); old?.call(d); };
```

**What it found, in `accept_invitation_screen_test.dart`: `"pumpAndSettle timed
out"`, ten times.** And the cause is a real defect, not an environment quirk.
That file had its own private settle routine:

```dart
await tester.runAsync(() => Future<void>.delayed(Duration.zero));
await tester.pumpAndSettle();
```

**A zero-duration real-timer hop is enough on the VM and not enough in the
browser.** On the VM dio's pipeline is microtask-based, so one hop drains it. In
the browser dio's web transport needs a genuine event-loop turn, so the request
was still in flight, the loading box was still showing its
`CircularProgressIndicator`, and the closing `pumpAndSettle` — which cannot
settle an indeterminate animation — timed out. **Ten tests passed on the VM and
failed on Chrome, with no message.**

The fix is `settleRequests`, which the Phase 4 log already introduced *for
exactly this class of problem* and which simply had not been applied here. The
pattern existed, was documented, and was duplicated wrong.

**Which makes the second half of the fix the more important one: the duplicate
is deleted.** That file now calls the shared helper at all six sites and the
reasoning lives on `settleRequests` itself. **Two copies of a settle routine is
the defect, not a style preference** — the wrong one still looks correct, because
it is right on the platform it was written on, and no compiler or reviewer signal
distinguishes the two.

**The same defect had taken root in the navigation helpers, and that is the part
worth generalising.** There were three of them — `goTo` (settle only),
`goToAndLoad` (pump, drain, settle) and `goToSettled` (settle, drain, settle) —
and they differed only in whether the destination fetched on arrival. **That is
not a property of a route; it is a property of whether the caller happened to
know.** Twelve call sites used the unsafe `goTo`, fourteen used `goToAndLoad`,
one used `goToSettled`, and `goTo` at a fetching destination is the silent
timeout described above.

So the three are now **one** `goTo` that drains before it settles, and the other
two are deleted. The cost is a few milliseconds of real waiting on a route that
renders instantly. The benefit is the one that matters here: **a new screen
cannot be added to a test in a way that quietly breaks it on one platform**, which
is precisely how ten tests in this entry were invisible for three phases. A
convenience API that silently differs by platform is worse than a slightly slower
one, because its cost is paid as *missing information* rather than as time.

**Four more Chrome failures were 7.1's own doing and are fixed:** the calendar
made `/events` a fetching screen, so every test that navigated there and then
called `pumpAndSettle` inherited the same timeout — `the "here" link returns to
the app`, `cancel returns to the list` (to `/customers`), `Profile navigates`
(to `/profile`, which fetches its details) and `either scope suffices for
/users/create`. All four now use `settleRequests` / `goToSettled`, which is what
those helpers already existed for.

**Chrome: **18 failures to 5**, and the whole of the remainder is one
platform assumption in `user_list_screen_test.dart`.** The remaining five are one cause and are **not**
from this task: `user_list_screen_test.dart`'s invitation tests hard-code the
VM's `Uri.base`, which is `file:///...` and therefore has an **empty authority**,
so the link renders as `/register?token=tok-42`. On Chrome `Uri.base` is
`http://localhost:<port>/...`, so the same screen correctly renders an absolute
URL and the literal assertion fails. The test's own comment states the `file:`
assumption — it was written for the VM and never checked on the other platform.
Left alone as out of scope here, but it is the *whole* of the remaining Chrome
backlog and it is a one-line-per-test fix for whoever takes 12.6.

#### Three more things the harness learned, all found by these tests

**`pumpApp` ended in a bare `pumpAndSettle`, which the calendar broke.** The
router's `initialLocation` is `/events`; while that was a placeholder nothing
happened on boot, and now it is a screen that fetches and shows a
`CircularProgressIndicator`. `pumpApp` now calls `settleRequests` — which also
means the app arrives *settled* rather than mid-flight, which is what a test
wants to reason about.

**`/api/events` is now the third endpoint `contextAdapter` has to answer, and the
first where the order matters.** It is both the app's initial location and the
event screens' own endpoint, so leaving it to fall through to the harness's 401
signed every test out mid-assertion — twenty-odd failures whose first symptom
was landing on `/login` with no rail. But answering it *before* `forOtherRoutes`
— which is what `/api/organizations` does, and the exact trap
`organization_list_screen_test.dart` recorded — then made every event test render
an empty list while looking like it worked. So this branch consults
`forOtherRoutes` first, and the comment says why the two differ.

**Hover-revealed actions do not exist on web until the row is hovered.** Four of
the list's tests passed on the VM and failed on Chrome for this alone. The VM
passes because `kIsWeb` is false there, which is the same lesson as 4.2's
`revealActionsOnHover` parameter: **the VM-only green is not evidence about the
browser this app ships to.** `hoverFirstRow` is now called unconditionally.

**Also: `RequestOptions.data` is the typed request, not a JSON string.** The
stub adapter sits *under* dio's transformer, so an RSVP assertion written as
`contains('"availability":"available"')` fails on a perfectly correct request
for a reason that has nothing to do with availability.

#### Two API-shape findings worth keeping

**`GET /api/events/{id}` must answer a bare event, not a paged envelope.**
Reusing the list page's stub for the edit form's load decodes
`{"items":[…]}` as an `EventResponse` and throws inside generated
deserialization — which reads as a broken fixture rather than a wrong one. Same
class of mistake the Phase 1 log records about service fixtures.

**`TableRow` is not in the element tree, and `TableCell` does not exist.** Both
are the obvious things to use to scope a finder to one table row, and both answer
zero matches — a failure that reads as "the row is not there" rather than "you
named the wrong class". The nearest findable ancestor is the `Table`. The same
applies inside `table_calendar`: its `TableRow` is layout data, not a widget, and
it lays a *week* out per `Table`, so "the bar is not in today's cell" is
unanswerable by ancestry. That is why the day's bar area carries a key.

#### Test count and what is verified

38 new tests, all green on **both** platforms. Calendar: the month's first and last
day, the inherited ceiling, no `offset`, refetch on paging, placement on the
right day *and not on a neighbouring one*, an out-of-month event staying off
screen, today's `#e7f0f7`, the orange "requested" bar for this user and the blue
bar for someone else's, tapping a bar → `/events/42`, tapping a day →
`/events/create?date=…`, and the create button's permission gate and picker
intercept. List: all six columns, `N/A` for a customerless event, the request
parameters, the start-date picker and "Today", sorting, all three RSVP posts,
this user's answer winning over another's, the permission-gated row actions, the
delete dialog and its consequence, and a server error.

**Not verified in a browser.** As with every phase since 3.12, this is the gap
the tests cannot close. It matters more here than in Phase 4: this is the first
screen whose layout depends on a **third-party widget's** rendering rather than
only on this repo's, and `table_calendar`'s grid at 500 / 900 / 1400 px is
something no assertion in this file can speak to. A browser pass should confirm
the grid is legible at three widths, that `rowHeight: 64` is enough for a
number plus two bars, and that the hover reveal on bars does not fight the day's
tap.


---

### 2026-10-20 — The calendar grid gets more room, gets ruled, and stops stealing the scroll

**Done.** The month grid's rows are half again as tall, the per-day cap is four
rather than three, the grid is ruled the way the calendar it replaced always
drew it, and the grid no longer takes the page's scrolling for itself.
`./teven verify` clean: 345 tests. **Verified in a browser**, against the live
backend, by the user and by me.

#### The row height was too short, and it was shortening the day in a way nobody had looked at

`rowHeight: 64` held the date number and **two** bars — not three, which is
what `kMaxEventsPerDay` claimed. `table_calendar` clips marker overflow
(`canMarkersOverflow: false`), so the third bar was cut off mid-height and the
"+N more" line was cut off with it. **A day with four events rendered two bars
and half of a third, and said nothing at all about the fourth.**

Measured rather than estimated: a bar was 18px in the test font and the marker
area was 42px. **The cap and the row height have to agree, and they did not** —
the cap was a number the row could not honour.

**This closes the open question the Phase 7 entry left.** It said "whether three
reads as the right number is the open question; widget tests cannot judge that".
Three was not the right number — it was the number that fit in a row that was
too short. The cap goes to four.

**The height is 100, and it is derived rather than guessed.** The row holds the
date number (20px), then four bars, then the "+N more" line a busier day draws
in their place — and the constants that add up to it are in the code, so
raising the cap again moves the row with it.

#### The bar's height had to stop depending on the font, and that is the interesting part

The first attempt at 100 was a **test-only pass**: 100 fits four bars and the
count in a browser, and does not fit them in a widget test, because the test
font is not the browser's font and measures 3px taller per bar. A budget
derived from the browser overflows in the tests; a budget derived from the
tests leaves the browser half empty. **Neither number is the row's height —
the row's height is a function of the font, and that is the defect.**

The fix is a fixed line height on the bar's text (`height: 1.2`), which is
exact: the glyphs are scaled to fit it, so the bar is the same height in every
environment. The Phase 4 log records the same lesson from the other direction
("any pixel threshold in a widget test is measuring the font, not the layout"),
and this is the calendar-side version of it.

Measured afterwards: the bar is 15px, the count line 16px, the row 100px, and
the count ends 3px above the row's bottom edge — in the widget test *and* in
the browser, which is the point.

#### The grid was taking the page's scrolling, and the symptom was a phantom column

**The taller rows made this visible**, which is worth recording: the defect
was there before and the extra height gave it room to be noticed.

The report was that the calendar "seems like it's trying to take over
scrolling" and "does some left and right motion, seemingly trying to show
more dates on each side even though they're all visible currently" — and then,
on a second look, "the extra column on the right is another thursday".

**There was no eighth column.** The grid is seven columns wide, measured: the
`Table` is one widget, its seven cells tile the width exactly, and the
weekday header has seven labels. What was happening is that **the grid is a
`PageView`, and a `PageView` answers scroll *signals* as well as drags.**

| | |
|---|---|
| `table_calendar`'s default | `AvailableGestures.all` → the `PageView` gets `PageScrollPhysics` |
| What that means | the month can be dragged sideways, **and** the `PageView` handles scroll signals |
| A horizontal `Scrollable` scrolls on | the **x** component of the delta (`Scrollable._pointerSignalEventDelta`) |
| So a trackpad's horizontal component | slid the month sideways mid-scroll, and a sliver of the neighbouring month appeared at the right edge of a grid whose days were all on screen |
| And worse | `Scrollable` only registers interest in a scroll event if it would actually scroll — so the calendar **claimed** a diagonal scroll that the page should have had, and the page stopped scrolling under the cursor |

`AvailableGestures.none` gives the `PageView` `NeverScrollableScrollPhysics`,
which opts out of both (`shouldAcceptUserOffset` is false, so the `PageView`
never even registers interest in the signal). The month is still reachable
from the header's chevrons — which is how it was reached before, since a month
grid has no time axis to swipe along.

**A test that bites:** a horizontal drag right across the grid does not change
the month. Verified by mutation — with the package's default gestures the
month moves and the test fails.

#### The grid is ruled, which the calendar it replaced always was

react-big-calendar drew a frame around the month grid, a rule under the weekday
names, a rule between the week rows and a rule between the day columns — all
`1px solid #ddd`, from its own stylesheet (`:352`, `:98`, `:399`, `:439`),
none of it overridden by the app. The port now draws all four in
`TevenTheme.gridline`.

**Three details make it work, and each was a trap.**

1. **`CalendarStyle.tableBorder` — the one place table_calendar offers for
   rules — cannot be used.** It rules the *whole* table, so its verticals run
   through the middle of every weekday label. The rules have to be drawn by the
   cells instead: the right edge on every day cell (which is both the rule
   between two columns and the grid's own right edge), the left edge on the
   first column only (every other cell's left edge is its neighbour's right
   edge, and drawing it twice would draw the line twice as dark), and the
   bottom edge on every cell (which is both the rule between two week rows and
   the grid's bottom edge). The weekday header row is written by hand for the
   same reason, and the frame's top edge and the rule under the weekday names
   come from the row's own decoration.
2. **`foregroundDecoration`, not `decoration`.** Today's fill is opaque, so a
   rule painted *under* the cell would disappear under it and the grid would
   have a gap in it exactly where the highlight is. A `decoration` would also
   inset the cell's child by the rule's width, which is a hair's breadth of
   layout for nothing.
3. **The rules are 1px and `#ddd`, which is subtle by construction.** The
   nearest colour in the app's own palette is Bootstrap's `$gray-200`
   (`#e9ecef`, `ColorScheme.outlineVariant`), which is lighter. The calendar's
   own grey is what a user of the app has always seen.

#### Two tests, and both fail on the old code

A day with four events shows four bars and the fourth is *not clipped* — a
geometric assertion against the cell's bottom edge, because "the widget exists"
is what a clipped bar also satisfies. And the "+N more" count is visible inside
the cell, which is the half that was broken: the count is drawn below the
bars, so a row too short for the bars clipped the count too, and a busy day
said nothing about the events it was hiding. **The count is the only thing
standing between a truncated cell and a lie.**

Verified by mutation: with `_rowHeight` back at 64 and the cap back at three,
both fail.

#### The Dart comments no longer cite the React code

`frontend/` is going away, and a comment pointing at a file that will not
exist is a citation a reader cannot follow — which task 10.8 exists to fix,
one file at a time. This change does it for the calendar screen and its test
file: the reasoning stays, the `EventCalendar.tsx:123` citations go, and the
history is here instead. The occurrences in the other files are unchanged and
remain 10.8's, with its list of them still accurate.

#### What the browser pass found that the tests could not

Two of the three things this entry describes were found by a person looking at
the app, not by a test: that 128 was too tall a row (the user, who then asked
for 100), and that the calendar was taking the scroll and showing a phantom
column. The tests could have pinned the *settings* — `rowHeight`, `availableGestures`
— but the complaint was about behaviour, and only the behaviour test ("a
horizontal drag does not move the month") would have failed on the old code.

**Still open for a browser pass:** the rules at 500 / 900 / 1400 px, and
whether 100 is right on a phone.


---

### 2026-10-20 — Task 7.2: a mouse clicks, a finger holds

**Done.** The month grid creates an event from a **mouse click** or a **finger
long-press**, and the two are told apart by the device that produced the
gesture.

`./teven verify` clean: 350 tests on the VM, all green. The calendar's own file
is green on **Chrome** as well (27 tests), and the full Chrome run still shows
only the five pre-existing `user_list_screen_test.dart` failures this log
recorded in the Phase 7 entry — the `Uri.base` / empty-authority problem, which
is 12.6's and is not touched here.

#### Yes — Flutter tells a mouse from a finger, and it is not a workaround

That was the open question in the task, and the answer is that it is a
first-class part of the framework. **Every pointer event carries the device it
came from.** `PointerEvent.kind` is a `PointerDeviceKind`:

| Kind | What produced it |
|---|---|
| `mouse` | a mouse, a trackpad, a trackpad's click |
| `touch` | a finger |
| `stylus` | a pen |

**The same value on the web and on a device** — the browser reports which
device produced the event and the framework passes it through — so there is
**no `kIsWeb` branch and no platform sniff anywhere in this.** That is worth
contrasting with the other pointer-sensitive work in the port: task 4.2's
hover-revealed row actions *are* gated on `kIsWeb`, because **hover** has no
cross-platform equivalent — it does not exist on a phone. **The device that
made the gesture does**, and that is the difference between the two problems.

**The obstacle was that `table_calendar` does not pass it on.** `onDaySelected`'s
signature is two `DateTime`s and nothing else, and `onDayLongPressed` is the
same shape. So the kind is read from a **`Listener`** wrapped around the grid.

**A `Listener`, and not a `GestureDetector`.** This is the part worth writing
down, because the obvious alternative fails *silently*. A `GestureDetector`
**competes** for the gesture: the day cell's own tap recogniser would lose the
arena to ours, `onDaySelected` would stop firing, and the calendar would stop
creating events **with no error anywhere**. A `GestureDetector` that wins an
arena it was never supposed to enter does not complain — it just works, in the
wrong direction. A `Listener` sees raw pointer events without claiming them,
which is exactly what is wanted.

**And a `ValueNotifier` rather than a `setState`,** because the hint under the
grid has to change when the pointer does, and a `setState` would rebuild the
grid **in the middle of the gesture that is about to create an event**. The
notifier has exactly one listener — the hint — and the grid is not rebuilt at
all.

#### The rule, and why the touch half does nothing

| | Creates an event |
|---|---|
| Mouse click | yes |
| Trackpad click | yes |
| Pen tap | yes |
| Keyboard | yes |
| **Finger tap** | **no** |
| **Finger long-press** | **yes** |

**The finger's tap does nothing, and that is the point.** It is the mobile
calendar idiom: a tap on a day means "show me this day", and a long press means
"I want to do something *with* this day". This app has no day view for the tap
to open, so on a touch screen the tap is left inert rather than throwing a
create form under a finger that was on its way to scrolling — which is what a
single-gesture design does on a phone, every time.

**The inert tap is a gap, and it now has a task: 7.11.** The split is only
half a design until the tap has something to open. 7.11 files a day view —
and asks whether a package can draw an hourly schedule with overlapping
events, since `table_calendar` has no day view and task 11.7 already notes
that a week view would have to be hand-built. **When that lands, the tap opens
the day and the long press stays as the create gesture; the split by device
does not change.** The one thing that would change is the reason the tap does
nothing today, which is "there is nowhere to go" rather than "a tap is not a
create gesture".

**Null means "not a finger",** so a keyboard activation — which sends no
pointer event at all — creates, like a click does.

**A hybrid device gets both**, because the rule is *per pointer* rather than
per device: the mouse still clicks and the finger still holds. The hint follows
the last pointer that went down, so it says the right thing for whichever
input was just used.

**A mouse long-press also creates, which is redundant, and it was reviewed and
kept.** Holding the button down on a day is a second way to do something a
click already does. The alternative is a rule with two branches — "the long
press does nothing *on a mouse*" — rather than one, "a long press creates", and
the second is easier to reason about and easier to test. It is also not two
creates: the long-press recogniser wins the arena, so the tap is rejected when
the pointer comes up and only one of the two callbacks fires. There is a test
for it, because "redundant but deliberate" is exactly the kind of behaviour a
later reader mistakes for an oversight.

#### A long press on a bar opens the event, and it nearly did not

The day cell's long press creates an event *for that day*, and the cell is the
bar's ancestor — so the question is which recogniser wins the arena.

**The bar's does.** Its `InkWell` is nearer the pointer than the cell's
`GestureDetector` and is added to the arena first, so it is the one that is
eager when the deadline passes and the cell's long press never runs. **Which
means that without a handler of its own, a long press on a bar does *nothing
at all*** — silently, on a bar that a click opens. (Measured, not assumed: with
the bar's `onLongPress` removed, the long press leaves the route at `/events`
rather than opening the create form.) So the bar carries an `onLongPress` that
opens the event, the same as its `onTap`. **A long press on a link should go
where a click on it goes.**

#### The hint under the grid

**"Click a day to create an event."** / **"Long-press a day to create an
event."**

It follows the last pointer, and it exists because the finger's tap does
nothing: **a gesture that is silently inert is indistinguishable from a broken
cell.** There is no day view behind it and no toast to explain it, so without
the hint the long press is a gesture nobody is going to discover.

**It is a divergence from the original.** The React calendar had one gesture
for one device class and no hint; this has two gestures and one line of text.
The line is small, and it is the only thing that makes the touch half usable.

#### Tests

Six new cases in `test/event_calendar_screen_test.dart`, all green on the VM
and on Chrome:

- a mouse click on a day opens the create form for that day;
- a mouse long-press on a day opens the create form too — redundant, and
  deliberately so;
- a finger long-press on a day opens the create form for that day;
- a finger's tap on a day does **not** open the create form;
- the hint names the gesture the last pointer used — and a mouse turns it back;
- a long press on a bar opens the event, not the create form.

**`tester.tap` sends a *touch* pointer,** which is the detail the whole file
turns on. The harness's tap helper takes the pointer kind as a parameter for
that reason, and the pre-existing "tapping a day opens the create form" case
now says `kind: PointerDeviceKind.mouse` explicitly rather than leaning on a
default that means the opposite of what the test is about.

**Verified by mutation.** Removing the touch guard fails the tap case; making
the long-press handler a no-op fails the long-press case; removing the bar's
`onLongPress` fails the bar case. Each of the three fails loudly rather than
passing vacuously.

**Not verified in a browser.** The pointer kinds in a widget test are the
framework's own, so the tests say that the rule is *implemented*; they cannot
say that a browser's mouse is reported as `mouse` and its finger as `touch`.
A browser pass — a click and a long press on the same day, and a real
touchscreen — is the check that would close it.


---

### 2026-10-20 — Task 7.6: the event details screen, and a widget that was never mounted

**Done.** `EventDetails.tsx` (277 lines) and `RsvpWidget.tsx` (72 lines).
**380 tests pass on the VM** (up from 351 — the 29 new ones are all here);
`flutter analyze` and `dart format` clean; web build succeeds. **Both new
test files pass on Chrome as well as the VM** (29 tests).

**Files added:** `lib/screens/events/event_details_screen.dart`,
`lib/widgets/rsvp_widget.dart`, `lib/providers/event_details.dart`,
`test/event_details_screen_test.dart`, `test/rsvp_widget_test.dart`.
**Files changed:** `app_router.dart` (the route now builds the screen rather
than a placeholder), `permissions.dart` (one permission added — see below),
`teven_theme.dart` (`success`, `successSurface`, `onSuccessSurface`),
`event_calendar_screen.dart` (the pending-RSVP card), `event_list_screen.dart`
(the two RSVP colours moved to the theme), `pubspec.yaml` (**`url_launcher`**),
`auth_harness.dart` and `accept_invitation_screen_test.dart` (the trap below).

#### The React screen never shows an error when the event fails to load

**This is the one behavioural divergence, and it is a divergence because the
original is broken.**

`EventDetails.tsx:80` returns a spinner whenever `event` is null:

```tsx
if (!event) {
  return (<div className="container mt-5 text-center"><div className="spinner-border text-primary" …/></div>);
}
```

and the `catch` at `:31` only calls `setError(...)` — which is rendered at
`:133`, **inside the card the spinner's early return never reaches**. So a
404, a 403 or a dead backend produce an endless spinner and a message nobody
can read. The error state is unreachable.

The port shows the error instead, in place of the body, and keeps the "Back to
Events" button so the user is not stranded. This is the same call the event
list made in task 4.14 — **the port's convention is that a failure is shown** —
and the alternative is a screen that looks busy while it can never finish.

#### The delete navigates away, and that is the whole point of it

`EventDetails.tsx:44-58`: confirm, `DELETE /api/events/{id}`, then
`navigate('/events')`. **No refetch**, because the record is gone — there is
nothing to refetch, and the screen it would refetch does not exist any more.

This is the **sixth and last** of the React app's `window.confirm` delete
flows, and 4.8's rule holds: the *dialog* is shared (`confirmDestructiveAction`)
and the *consequence* stays at the call site. The wording matches the event
list's (7.5) rather than the original's — the dialog names the record, because
that is what the other five sites do and a generic "Are you sure?" is what made
six of them worth sharing.

#### `RsvpWidget` was dead code, and the endpoint behind it has never been used

**It has never been imported by anything.** `RsvpWidget.tsx` was added in
`f13ae83` — *"wip sending RSVPs, selecting users to request rsvps from on
edit event"* — the same commit that added `GET /api/events/rsvps/requested` —
and nothing has referenced it since. `git log -S "RsvpWidget"` returns that
one commit.

So the endpoint has been reachable and unused for the whole life of the app,
and **7.10's question ("confirm whether the React app uses it — if not,
decide whether to expose it") has an answer: it does not, because the only
thing that used it was never mounted.**

The port mounts it, **on the calendar**, and the reason is that the calendar
is where the request is *already visible*: an event awaiting your answer is
drawn in orange on its bar (`TevenTheme.requestedRsvp`, task 7.4), and the
card is the control that answers it. Without it, a user can see that something
is waiting and has no way to answer it except by opening each event in turn.

**This is a divergence from the original — the app now shows a surface the
React app does not have** — and it is the third such divergence in Phase 7
(the first is 7.5's "Calendar view" button, the second is 4.9's pagination).
It is recorded rather than buried, and **7.10 is left open** with a note that
the exposure landed here: moving the card is a one-line change to the calendar
screen if the team would rather it sat elsewhere.

**The availability is a free-form string, exactly as the task says.** The
server type is `String` with no validation (`RsvpRequest.kt`), so anything
posted is stored as-is; `RsvpAvailability.available` and `.unavailable` are
`String` constants for that reason, and a Dart enum would be a closed set the
server does not enforce. Task 10.17 still owns the question.

**The card renders nothing at all when nothing is pending**, which is the
React original's `if (rsvps.length === 0) return null` — and it matters for
more than tidiness: the card is on the app's landing page, and a permanent
empty card there is noise.

#### The RSVP buttons needed a permission the client could not name

`EventDetails.tsx:20` gates the buttons on
`hasPermission('ASSIGN_TO_EVENTS_SELF')` — a **raw string**, not the
`Permission` const object. That is why the React app never needed it in
`permissions.ts` to work: `usePermissions().hasPermission` takes a `string`
and compares it against the server's list (`AuthContext.tsx:84`), so a
permission the client cannot *name* is still a permission it can *ask about*.

The permission is real and widely held — the server's enum has it
(`Permission.kt:89`) and the seeded `Organizer` and `Staff` roles both hold it
(`InitialSetup.kt:69,91`) — so the buttons are live for every seeded account.
It is added to the client's `Permission` enum on the same terms as
`MANAGE_CUSTOMERS_GLOBAL` (10.16), which was added early for the same reason:
**a screen cannot be ported without the permission it gates on.**

**The server does not check it.** `POST /api/events/{id}/rsvp` carries no
`withPermission` wrapper at all (`EventRoutes.kt:128`), so this client-side
gate is the only one there is. Task 10.14 calls the permission vestigial,
because the route it was written for (`POST /api/events/{id}/join`) was deleted
on the same afternoon it was added — this is the one place it is still
load-bearing.

#### One new package: `url_launcher`

For the location's Google Maps link (`EventDetails.tsx:120`). Flutter has no
built-in way to open a URL — `dart:html` is deprecated and web-only — and **a
location that cannot be opened is a location that cannot be found.** On the web
this is `window.open(url, '_blank')`, which is what the original's
`target="_blank"` did. Native builds will need the platform's URL-query
configuration, which arrives with Phase 11.

#### The column split is keyed on the content width, and the browser said so

`col-lg-8` / `col-lg-4` in the original, which splits at a **992px viewport**.
The port has a rail down the side instead of a navbar across the top, so its
content is 80px narrower on a tablet layout and 256px narrower on a desktop
one — **the same window size leaves very different amounts of room.**

The first cut used the app's own desktop threshold (1100) against the
**content** width, which put the split at about 1360px of window. **The
browser pass found it immediately:** at a 1074px window the sidebar was
stacked *under* a 900px-wide main card, and the "Going" / "Not Going" buttons
were stretched across the full width of the page — a `btn-group w-100` that
React had confined to a third of the viewport.

The threshold is now **860px of content**, which gives a 2:1 split a ~280px
sidebar and a ~560px main card. The same browser pass then showed the two
columns side by side, the sidebar reading as the narrow column the original
intended.

**The measure is the point, not the number.** The question the split answers
is "is there room for a main card *and* a sidebar", and that is a question
about the content — which is why the number is a content width rather than
another entry in `AppBreakpoints`, whose three sizes are all window widths.

#### The same trap, for the fourth time

The calendar carries the pending-RSVP card, and the router opens at `/events` —
so **every test that boots the app now requests `/api/events/rsvps/requested`**,
whether or not it means to. Unanswered, it falls through to the harness's 401,
which raises `UnauthorizedException`, trips the single-flight 401 redirect and
**signs the user out mid-assertion**.

That is the same trap `auth_harness.dart` documents for `/api/organizations`,
`/api/users/{id}`, `/api/roles` and `/api/events` — and the **symptom is
misleading every time**: the test lands on `/login` with no rail, which reads
as a broken shell rather than an unanswered path.

**Fifty-one tests failed before the harness was taught the new path**, and the
count is worth recording because it is the cost of one card on one screen.
`auth_harness.dart` now answers it, and `accept_invitation_screen_test.dart`
— which has its own adapter — was the one place it still 401'd. Two more
failures came from the **details screen itself**: the route now fetches, so
`router_test.dart`'s deep link and `responsive_chrome_test.dart`'s nested path
both needed `/api/events/{id}` answered, which the harness now does with the
id echoed back.

#### The server's permission check is not enforced, and that is a security defect

**Found by hand, against the running dev backend, while porting this screen.**
It is filed as **task 10.22** and added to the discrepancy table, because it is
the first security defect the port has found and it does not belong to a
Phase 7 commit.

Signing in as `alice` — a seeded **Organizer**, whose role grants neither
`VIEW_ORGANIZATIONS_GLOBAL` nor `VIEW_EVENTS_GLOBAL` — and asking for an
endpoint gated on exactly that:

```
GET /api/organizations   →  200, and the full organization list
```

Four organizations, including the `SuperAdmin`'s own, returned to a user with
no global permission of any kind. `/api/users`, `/api/customers`,
`/api/inventory` and `/api/events` all answered 200 for the same caller.
**Authentication is enforced — the same request without a token is a 401 — and
nothing else is.**

`AuthorizationPlugin`'s check is *written* correctly: it looks the caller's
permissions up and answers 403 when the check fails. The defect is in how the
plugin is wired: `pluginConfig.forEach { permission -> onCall { … } }` registers
**one `onCall` hook per permission**, and Ktor's `onCall` hooks do not
short-circuit — the route handler runs anyway and its own `respond` is what the
client receives. The 403 is written and then overwritten.

**Until it is fixed, the client-side permission gates are the only thing
standing between a user and the whole database.** The port's route guards, nav
items and per-screen buttons all work, and none of them is a security
boundary.

#### The browser pass

**Done — against the live backend, signed in as `alice`.** The details screen
was opened at `/events/523` and checked at 1074px:

- the title, the date, the time and the duration, the location as a link, the
  description, and the customer callout with its blue left border all render
  as the original intends;
- the **RSVP round trip works**: "Not Going" posts, the screen shows
  *"Successfully updated RSVP to unavailable!"*, the two buttons swap which
  one is filled, and **the roster repaints** — the badge goes to 0, "Confirmed"
  empties, and "Declined" gains Alice. The request sequence is
  `POST /api/events/523/rsvp` then `GET /api/events/523`, which is the
  refetch the original does;
- the **delete dialog** appears with the shared wording and a red confirm, and
  **cancelling issues no request** (checked in the network log);
- the console is clean.

**How the session was arranged, since it took a while:** the token is stored by
`flutter_secure_storage`, whose web backend encrypts it with AES-GCM under a
key in `localStorage` — so a token cannot simply be pasted in. It was
**encrypted in the page** with the same scheme the plugin uses
(`base64(iv).base64(ciphertext)` under `FlutterSecureStorage.teven-auth-token`,
with the raw key at `FlutterSecureStorage`), then the page reloaded. The
plugin's default `publicKey` option is **`'FlutterSecureStorage'`**, not
`'publicKey'` — the constant in the web plugin is the *option's name*, not its
value, and getting that wrong produces a token that is stored correctly and
never read.

**Verified in a browser, and by the user rather than by the harness.** The
harness has no viewport-resize tool, so the narrow layout was covered by the
widget tests only — and the **user resized the window and confirmed the
layout holds at every width**, which is the check the harness could not make
and the one that matters for the 860px threshold. The split point is now
confirmed from both sides: the two-column layout at a wide window, and the
stacked layout with the sidebar under the card at a narrow one.

**Still not verified:** the Google Maps link actually opening a tab, and the
delete going through — the seeded event was left alone, and the delete's
*request* was checked from the network log rather than by letting it happen.

#### The tests

**29 new cases**, all green on the VM and on Chrome:

`test/event_details_screen_test.dart` (24) — the rendering; the load failure
showing an error rather than spinning; the two permission gates (manage, and
`ASSIGN_TO_EVENTS_SELF`); the delete (asks first, cancelling changes nothing,
confirming deletes and navigates to `/events`, a failed delete keeps the
screen and says why); the RSVP (each of the three availabilities posts the
right string, the event is refetched, the current answer is the filled
button); the roster (the three-way split, the declined list being for managers
only, the empty groups, the badge counting the confirmed); and the layout.

`test/rsvp_widget_test.dart` (5) — nothing renders when nothing is pending;
the list shows the title, date and time; Accept posts `available` and drops
the row; Decline posts `unavailable` and drops the row; **a failed answer
keeps the row**, because the request is still outstanding.

**Verified by mutation,** which is the only way to know a test is not
vacuous: navigating somewhere else after the delete fails the delete case;
posting the wrong availability fails the RSVP case; dropping the manage gate
from the declined list fails the roster case; posting the wrong value from the
widget fails the widget case; and dropping the row on a *failed* answer fails
the failure case. Each fails loudly and each fails the right one.

**One finder worth recording, because it fails as "the widget does not exist".**
`find.byType(OutlinedButton)` matches the **runtime type exactly**, and
`OutlinedButton.icon` builds an `_OutlinedButtonWithIcon` — a subclass. So
`find.widgetWithText(OutlinedButton, 'Going')` matches **nothing at all**, and
the failure reads as "the button is not there" rather than "you named the
wrong class". The finder is `byWidgetPredicate((w) => w is OutlinedButton)`.

---

### 2026-10-20 — Task 7.7: the panel that had nothing to show

**Done.** `OtherEventsPanel.tsx` (97 lines).

**The widget already existed.** It was written in Phase 6 (`3e36ef4`) as a
supporting piece for the create and edit forms, which is why 7.7 was still open
and why this entry is about the parts around it rather than about the widget.

**398 tests pass on the VM** (up from 380 — the 18 new ones are all here);
`flutter analyze` and `dart format` clean. **The new test file passes on Chrome
as well as the VM** (18 tests).

**Files added:** `test/other_events_panel_test.dart`.
**Files changed:** `lib/widgets/other_events_panel.dart` (rewritten),
`lib/screens/events/create_event_screen.dart` and
`edit_event_screen.dart` (the date wiring), `test/support/stub_adapter.dart`
(the handler may now be asynchronous — see the race test).
**Backend:** `backend/data/.../TestDataProvider.kt` — seed data only, behind
`DEV_MODE`.

#### The panel's comments cite no TypeScript file

`frontend/` is deleted in Phase 10, so a comment naming a file inside it is a
citation that will not resolve — and one that *looks* resolvable, which is the
worse failure. The panel's comments therefore describe the original rather than
pointing at it: "the original replaces the whole card body with this", not "the
React original replaces the card body (`OtherEventsPanel.tsx:61-68`)".

**The rule is now in `AGENTS.md`,** so it applies to new code from here on and
to whoever does task 10.8's sweep. **The React sources stay citable in this
file**, which is the historical record and keeps them deliberately — the
citations here are how a reader checks a claim, and this file outlives
`frontend/`.

**What this leaves, stated rather than hidden:** the panel, the two event forms
and the new test file are clean, and **the rest of the port is not.** There are
**388 `.ts`/`.tsx` citations** across **71 files** — 53 in `flutter_app/lib/`
and 18 in `flutter_app/test/` — carried over from Phases 1–6 and not yet
swept. That is task **10.8**, which the plan has owned since the port began
and which nobody has picked up yet; the calendar screen was done separately, as
a demonstration of the shape.

The count is worth having because it is a **mechanical** job rather than a
design one — every one of those citations is a path to be replaced by a
sentence saying what it pointed at — and because the reasoning each one
carries is the part worth keeping. A sweep that deletes the citations without
rewriting the reasoning would be a loss; a sweep that rewrites them is
task 10.8's work, done properly, when someone has the time for it.

#### The seeded database could not show the feature at all

**Every seeded event was alone on its day.** The six named events sit on
`today+1`, `today+2`, `today-1`, `today+5`, `today-3` and `today+7`, and the
fourteen pagination events alternate between `today+i` and `today-i` — so no
day holds two of them, except by accident in a second organization.

The panel lists the events on a day. With the seed as it stood, it was empty
everywhere, on every screen, all the time. **That is not a bug in the panel —
it is the seed making the feature unobservable.** The create form defaults its
date to today, and today held nothing at all.

Two clusters now seed on `today`, one per organization:

| Organization | Events |
|---|---|
| `TEST_ORG_Green Vistas Landscaping` | Morning Irrigation Check 07:30/45 min, Fence Repair 10:00/120 min, **Mulch Delivery 13:15/30 min, no location**, Gutter Cleaning 16:00/90 min |
| `TEST_ORG_Urban Bloom Gardens` | Planter Maintenance 09:00/60 min, Greenhouse Repotting 14:00/120 min |

Four things are deliberate about that shape:

- **On `today`,** because that is where the create form starts and where the
  panel is met first.
- **Two organizations,** so the scoping is visible by hand: alice sees one
  list, charlie sees another, and the date is the same.
- **Spread times,** so the sort is visible without reading the code.
- **One event with no location,** because the location is rendered only when
  there is one (`OtherEventsPanel.tsx:88`) and no other seeded event exercises
  that branch.

This is the only backend file Phase 7 touches, and it is seed data behind
`DEV_MODE` rather than a behaviour change. The rule that the backend is frozen
through Phase 8 is about the API; a dev-only fixture that exists so a screen
can be looked at is not the API.

#### The date never reached the panel

**The React forms keep the date in state** — `CreateEventForm.tsx:31` and
`EditEventForm.tsx:32` both hold a `date` — so changing it re-renders the form
and the panel in its sidebar gets the new day.

**The Flutter forms keep it in a `TextEditingController`,** and a controller
notifies the field that owns it, not the widget that read it. The date field
rebuilt itself when the user picked a date; the screen did not, so
`date: _date.text` in the sidebar's `build` went on returning the day the form
was **opened** with. The panel listed the wrong day's events, for as long as
the form was open.

The fix follows the convention the event list already set (task 7.5): the
screen holds the date as a `String`, `DateField.onChanged` writes it, and the
panel is given that rather than the controller's text.

**This is the kind of defect a seeded database would never have shown** — with
one event per day, every day looks the same and the wrong one is not
distinguishable from the right one.

#### Three deliberate divergences

1. **The heading stays put while the list loads.** React returns the spinner
   *instead of* the card body (`OtherEventsPanel.tsx:61-68`) — heading and all —
   so the card collapses to the height of a spinner and grows back when the
   answer lands. Here the heading stays and only the body changes.

2. **A failed request says what went wrong.** React catches, logs to the
   console, and leaves the empty list in place — so a 500 renders **"No other
   events scheduled for this day."**, which is a statement about the day that
   the failure makes untrue. The port shows the error through the shared
   `ErrorDisplay` instead. This is the same call the event details screen made
   in task 7.6, and the same one task 4.14 made for the list screens.

3. **The list says how many events it is not showing.** React asks for no
   limit at all, which the server reads as "no cap" (`EventDao.kt:176` does
   `limit?.let { query.limit(it) }`) — it returns every event on the day. The
   port has to send a limit, because `EventService.getAllEvents` defaults to
   ten and ten would silently truncate a busy day, so the port sends a
   thousand and **says so** when the server sends fewer than the day holds.

   The count is `total - items.length`, which is the rows the *server* did not
   send — **not** the row the exclusion removed. The excluded event is the one
   the panel is shown beside; the user already knows about it, and counting it
   would put a "and 1 more" under a list that is showing everything.

#### Smaller things, and the ones that are not smaller

- **Material icons for the clock and the location.** `<i className="bi
  bi-clock">` renders as an *empty tag* in the React app — the Bootstrap Icons
  were never installed — so there is nothing to match. Task 3.11 settles it:
  Material icons throughout.

- **A rule between the rows.** React gives every `list-group-item` a
  `border-bottom` (`OtherEventsPanel.tsx:82`), so the list is ruled rather than
  floating. The port puts a `Divider` between the rows and not after the last.

- **A request counter.** The React original has no such guard and gets away
  with it, because its refetches are rare. This one refetches whenever the
  date changes, which on the create and edit forms is every time the user
  picks one — so a slow answer for a day they have moved on from can land
  after a faster one for the day they are on, and quietly replace it. The
  counter is three lines.

- **`int.tryParse` is stricter than the original's `parseInt`.** `parseInt("12x")`
  is 12 and `parseInt("")` is NaN; `int.tryParse` refuses both. The stricter
  reading is the one the server would agree with, and no caller passes
  anything but digits.

#### The tests

**18 new cases**, green on the VM and on Chrome.

The harness needed one change to make the race test possible: `StubAdapter`'s
handler is now a `FutureOr` rather than a plain function, so a test can hold
one answer back and release it after another has landed. The shared stub
answered immediately, so the case the request counter exists for could not be
built with it at all.

The race test is the interesting one. It holds the answer for the first day
open, moves to the second day, lets that one land and be shown, and *then*
releases the first — and asserts the panel still shows the second day's event.
**Without the counter the late answer replaces what is on screen**, which is
the whole defect.

**Verified by mutation,** which is the only way to know a test is not
vacuous. Four mutations, four failures, each in the right case:

| Mutation | Case that failed |
|---|---|
| Drop the sort | lists the day, earliest first |
| Drop the exclusion | leaves out the event it is shown beside |
| Swallow the failure | says what went wrong rather than claiming the day is empty |
| Drop the stale-response guard | a slow answer for the old day does not replace the new one |

#### Verified in a browser

**The stack was rebuilt with the new bundle and the new seed, and the panel was
checked against the live backend.**

The request the panel makes, from the browser's own network log:

```
GET /api/events?limit=1000&organizationId=59&startDate=2026-10-20&endDate=2026-10-20
```

— org-scoped, one day, with the limit the port sends rather than the ten the
service would default to.

On `/events/567` — the seeded *Morning Irrigation Check* — the panel lists
**Fence Repair 10:00/120 min/456 Business Ave**, **Mulch Delivery
13:15/30 min**, and **Gutter Cleaning 16:00/90 min/123 Main St**: sorted by
time, the duration and the location on each row, **the location absent on the
one event that has none**, a rule between the rows, and **the event the panel
is shown beside excluded from its own list**.

And the user picked different dates on the create form and watched the list
change — which is the date wiring above, verified against the live backend
rather than in a widget test. The seeded clusters are what made that check
possible: with one event per day, every day looked the same and a panel
showing the wrong one would have been indistinguishable from a panel showing
the right one.

---

### 2026-10-20 — The date picker could not reach into the future

**Done.** The event date — the one field the whole app exists to fill in — now
accepts a day that has not arrived yet. `./teven verify` clean: 403 tests (398
before, 5 new).

**The bug was one line, and it was in the shared widget rather than in either
event form.** `DateField` — the field both event forms use for the event date —
opened `showDatePicker` with `lastDate: lastDate ?? now`. With no `lastDate`
passed, the picker's last selectable day was **today**. The create and edit
forms are the only two callers that pass none, so both were capped at today
and neither could schedule forward. The event list screen, the third caller,
*does* pass one (`DateTime(DateTime.now().year + 5)`), and its comment already
said why: *"this screen's whole point is upcoming events"* — so the problem was
known, worked around at one call site, and left in place at the two that
mattered.

**Nothing in the original forbade it.** The React forms use
`<input type="date">`, which has no `max` attribute, so the browser never
prevented a future date. The cap was introduced by the port, not inherited
from it. Fixing it restores the original's range rather than inventing a
restriction, and the bound is now the end of 2100 — the same horizon the
calendar screen already draws to.

#### The second defect, which the first was hiding

`showDatePicker` asserts that its initial date falls inside the range it was
given, and the field seeds that initial date from the controller — which, on
the edit form, holds **the event's own date**. With the range capped at today,
editing an event scheduled for next month asserted and the picker never
opened. So the bug was not only that future dates could not be *chosen*; an
event already in the future could not have its date *changed* at all — the
picker threw instead of opening.

The fix clamps the initial date into the range before opening the picker, so
the field's value can never take the screen down. The value the user sees is
untouched either way; only what the picker starts on moves.

#### The one place that genuinely wants a past-only bound

The date of birth. A date of birth is a date that has already happened, and
the shared field's old default happened to give it one for free. The new
default is permissive — the event forms need to schedule forward — so that
constraint is now stated at the profile screen's call site, where it belongs
and where it is visible. The event list screen's `lastDate` override went the
other way: it existed only to work around the old default, and is now
redundant.

#### The create form's default date was a day off east of UTC

Found on the way through, and fixed here because it is the same field and the
same failure. The create form defaulted its date with
`DateTime.now().toIso8601String().split('T')[0]`, which converts to **UTC**
before formatting — so at local midnight east of UTC it reported *yesterday*,
and the event was created on the wrong day. `local_date.dart` documents this
exact call as the thing never to write, and the event list screen already uses
`formatLocalDate`; the create form was the one that had not been converted.
It now does.

#### The tests, and why they are written the way they are

Four new cases across two files, and **every one of them was checked against
the unfixed code first** — a test that passes on the bug it is meant to catch
is worse than no test, because it reports a fix that is not there.

- `picker_fields_test.dart`: the picker's bound is in the future; a future
  date already in the field opens a picker rather than asserting; a
  caller-supplied `lastDate` is honoured (the date-of-birth case).
- `event_form_test.dart`: the create form's picker reaches into the future;
  the edit form's picker opens for an event scheduled in the future.

The two screen-level cases assert on the **dialog's own `lastDate`** rather
than on which day cells happen to be rendered. The claim under test is the
*range*, and which cells are built depends on the viewport — asserting on the
grid would have made the test a statement about the window size.

Against the original code, both screen-level cases fail with the real symptom:
`initialDate 2026-12-04 00:00:00.000 must be on or before lastDate
2026-10-20 00:00:00.000.` — the assert, caught by the test framework, which
is exactly what a user would have hit.

### The two event forms, unified (9.13–9.18)

The create and edit event screens are the app's densest and the only pair written out twice. They are 805 and 700 lines, and the three nested modals alone are ~300 duplicated lines — which is why the two drifted apart in the first place: the duration default, the location latch, the organization field and the organization-on-the-wire each ended up with a different answer in each file. These six tasks are one unit of work: 9.13 is the pure refactor that makes the other four land in one place instead of two, and 9.18 replaces the tests for the screens they replace.

