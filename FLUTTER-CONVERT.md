# Flutter Conversion Plan

Rewrite of `frontend/` (React + Vite + Bootstrap SPA) into a Flutter app, **web first**.

The React app stays in place and fully functional until the Flutter app is verified working. Each task below is intended to be **one commit**. Work top to bottom; do not reorder without updating this file.

Responsive layout is in scope throughout, because the site will be viewed in mobile browsers. What is *not* in scope for Phases 0–10 is native app packaging — that is Phase 11.

---

## Ground rules

- **Do not modify or delete `frontend/`.** It remains the live app until Phase 10.
- **Do not modify the backend** during Phases 0–8. Backend work is confined to Phases 9–10 and is called out explicitly in those tasks (9.9, 10.6, 10.7).
- **Do not plan for deployment.** Docker is the deployment mechanism and it is sufficient; do not add hosting, TLS, proxy, or CI/CD work to any task. Verification is local. The single known gap is noted under *The one deployment consideration*.
- Every task must leave the repo in a **buildable** state (`npm run build --prefix frontend` and `flutter analyze` both clean).
- One task per commit. Commit message conventions live in `AGENTS.md`; there is no commit-message tooling in this repo, and a conventional-commit prefix is optional rather than required.
- 2-space indentation, per `AGENTS.md`.
- Run `dart format .` and `flutter analyze` before every commit in `flutter_app/`.
- New Flutter packages must be justified in the commit message.
- **Generated code is not committed.** `*.freezed.dart` and `*.g.dart` are gitignored (`flutter_app/.gitignore`), so `dart run build_runner build` is a required setup step after every clone, not an optional one. This is a deliberate departure from the freezed default of committing generated output.

---

## Resolved decisions

| Decision | Choice | Consequence |
|---|---|---|
| Targets | Flutter web **first**; native deferred to Phase 11 | Phase 0–10 are web-only. Native is additive, not a rewrite |
| Calendar | Month grid + event list (`table_calendar`) | Week/work-week/day views and drag-select are **dropped**. A custom view may come later (Phase 11) |
| State management | Riverpod | Replaces React Context; no existing pattern to preserve |
| Web serving | Same-origin via Ktor `staticResources` | Invite links and no-CORS setup are preserved |
| Environment | **Local only** — `flutter run -d chrome` + `docker compose` | All verification happens on a developer machine |
| Tests | Written alongside each task | Layers with non-obvious logic are tested as they are built; Phase 12 covers integration and UI suites |

**Deployment is out of scope.** How and where this app is hosted is handled independently of building the app, and nothing in this plan should wait on it or plan for it. The single place hosting touches a code decision is task 1.13.

### The one deployment consideration

Deployment via **Docker is sufficient** and is already how this repo works: `docker-compose.yml` builds `Dockerfile`, which bundles the compiled frontend into the backend jar's static resources (`Dockerfile:61`) and publishes one port. The Flutter rewrite only swaps the build stage (task 0.12) and does not change the deployment model.

The one gap is **TLS**. `docker-compose.yml:25` publishes port `2022` over plain HTTP, and `flutter_secure_storage` *"only works on HTTPS or localhost environments"*. Reached from another machine, the app is neither.

When the time comes, the fix is small and confined to task 1.13's area — either terminate TLS in front of the container, or make the token store fall back to `shared_preferences` when `window.isSecureContext` is false. Choose then; do not plan for it now. Local dev is unaffected, since `http://localhost` qualifies.

---

## Parity matrix

Every React component maps to at least one task below. Nothing is silently dropped.

| React source | Lines | Phase |
|---|---|---|
| `src/api/*` (10 services) | 425 | 1 |
| `src/types/*` (10 files) | 316 | 1 |
| `src/errors/*` | 15 | 1 |
| `src/AuthContext.tsx`, `src/OrganizationContext.tsx` | 136 | 2 |
| `src/components/common/ProtectedRoute.tsx` | 33 | 2 |
| `src/Auth.tsx` | 71 | 2 |
| `src/App.tsx` (21 routes) | 84 | 2 |
| `src/layouts/MainLayout.tsx` | 52 | 3 |
| `src/components/common/OrganizationSelector.tsx` | 64 | 3 |
| `src/components/common/QuickOrganizationPickerModal.tsx` | 102 | 3 |
| `src/components/common/TableView.tsx` | 90 | 4 |
| `src/components/{customers,inventory,organizations,users}/…List` | ~676 | 4 |
| `src/components/reports/ReportList.tsx` | 133 | 8 |
| `src/components/{customers,inventory,organizations,users,profile}/*Form` | ~640 | 5 |
| `src/components/users/CreateInvitationForm.tsx` | 182 | 5 |
| `src/components/auth/AcceptInvitationPage.tsx` | 176 | 2 |
| `src/components/events/CreateEventForm.tsx` | 518 | 6 |
| `src/components/events/EditEventForm.tsx` | 442 | 6 |
| `src/components/events/EventCalendar.tsx` | 329 | 7 |
| `src/components/events/{EventDetails,RsvpWidget,OtherEventsPanel,EventListPage}` | ~985 | 7 |
| **Total** | **5,946** | |

---

## Phase 0 — Scaffolding and build pipeline

Establishes that a Flutter web build runs locally and survives the Docker + Ktor pipeline. **Do this first**; it de-risks the whole port.

- [x] **0.1** Create `flutter_app/` via `flutter create --org com.teven --project-name teven_app --platforms=web flutter_app`. Verify `flutter_app/.gitignore` covers `.dart_tool/` and `build/`. Native platforms are added in Phase 11, not now. **Distribution ID is `alphainterplanetary.teven`** — set in `web/manifest.json` as `id` (task 0.7); the Dart package name stays `teven_app` since that is a source identifier, not a distribution one. Reuse the same ID for native `applicationId` / bundle id in Phase 11.
- [x] **0.2** Add to root `.gitignore`: `.dart_tool/`, `.flutter-plugins*`, `*.iml`. Note root already has `build/` at line 31, which correctly covers `flutter_app/build/`.
- [x] **0.3** Add core dependencies: `flutter_riverpod`, `dio`, `go_router`, `flutter_secure_storage`, `shared_preferences`, `intl`, `table_calendar`, `json_annotation`.
- [x] **0.4** Add dev dependencies: `build_runner`, `json_serializable`, `freezed`, `freezed_annotation`, `riverpod_generator`. **`custom_lint` and `riverpod_lint` were dropped** — see the progress log; the solver cannot satisfy them alongside `json_serializable`. Revisit if generator lints prove valuable.
- [x] **0.5** Set `analysis_options.yaml` with `flutter_lints`, `require_trailing_commas`, and `prefer_final_locals`. Commit any lint suppressions with an inline justification.
- [x] **0.6** Add `ApiConfig` with a `baseUrl` that is **empty (relative) on web** and from `--dart-define=API_BASE_URL` on native. Document this asymmetry in a comment.
- [x] **0.7** Add `web/index.html` customization: app title `Teven`, theme color, and the `teven.png` favicon copied from `frontend/public/teven.png`. Also set the PWA distribution ID: `web/manifest.json` gets `"id": "alphainterplanetary.teven"`. `flutter build web` has no `--application-id` flag, so the manifest `id` is where a web distribution ID belongs.
- [x] **0.8** Add a placeholder `HomeScreen` rendering app name + build version. Wire `flutter run -d chrome` and confirm it renders.
- [x] **0.9** **Call `usePathUrlStrategy()`** from `flutter_web_plugins` in `main.dart` so paths stay `/login`, `/register` instead of `/#/login`. Without this, invite links break.
- [x] **0.10** Build with `--no-web-resources-cdn` to self-host CanvasKit. Optional for local dev — the gstatic fetch resolves on a normal connection — but it removes a third-party runtime dependency and makes the build fully self-contained. Confirm the built page renders from `build/web` served over plain HTTP on `localhost`.
- [x] **0.11** Measure `build/web` bundle size. Compare against the React baseline (596 KB JS + 246 KB CSS) and record the number in this file. Expect a regression.
- [x] **0.12** Add a Flutter stage to `Dockerfile`. **Deviation:** no Flutter SDK runs in Docker at all. The registry has no image new enough, and Flutter publishes no `linux/arm64` SDK, so the stage copies a bundle built on the host. See progress log.
- [x] **0.13** Parameterize the frontend source with `ARG WEB_SOURCE` (`react` | `flutter`) so **both** pipelines remain buildable during the migration.
- [x] **0.14** Verify both `docker build` variants succeed and that the Flutter variant serves correctly through Ktor `staticResources("/", "static")` (`backend/app/src/main/kotlin/.../Routing.kt:56`). **Verified** — see progress log.
- [x] **0.15** **Premise did not hold — no work needed.** Flutter 3.47.2's default service worker is a 784-byte stub that unregisters itself; there is no aggressive cache to version. `--pwa-strategy` is hidden and deprecated. Verified against the SDK source; see progress log.

**Exit criterion:** `docker compose up --build` serves a Flutter page from Ktor on `localhost`, with correct path-based URLs, and `flutter run -d chrome` works against the same backend.

**Status: met,** with two caveats. `docker compose up --build` with `WEB_SOURCE=flutter` serves the Flutter app from Ktor on `localhost:2022`, deep paths and `?token=` included, with API routing still taking precedence (task 0.14). Not verified: `flutter run -d chrome`, and whether the address bar actually follows in-app navigation under the path strategy — the open question from the 0.9–0.11 entry, which needs a real browser. Both are Phase 1 work; Phase 1.1 can proceed regardless.

---

## Phase 1 — Data layer

Ports `src/api/*` (425 lines) and `src/types/*` (316 lines). Mechanical, but must model the envelope defensively.

- [x] **1.1** Port `ApiResponse<T>` / `ApiError` from `src/types/api.ts`. **Note:** the server's `failure()` helper sets `data = Unit`, so error bodies carry `data: {}` rather than `data: null` — see `backend/api/.../common/ApiResponse.kt:5`. Make `data` nullable.
- [x] **1.2** Port `PaginatedResponse<T>`. Offset/limit only — **no page numbers, no cursor, no total-page count**.
- [x] **1.3** Port `src/types/common.ts`, `roles.ts`, `permissions.ts`.
- [x] **1.4** Port `src/types/auth.ts` (83 lines) — includes `UserContextResponse` with `permissions: List<String>`, the UI gating source.
- [x] **1.5** Port `src/types/customers.ts`, `inventory.ts`, `organizations.ts`.
- [x] **1.6** Port `src/types/events.ts` (77 lines) — largest type file, includes `rsvps`, `inventoryItems`, nested `customer`/`organization`.
- [x] **1.7** Port `src/types/reports.ts`.
- [x] **1.8** Port all model classes to `freezed` + `json_serializable`. Run `build_runner`.
- [x] **1.9** Add `ApiException` hierarchy replacing `src/errors/*`: `UnauthorizedException`, `ApiException(message, details)`, `NetworkException`. **Consolidate** the ~20 copy-pasted `try/catch` unwrapping blocks into these rather than porting the duplication.
- [x] **1.10** Implement `ApiClient` on `dio` with: auth header injection, JSON envelope unwrapping, 401 → `UnauthorizedException`.
- [x] **1.11** Handle the two non-conforming server responses: bare-string bodies from `AuthorizationPlugin.kt:24,31` (e.g. `"User does not have the required permission"`), and 204 empty bodies. Model as nullable.
- [x] **1.12** **Do not treat non-JSON 200 as success.** An unmatched route with a verb other than GET/POST/PUT/DELETE falls through to the SPA handler and returns `index.html` with HTTP 200 (`Routing.kt:40-58`). Sniff `content-type` before decoding, as `apiClient.ts:44` already does.
- [x] **1.13** Use `flutter_secure_storage` directly for the token. Its web backend *"only works on HTTPS or localhost environments"*, which covers all local verification. Add a brief comment noting the container is served over plain HTTP on port 2022, so a non-localhost host will need either TLS or a `shared_preferences` fallback — deferred, not handled here.
- [x] **1.14** Port `AuthService` (`src/api/AuthService.ts`): login, logout, getToken, getUserContext, getUserDetails, updateUserDetails.
- [x] **1.15** Port `UserService`, `OrganizationService`, `CustomerService`, `InventoryService`.
- [x] **1.16** Port `EventService` — note `GET /api/events` **ignores `sortBy`** server-side despite being documented. Do not rely on it.
- [x] **1.17** Port `InvitationService`, `ReportService`, `RoleService`.
- [x] **1.18** Set a small default `limit` on event queries. `EventResponse` nests rsvps + inventory + customer + organization with **no server-side compression** (`ktor-server-compression` is absent). Default to `limit: 10`; make it configurable per screen.
- [x] **1.19** Write unit tests for `ApiClient`: envelope unwrapping, bare-string body, 204, non-JSON 200, 401.
- [x] **1.20** Unit tests for the service layer and the models, using the shared `FakeApiServer` harness.
  Split across three files: `test/api_client_test.dart` (1.19), `test/services_test.dart`, `test/models_test.dart`.

  **Services** — assert on the *request*, not the decoded response, since a fake body is not the point: each service hits the documented path; `deleteCustomer` targets `/api/customers/{id}`; `trackInventoryUsage` posts to `/api/inventory/{id}/usage`; `validateInvitation` passes `token` as a query param; the reports pass both dates. Plus the behaviours that are easy to regress: `getAllEvents` sends `limit=10` when unspecified and honours an explicit override, non-event lists send **no** limit, and the three update methods return `String` rather than a model.

  **Models** — the cases whose behaviour is *not* visible at the call site:
  - `ApiResponse.fromJson` does **not** invoke `decode` on a failure envelope, even though `data` is `{}`. This is the whole reason the callback form exists.
  - `EventResponse.startAt` / `endAt` stay naive-local — `"2026-03-04"` + `"09:30:00"` + 90 min must yield `11:00` local, **not** a UTC-shifted instant.
  - `Permissions.hasAny` uses OR-semantics, and an empty requirement grants access.
  - `PaginatedResponse.fromJson` decodes nested items through the supplied decoder.

  **Do not test** what the type system already guarantees. The value here is in the response-shape and permission logic, not in asserting that a freezed class round-trips.

  **Double convention for the rest of the port.** Only the parsing tests bind a real socket; everything above that layer crafts responses through `StubAdapter`. Applies to all the test tasks added in Phases 3–9.

---

## Phase 2 — Auth, permissions, routing

- [x] **2.1** Port `AuthProvider` → `authControllerProvider` (`AsyncNotifier`). Reproduce the boot sequence from `AuthContext.tsx:29-59`: read token → fetch `/api/users/context` → set or clear.
- [x] **2.2** Reproduce the single-flight 401 redirect. `AuthContext.tsx:16` uses a module-level `isRedirecting` flag; in Riverpod use a provider guard so concurrent 401s don't trigger repeated navigation.
- [x] **2.3** Add `hasPermission(permission)` and `permissions` as a Riverpod provider derived from `authControllerProvider`, replacing `usePermissions()` (`AuthContext.tsx:80-92`).
- [x] **2.4** Port `OrganizationProvider` (`src/OrganizationContext.tsx`): super-admin selected-org scope, persisted under key `selectedOrganization`.
- [x] **2.5** Port `ProtectedRoute` → `go_router` route guard. **Preserve OR-semantics** for array permissions: `App.tsx:62` passes `[MANAGE_USERS_GLOBAL, MANAGE_USERS_ORGANIZATION]` and `ProtectedRoute.tsx:22-25` treats it as `.some()`.
- [x] **2.6** Port all 21 routes from `App.tsx:38-68` with matching paths and param names (`eventId`, `customerId`, `inventoryId`, `organizationId`, `userId`).
- [x] **2.7** Reproduce the unauthorized redirect target. `ProtectedRoute.tsx:27` sends users to `/events`; the catch-all `App.tsx:67` sends to `/` or `/login`.
- [x] **2.8** Reproduce the branching behavior in `App.tsx:40-65`: when `userContext` is null **only** `/login` and `/register` exist. Otherwise the `/` subtree mounts.
- [x] **2.9** Port the login screen (`src/Auth.tsx`, 71 lines). Note the current `width: '25rem'` card is desktop-tuned.
- [x] **2.10** Port `AcceptInvitationPage` (176 lines). Must read the `?token=` query param **on web via path strategy** — this is the reason for task 0.9.
- [x] **2.11** Port `AlreadyLoggedInError` (16 lines), rendered when `POST /api/invitations/accept` rejects a logged-in caller with 400.
- [x] **2.12** Tests: permission OR-semantics, both unauthenticated route branches, 401 single-flight redirect.
### Phase 2 progress log

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

## Phase 3 — Shell and navigation

The React shell is desktop-only (`navbar-expand-lg`). This phase establishes the responsive scaffold both targets share.

- [x] **3.1** Port `MainLayout` (52 lines) to a `go_router` `ShellRoute`. Reproduce the `loading` → "Loading..." gate from `App.tsx:34-36`. **Already done in Phase 2** — the `_AuthGate` in `main.dart` plus the redirect's loading short-circuit; nothing to add here.
- [x] **3.2** Define breakpoints: mobile `< 700`, tablet `700–1100`, desktop `> 1100`. Use `LayoutBuilder`, not device checks, so web resizing behaves.
- [x] **3.3** Build the responsive chrome: `NavigationDrawer` on mobile, `NavigationRail` at tablet, extended rail or sidebar at desktop.
- [x] **3.4** Reproduce the conditional nav items from `MainLayout.tsx:22-27` — each link gated on its `VIEW_*` permission. Six items, two of which are OR-gated (`VIEW_USERS_ORGANIZATION || VIEW_USERS_GLOBAL`, line 27).
- [x] **3.5** Reproduce `isSuperAdmin` determination: `MainLayout.tsx:10` derives it from `hasPermission(VIEW_USERS_GLOBAL)`.
- [x] **3.6** Port `OrganizationSelector` (64 lines) — super-admin org switcher in the chrome.
- [x] **3.7** Port `QuickOrganizationPickerModal` (102 lines) — becomes a bottom sheet on mobile, dialog on desktop.
- [x] **3.8** Build the non-super-admin variant of the org display (`MainLayout.tsx:36`): a static org name label, no picker.
- [x] **3.9** Port the Profile nav link and Logout action.
- [x] **3.10** Replace the Bootstrap `#f8f9fa` page background and `#3174ad` primary with a Flutter `ColorScheme`, so screens land close to the current visual weight. Record chosen hex values in a comment for traceability.
- [x] **3.11** Replace icons. `react-icons/fa` gives ~6 glyphs; **the `bi bi-*` Bootstrap Icons were never installed** and currently render as empty `<i>` tags — do not attempt parity, use Material icons throughout.
- [x] **3.12** Confirm the shell renders at all three breakpoints **in a web browser**. Screenshotted at 500 / 900 / 1400 px against the live backend, signed in as a seeded user. **This pass found a layout bug every widget test had missed** — see the 2026-10-13 progress entry.
- [x] **3.13** Widget tests for the responsive chrome: nav items appear and disappear at each breakpoint, and `NavigationDrawer` / `NavigationRail` / sidebar render at mobile / tablet / desktop. Pin sizes rather than relying on a real browser — 3.12's real-browser pass stays as the manual check, and it earns its place: it caught a positional bug that no presence assertion here could see.
- [x] **3.14** Fix the organization display in the sidebar — only a chevron was visible. **Fixed.** See the 2026-10-13 progress entry: `DropdownButton` has three text paths that do not agree, all three of them defaulted to the light-container ink, and the static org label had the identical bug. Pinned by a contrast-ratio test that fails at 1.0:1 without the fix.
- [x] **3.15** Double-check the vertical sidebar against React. **Your recollection is right, and the difference is deliberate.** React *does* have an across-the-top bar: `MainLayout.tsx:14` is `navbar navbar-expand-lg navbar-dark bg-dark`, with the nav items inline and everything collapsing behind a `navbar-toggler` hamburger below Bootstrap's 992px. The port replaces it with a rail, and mobile already collapses to a hamburger and a flyout — so the second half of the question is also what was built.

  What actually changed, and why it is not parity:

  | | React | Port |
  |---|---|---|
  | Desktop | top bar, one row | extended rail |
  | Tablet | top bar, hamburger | collapsed rail |
  | Mobile | hamburger → collapse | hamburger → `NavigationDrawer` |
  | Org switcher | `<select>` inside the navbar | rail at ≥700, bottom sheet below |
  | Profile / Logout | right end of the bar | foot of the rail / drawer |

  The reason for the redesign is the one recorded when 3.6 was written: **the React navbar's own contents were unreachable on small screens.** The org `<select>` lived inside the collapse, so below 992px a super-admin had no way to switch organization at all, and `QuickOrganizationPickerModal` — the searchable list — was wired only to the event forms. A rail keeps the six nav items visible without a hamburger at 700px and up, and gives the org switcher a home at every size. The React layout was desktop-only and had one breakpoint; this has three.

  Cost, stated plainly: it is **not** visually faithful, and anyone comparing the two side by side will notice immediately. That is a deliberate trade for reachability, not an oversight, and it is the kind of decision worth revisiting if the team would rather match the current look and accept the responsive gap.

---

## Phase 4 — CRUD list screens

Covers `TableView.tsx` (90 lines) plus six list screens (~676 lines). **Redesign, not port.** Tables become responsive lists.

- [x] **4.1** Build a shared `ResponsiveListView` replacing `TableView.tsx`: data-table layout at desktop, card layout at mobile.
- [x] **4.2** Reproduce hover-revealed row actions. `TableView.tsx:17-18` exposes `onRowMouseEnter`/`onRowMouseLeave` purely so buttons appear on hover, across 6 call sites. On mobile use always-visible trailing actions or a long-press menu; **web may keep hover** behind a `kIsWeb` branch.
- [x] **4.3** Reproduce hover tooltips (`OverlayTrigger` in 5 files). Same `kIsWeb` treatment; use `Semantics` labels for accessibility on native.
- [x] **4.4** Port `CustomerList` (134 lines): search, paginated table, create/edit/delete.
- [x] **4.5** Port `InventoryList` (144 lines). **Done** — search, sort by name or quantity, create, delete. The `events` list is capped at 3 per row with a `+N more` count, and that cap is the one place this screen is not a transcription: `InventoryDao.toInventoryItemResponse` selects *every* `EventInventory` row for an item, so the list is unpaginated on `GET /api/inventory` too, not only on `GET /api/inventory/{id}`. Delete uses `confirmDestructiveAction` (4.8). The server-side N+1 behind it is **10.21**.
- [x] **4.6** Port `OrganizationList` (134 lines), gated on `VIEW_ORGANIZATIONS_GLOBAL`. **Done**, including the one thing that is *not* shared with the other two lists: this screen is deliberately **not** scoped to the selected organization. Delete uses `confirmDestructiveAction` (4.8).
- [ ] **4.7** Port `UserList` (264 lines) — the largest list screen. Includes role display and sort controls. **Two** delete flows (`UserList.tsx:79,94`), both via `confirmDestructiveAction` (4.8); the user one still calls an endpoint that does not exist (10.12).
- [x] **4.8** Port the 6 `window.confirm` delete flows as async dialogs (`CustomerList.tsx:60`, `InventoryList.tsx:60`, `OrganizationList.tsx:51`, `UserList.tsx:79,94`, plus events in Phase 7). **Done as one shared widget rather than six dialogs** — `confirmDestructiveAction` in `lib/widgets/confirm_dialog.dart`, used by the customer, inventory and organization screens. Ticked with 3 of 6 wired, because the wiring is not separate work: it is a call each screen makes while being ported, and 4.7 and 7.6 are already open for that. **Each of those two tasks carries the obligation to use the shared dialog** — a closed task is a claim nobody re-reads, and a hand-rolled fourth dialog would be silent. The *consequence* of a confirmed delete (refetch vs redirect) stays at the call site in every case, because `UserList.tsx:94` deletes an invitation and `EventDetails.tsx:49` navigates away.
- [ ] **4.9** Port pagination controls against offset/limit. Per-endpoint default limits vary (10 or 1000) — verify each. **Premise did not hold — no work needed.** `grep` finds no pagination control in any React list: all four fetch a single fixed page (`CustomerList.tsx:27` uses `25, 0`) and none can reach the rest. There is nothing to port. Whether to *add* paging is a product decision, not a porting one, and it is not recorded as a task.
- [x] **4.10** Port the search-debounce pattern. The React lists use plain `useState`; pick a deliberate debounce and note the interval.
- [ ] **4.11** Verify sort controls against each endpoint. **`sortBy` is silently ignored on `/api/events`**, and `GET /api/events` defaults `sortOrder` to `asc`.
- [x] **4.12** Widget tests for `ResponsiveListView`: table layout at desktop, card layout at mobile. **Split** — the third case in the original wording (the truncated `events` list on an inventory row) needs 4.5's screen, so it is now **4.13**.
- [ ] **4.14** **Stop the list flashing on every search. Optional — raised during task 4.4's browser check and confirmed tolerable by hand, so it is filed rather than fixed.** A new query takes the whole card down to a spinner, header and all, so the header blinks out and back on every keystroke that survives the 300ms debounce. `CustomerList.tsx:46-48` never showed this: it left the previous rows up until the response landed, because `setCustomers` only ran on success. Three fixes, cheapest first:
  1. **A thin `LinearProgressIndicator` over the existing rows**, with the previous items still rendered. Needs the last result kept across query keys, and it is the smallest change that removes the perceived flicker.
  2. **Keep the header rendered during loading** — pass a `loading` flag into `ResponsiveListView` so the columns stay put and only the body swaps. Fixes half the symptom; the rows still blink.
  3. **Retain the last value across family keys** with Riverpod's keep-alive link pattern, which restores the original behaviour exactly. Most machinery, and correct — `FutureProvider.autoDispose.family` disposes each key the moment it loses its last listener, which is why a new search starts from nothing.

  Deferred because the debounce already collapses a burst into one request, so the flicker is once per pause rather than once per keystroke, and the user judged it acceptable in a browser. Options 1 and 3 are not mutually exclusive; do 1 first and 3 only if the flash is still objectionable once the list is stale-but-visible.

- [x] **4.13** Widget test for the truncated `events` list on an inventory row — 4.12's third case, held back because it needs `InventoryList` (4.5). Rides with that task. **Done with 4.5** — four cases in `inventory_list_screen_test.dart`: never used, all shown under the cap, truncated with a `+N more` count, and the cap applied **per row** rather than across the list.

---

## Phase 5 — Forms (non-event)

~640 lines across seven forms, plus `CreateInvitationForm` (182). ~70 raw HTML inputs become explicit `TextFormField`s.

- [ ] **5.1** Establish a form convention: `TextFormField` + `InputDecoration` + `Form` `GlobalKey`, validators replacing HTML `required`. **No form library** — the React code has none, so this is a free choice.
- [ ] **5.2** Port `CreateCustomerForm` (146 lines) and `EditCustomerForm` (139 lines).
- [ ] **5.3** Port `CreateInventoryForm` (140 lines) and `EditInventoryForm` (132 lines).
- [ ] **5.4** Port `CreateOrganizationForm` (59 lines) and `EditOrganizationForm` (86 lines).
- [ ] **5.5** Port `CreateUserForm` (168 lines) and `EditUserForm` (153 lines).
- [ ] **5.6** Port `Profile` (78 lines) and `EditProfileForm` (87 lines) to `/profile`.
- [ ] **5.7** Port `CreateInvitationForm` (182 lines). **Also the first real end-to-end test of the invite link** (carried over from Phase 2): mint an invitation here, then open `${Uri.base.origin}/register?token=...` cold and accept it, confirming the account is created and the app redirects to `/login`. This is the one flow the whole `usePathUrlStrategy` decision exists to serve, and Phase 2 could not exercise it — there was no way to mint a token. The server side is already proven (`/register?token=nonsense` survives the Ktor SPA fallback and reaches `GET /api/invitations/validate` intact); what remains is the success path and the link generated by 5.10.
- [ ] **5.8** Port `InventoryAssociationEditor` (143 lines) — shared component, largest in `common/`.
- [ ] **5.9** Replace HTML input types with Flutter pickers: `type="date"` → `showDatePicker`, `type="time"` → `showTimePicker`, `type="number"` → numeric `TextFormField` with `FilteringTextInputFormatter`, `type="email"` → `RegExp` validator.
- [ ] **5.10** **Fix the invite-link bug surface.** `UserList.tsx:157` and `CreateInvitationForm.tsx:74` build `${window.location.origin}/register?token=`. Derive the origin from `Uri.base` — no native path needed, since invitees receive a link they open in a browser. Ensure the link is not token-dependent on any in-app state.
- [ ] **5.11** Two-column `col-lg-*` layouts become single-column scrolls on mobile; modals become bottom sheets. Apply to all seven forms.
- [ ] **5.12** Verify `EditUserForm` gating. `App.tsx:63` gates it on `MANAGE_USERS_GLOBAL` only, while `App.tsx:62` gates create on either global or org — this asymmetry is likely a bug; confirm intent before porting.
- [ ] **5.13** Widget tests for the form convention: required-field validators reject empty input, and the invite link built in 5.10 is derived from `Uri.base` and carries the token as a query param. The forms are the largest surface in the port and the least covered, so start with one representative form rather than all seven.

---

## Phase 6 — Event forms (highest risk)

`CreateEventForm.tsx` (518) + `EditEventForm.tsx` (442) = **960 lines**, the densest code in the app. Budget 5–7 days.

- [ ] **6.1** Inventory every field and every conditional in both forms before writing code. Produce a written field-by-field map in the PR description.
- [ ] **6.2** Port the ~20 `useState` fields per form to Riverpod form state, or `TextEditingController`s. **Decide deliberately** — there is no existing abstraction to preserve.
- [ ] **6.3** Port the three nested modals in each form.
- [ ] **6.4** Port cross-form logic: auto-fill event location from the selected customer's address.
- [ ] **6.5** Port `locationManuallyEdited` tracking — once the user edits location, stop overwriting it from the customer address.
- [ ] **6.6** Port the org-scoping cascades that refetch customers/users/inventory when the selected organization changes.
- [ ] **6.7** Port `staffInvites` handling. This is the **only** mechanism for event staffing — the staff endpoints documented in `API.md:343-351` **do not exist** server-side.
- [ ] **6.8** Port inventory association within the event form.
- [ ] **6.9** Handle the `PUT /api/events/{id}` response, which returns `data: "Event with ID N updated"` — a **bare string, not a DTO**.
- [ ] **6.10** Ensure `go_router` invalidates the right providers after create/update so list and calendar views refresh.
- [ ] **6.11** End-to-end test the full create flow and the full edit flow, including customer-address autofill and org switching.

---

## Phase 7 — Calendar, list, details, RSVP

- [ ] **7.1** Rebuild `EventCalendar.tsx` (329 lines) as a `table_calendar` month grid. **Explicitly dropping:** week / work-week / day / agenda views, drag-to-select slot creation, and the hover-to-reveal "Create Event" placeholder (`EventCalendar.tsx:26-68`, which needs a 100 ms mouseleave timer purely to avoid flicker).
- [ ] **7.2** Replace drag-to-select with **long-press-a-day** to open the create form prefilled with that date.
- [ ] **7.3** Replace the hover placeholder with a visible create affordance (FAB) on mobile and an `+` affordance on web.
- [ ] **7.4** Reproduce `eventPropGetter` / `dayPropGetter` styling, including today's `#e7f0f7` highlight.
- [ ] **7.5** Port `EventListPage` (240 lines): title, date, time, description, customer, RSVP columns → responsive rows.
- [ ] **7.6** Port `EventDetails` (277 lines), including the two `window.confirm` flows — via `confirmDestructiveAction` (4.8), and note the delete navigates away rather than refetching — and the `RsvpWidget` (72 lines) — drop-in RSVP posting `availability: "available" | "unavailable"` as a **free-form string**, not an enum.
- [ ] **7.7** Port `OtherEventsPanel` (97 lines).
- [ ] **7.8** Replace `moment` with `intl` + `DateTime`. The existing parsing is fragile — `new Date(event.date + 'T' + event.time)` at `EventCalendar.tsx:230` — so use explicit `DateTime` construction.
- [ ] **7.9** Handle timezone-naive timestamps. The API returns `"YYYY-MM-DD"` / `"HH:MM:SS"` strings with **no timezone**. Do not silently re-interpret as UTC; keep naive local semantics to match current behavior, and note this as a known limitation.
- [ ] **7.10** Route `/events/rsvps/requested` into the UI. It is **undocumented in `API.md`** but real (`EventRoutes.kt:118`). Confirm whether the React app uses it — if not, decide whether to expose it.
- [ ] **7.11** Tests for the calendar's date handling, which is where the fragile logic lives: naive-local date construction (7.8/7.9), and the month grid rendering the right events on the right days. Golden tests for the grid itself are 12.5 — here it is the placement logic, not the pixels.

---

## Phase 8 — Reports

- [ ] **8.1** Port `ReportList` (133 lines).
- [ ] **8.2** Port `POST /api/reports/staff_hours` (date-range form → `List<StaffHoursReportResponse>`).
- [ ] **8.3** Port `GET /api/reports/inventory_usage` (→ `List<InventoryUsageReportResponse>`).
- [ ] **8.4** **Client-side org filtering is required.** `ReportService` receives no `AuthContext`, so `_GLOBAL`/org scoping is not applied server-side. Decide whether to filter in the UI or fix the backend — flagged, not silently replicated.
- [ ] **8.5** Both report endpoints return **unpaginated** lists over the whole org. Virtualize the tables.
- [ ] **8.6** Tests for the client-side org filtering added in 8.4 — the server applies no scoping, so this logic is the only thing preventing one org's staff hours showing in another's report. That makes it worth a test even though the surrounding UI is simple.

---

## Phase 9 — Responsive, accessibility, polish

- [ ] **9.1** Audit all 25 former Bootstrap `row`/`col` sites; confirm each degrades to single-column on mobile.
- [ ] **9.2** Replace fixed pixel sizing that was tuned for wide viewports: calendar `height: 800` (`EventCalendar.tsx:297`), search input `width: '250px'` (line 248), list column `maxWidth: '150px'` (`UserList.tsx:179`), modal `maxHeight: '300px'` (`QuickOrganizationPickerModal.tsx:72`).
- [ ] **9.3** Add `Semantics` labels to icon-only buttons, now Material icons rather than `<i>` tags.
- [ ] **9.4** Verify touch target sizes (≥44pt) on all mobile list actions.
- [ ] **9.5** Add `FocusTraversalGroup` / focus order for keyboard and screen-reader navigation on web.
- [ ] **9.6** Handle concurrent-request cancellation. Three React `setTimeout` calls exist (`AcceptInvitationPage.tsx:73`, `UserList.tsx:160`, calendar hover); the React code never cancels them — use `CancellationToken` and cancel in `dispose`.
- [ ] **9.7** Add pull-to-refresh on mobile list screens.
- [ ] **9.8** Add an app-level error boundary surfacing `ApiException.details`. **Note:** `Application.kt:55-75` returns `cause.stackTraceToString()` in `error.details` on 500s, so server internals reach the client. Consider rendering `details` only behind a debug flag.
- [ ] **9.9** Fix the known 500 stack-trace leak server-side, or suppress `details` in the UI.
- [ ] **9.10** Full pass at all three breakpoints, plus mobile browser widths and touch input.
- [ ] **9.11** Tests for the error boundary from 9.8: an `ApiRequestException` surfaces its message, and `details` is hidden unless the debug flag is on. Also assert cancellation (9.6) does not surface an error to the user.

---

## Phase 10 — Cutover and cleanup

Once the Flutter web app is verified working locally against the real backend. The trigger for deleting `frontend/` is internal confidence, not a deployment.

- [ ] **10.0** Strip out comments referencing conversion tasks or filename/linenumber combos.  If dart has javadoc-like capabilities for linking use those, otherwise use File.member type references.
- [ ] **10.1** Default `WEB_SOURCE` in `Dockerfile` to `flutter`; keep the React stage for one release cycle, then remove.
- [ ] **10.2** Verify the Flutter build end-to-end against the real backend via `docker compose up --build`: login, org switch, and one full create/read/update/delete pass per resource.
- [ ] **10.3** **Delete `frontend/`.** The last commit touching it is the deletion commit.
- [ ] **10.4** Remove React deps, ESLint config, and node tooling references from the repo.
- [ ] **10.5** Update `AGENTS.md`, `README.md`, and `BACKEND-DESIGN.md` for Flutter conventions.
- [ ] **10.6** Update `API.md` for the drift found during the port (below) — regenerate rather than hand-edit, per `build.gradle.kts:23-87`.
- [ ] **10.7** Remove dead `backend/service/geo/` code if the Flutter app does client-side geocoding, or wire up `GeoRoutes` if it does.
- [ ] **10.8** **Strip dangling `frontend/` references from `flutter_app/lib/`.** 10.3 deletes the directory these comments point at, leaving paths like ``frontend/src/api/apiClient.ts`` that resolve to nothing — a comment that looks like a citation a reader could follow but cannot. 10.4 covers React *dependencies* and node tooling; it does not reach prose in doc comments.

  **Do not delete these references wholesale — they carry the rationale for non-obvious decisions.** Most of the 10 current occurrences explain *why* something is shaped the way it is, and that reasoning is the durable value. Reword to keep the explanation and drop the path, e.g. rather than "Replaces `apiClient` in `frontend/src/api/apiClient.ts`", say "Replaces the React app's hand-rolled `apiClient`, which wrapped `fetch`".

  Known occurrences at time of writing (verify with `grep -rn 'frontend/src' flutter_app/lib/`):

  | File | What it explains |
  |---|---|
  | `core/api/api_client.dart` | Replaces the React `apiClient` and its ~20 duplicated `try/catch` sites |
  | `core/api/api_exception.dart` | Why an exception hierarchy exists at all |
  | `core/api/token_store.dart` | Replaces `localStorage` |
  | `core/theme/teven_theme.dart` (×2) | Bootstrap `#f8f9fa` / `#3174ad` carry-over values |
  | `models/permissions.dart` | OR-semantics of the permission guard |
  | `models/role.dart` | Role names as strings, not ids |
  | `models/common.dart` | Why `StatusResponse` is near-vestigial |
  | `models/customer.dart` | Geo fields absent from the old types |
  | `models/report.dart` | Missing `displayName` column |

  Also check `frontend/public` references (favicon provenance in `web/`) and run the same grep across `flutter_app/test/`, `Dockerfile`, `docker-compose.yml`, and `./teven`.

- [ ] **10.9** **Make the server's error responses conform to the envelope, then remove the client's compensating branches.** The client currently carries permanent defensive code for a server inconsistency that is a two-line fix. `AuthorizationPlugin.kt:24,31` responds with a bare string while every other route uses `failure(...)`; the Flutter client therefore special-cases bare strings in `ApiClient._tryDecode` / `_NonJsonBody`.

  **Ordering is load-bearing.** This must come *after* 10.3. Until `frontend/` is deleted both pipelines are live, and the React `apiClient.ts` unwraps `data` unconditionally — changing these responses now breaks the React app. That is the real reason the Phase 0–8 "do not modify the backend" rule exists, and it is why this is not a Phase 1 task.

  Two commits:
  1. `AuthorizationPlugin.kt` — replace both bare-string `call.respond` calls with `failure(...)`, matching every other error path.
  2. Delete the now-dead branches in `ApiClient`: `_NonJsonBody`, the bare-string path in `_unwrap`, and the bare-string branch in `_errorFor`. Kept separate so it is clear the defensive code was **temporary**, not left behind by oversight.

  **Keep the content-type sniff even after this.** Task 1.12's `index.html`-at-HTTP-200 case is not a server bug — it is a structural consequence of serving the SPA from the same origin as the API (`Routing.kt:56`), and will outlive any change to error formatting. Only the *bare-string* handling is contingent.

  Verify after: a 403 from a permission failure arrives as a normal envelope, and the client still throws `ApiRequestException` carrying the server's message.

- [ ] **10.10** **Give the remaining non-conforming *success* responses a real DTO.** Distinct from 10.9, which covers **error** responses only. These are successes whose envelope is intact but whose `data` is a bare string, so callers get `String` where they expect an object. Counted from the source, there are **11 call sites**:

  | Pattern | Sites |
  |---|---|
  | `success("... with ID N updated")` | customer, inventory, organization, event, role (5) |
  | `success("OK")` | role ×2, inventory, event (4) |
  | `success("Created invitation")` | invitation ×1 |
  | 204 `NoContent` with no envelope at all | customer, inventory, organization, event, role (5) |

  The second and third rows are the ones that actually cost the client something: `PUT /api/events/{id}` returning `"Event with ID N updated"` is why task 6.9 exists, and `StatusResponse` in `common.dart` is near-vestigial because deletes return 204 rather than the `{status, message}` shape the React types claimed.

  **This is a bigger change than 10.9 and should be scoped deliberately.** Options, in increasing order of effort: introduce a `MessageDto { message: String }` and wrap; return the updated entity instead of a string; or leave as-is and document. `success("OK")` in particular carries no information — `data: {}` or `204` would be equivalent. Whichever is chosen, the client-side fallout is deleting `ResponseBody.bareString`, `ApiClient.deleteWithBody`, and possibly `StatusResponse`, so that task must land too.

  Verify after: every `success()` response carries a typed payload, and `grep -rn 'success("' backend/app` returns nothing.

- [ ] **10.11** **Implement `sortBy` on `GET /api/events`, or delete the parameter.** Confirmed dead: `EventRoutes.kt` never reads `sortBy` (zero occurrences) and neither does `EventDao`. Every other list DAO honours it — `CustomerDao` switches on `"name"` and falls back to id — so events are the outlier. `API.md` documents it as working.

  `sortOrder` **does** work and defaults to `asc`, which is the more surprising half: callers expecting "newest first" get the earliest event unless they pass `sortOrder=desc`. Worth fixing alongside, or at minimum correcting in `API.md`.

  Task 4.11 tells the UI to verify sort controls; this is the task that makes that verification pass.

- [ ] **10.12** **Implement hard `DELETE /api/users/{id}`, deleting dependent rows explicitly.** **Decision made: hard delete, not soft.** The button exists in the React UI (`UserList.tsx:81`) and has never worked.

  **The database will not cascade on its own.** Verified against the running dev database rather than inferred from the Kotlin — all five FKs onto `users(id)` are **`ON DELETE RESTRICT`**:

  | Table | Column | Actual `delete_rule` |
  |---|---|---|
  | `rsvps` | `user_id` | RESTRICT |
  | `staffhours` | `user_id` | RESTRICT |
  | `userroles` | `user_id` | RESTRICT |
  | `userorganizations` | `user_id` | RESTRICT |
  | `invitations` | `used_by_user_id` (nullable) | RESTRICT |

  So `DELETE FROM users` fails with an FK violation if any dependent row exists. **There are five, not one** — an earlier draft of this task claimed `StaffDetails` would cascade; that table is not in `DatabaseFactory.kt`'s `SchemaUtils.create` list, so it **does not exist** in the database (confirmed: `\dt` returns 13 tables, no `staffdetails`) and is never queried anywhere. The one table that declared `CASCADE` is a phantom.

  **The dev database can be regenerated, so add `ReferenceOption.CASCADE` to the five FKs** in `Rsvps.kt`, `StaffHours.kt`, `UserRoles.kt`, `UserOrganizations.kt`, and `Invitations.kt`. Then the DAO needs no manual ordering and the schema documents its own intent.

  **One exception:** `Invitations.usedByUserId` should stay `RESTRICT`/nullable and be **nulled explicitly, not cascaded** — the invitation is audit-relevant and should outlive the user who accepted it. So: cascade the four genuinely-dependent tables, null the invitation.

  **Schema regeneration:** `DatabaseFactory` uses `SchemaUtils.create`, which is **create-if-missing and never alters existing tables** — it will not add a CASCADE to an already-created FK. Since the schema comes entirely from Exposed (no `.sql` files, no Flyway/Liquibase), recreating the dev database is the correct and supported path: drop and recreate, then let `init()` rebuild. Confirm nothing of value lives in the dev database before doing so.

  If instead the ordering is done manually in the DAO, follow the precedent already in `TestDataProvider.kt:52-55`:

  ```kotlin
  Rsvps.deleteWhere { Rsvps.userId eq userId }
  StaffHours.deleteWhere { StaffHours.userId eq userId }
  UserRoles.deleteWhere { UserRoles.userId eq userId }
  UserOrganizations.deleteWhere { UserOrganizations.userId eq userId }
  Invitations.update({ Invitations.usedByUserId eq userId }) {
    it[usedByUserId] = null   // nullable — preserve the invite record
  }
  Users.deleteWhere { Users.id eq userId }
  ```

  **Ordering is load-bearing** — `Invitations.usedByUserId` is nullable and the invite should survive with the link cleared, since the invitation itself is audit-relevant. Everything else is genuinely dependent and goes.

  **Prefer adding `CASCADE` over manual deletes** — it removes a whole class of future bug where a new dependent table is added and silently forgotten. The five FKs to change are listed above.

  **Guard rails.** Reject deleting the **last** super-admin, and reject self-deletion (a user who can delete themselves can lock themselves out mid-session). Check `VIEW_USERS_GLOBAL`/`MANAGE_USERS_GLOBAL` scoping so one org's admin cannot delete another's user — mirror the permission model on `PUT /api/users/{id}` (`UserRoutes.kt:84`).

  **The last-super-admin check is close to redundant, but not quite — verify before dropping it.** Banning self-deletion does make "zero super-admins left" unreachable *by the obvious route*: the deleter always survives their own delete, so the count bottoms out at one. That argument is sound and it is why the self-deletion ban is the load-bearing half.

  It has a hole, though, and the hole is in the permission model rather than in this route. **`isSuperAdmin` is derived from `VIEW_USERS_GLOBAL`** (`MainLayout.tsx:10`), while the delete button is gated on **`MANAGE_USERS_GLOBAL || MANAGE_USERS_ORGANIZATION`** (`UserList.tsx:25`). Those are independent grants, so a user holding only `MANAGE_USERS_ORGANIZATION` can delete users and is *not* a super-admin — and could delete the only super-admin without deleting themselves. Two ways to close it, and the cheaper one is preferable:

  - **Ban self-deletion server-side and make "may delete users" imply super-admin** (gate the route on `VIEW_USERS_GLOBAL` rather than `MANAGE_USERS_GLOBAL`). One-line, and the invariant then holds by construction.
  - **Keep the last-super-admin check** as a backstop, and re-check it whenever a new `MANAGE_*` permission is granted to non-super-admins.

  Either way the route must check self-deletion **server-side**; a client-side check is a UI affordance, not a guard, and the React delete button is a UI affordance. Note that the *button* in `UserList.tsx:79` has never worked, so there is no existing behaviour to preserve here and no regression risk in fixing it.

  Add the route to `API.md`, where it is currently documented as if it exists.

- [ ] **10.13** **Restore the staff-details feature: create `staff_details`, store `skills` as a proper list, and fix the silent-discard path.** **Decision made: fix it, do not delete it.** Staff profiles are a real feature the app presents, so the table and its read/write path get built properly rather than removed.

  **The bug today.** `StaffDetails.kt` defines the table but `DatabaseFactory.kt` omits it from `SchemaUtils.create`, and there is no DAO — nothing in `data/`, `core/`, `service/`, or `app/` references it. With no `.sql` files and no migration tool, the table is simply never made (confirmed: `\dt` returns 13 tables, no `staffdetails`). So `UserResponse.staffDetails` is **always null**, and:

  - `Profile.tsx:61` guards on `userDetails.staffDetails &&` — the block never renders, so the fields silently vanish from the profile screen.
  - `EditProfileForm.tsx:28` sends `staffDetails` on **every** save and `UpdateUserRequest` accepts it on the wire, but nothing reads it. **The user's edits are discarded with no error.** This silent-discard path is the actual defect and must be closed regardless of the rest.

  **Work items, in order:**

  1. Add `StaffDetails` to `SchemaUtils.create` in `DatabaseFactory.kt`. The `CASCADE` on its `userId` FK is already declared and correct — it is currently the only well-formed part of this feature.
  2. Write a `StaffDetailsDao`: fetch by `userId`, insert, and update-merge. Follow `UserDao`'s shape.
  3. Wire `staffDetails` into `toUserResponse` (`UserDao.kt:27`) so it populates, and into the update path so `UpdateStaffDetails` is applied rather than dropped.
  4. **Populate `hoursWorked` from `StaffHours`**, do not trust the column on `staff_details` — see below.
  5. Create the row lazily: a user has no staff details until something writes them, so reads must treat "no row" as `null` rather than erroring. This is why the DTO field is nullable.

  **`skills` becomes a real list — and the wire format already is one.** `StaffDetails` (the DTO) declares `skills: List<String>`; only the *storage* is wrong — a comma-separated `text` column, annotated "for simplicity". So this is a backend-only change: the JSON contract does not move. Choose one:

  - **Separate join table** (`staff_skills(user_id, skill)`) — normalized, no escaping concerns, queryable. Most work.
  - **JSON/array column** (`text` holding a serialized `List<String>`) — least work, still no comma corruption.

  Precedent to weigh: `Roles.permissions` stores a list the same comma-separated way (`RoleDao.kt:22,30,65`), so the codebase already has this pattern twice over. **Fix both or neither** — leaving `Roles.permissions` comma-joined while making `skills` a real array just relocates the same corruption. Add `Roles.permissions` to this task if that scope is acceptable, or file it separately; do not leave them half-converted.

  **Do not use a comma join at all.** Any skill containing a comma — "Forklift, electric" — silently corrupts into two entries. There is no data to migrate (no users yet, and no test data creates staff details), so there is no reason to preserve the format.

  **`hoursWorked` has no source today.** `StaffDetails.hoursWorked` is a stored column, but **nothing ever writes `StaffHours` rows** — `EventService` never inserts them. So the staff-hours *report* (`ReportDao.kt:19`) reads a table that is always empty, and the `hoursWorked` on `staff_details` would be a dead value. Decide whether hours are accumulated from event attendance (RSVP `available` plus event duration) or the column is dropped from the DTO. Do not ship a column that reads 0 forever.

  **`dateOfBirth` is `varchar(20)`** with an "ISO 8601" comment but no validation anywhere (`StaffDetails.kt:12`). Leave as a string for parity, or convert to a real date type — a decision, not an accident.

  **Add `staff_details` to the schema check** so a missing table fails at boot rather than surfacing later as vanished profile fields. That class of bug — a table defined but never created — is exactly what let this ship, and it cost a whole phase to notice.

- [ ] **10.14** **Delete the dead `POST /api/events/{id}/join` route and `EventService.joinEvent` from the React app.** **Confirmed leftover from before the RSVP system** — this is settled, not an open question.

  The git history is unambiguous, and all four commits land on **2025-09-14**:

  | Commit | Message |
  |---|---|
  | `f2ca476` | wip users can join events |
  | `13d3ef6` | view joined users on an event |
  | `a6b28e7` | use existing rsvps class |
  | `fdaf271` | **remove the join route, use only the rsvp route** |

  So `join` was built first, then RSVP was introduced alongside it, then `join` was deleted the same afternoon. In `a6b28e7` both routes coexist — `post("{event_id}/rsvp")` at line 142 and `post("{event_id}/join")` at line 161 — and `fdaf271` removes `join`, changing 4 files and −69 lines.

  **The permission is vestigial too.** The deleted route was gated on `ASSIGN_TO_EVENTS_SELF`, which still exists in `Permission.kt` and is now unreachable. Clean it up in the same change, or note in task 10.16 why it is retained.

  **The React client was never updated.** `EventService.joinEvent` (`EventService.ts:56`) still calls the removed route — the commit removed the server side and `EventDetails.tsx`, but not the service method. Nothing calls it, so it 404s silently if ever invoked.

  Remaining work: delete `joinEvent` from `frontend/src/api/EventService.ts` (before 10.3 removes the directory), and confirm nothing referenced it. `EventService` in `flutter_app` already omits the method for the same reason as 10.12.

- [ ] **10.15** **Give list endpoints a real default `limit` instead of returning every row.** Every DAO does `limit?.let { query.limit(it) }` — `CustomerDao.kt:73`, `EventDao.kt:180`, plus `UserDao`, `InventoryDao`, `OrganizationDao`. Omitting `limit` therefore applies **no cap**, and the `limit: 0` echoed in the response is cosmetic. An unfiltered `GET /api/customers` returns the entire customer table.

  The client already defends itself (task 1.18 defaults events to `limit: 10`), but that is a mitigation in one caller, not a fix — any other client, or a caller that forgets the parameter, still gets everything. Note the interaction with `total`: the count query is computed before the limit is applied, so `total` is already the unpaginated figure and a server-side default would not break the pagination UI.

  Pick a sane default per resource, or one global default, and return it in the `limit` field so clients can see what was applied rather than inferring it from a `0` that means nothing. Then drop the matching client-side defaults where they become redundant.

- [ ] **10.16** **Close the permission gap: 33 server permissions, 15 client-known.** `core/security/Permission.kt` defines 33; `src/types/permissions.ts` declared only 15. The 18 unreachable ones are mostly `*_GLOBAL` variants beyond organizations (`MANAGE_EVENTS_GLOBAL`, `MANAGE_CUSTOMERS_GLOBAL`, `MANAGE_INVENTORY_GLOBAL`, `MANAGE_ROLES_GLOBAL`, …) plus `MANAGE_ROLES_*`, `ASSIGN_*`, `CAN_ASSIGN_*`, and `MANAGE_USERS_SELF`.

  The backend enforces all 33, so a super-admin *can* hold a permission the client cannot name — meaning the UI cannot gate anything on it, and a nav item or route guard for that capability simply cannot be built. Confirm each of the 18 is intentional and either: (a) grant it a client constant and gate the corresponding UI, or (b) remove it from the server enum if nothing should ever use it. `RoleService` currently exposes read-only access, so `MANAGE_ROLES_*` has no UI at all.

  `Permission` in `flutter_app/lib/models/permissions.dart` mirrors the React 15 for parity. Extend it in the same commit, and re-check the role-assignment path discrepancy already in the table (`API.md:632` is wrong; see `RoleRoutes.kt:86`).

- [ ] **10.17** **Decide whether `RsvpRequest.availability` stays a free-form `String`.** The server type is `String` with no validation (`RsvpRequest.kt`) and the app posts `"available"`, `"unavailable"`, and server-initiated `"requested"`. Any string is accepted, so a typo is stored silently and only shows up as a filter that never matches.

  An enum on the server would catch that at the boundary. The cost is a migration for existing rows holding values outside any chosen set — check the data first (`SELECT DISTINCT availability FROM rsvps`) before deciding, since that query is cheap and the answer determines whether this is a small change or a data migration. Client-side, `RsvpAvailability` in `models/event.dart` already names the three values in use; tighten it once the server agrees on a set.

  **Already covered elsewhere, do not duplicate:** `Dockerfile:32-47` (the `frontend-react` builder stage, including its `COPY frontend/src` and `COPY frontend/public` lines) disappears with 10.1. Those are functional build instructions, not comments, so they are not this task's concern. `FLUTTER-CONVERT.md` itself is *expected* to reference `frontend/` paths throughout — it is a historical record and keeps them deliberately; exclude it.

- [ ] **10.19** **Soft-delete customers, so deleting one does not destroy the events that reference it.** Found by deleting a real customer during task 4.4's browser check. **Decision made: soft delete**, on the grounds that prior events are business records and a customer row is not.

  **The bug, exactly as the server reports it.** `CustomerDao.deleteCustomer` is `Customers.deleteWhere { Customers.id eq customerId } > 0` — a hard delete. `Events.customerId` is `integer("customer_id").references(Customers.id).nullable()` with no `onDelete`, so the FK is `ON DELETE NO ACTION`, and the delete fails the moment the customer has any event at all:

  ```
  ERROR: update or delete on table "customers" violates foreign key constraint
  "fk_events_customer_id__id" on table "events"
   Detail: Key (id)=(10) is still referenced from table "events".
  ```

  It surfaces to the user as a **500 carrying a Java stack trace**, via `Application.kt`'s generic handler — so the failure looks like a server fault rather than a refused delete. It has been this way for as long as the delete button has existed, and it is invisible to anyone whose customers have no events, which is most of them early on.

  **Note the nullable column is doing nothing here.** `customer_id` being nullable means an event can have no customer, which is the shape a *hard* delete would want after nulling the references. Nothing nulls them, so the escape hatch that was built into the schema is unused. That is worth deciding explicitly rather than leaving as an accident: soft delete keeps the references, and the nullable column then only ever serves events that genuinely have no customer.

  **Work items:**

  1. Add the flag to `Customers` — `deletedAt` (timestamp, nullable) is the better choice over a boolean, because it answers "when" as well as "whether" and can be indexed. **`SchemaUtils.create` is create-if-missing and never alters an existing table** (established in 10.12), so this needs the dev database dropped and recreated; there is no migration path in this project.
  2. `deleteCustomer` sets the flag instead of deleting, and returns the same shape it does now.
  3. **Filter every read path, and this is the part that decides whether the task is 10 lines or 60.** `CustomerDao` has five: `getCustomers` (paged), `getAllCustomers`, `getAllCustomersByOrganization`, `getCustomerById`, and the one used to resolve the customer embedded in an event response. The first four must exclude deleted rows; **the fifth must not**, or every historical event silently loses its customer. `getCustomers` is the easy one — it already builds a `conditions` list and counts from the same query, so one added condition fixes the list *and* the `total` together. Put the filter in one helper so a sixth read path cannot forget it, and grep for direct `Customers.selectAll()` uses when adding it.
  4. Decide what `GET /api/customers/{id}` returns for a deleted customer: 404 is cleanest and stops the edit form resurrecting a row that is meant to be gone. Whichever it is, `EditCustomerForm` should not be able to un-delete by accident.
  5. Decide whether an edit to a deleted customer is allowed at all. The simplest coherent rule is that a deleted customer is immutable.

  **No client change is needed.** The Flutter button, the shared `confirmDestructiveAction` dialog, the refetch, and "the row disappears from the list" all keep working, because a soft-deleted row is simply filtered out of the list. That is the main argument for doing it this way rather than as a 409.

  **Why not just null the references, or cascade?** Nulling them is the hard-delete variant and throws away exactly the thing this task exists to preserve: the event would keep its date and description and lose the customer, which is the one field anyone reads. Cascading is worse and not worth spelling out. Soft delete preserves both the event and the customer's name on it, at the cost of the filtering work in item 3.

  **This decision and 10.12's are deliberately different, and the difference is worth stating.** 10.12 chose a *hard* delete for users and nulls `Invitations.usedByUserId` rather than cascading. The split is on what the row *is*: a user is an identity that other rows authenticate against, and a deleted user should stop authenticating; a customer is a reference that history points at, and deleting one should not rewrite the past. If 10.12 is ever revisited, this is the reasoning to revisit it against — "history is audit-relevant" argues for soft-deleting users too, and the reason it does not is credential revocation, which is a real reason.

  **Reachable through the UI, so it is not theoretical.** The customer list's delete button (`CustomerList.tsx:60`, ported in 4.4) hits this on the first customer that has an event. Given events are the core of the app, that is most customers in real use.

- [ ] **10.20** **Build the customer details screen.** Found during task 4.4's browser check: clicking a customer's name lands on the event calendar. **Design direction is settled — a read-only rendering of the same fields the edit form shows, with the customer's events on the page. Build it; do not drop the link.**

  **The screen has never existed, in any commit.** Verified rather than inferred, because it was asserted both ways in conversation and the history settles it:

  | Check | Result |
  |---|---|
  | `grep -rl "CustomerDetail\|customerDetails" frontend/src/` | **nothing** — no component, no import, no link target |
  | `git log -S 'customers/:' --all` | **zero commits** — the route has never been declared |
  | `git log --diff-filter=ADR --name-only -- '*CustomerDetail*'` | **nothing** — the file was never added, deleted or renamed |
  | All-time file list — `git log --all --name-only \| grep -i customer` | three React components: `CreateCustomerForm`, `CustomerList`, `EditCustomerForm`. That is all, ever |

  **Two documents in the repo assume it exists, which is why it is so easy to believe it does.** `CustomerList.tsx:78` links to `/customers/${id}`, and `GEO_FEATURES_PLAN.md:80` lists *"Add `MapDisplay` to `EventDetails` and `CustomerDetails`"* as a geocoding task. Both reference a screen that was planned and never built — and that plan document is still in the repo, still referring to it. A dead link plus a live plan document makes a convincing fiction. Worth recording because the geocoding plan has an open task that cannot currently be done.

  **The port reproduces the dead link exactly.** No `/customers/:customerId` route is registered, so the path falls through the `*` catch-all (`App.tsx:67`) to `/`, and the index route sends it to `/events`. Faithful; the fix is to build the screen rather than deviate from the original.

  **Work items, in order.**

  1. **The events list is the real work, and it is blocked on the backend.** The intended shape is the customer's past *and* future events, and `GET /api/events` **has no customer filter** — `EventRoutes.kt` takes `search`, `sortBy`, `sortOrder`, `limit`, `offset` and no `customerId`, and neither does `EventDao`. So this is not purely a screen task: it needs a new query parameter on the route and the DAO, which is Phase 10 backend work under the ground rules. If the screen is wanted before that parameter lands, ship the field rendering first — a customer page with no events on it still beats a link to the calendar.
  2. Register the route in the port's table in Phase 5, alongside the forms, behind `VIEW_CUSTOMERS_ORGANIZATION` — the same gate as the list. **Not** `MANAGE_CUSTOMERS_ORGANIZATION`: the rendering is read-only and viewers can see the list, so the `App.tsx:62` create/edit split does not apply to a screen that cannot write.
  3. Render the fields `EditCustomerForm` shows, as disabled rather than absent, so the two stay comparable. Do not build it as "the edit form in read-only mode" — that couples a read path to a write path, and the part that will differ (the events section) is most of the page.
  4. The geo fields (`latitude`, `longitude`, `formattedAddress`) are on the DTO and null in practice, because the backend's geo service is dead code (**10.7**). Render them when the geocoding work lands (**`GEO_FEATURES_PLAN.md`**), not before — otherwise it is a page of empty coordinates.

  **The same shape of problem exists for staff details, and the reason neither is noticed is identical.** `StaffDetails` is a planned surface with a DTO field and no storage (**10.13**), and `GEO_FEATURES_PLAN.md` assumes it too. Two documents promising screens the app does not have is a pattern rather than a coincidence, and it survives review because nothing links to either — so nothing fails, and the only way to notice is to click.

- [x] **10.18** **Make the seeded test users loggable in.** Found while trying to discharge task 3.12's real-browser check.

  `TestDataProvider.kt` writes `it[passwordHash] = "password"` into `users.password` — a plaintext string in a column that `AuthServiceImpl.loginUser` passes straight to `BCrypt.checkpw`. That call **throws** `IllegalArgumentException: Invalid salt version` on the first character, and nothing catches it, so the request escapes to the generic 500 handler. Every seeded account (`alice`, `bob`, `charlie`, `diana`) answers:

  ```
  {"success":false,"data":{},"error":{"message":"Internal server error",
   "details":"java.lang.IllegalArgumentException: Invalid salt version
    at org.mindrot.jbcrypt.BCrypt.hashpw(BCrypt.java:659) ..."}}
  ```

  Not a 401, not a 400 — a 500 carrying the stack trace, which is task 9.9's leak arriving through a different door. Two things worth fixing, and the first is the one that matters:

  1. **Seed a real hash.** `BCrypt.hashpw("password", BCrypt.gensalt())` at seed time. `PasswordHasher` already exists in `core` and `UserDao.createUser` already used it — only the seed was bypassing it.
  2. **Do not let a malformed hash become a 500.** `checkpw` throwing `IllegalArgumentException` should be a failed login, not an unhandled error. A stored value that is not a hash is corrupt data; the response should say "these credentials are wrong" (401) and log the corruption, not serialize a stack trace to the caller.

  Verify after: `POST /api/users/login` with `alice` / `password` returns a token and a 200, and a deliberately corrupted `users.password` returns 401 rather than 500. Note that jbcrypt rejects `$2y$` as well as plaintext (`Invalid salt revision`), so anything producing the hash — `htpasswd` included — must be `$2a$`.

  **Done — see the 2026-10-13 progress entry.** Two things beyond the above surfaced while fixing it: `checkpw` throws `StringIndexOutOfBoundsException` for short inputs as well as `IllegalArgumentException` for `$2y$`, and `UserDao.createUser` was hashing the password twice.

---

- [ ] **10.21** **Stop `GET /api/inventory` embedding an unbounded `events` list per row.** Found while porting the inventory list (4.5). `InventoryDao.getInventoryItems` builds every row through `toInventoryItemResponse`, which does a second `selectAll` on `EventInventory` for that item with **no `limit`, no `offset` and no filter** — so a list of 25 items is 26 queries, and a heavily-used item brings back every event that has ever drawn on it.

  Two consequences, and only the second one is visible to a user. The **N+1** is a performance problem that no test and no screenshot will report. The **unbounded payload** is a correctness one: the port has to truncate at the client (`maxEventsShown`, 4.5) because there is no server-side way to ask for fewer, so the count a user sees is a number the client invented.

  Options, in increasing order of effort:
  1. **Return a count instead of a list** on the list endpoint — an `eventCount` per item, with the full list kept on `GET /api/inventory/{id}` for whoever needs it. This is the shape the list screen actually wants, and it makes the client's truncation disappear rather than become a permanent workaround.
  2. **Paginate `events`** within `InventoryItemResponse`. Preserves the current shape and costs a nested envelope; a page of events inside a page of items is awkward to consume.
  3. **Batch the lookup** — one `where { EventInventory.inventoryItemId inList ids }` rather than one per row — and leave the list unbounded. Fixes the N+1 only, and leaves the payload problem.

  Whatever is chosen, check the callers before narrowing the response: `getInventoryItemsForEvent` and `getAllInventoryItemsByOrganization` share `toInventoryItemResponse`, so changing it changes three endpoints at once.

  Verify after: a request for 25 items issues a constant number of queries, and the client's `maxEventsShown` truncation is either gone or no longer load-bearing.

---

## Phase 11 — Native packaging (deferred, not required for cutover)

Additive: the web app keeps working unchanged. Only do this once web is stable and signing is arranged.

- [ ] **11.0** Confirm things run on a **simulator or physical device**. The device half of what 3.12 used to be. **Not started — no simulator or device is available on this machine.** Native platforms do not exist yet either; they arrive with Phase 11's `flutter create --platforms=android,ios .`, so this is really a **Phase 11 prerequisite** and should be run against that build rather than scheduled ahead of it. What to check, beyond "it renders":
  - **Touch.** Tap a rail destination, tap the hamburger, swipe the drawer closed, pick an organization in the sheet, tap Logout. The browser pass was pointer-driven at fixed widths and exercised none of this. Task 9.4 covers target *sizes*; this covers the gestures.
  - **Safe areas.** A notch or a home indicator is the most likely thing to be wrong. `AppBar` handles the top inset itself and `NavigationRail` wraps itself in a `SafeArea`, but the extended rail's trailing group and the drawer's bottom items are hand-placed — check the last item clears the home indicator.
  - **Rotation.** A device is the only place the breakpoints change *without* a window resize. Confirm a phone in landscape crosses into the tablet layout and the rail does not jump on the transition.
  - **The organization sheet with a keyboard.** It uses `MediaQuery.viewInsetsOf` under `isScrollControlled`, and the search field is `autofocus` — so the keyboard is up the moment it opens. That is the case least likely to have been thought about and the first thing likely to look wrong.
  - **Session persistence.** `flutter_secure_storage` behaves differently off-localhost, and `TokenStore.write` propagates failure deliberately, so a device build on plain HTTP is *expected* to fail loudly at login. That is task 1.13's known limitation rather than a new defect — confirm it fails the same way and not differently.
- [ ] **11.1** Add iOS and Android platforms to `flutter_app/` (`flutter create --platforms=android,ios .`). Set `applicationId` to `alphainterplanetary.teven` in `android/app/build.gradle.kts` and the matching bundle identifier in the iOS project, matching the web manifest `id` from task 0.7.
- [ ] **11.2** Set up the API base URL for native via `--dart-define=API_BASE_URL=<host>`, since relative URLs cannot work off-browser. Revisit task 0.6. A reachable host value is a prerequisite for native work and is out of this plan's control.
- [ ] **11.3** Revisit token storage for native. `flutter_secure_storage` works on both platforms already, so this may be a no-op — verify rather than assume.
- [ ] **11.4** Re-test every screen for touch: hover-revealed actions (task 4.2) currently assume a pointer, and dialogs become bottom sheets (tasks 3.7, 5.11).
- [ ] **11.5** Add deep-link handling so `/register?token=...` opens the app when installed, falling back to the web link otherwise (builds on task 5.10).
- [ ] **11.6** Arrange code signing / store distribution.
- [ ] **11.7** **Optional:** a custom week view, restoring the calendar capability dropped in task 7.1. `table_calendar` does not support it, so this means a hand-built grid. Attempt only if users ask for it.

---

## Phase 12 — Tests (deferred, post-conversion)

The React app had **zero** tests, so there is no existing specification to lean on — task 10.3 deletes the last of the original behaviour. Phase 1 onward therefore writes tests **as each layer is built** (see the per-task test tasks), and Phase 12 is where the integration and UI suites live.

The distinction: per-task tests cover logic whose behaviour is not obvious from reading it — response-shape handling, permission semantics, date arithmetic, query defaults. Anything whose correct behaviour is visible at the call site does not need one.

- [ ] **12.1** Decide the testing scope now that the app is live and its real failure modes are known.
- [ ] **12.2** Integration tests for login → context fetch → authenticated call, per `AGENTS.md` expectations.
- [ ] **12.3** Broaden `ApiClient` coverage beyond task 1.19 — currently the five response-shape cases only.
- [ ] **12.4** Widget tests for the permission guard and the responsive list.
- [ ] **12.5** Golden tests for the calendar month grid and the event forms.
- [ ] **12.6** Ensure the suite runs on both VM and Chrome. **Partly done:** `flutter test` (48 passing) and `flutter test --platform chrome` (22 passing, 2 skipped) both work as of task 1.20. The socket-based tests skip on web because `dart:io`'s `HttpServer` is unavailable there — they skip explicitly rather than passing vacuously. Remaining: any widget tests added in Phases 3–9 must be verified on both.

---

## Backend discrepancies found during exploration

Documented here so task 10.6 can address them. **Do not fix these during the port** — parity first, corrections after.

**Every row now has an owning task** in the "Fix" column. A row with no task was documentation nobody would act on, which is how five real defects sat here unowned for the first three phases. If you find a new one during the port, give it a task in the same change — otherwise add it to this table and note in the progress log that it is unowned.

| Discrepancy | Evidence | Fix |
|---|---|---|
| `POST /api/users/register` documented, **does not exist** | `API.md:57` vs `app/user/UserRoutes.kt:28` | 10.6 (drop from docs) |
| Staff endpoints documented, **do not exist** | `API.md:343-351`; staffing is via `staffInvites` on event create/update | 10.6 (drop from docs) |
| `GET /api/events/rsvps/requested` **undocumented** but real | `app/event/EventRoutes.kt:118` | 7.10, 10.6 (document) |
| Role-assignment path is wrong | `API.md:632` says `/api/users/{userId}/roles`; actual is `/api/users/{user_id}/roles/{role_id}` (`app/role/RoleRoutes.kt:86`) | **10.16** |
| `sortBy` ignored on `GET /api/events` | `app/event/EventRoutes.kt:80` does not read it | **10.11** |
| Geo fields absent from docs | `latitude`/`longitude`/`formattedAddress` exist on customer/event DTOs but not in `API.md` | 10.6 (regenerate) |
| Geo service is dead code | `service/geo/GeoService.kt:9-19` falls through to a mock; no `GeoRoutes` file exists; no PostGIS | **10.7** |
| `RsvpRequest.availability` is a free-form `String` | No enum validation server-side | **10.17** |
| Permission failures return bare strings, not the envelope | `auth/AuthorizationPlugin.kt:24,31` (note: the file is `AuthorizationPlugin.kt`, not `PermissionInterceptor.kt`) | **10.9** |
| **11 success responses carry a bare-string `data`** instead of a DTO | 5 × `success("... with ID N updated")`, 4 × `success("OK")`, 1 × `success("Created invitation")` | **10.10** |
| **5 deletes return `204 NoContent`** with no envelope, though React types claim `StatusResponse` | customer, inventory, organization, event, role route files | **10.10** |
| **`DELETE /api/users/{id}` does not exist** | `UserService.deleteUser` calls it (`UserService.ts:36`); `UserRoutes.kt` defines no `delete`. Reaches the `/api` catch-all → 404 JSON envelope. **Decided: hard delete** | **10.12** |
| **`POST /api/events/{id}/join` does not exist** | `EventService.joinEvent` calls it (`EventService.ts:56`); `EventRoutes.kt` has no `join` route | **10.14** |
| **`ASSIGN_TO_EVENTS_SELF` permission is unreachable** | Was used only by the deleted `join` route; still in `Permission.kt` | **10.14**, 10.16 |
| **`staff_details` table is never created** | `DatabaseFactory.kt` omits it from `SchemaUtils.create`; confirmed absent via `\dt` (13 tables). No DAO either. `UserResponse.staffDetails` is always null, so `EditProfileForm` **silently discards** every staff-field edit | **10.13** (restoring) |
| **`StaffHours` is never written to** | Created and queried by the report (`ReportDao.kt:19`), but nothing inserts rows — the staff-hours report is always empty, and `staff_details.hours_worked` has no source | **10.13** |
| **All 5 user FKs are `ON DELETE RESTRICT`** | Queried from the running dev DB. No cascade anywhere, so user deletion fails outright | **10.12** (add CASCADE) |
| **Omitting `limit` returns the entire table** | Every DAO does `limit?.let { query.limit(it) }` (`CustomerDao.kt:73`, `EventDao.kt:180`, +3). The `limit: 0` in the response is cosmetic, **not** a real cap | **10.15** |
| **18 of 33 server permissions are unreachable from the client** | `core/security/Permission.kt` defines 33; `src/types/permissions.ts` declares only 15. The `*_GLOBAL` variants beyond the two org ones, plus `MANAGE_ROLES_*`, `ASSIGN_*`, `CAN_ASSIGN_*`, `MANAGE_USERS_SELF` | **10.16** |
| **`DELETE /api/customers/{id}` returns 500 when the customer has any event** | `CustomerDao.deleteCustomer` hard-deletes; `Events.customerId` is `.nullable()` with no `onDelete`, so the FK is `NO ACTION`. Observed: `violates foreign key constraint "fk_events_customer_id__id"`, surfacing as a 500 with a stack trace. Invisible to any customer with no events | **10.19** |
| **No customer details screen exists — the link is dead in the React app too** | `CustomerList.tsx:78` links to `/customers/{id}`; `App.tsx` declares only `customers`, `customers/create`, `customers/edit/:customerId`, and `components/customers/` has no `CustomerDetails`. The `*` catch-all redirects to `/events`. Ported faithfully, so the port reproduces the dead link | **10.20** |
| **`GET /api/inventory` embeds an unbounded `events` list per row, via a query per row** | `InventoryDao.toInventoryItemResponse:29` selects *all* of `EventInventory` for the item — no `limit`/`offset`/filter — and `getInventoryItems:83` calls it per row, so a 25-item page is 26 queries. Found while porting the inventory list; the plan's own note that this was a property of `GET /api/inventory/{id}` was **wrong** — the list endpoint does it too | **10.21** |
| **The inventory and organization name links are dead, as the customer one is** | `InventoryList.tsx:78` → `/inventory/{id}` and `OrganizationList.tsx:80` → `/organizations/{id}`; `App.tsx:53-60` declares neither. Same defect as the row above, in two more screens | **10.20** (all three screens, or none) |
| **Seeded users cannot log in — `TestDataProvider` writes a plaintext password** | `TestDataProvider.kt` set `it[passwordHash] = "password"` and the column is `users.password`. `BCrypt.checkpw("password", "password")` throws `IllegalArgumentException: Invalid salt version`, which `AuthServiceImpl.loginUser` did not catch — so **every seeded login answered HTTP 500 with a stack trace**, not 401. Found during task 3.12's verification attempt; the seeded `alice`/`bob`/`charlie`/`diana` accounts were unreachable until the seed stored a real hash | **10.18** ✅ |
---

## Progress log

Append a dated entry per completed phase. Record measured bundle sizes, known limitations, and deviations from this plan.

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

The practical consequence is sharper than the plan's "The one deployment consideration" states. The plan says the gap is that secure storage *"does not work"* off-localhost; in fact it means **login breaks outright** over plain HTTP on port 2022 — reads quietly return no token, writes throw. Not a silent degradation, a visible failure. Still a deployment concern, still deferred, but worth knowing that task 1.13's comment should say "login fails" rather than "guarantees do not hold".

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

The reason for changing it was already recorded when 3.6 was written, and this
is the first time it has been worth stating plainly: **the React navbar's own
contents were unreachable below 992px.** The organization `<select>` sat inside
the collapse, so a super-admin on a phone could not switch organization at all,
and `QuickOrganizationPickerModal` — the searchable list — was wired only to the
event forms. A rail shows the six items without a hamburger from 700px up and
gives the switcher a home at every size. The trade is that it is **not**
visually faithful, and it should be revisited if matching the current look
matters more than closing the responsive gap.

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
