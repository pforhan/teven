# Flutter Conversion — Task Checklist

Rewrite of `frontend/` (React + Vite + Bootstrap SPA) into a Flutter app, **web first**.

The React app stays in place and fully functional until the Flutter app is verified working. Each task below is intended to be **one commit**. Work top to bottom; do not reorder without updating this file.

Responsive layout is in scope throughout, because the site will be viewed in mobile browsers. What is *not* in scope for Phases 0–10 is native app packaging — that is Phase 11.

## The three files of this plan

This file is the **checklist**: the ground rules, and every task with its checkbox. The other two hold everything that is not a task:

| File | Holds | Read it when |
|---|---|---|
| **`FLUTTER-CONVERT.md`** (this file) | The ground rules and every task, with its checkbox | Working a task, or deciding what is next |
| **[`FLUTTER-CONVERT-DESIGN.md`](FLUTTER-CONVERT-DESIGN.md)** | Planning and design — the resolved decisions, the parity matrix, and the survey of backend discrepancies | Wanting to know *why* the plan is shaped this way, or what the server actually does |
| **[`FLUTTER-CONVERT-NOTES.md`](FLUTTER-CONVERT-NOTES.md)** | Implementation notes — the dated progress log, one entry per completed phase | Looking for what actually happened, and how it was verified |

Task numbers are stable across all three files. Where a task below says "see the progress log", it means `FLUTTER-CONVERT-NOTES.md`; where it says "the discrepancies below", it means the table in `FLUTTER-CONVERT-DESIGN.md`.

---

## Ground rules

- **Do not modify or delete `frontend/`.** It remains the live app until Phase 10. **One exception:** task 7.22, the single React-client patch that restores the event screens broken by 7.21.
- **Do not modify the backend** during Phases 0–8, **except for the timezone work in Phase 7A** (7.13–7.21, 7.24). That work changes the event and invitation wire formats, which breaks the React app's event screens. The break is a known, accepted cost — see *Phase 7A* below. Everything else in the backend stays frozen until Phases 9–10, where it is called out explicitly (9.9, 10.6, 10.7).
- **Do not plan for deployment.** Docker is the deployment mechanism and it is sufficient; do not add hosting, TLS, proxy, or CI/CD work to any task. Verification is local. The single known gap is noted under *The one deployment consideration* in `FLUTTER-CONVERT-DESIGN.md`.
- Every task must leave the repo in a **buildable** state (`npm run build --prefix frontend` and `flutter analyze` both clean).
- One task per commit. Commit message conventions live in `AGENTS.md`; there is no commit-message tooling in this repo, and a conventional-commit prefix is optional rather than required.
- 2-space indentation, per `AGENTS.md`.
- Run `dart format .` and `flutter analyze` before every commit in `flutter_app/`.
- New Flutter packages must be justified in the commit message.
- **Generated code is not committed.** `*.freezed.dart` and `*.g.dart` are gitignored (`flutter_app/.gitignore`), so `dart run build_runner build` is a required setup step after every clone, not an optional one. This is a deliberate departure from the freezed default of committing generated output.

---

## Phase 0 — Scaffolding and build pipeline

Establishes that a Flutter web build runs locally and survives the Docker + Ktor pipeline. **Do this first**; it de-risks the whole port.

- [x] **0.1** Create `flutter_app/` via `flutter create --org com.teven --project-name teven_app --platforms=web flutter_app`. Verify `flutter_app/.gitignore` covers `.dart_tool/` and `build/`. Native platforms are added in Phase 11, not now. **Distribution ID is `alphainterplanetary.teven`** — set in `web/manifest.json` as `id` (task 0.7); the Dart package name stays `teven_app` since that is a source identifier, not a distribution one. Reuse the same ID for native `applicationId` / bundle id in Phase 11.
- [x] **0.2** Add to root `.gitignore`: `.dart_tool/`, `.flutter-plugins*`, `*.iml`. Note root already has `build/` at line 31, which correctly covers `flutter_app/build/`.
- [x] **0.3** Add core dependencies: `flutter_riverpod`, `dio`, `go_router`, `flutter_secure_storage`, `shared_preferences`, `intl`, `table_calendar`, `json_annotation`.
- [x] **0.4** Add dev dependencies: `build_runner`, `json_serializable`, `freezed`, `freezed_annotation`, `riverpod_generator`. **`custom_lint` and `riverpod_lint` were dropped** — see the progress log in `FLUTTER-CONVERT-NOTES.md`; the solver cannot satisfy them alongside `json_serializable`. Revisit if generator lints prove valuable.
- [x] **0.5** Set `analysis_options.yaml` with `flutter_lints`, `require_trailing_commas`, and `prefer_final_locals`. Commit any lint suppressions with an inline justification.
- [x] **0.6** Add `ApiConfig` with a `baseUrl` that is **empty (relative) on web** and from `--dart-define=API_BASE_URL` on native. Document this asymmetry in a comment.
- [x] **0.7** Add `web/index.html` customization: app title `Teven`, theme color, and the `teven.png` favicon copied from `frontend/public/teven.png`. Also set the PWA distribution ID: `web/manifest.json` gets `"id": "alphainterplanetary.teven"`. `flutter build web` has no `--application-id` flag, so the manifest `id` is where a web distribution ID belongs.
- [x] **0.8** Add a placeholder `HomeScreen` rendering app name + build version. Wire `flutter run -d chrome` and confirm it renders.
- [x] **0.9** **Call `usePathUrlStrategy()`** from `flutter_web_plugins` in `main.dart` so paths stay `/login`, `/register` instead of `/#/login`. Without this, invite links break.
- [x] **0.10** Build with `--no-web-resources-cdn` to self-host CanvasKit. Optional for local dev — the gstatic fetch resolves on a normal connection — but it removes a third-party runtime dependency and makes the build fully self-contained. Confirm the built page renders from `build/web` served over plain HTTP on `localhost`.
- [x] **0.11** Measure `build/web` bundle size. Compare against the React baseline (596 KB JS + 246 KB CSS) and record the number in `FLUTTER-CONVERT-NOTES.md`. Expect a regression.
- [x] **0.12** Add a Flutter stage to `Dockerfile`. **Deviation:** no Flutter SDK runs in Docker at all. The registry has no image new enough, and Flutter publishes no `linux/arm64` SDK, so the stage copies a bundle built on the host. See the progress log in `FLUTTER-CONVERT-NOTES.md`.
- [x] **0.13** Parameterize the frontend source with `ARG WEB_SOURCE` (`react` | `flutter`) so **both** pipelines remain buildable during the migration.
- [x] **0.14** Verify both `docker build` variants succeed and that the Flutter variant serves correctly through Ktor `staticResources("/", "static")` (`backend/app/src/main/kotlin/.../Routing.kt:56`). **Verified** — see the progress log in `FLUTTER-CONVERT-NOTES.md`.
- [x] **0.15** **Premise did not hold — no work needed.** Flutter 3.47.2's default service worker is a 784-byte stub that unregisters itself; there is no aggressive cache to version. `--pwa-strategy` is hidden and deprecated. Verified against the SDK source; see the progress log in `FLUTTER-CONVERT-NOTES.md`.

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
  Split across three files: `test/api_client_test.dart` (1.19), `test/services_test.dart`, `test/models_test.dart`. What each file pins is listed in the 2026-10-09 entry of `FLUTTER-CONVERT-NOTES.md`.

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
- [x] **3.12** Confirm the shell renders at all three breakpoints **in a web browser**. Screenshotted at 500 / 900 / 1400 px against the live backend, signed in as a seeded user. **This pass found a layout bug every widget test had missed** — see the 2026-10-13 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **3.13** Widget tests for the responsive chrome: nav items appear and disappear at each breakpoint, and `NavigationDrawer` / `NavigationRail` / sidebar render at mobile / tablet / desktop. Pin sizes rather than relying on a real browser — 3.12's real-browser pass stays as the manual check, and it earns its place: it caught a positional bug that no presence assertion here could see.
- [x] **3.14** Fix the organization display in the sidebar — only a chevron was visible. **Fixed.** See the 2026-10-13 entry in `FLUTTER-CONVERT-NOTES.md`: `DropdownButton` has three text paths that do not agree, all three of them defaulted to the light-container ink, and the static org label had the identical bug. Pinned by a contrast-ratio test that fails at 1.0:1 without the fix.
- [x] **3.15** Double-check the vertical sidebar against React. **Answered: the React app does have an across-the-top bar, and the port's rail is a deliberate redesign rather than parity.** Cost of the trade, stated plainly: it is **not** visually faithful, and anyone comparing the two side by side will notice immediately. That is the price of reachability — the React navbar's own contents were unreachable on small screens — and it is the kind of decision worth revisiting if the team would rather match the current look and accept the responsive gap. See the 2026-10-13 entry in `FLUTTER-CONVERT-NOTES.md`.

---

## Phase 4 — CRUD list screens

Covers `TableView.tsx` (90 lines) plus six list screens (~676 lines). **Redesign, not port.** Tables become responsive lists.

- [x] **4.1** Build a shared `ResponsiveListView` replacing `TableView.tsx`: data-table layout at desktop, card layout at mobile.
- [x] **4.2** Reproduce hover-revealed row actions. `TableView.tsx:17-18` exposes `onRowMouseEnter`/`onRowMouseLeave` purely so buttons appear on hover, across 6 call sites. On mobile use always-visible trailing actions or a long-press menu; **web may keep hover** behind a `kIsWeb` branch.
- [x] **4.3** Reproduce hover tooltips (`OverlayTrigger` in 5 files). Same `kIsWeb` treatment; use `Semantics` labels for accessibility on native.
- [x] **4.4** Port `CustomerList` (134 lines): search, paginated table, create/edit/delete.
- [x] **4.5** Port `InventoryList` (144 lines). **Done** — search, sort by name or quantity, create, delete. The `events` list is capped at 3 per row with a `+N more` count, and that cap is the one place this screen is not a transcription: the list is unpaginated server-side on `GET /api/inventory` too, not only on `GET /api/inventory/{id}`. Delete uses `confirmDestructiveAction` (4.8). The server-side N+1 behind it is **10.21**. See the 2026-10-14 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.6** Port `OrganizationList` (134 lines), gated on `VIEW_ORGANIZATIONS_GLOBAL`. **Done**, including the one thing that is *not* shared with the other two lists: this screen is deliberately **not** scoped to the selected organization. Delete uses `confirmDestructiveAction` (4.8). See the 2026-10-14 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.7** Port `UserList` (264 lines) — the largest list screen. Includes role display and sort controls. **Two** delete flows (`UserList.tsx:79,94`), both via `confirmDestructiveAction` (4.8); the user one still calls an endpoint that does not exist (10.12). **Done.** The only screen in the app that renders **two** tables in one route — unused invitations above the users — and the only one whose manage-gate ORs two scopes (`UserList.tsx:25`). "Create Invitation" is **omitted**: `UserList.tsx:206` toggles an inline form (182 lines) that is task 5.7, and there is no route for it, so a button would open nothing. See the 2026-10-15 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.8** Port the 6 `window.confirm` delete flows as async dialogs (`CustomerList.tsx:60`, `InventoryList.tsx:60`, `OrganizationList.tsx:51`, `UserList.tsx:79,94`, plus events in Phase 7). **Done as one shared widget rather than six dialogs** — `confirmDestructiveAction` in `lib/widgets/confirm_dialog.dart`. **6 of 6 wired**: 4.4 added the customer's, 4.5 and 4.6 the inventory and organization ones, 4.7 both of the user screen's, 7.5 the event list's, and 7.6 the event details one. The *consequence* of a confirmed delete (refetch vs redirect) stays at the call site in every case, because `UserList.tsx:94` deletes an invitation and `EventDetails.tsx:49` navigates away. See the 2026-10-14 and 2026-10-20 entries in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.9** **Reopened and implemented — pagination is now real.** Originally closed as "premise did not hold": `grep` finds no pagination control in any React list, and all four fetch a single fixed page (`CustomerList.tsx:27` uses `25, 0`) with no way to reach the rest, so there was genuinely nothing to *port*. Reopened because adding paging is a **product decision**, and it was made. The page *size* stays 25 — the original's own number, now `kListPageSize` — and what is new is a way to ask for the next one. Seamless loading on scroll, with a "Load more" button as the reachable floor. Applies to all four list screens. **This is a divergence from the original, not parity:** the React app can only ever see the first 25 rows, and now this one can see all of them. See the 2026-10-15 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.10** Port the search-debounce pattern. The React lists use plain `useState`; pick a deliberate debounce and note the interval.
- [x] **4.11** Verify sort controls against each endpoint. **`sortBy` is silently ignored on `/api/events`**, and `GET /api/events` defaults `sortOrder` to `asc`. **Verified against every DAO rather than taken on the plan's word, and the answer is a table, not a yes/no.** Three of the five list screens agree with the server; the customer screen offers **three sort headers the server ignores** (`CustomerDao` switches on `name` alone and falls back to `id`), which is the one real mismatch and is left as-is under the parity rule. Events remain the outlier and stay **10.11**. See the 2026-10-15 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **4.12** Widget tests for `ResponsiveListView`: table layout at desktop, card layout at mobile. **Split** — the third case in the original wording (the truncated `events` list on an inventory row) needs 4.5's screen, so it is now **4.13**.
- [x] **4.14** **Stop the list flashing on every search. Done — and the retained rows were cheaper than any of the three options filed here.** A search is now **silent**, exactly as it was in React: `TableView` had no loading state at all, so there is no indicator that the rows are stale — a deliberate trade, recorded at `PagedListView.stale`. It also fixed a second divergence nobody had written down: React rendered the error banner **and** the previous table together, and the port now puts the banner above the stale rows. See the 2026-10-15 entry in `FLUTTER-CONVERT-NOTES.md`.

- [x] **4.13** Widget test for the truncated `events` list on an inventory row — 4.12's third case, held back because it needs `InventoryList` (4.5). Rides with that task. **Done with 4.5** — four cases in `inventory_list_screen_test.dart`: never used, all shown under the cap, truncated with a `+N more` count, and the cap applied **per row** rather than across the list.

---

## Phase 5 — Forms (non-event)

~640 lines across seven forms, plus `CreateInvitationForm` (182). ~70 raw HTML inputs become explicit `TextFormField`s.

- [x] **5.1** Establish a form convention: `TextFormField` + `InputDecoration` + `Form` `GlobalKey`, validators replacing HTML `required`. **No form library** — the React code has none, so this is a free choice.
- [x] **5.2** Port `CreateCustomerForm` (146 lines) and `EditCustomerForm` (139 lines).
- [x] **5.3** Port `CreateInventoryForm` (140 lines) and `EditInventoryForm` (132 lines).
- [x] **5.4** Port `CreateOrganizationForm` (59 lines) and `EditOrganizationForm` (86 lines).
- [x] **5.5** Port `CreateUserForm` (168 lines) and `EditUserForm` (153 lines).
- [x] **5.6** Port `Profile` (78 lines) and `EditProfileForm` (87 lines) to `/profile`.
- [x] **5.7** Port `CreateInvitationForm` (182 lines). **Also the first real end-to-end test of the invite link** (carried over from Phase 2): mint an invitation here, then open `${Uri.base.origin}/register?token=...` cold and accept it, confirming the account is created and the app redirects to `/login`. This is the one flow the whole `usePathUrlStrategy` decision exists to serve, and Phase 2 could not exercise it — there was no way to mint a token. The server side is already proven (`/register?token=nonsense` survives the Ktor SPA fallback and reaches `GET /api/invitations/validate` intact); what remains is the success path and the link generated by 5.10.
- [x] **5.8** Port `InventoryAssociationEditor` (143 lines) — shared component, largest in `common/`.
- [x] **5.9** Replace HTML input types with Flutter pickers: `type="date"` → `showDatePicker`, `type="time"` → `showTimePicker`, `type="number"` → numeric `TextFormField` with `FilteringTextInputFormatter`, `type="email"` → `RegExp` validator. **The date picker's range was wrong and has been fixed** — it capped the last selectable day at *today*, which made the event date impossible to set forward on both event forms, and made editing a future-dated event throw. The bound is now the end of 2100, matching the original's unbounded `<input type="date">` and the calendar's own horizon; the date-of-birth field, which genuinely wants a past-only bound, now says so at its call site. See the 2026-10-20 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **5.10** **Fix the invite-link bug surface.** `UserList.tsx:157` and `CreateInvitationForm.tsx:74` build `${window.location.origin}/register?token=`. Derive the origin from `Uri.base` — no native path needed, since invitees receive a link they open in a browser. Ensure the link is not token-dependent on any in-app state.
- [x] **5.11** Two-column `col-lg-*` layouts become single-column scrolls on mobile; modals become bottom sheets. Apply to all seven forms.
- [x] **5.12** Verify `EditUserForm` gating. `App.tsx:63` gates it on `MANAGE_USERS_GLOBAL` only, while `App.tsx:62` gates create on either global or org — this asymmetry is likely a bug; confirm intent before porting.
- [x] **5.13** Widget tests for the form convention: required-field validators reject empty input, and the invite link built in 5.10 is derived from `Uri.base` and carries the token as a query param. The forms are the largest surface in the port and the least covered, so start with one representative form rather than all seven. **Done** — and the origin derivation turned out to be wrong on every non-http scheme, which is the finding worth keeping. See the 2026-10-16 entry in `FLUTTER-CONVERT-NOTES.md`.

---

## Phase 6 — Event forms (highest risk)

`CreateEventForm.tsx` (518) + `EditEventForm.tsx` (442) = **960 lines**, the densest code in the app. Budget 5–7 days.

- [x] **6.1** Inventory every field and every conditional in both forms. **Relocated and re-scoped** — it asked for the map "in the PR description", which this repo does not have, so it lives in `FLUTTER-CONVERT-NOTES.md` instead. It was also written to be produced *before* the code, which is moot now that both forms exist; it is discharged in the Phase 6 entry of `FLUTTER-CONVERT-NOTES.md` as a **verification pass** against what was built. The pass found a real divergence — see that entry.
- [x] **6.2** Port the ~20 `useState` fields per form to `TextEditingController`s.
- [x] **6.3** Port the three nested modals in each form.
- [x] **6.4** Port cross-form logic: auto-fill event location from the selected customer's address.
- [x] **6.5** Port `locationManuallyEdited` tracking — once the user edits location, stop overwriting it from the customer address.
- [x] **6.6** Port the org-scoping cascades that refetch customers/users/inventory when the selected organization changes.
- [x] **6.7** Port `staffInvites` handling. This is the **only** mechanism for event staffing — the staff endpoints documented in `API.md:343-351` **do not exist** server-side.
- [x] **6.8** Port inventory association within the event form.
- [x] **6.9** Handle the `PUT /api/events/{id}` response, which returns `data: "Event with ID N updated"` — a **bare string, not a DTO**.
- [x] **6.10** Wire the create/edit routes to the new screens so list and calendar views refresh via navigation.
- [x] **6.11** End-to-end test the full create flow and the full edit flow, including customer-address autofill and org switching. Done: `test/event_form_test.dart` (validation, autofill, edit load/submit).

---

## Phase 7 — Calendar, list, details, RSVP

- [x] **7.1** Rebuild `EventCalendar.tsx` (329 lines) as a `table_calendar` month grid. **Explicitly dropping:** week / work-week / day / agenda views, drag-to-select slot creation, and the hover-to-reveal "Create Event" placeholder (`EventCalendar.tsx:26-68`, which needs a 100 ms mouseleave timer purely to avoid flicker). **See the Phase 7 entry in `FLUTTER-CONVERT-NOTES.md`** — tap-to-create survives (it is the `action === 'click'` branch, not drag-select), and 7.4 came along with it because a bar cannot be drawn without a colour.
- [x] **7.2** Replace drag-to-select with **long-press-a-day** to open the create form prefilled with that date. **Done, and the gesture is split by the device that made it: a mouse click creates, a finger has to long-press, and a finger's tap does nothing.** The tap is inert because there is nothing for it to open — the app has no day view, which is the gap **7.11** was filed for; when that lands, the tap opens the day and the long press stays as the create gesture. **Divergence from the original, and a deliberate one:** the React calendar had one gesture (a click) for one device class; this has two, plus one line of hint text under the grid. See the 2026-10-20 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **7.3** Add the Create Event affordance to **both** event pages. There are three in the React original, not one: the calendar header button (`EventCalendar.tsx:253`), the list-page header button (`EventListPage.tsx:168`), and the hover-to-reveal placeholder (`EventCalendar.tsx:26-68`). All three gate on `MANAGE_EVENTS_ORGANIZATION`, derived independently in each file. The placeholder is *replaced* as the original task describes — a FAB on mobile, a `+` on web — and the two buttons are *added* alongside it. **Two of the three landed with 7.1/7.5; the FAB does not** — see the progress log in `FLUTTER-CONVERT-NOTES.md`. **Both buttons intercept before navigating:** a `VIEW_USERS_GLOBAL` user with no selected organization opens `QuickOrganizationPickerModal` and navigates only after a selection, rather than landing on the create form's "Organization Required" card and having to tap through it. **Settled** on one `CreateEventButton` with a nullable `resumeUrl`, so the pending-navigation question is answered once rather than per file.
- [x] **7.4** Reproduce `eventPropGetter` / `dayPropGetter` styling, including today's `#e7f0f7` highlight. **Landed with 7.1** rather than separately: `CalendarStyle` in table_calendar 3.3.0 has no full-cell today highlight (only the `todayDecoration` dot), so the day cell is written by hand — which the colour is inseparable from.
- [x] **7.5** Port `EventListPage` (240 lines): title, date, time, description, customer, RSVP columns → responsive rows. **One deliberate divergence: a "Calendar view" button.** The React original links *out* to this list (`EventCalendar.tsx:253`) but has no way back — the only route to the calendar is the nav rail's "Events" item, which is a drawer on a phone. The port adds the missing half, beside the search box, so the two screens are mirror images; see the progress log in `FLUTTER-CONVERT-NOTES.md`.
- [x] **7.6** Port `EventDetails` (277 lines), including the two `window.confirm` flows — via `confirmDestructiveAction` (4.8), and note the delete navigates away rather than refetching — and the `RsvpWidget` (72 lines) — drop-in RSVP posting `availability: "available" | "unavailable"` as a **free-form string**, not an enum.
- [x] **7.7** Port `OtherEventsPanel` (97 lines). **The widget already existed** — it was written in Phase 6 as a supporting piece for the create and edit forms — so what was missing was everything around it, and one thing inside it that a seeded database could not have revealed. **Done**, with three deliberate divergences and one backend file touched (dev-only seed data). See the 2026-10-20 entry in `FLUTTER-CONVERT-NOTES.md`.
- [ ] **7.8** **Replace `moment` with `intl` + `DateTime`. Largely done for the port; the last fragile site is removed by 7.19.** The React original uses `moment` throughout the calendar; the port never did — `lib/core/util/local_date.dart` formats the wire date from a `DateTime`'s own calendar fields, and `EventResponse.startAt` builds its `DateTime` from components rather than parsing a concatenated string.

  **One fragile site is left, and it is the exact expression this task names.** `create_event_screen.dart:107` does `DateTime.tryParse('$dateParam $startTimeParam')` — the `'T'`-concatenation pattern with a space instead of a `T`. It is **dead**: nothing in the Flutter app emits the `startTime` / `endTime` parameters it reads; they were the React original's drag-select remnants, and task 7.1 already dropped that gesture. **7.19 removes it and the parameters with it.**

  The React app's `moment` usage disappears with 10.3, which deletes `frontend/`. No React change is needed for this task.

- [ ] **7.9** **Every timestamp on the wire is unambiguous. Superseded by Phase 7A; closes with 7.21.**

  **The old wording of this task is withdrawn.** It asked for the opposite of what the app should do: *"Do not silently re-interpret as UTC; keep naive local semantics to match current behavior."* Naive-local was right **only** while the app had no way to know a better one. The rules it is replaced with are in the design doc under *Time zones → On the wire*.

  **What "closed" means, concretely:** no DTO carries a naive date-time, no column stores one, and the client has no code path that reads a timestamp without being told which zone to read it in. Phase 7A gets there in stages — 7.14 (invitations), 7.18 (events), 7.21 (the legacy event fields retired) — and **this checkbox closes when 7.21 lands.**

- [x] **7.10** Route `/events/rsvps/requested` into the UI. It is **undocumented in `API.md`** but real (`EventRoutes.kt:118`). Confirm whether the React app uses it — if not, decide whether to expose it. **Both halves are settled: the React app does *not* use it** — `RsvpWidget.tsx` was the only thing that ever fetched it, it was added in the same commit as the route (`f13ae83`), and it has never been imported by anything since. **The port exposes it**, as a card on the calendar — the app's landing page, and the place where a pending request is already marked in orange on the event's bar. What is left here is whether the card belongs there rather than somewhere else; moving it is a one-line change to the calendar screen. See the 2026-10-20 entry in `FLUTTER-CONVERT-NOTES.md`.
- [ ] **7.11** come up with a day view for day selection, referenced in the work we did for 7.2.  If there is a widget for an hourly schedule that can potentially handle overlapping events we should use it.
- [ ] **7.12** Tests for the calendar's date handling, which is where the fragile logic lives: naive-local date construction (7.8/7.9), and the month grid rendering the right events on the right days. Golden tests for the grid itself are 12.5 — here it is the placement logic, not the pixels. **The placement half landed with 7.1** (`test/event_calendar_screen_test.dart`, four cases); the naive-local construction is covered by the existing `models_test.dart` case, so what is left is the golden half, which 12.5 owns.

---

## Phase 7A — Timezones

The app has **no concept of a time zone anywhere** — not in the database, not in the API, not in the Flutter app. Every date and time is a string, read in whatever zone the reader happens to be in. This phase fixes that: **capture the zone in everything, API and backend included.**

**The model, the decisions behind it, and the order the work lands in are in [`FLUTTER-CONVERT-DESIGN.md`](FLUTTER-CONVERT-DESIGN.md) under *Time zones*.** The survey that produced these tasks is in [`FLUTTER-CONVERT-NOTES.md`](FLUTTER-CONVERT-NOTES.md) under 2026-10-21, and the per-defect inventory is in that file's *Time zone discrepancies* table.

Three things to carry into every task below:

- **Three zones, kept apart.** The organization's (its home clock), the event's (its identity), and the reader's (what things render in). The reader's resolves: **local override → device zone → the organization's zone → UTC**.
- **The reader's override is local-only** — `shared_preferences`, never the server. A detected zone is a property of the device, not the account.
- **On the wire:** an instant carries an offset, a wall clock carries its zone, a day is a day, and the server never guesses — a naive timestamp is a **400**.

**The React app's event screens break at 7.21** and are restored by 7.22. That is an accepted cost, and the ground rule above is amended for it.

### The tasks

- [ ] **7.13** **Pin the server's clock and its time zone.**

  The JVM's zone and the Postgres session zone are two independent defaults that agree by accident, and there is no `Clock` seam, so no temporal logic is testable.

  - `docker-compose.yml`: `TZ: UTC` on `db` and `backend`, plus `PGTZ: UTC` on `db`. `Dockerfile` (final stage): `ENV JAVA_TOOL_OPTIONS="-Duser.timezone=UTC"`. `gradle.properties`: `-Duser.timezone=UTC`.
  - Add `single<Clock> { Clock.systemUTC() }` to `app/di/KoinModule.kt`; inject it into `InvitationService`, `InvitationDao` and `InventoryDao`, replacing the five static `now()` calls (`InvitationService.kt:57,67,82`, `InvitationDao.kt:83`, `InventoryDao.kt:166`).
  - **Collapse the duplicated expiry check.** SQL (`InvitationDao.kt:83`) and Kotlin (`InvitationService.kt:67,82`) judge the same expiry against two clocks. The DAO filter should be an index-friendly pre-filter; Kotlin decides.
  - Leave `AuthServiceImpl.kt:46` alone — epoch millis are zone-independent.

  Verify: `./teven verify-backend`; `docker exec teven_backend date` and `psql -c "SHOW timezone"` both UTC; a fixed-`Clock` test drives an invitation past its expiry.

- [ ] **7.14** **Type the date columns that are not events, and make an invitation's expiry a real instant.**

  | Column | Today | Becomes |
  |---|---|---|
  | `invitations.expires_at` | `TIMESTAMP` | `TIMESTAMP WITH TIME ZONE` |
  | `invitations.created_at` | `TIMESTAMP` + `CURRENT_TIMESTAMP` | `TIMESTAMP WITH TIME ZONE` + `CurrentTimestampWithTimeZone` |
  | `staffhours.date` | `varchar(255)` | `date` |
  | `inventoryusage.usage_date` | `varchar(255)` | `date` |
  | `staff_details.date_of_birth` | `varchar(20)` | `date` (declaration only — 10.13 creates the table) |

  - **`timestamp()` is not a `timestamptz`** — `timestampType()` delegates to `dateTimeType()`, which Postgres returns as `"TIMESTAMP"`. Use **`timestampWithTimeZone()`**, which gives a `Column<OffsetDateTime>`. `exposed-java-time` is already a dependency.
  - **A day is a day.** `staffhours.date` and `date_of_birth` must not gain a zone.
  - `core/user/Invitation.kt` — `expiresAt` and `createdAt` become `Instant`. The DAO's comparison becomes `greaterEq OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)`; the two Kotlin checks become `isAfter` / `isBefore` against `clock.instant()`.
  - `InvitationResponse.expiresAt` / `.createdAt` serialize as offset-bearing ISO 8601, not `LocalDateTime.toString()`'s naive form.
  - `CreateInvitationRequest.expiresAt` accepts an offset-bearing ISO string, parsed with `OffsetDateTime.parse`. **A malformed value must be a 400, not a 500** — catch the `DateTimeParseException` and answer with `failure(...)`.
  - **Schema regeneration:** the dev database is dropped and recreated. `createMissingTablesAndColumns` will not change a column's type, and this project has no migration path.

  Verify: `./teven verify-backend`; an invitation's expiry round-trips with an offset.

- [ ] **7.15** **Give an organization a home time zone.**

  - `data/organization/Organizations.kt` — `val timezone = varchar("timezone", 64)`.
  - `OrganizationResponse.timezone: String` — **required**, so every consumer sees it. `UserResponse.organization` and `EventResponse.organization` are `OrganizationResponse`s, so the zone rides along everywhere, and the reader's own organization's zone comes from the auth context with **no extra fetch**.
  - `CreateOrganizationRequest.timezone: String? = null` — **optional**, defaulting to `UTC` when absent, so the React app's create form keeps working. `UpdateOrganizationRequest.timezone: String? = null` — null means unchanged.
  - **Validate server-side:** an unknown id is a **400**, not a 500 (`ZoneId.of` throws `ZoneIdRulesException`). The check is `ZoneId.getAvailableZoneIds().contains(id)`.
  - **The client owns the picker list, the server owns the validation.** The Dart list is a subset of Java's, which is what makes the pairing safe — the client can only ever send a zone the server accepts. Verify that rather than assuming it.
  - **Seed distinct zones** so the interesting cases are visible: the two seeded test organizations get `America/New_York` and `Pacific/Auckland` (Auckland because it is UTC+13 in summer and UTC+12 in winter, and because it is on the other side of the date line). The bootstrap "Teven" organization gets `UTC`.
  - Schema regeneration, as 7.14.

  Verify: `./teven verify-backend`; `GET /api/organizations` shows the zone; a bogus zone answers 400.

- [ ] **7.16** **Add the `MANAGE_ORGANIZATION` permission.**

  The org-scoped counterpart to `MANAGE_ORGANIZATIONS_GLOBAL` — it is what lets an **Organizer** set their organization's zone.

  - `core/security/Permission.kt` — add `MANAGE_ORGANIZATION`. `app/InitialSetup.kt` — grant it to the seeded **Organizer** role. `flutter_app/lib/models/permissions.dart` — add the client constant; this is one of the 18 that 10.16 covers, added early for the same reason `MANAGE_CUSTOMERS_GLOBAL` was.
  - **Enforce it in the service, not only on the route.** 10.22 is still open: the permission plugin does not short-circuit, so a route-level `withPermission` is not a guard today. `OrganizationService.updateOrganization` takes the caller's id and allows the update when the caller holds `MANAGE_ORGANIZATIONS_GLOBAL`, **or** holds `MANAGE_ORGANIZATION` and the target is their own organization. Otherwise `AuthorizationException`.
  - **`OrganizationRoutes` passes the caller's id down**, and the route's `withPermission` widens to accept either permission — the *scoping* lives in the service.
  - **The read path needs the same treatment, or the edit screen cannot load.** `GET /api/organizations/{id}` is gated on `VIEW_ORGANIZATIONS_GLOBAL`, which an Organizer does not hold. Widen it the same way, with the same service-level scoping.

  Verify by signing in as the seeded Organizer: their own organization reads and writes; **another** organization's answers 403.

- [ ] **7.17** **Flutter: the time zone foundation.**

  Adds `timezone: ^0.11.2` (the IANA database — Dart's `DateTime` converts between local and UTC and nothing else) and `flutter_timezone: ^5.1.1` (the device's IANA id — `timeZoneName` gives an ambiguous abbreviation). Justify both in the commit message.

  - **Initialize the embedded database** (`timezone/data/latest.dart`), not the browser variant, which fetches a `.tzf` at runtime. Record the bundle-size cost against task 0.11's baseline in the progress log.
  - **A `TimeZoneService`** wrapping the package: `locations` for the picker; `offsetAt(zoneId, instant)` (DST-aware); `wallClockAt(instant, zoneId)`; and `instantAt(localDate, localTime, zoneId)` — which must **reject a wall clock that does not exist** (`02:30` on a spring-forward morning) and **flag one that happens twice** (`02:30` on a fall-back morning), rather than silently picking an occurrence.
  - **A `TimeZoneController`** resolving the reader's zone in the order settled above, exposing the effective zone, the detected zone, the override, and `setOverride(String?)` — `null` clears the override and falls back to detection. The override lives in `shared_preferences` under its own key and is never sent to the server.
  - **A shared `TimeZoneField` widget** (used by 7.19 and 7.23): shows the zone with its current offset; opens a searchable sheet (mobile) or dialog (desktop) listing every zone, grouped by offset, current value pre-selected; **marks the organization's zone** as the default; and **de-emphasizes itself when it agrees with that default**.
  - **A "Time zone" row on the profile screen** showing the detected zone and any override, with the same picker. This is where "see and override the detected timezone" lives.
  - **Tests override the detector** — `flutter_timezone` is a platform plugin and cannot answer in a headless VM test. Follow the `tokenStoreProvider` pattern (`test/support/fakes.dart`). **Verify the web implementation returns an IANA id**, not an abbreviation or an offset: the plugin's web path differs from its native one, and the browser is the platform this app ships on.

- [ ] **7.18** **An event becomes an instant plus a zone.**

  - `data/event/Events.kt` — drop `date` and `time`; add `val startsAt = timestampWithTimeZone("starts_at")` (**not** `timestamp()` — see 7.14) and `val timezone = varchar("timezone", 64)`.
  - `EventResponse` **gains** `startsAt: String` (offset-bearing ISO 8601) and `timezone: String`, and **keeps** `date` and `time` — now computed by the server from `startsAt` in the event's own zone. Keeping them is what keeps the React app alive until 7.21.
  - `CreateEventRequest` / `UpdateEventRequest` **accept both shapes** for one commit: the new `startsAt` + `timezone`, and the legacy `date` + `time`, resolved as a wall clock in `timezone` (defaulting to the caller's organization's zone). A naive `startsAt` is a **400**.
  - **`GET /api/events` gains a `timezone` query parameter.** `startDate` and `endDate` stay local dates; the server converts the pair into an instant range. **`timezone` absent** → the caller's organization's zone → UTC when there is no organization scope. The upper bound is **exclusive** (`endDate.plusDays(1).atStartOfDay(zone)`), because a fall-back day is 25 hours long and a naive `23:59:59` would drop its last hour.
  - **`ORDER BY startsAt` replaces `ORDER BY date`** — `date` and `time` were never combined, so same-day ties sorted arbitrarily. Ordering by the instant makes it deterministic and correct.
  - **Seed data** writes `startsAt` and `timezone`, deliberately spread across zones and across a DST boundary.
  - Schema regeneration, as 7.14.

  The Flutter client is unaffected by this commit — it keeps reading `date` and `time`, which now mean "the event's own local date and time".

- [ ] **7.19** **The event forms pick a zone, and send an instant.**

  - **The `TimeZoneField` lands on both forms**, between the date and the time. Its **default is the reader's effective zone**, not the organization's.
  - **The date and the time are a wall clock, and the zone says which one.** They are a set: `(2026-03-04, 09:00, Europe/Berlin)` is a moment; `(2026-03-04, 09:00)` alone is not.
  - **Changing the zone does not move the wall clock.** The zone is the *interpretation context* for the date and time beside it — choosing `America/New_York` while the form says `09:00` means "9 AM New York time". The alternative would rewrite the form's own fields under the reader's fingers. The consequence, stated plainly: changing the zone can move an event by up to 26 hours.
  - **The edit form loads the event's own zone**, so saving does not move the event. Loading the reader's zone and wall clock would silently re-zone it — invisible, because the form looks right and the save succeeds.
  - The create form defaults the wall clock to today at 10:00 in the effective zone.
  - **The Flutter request models drop `date` and `time`**, and gain `startsAt: String` and `timezone: String`. `startsAt` carries the zone's offset **at the event's date** — `+02:00` for a Berlin summer event, `+01:00` for its winter twin. The update sends **both or neither**: they are one fact, and a lone `startsAt` would mean "keep the old zone, move the wall clock".
  - **The dead query-parameter path goes** — `create_event_screen.dart:107`'s `DateTime.tryParse('$dateParam $startTimeParam')`, and the `startTime` / `endTime` parameters it read. **This closes 7.8.** The `?date=` parameter stays: it is a plain calendar date with no zone.

  Verify: 09:00 in `Europe/Berlin` stores `2026-03-04T08:00:00Z` with `timezone: "Europe/Berlin"`; editing without touching the zone leaves the instant unchanged.

- [ ] **7.20** **Every event surface renders in the reader's zone.**

  - **`EventResponse` gains the conversions, and they take the zone as an argument** — the model never picks a zone itself. `instant` (UTC), `wallClockIn(zoneId)`, `dateIn(zoneId)`, `timeIn(zoneId)`.
  - **The calendar** — the day an event lands on is its date **in the reader's zone**. This is the change that matters most: an event at 02:00 Berlin is on the **previous** day in New York, and one at 23:00 Berlin is on the **next** day in Auckland. The grid keys on `yyyy-MM-dd` today (`event_calendar_screen.dart:427`); the key becomes the reader's-zone date of the instant. The "today" highlight and the focused month follow too.
  - **The event list** — the Date and Time columns render in the reader's zone (`:196`, `:204`).
  - **The event details screen** — the meta items render in the reader's zone, and the **event's own zone is shown alongside when it differs** ("9:00 AM · Europe/Berlin"). Both are worth seeing: they are two different questions, and the event was scheduled against the second one.
  - **The other-events panel** — the heading date and the row times render in the reader's zone, and it **queries** the reader's-zone date, or it lists the wrong day.
  - **The RSVP widget** — the "date at time" line renders in the reader's zone.
  - **The user list's invitation expiry** — now an instant (7.14), so it must be converted explicitly. **This also retires the second date formatter**: fold `user_list_screen.dart:646`'s `formatDate(String)` into `lib/core/util/local_date.dart`. There should be **one** place that turns a `DateTime` into a wire date.
  - **The date-windowed queries send the zone.** The calendar's month window, the event list's "Start Date" filter and the panel's single-day window all send local dates **in the reader's zone** plus the zone itself. `ListQuery` gains a `timezone` field.
  - **A date of birth is not a time.** `StaffDetails.dateOfBirth` is a day; it is never converted and never picks up a zone.
  - **The tests that assert the old semantics are rewritten, not adjusted** — `models_test.dart`'s `naive-local event times` group is deleted, and the `DateTime.now()`-relative assertions in the calendar and list tests become explicit-zone assertions. 7.25 writes the replacements.

- [ ] **7.21** **Retire the legacy event date and time.**

  The commit that breaks the React app, deliberately and at a known point in the sequence.

  - **Backend:** `CreateEventRequest` and `UpdateEventRequest` drop `date` and `time`, and the legacy resolution goes with them. `EventResponse` drops `date` and `time`.
  - **A naive `startsAt` is a 400**, and **an unknown `timezone` is a 400** — catch the parse exceptions and answer with `failure(...)` rather than letting them escape as 500s. The two checks belong together: a request naming a zone and an instant is one fact.
  - The Flutter client already stopped using them (7.19, 7.20), so nothing changes on that side.

  **What breaks:** the React app's event calendar, event list, create form, edit form, details screen and RSVP panel. **7.22 restores them — do that next, not later.**

- [ ] **7.22** **Patch the React client for the new event shape.**

  **Recommended, and the only task permitted to touch `frontend/`.** The break at 7.21 is accepted, but the React app is the **live** app until Phase 10, and a knowingly-broken live app is a real cost for an accepted one.

  - `src/types/events.ts`, `src/api/EventService.ts` — the new response and request shapes.
  - `CreateEventForm.tsx`, `EditEventForm.tsx` — a time-zone control, and a request body built from the wall clock plus the zone.
  - `EventCalendar.tsx`, `EventListPage.tsx`, `EventDetails.tsx`, `OtherEventsPanel.tsx`, `RsvpWidget.tsx` — the same conversion.
  - `moment` is already a dependency and `moment-timezone` is **not** — `moment` alone has no zone database. The cheapest correct fix is one line: `moment.tz.setDefault(<the reader's zone>)` makes `momentLocalizer(moment)`, which `react-big-calendar` already uses, render the whole calendar in that zone.

  **If the React app is being retired immediately rather than at 10.3, skip this task** and say so in the progress log — that is the condition under which "breaking the React app is OK" is actually free.

- [ ] **7.23** **The organization's time zone in the UI.**

  - **A super-admin** selects an organization in the organization list and lands on the **Edit Organization** screen. The list's name column links to `/organizations/{id}` today — a **dead route** (the same defect 10.20 records for the customer, inventory and user name links). **Point it at the edit route**, which resolves the organization half of that row.
  - **Anyone holding `MANAGE_ORGANIZATION`** clicks their own organization's name in the sidebar and lands on the same screen. The sidebar's static label (`organization_selector.dart`'s non-super-admin branch) becomes a link for those who hold the permission and stays plain text otherwise. A super-admin's sidebar control is a **dropdown**, not a name, so the two paths do not overlap.
  - **One screen for create and edit**, following 9.13's pattern: *"edit loads an item first, create starts empty → the initial values."* The port currently has two near-identical files (`create_organization_screen.dart`, `edit_organization_screen.dart`). Merge them into one `OrganizationScreen` with a nullable `organizationId`.
  - **The time zone field** is the shared `TimeZoneField`, with **the organization being edited as its own "organization default"**. On the create screen there is no organization yet, so the field is at full weight and defaults to the reader's effective zone.
  - **The list shows the zone** — a "Time Zone" column, so a super-admin can see which organizations are on which clock.
  - **The Flutter model gains the field**: `OrganizationResponse.timezone` (required), `CreateOrganizationRequest.timezone` (optional, defaulting to UTC), `UpdateOrganizationRequest.timezone` (optional, null meaning unchanged) — mirroring the server's DTOs.

- [ ] **7.24** **Zone-aware report windows, and the inventory usage date.**

  - **`POST /api/reports/staff_hours`** — `startDate` and `endDate` stay local dates, and a `timezone` parameter names the zone they are in. The server compares them against `staffhours.date`, which is a `date` column (7.14) and therefore zone-free — **which is correct**, because a day is a day. The window's zone is the **reader's**: the reader is the one asking "what happened on the 3rd".
  - `GET /api/reports/inventory_usage` takes no dates and needs no zone.
  - **`usage_date` gets a source that is not the server's wall clock.** It becomes the **event's date in the event's own zone** — the DAO already has the event id, and the event carries its zone, so no join is needed.
  - **The column is still write-only.** Nothing reads `usage_date`, and the inventory usage report is an all-time aggregate. This makes the stored value *correct*; it does not make the column *used*. Say so in the progress log.
  - **The staff-hours aggregate is not fixed here.** `ReportDao.getStaffHoursReport` has no `SUM()` and no `GROUP BY`, so it returns one row per `staffhours` row despite the field being named `totalHoursWorked` — and nothing ever writes a `staffhours` row, so it is always empty (10.13 sees the same thing from the storage side). That belongs to **8.2**, where the report is ported.

- [ ] **7.25** **Tests: the zone conversions.**

  - **The resolution ladder** — override beats detection, detection beats the organization's zone, the organization's zone beats UTC, and clearing the override falls back to detection.
  - **The DST cases, which are the whole reason the `timezone` package is here:** a Berlin summer event and its winter twin have **different offsets**; a wall clock that **does not exist** is rejected with a message; one that **happens twice** is flagged rather than silently resolved; and a **23-hour** and a **25-hour** day both round-trip through the query window.
  - **The calendar's day bucketing** — 02:00 Berlin is on the **previous** day in New York, and 23:00 Berlin is on the **next** day in Auckland. The two pull in opposite directions, which is what makes them worth two assertions: one example only ever proves half the mechanism.
  - **The event form's request body**, asserted on what goes **out** via `test/support/stub_adapter.dart`, the way 9.18 does.
  - **The edit form does not re-zone an event** — load a `Europe/Berlin` event as a reader in `America/New_York`, save without touching anything, and assert the request carries the original instant. **This guards the most damaging bug in the phase**, the one that is invisible because the form looks right and the save succeeds.
  - **The zone picker** — current value pre-selected, the organization's default marked, the field de-emphasized when the two agree.
  - **The tests this task replaces are deleted, not edited.** `models_test.dart`'s `naive-local event times` group asserts the old model. A test that still says "the local `DateTime`" is asserting the thing this phase removed.

- [ ] **7.26** **Tests: the server's zone handling.**

  - **The instant window.** `GET /api/events?startDate=2026-03-01&endDate=2026-03-31&timezone=Pacific/Auckland` includes an event at `2026-02-28T23:00:00Z` (which is `2026-03-01 12:00 NZDT`) and excludes one at `2026-03-31T23:00:00Z` (which is `2026-04-01 12:00 NZDT`).
  - **A 25-hour day** — a window covering a fall-back day in `America/New_York` includes both 01:30 occurrences, and the window's end is exclusive.
  - **`timezone` absent** → the caller's organization's zone; absent *and* unscoped → UTC.
  - **Bad input is a 400, not a 500** — a naive `startsAt`, a malformed `startsAt`, an unknown `timezone`, and a malformed `expiresAt`. Each asserted as a 400 with the envelope's message.
  - **The `MANAGE_ORGANIZATION` scoping** — an Organizer may update **their own** organization and not another's. Assert the **service**, not the route, because 10.22 means the route's plugin is not the guard.
  - **The `Clock`** — a fixed clock drives the invitation expiry, so the test does not depend on the wall clock.

- [ ] **7.27** **Regenerate `API.md`.**

  Regenerate from `API_TEMPLATE.md` and the Dokka output via `generateApiDocs` (`build.gradle.kts:23-87`) — **do not hand-edit**. The models change substantially: the event response and requests lose `date` / `time` and gain `startsAt` / `timezone`; the organization DTOs gain `timezone`; the invitation timestamps change shape.

  **The template's prose needs the new formats described**, not just the models regenerated: what `startsAt` looks like (ISO 8601 **with an offset**), what `timezone` is (an IANA zone id), what the `timezone` query parameter means, and that a naive value is a 400. A regenerated model list with prose still saying *"ISO 8601 date string (e.g., YYYY-MM-DD)"* is worse than the old file, because it looks current.

- [ ] **7.28** **Reconcile the design doc, and write the progress log.**

  **The design doc's groundwork is already in place** — the decisions went in when the phase was planned. What this task does is correct them against what was actually built: a plan written before the work is a hypothesis, and a design doc written after it is a record.

  - Re-read each decision against the code. If the implementation diverged, the design doc gets the **implementation's** answer and the progress log records the divergence and its reason.
  - Update the *Time zone discrepancies* table's Fix column to point at the task that actually landed.
  - Add whatever the phase found that the survey missed — the survey was a reading of the source; the work is a reading of the running system.
  - Append a dated entry to `FLUTTER-CONVERT-NOTES.md` covering the phase: what each task did, the React app's state after 7.21 and 7.22, the `timezone` package's bundle-size cost against task 0.11's baseline, and anything that turned out differently from what these tasks say.

  **Do this as the last task of the phase, not as each task's commit.** The plan's convention is one progress entry per phase, and a phase this size earns one.

---

## Phase 8 — Reports

- [ ] **8.1** Port `ReportList` (133 lines).
- [ ] **8.2** Port `POST /api/reports/staff_hours` (date-range form → `List<StaffHoursReportResponse>`). **The window is a range of *days*, not a range of instants**, so it is interpreted in the reader's zone — 7.24 makes the endpoint zone-aware and the screen must send the zone with it. **The response is also wrong, in a way 7.24 found but deliberately did not fix:** `ReportDao.getStaffHoursReport` has **no `SUM()` and no `GROUP BY`**, so it returns one row per `staffhours` row rather than a total per user, despite the field being named `totalHoursWorked` — and nothing ever writes a `staffhours` row, so the report is always empty (10.13 records the same finding from the storage side). Fix the aggregate **here**, with the screen in front of it, rather than in the timezone phase.
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
- [ ] **9.12** Consider allowing horizontal swipe on event calendar on mobile; AvailableGestures.horizontalSwipe in event_calendar_screen.  Will take some testing in landscape and portrait.

- [ ] **9.13** **Collapse the two event forms into one implementation.** Merge `create_event_screen.dart` and `edit_event_screen.dart` into a single screen both routes use. **The differences that survive are parameters, not second implementations:**

  | Difference | Becomes |
  |---|---|
  | create vs. update request, and where the app goes afterwards | a submit callback |
  | edit loads an event first; create starts from the query params the calendar passes | the initial values |
  | create starts collapsed behind "Add More Details…"; edit shows every field | a `bool` |
  | the "other events" sidebar excludes the event being edited | a nullable id — **a create form has nothing to exclude**, because an event that does not exist yet cannot appear in that list |

  **This commit changes no behaviour.** It is a pure refactor, and it is what makes 9.14–9.17 land in one place instead of twice. The existing `test/event_form_test.dart` cases — validation, customer autofill, edit load, edit submit — must pass **unchanged**; they are the safety net for a refactor this size, and a test edited to fit the refactor is not a safety net.
- [ ] **9.14** **The duration default is 120 in both forms.** The create form's field starts at 120 minutes; the edit form's starts at 60, and the edit form also rewrites a **loaded** duration of zero to 60. All three become 120.

  **A deliberate divergence from the original, not parity.** The React original has the same split — the create form seeds 120 and the edit form does `fetchedEvent.durationMinutes || 60` (`EditEventForm.tsx:65`) — so unifying on 120 means the port is choosing one answer for a field the two forms disagreed about, and it is choosing the create form's.

  Only the *fallback* changes. A loaded event's own duration still wins; the fallback is for an event that has no duration, which is the only case the original's `|| 60` is reachable for.
- [ ] **9.15** **One location-autofill latch for both forms.** Choosing a customer fills the location field with that customer's address. The create form stops doing it once the user has typed in the location field (`locationManuallyEdited` — `CreateEventForm.tsx:38,155,164`); the edit form has no latch at all and only fills while the location is empty.

  Use the latch in both, with one rule: **the customer address fills the location only while the location is not "taken over", and a location loaded from the server counts as taken over.** So a customer change does not silently rewrite the address an event already has, but an event with no address still gets one from the customer; and in the create form, where nothing is loaded, the field starts untaken and the address fills it until the user types.

  **A deliberate divergence from the original.** The original's edit form (`EditEventForm.tsx:137`, `if (customer && !eventLocation)`) cannot express "the user took the location over" — only "the location is empty". The latch is the stronger rule, and it is the one the create form already used.

  **Watch the mechanism, not just the flag.** A programmatic write to the field's controller does **not** fire the field's `onChanged`, so loading an event's location does not set the latch, and the autofill does not set it either. The latch is set by the user's own typing and by nothing else — which is exactly what makes the loaded-location case above work.
- [ ] **9.16** **The organization is a dropdown in both forms.** Today the create form has no organization control at all: the organization comes from the shell's org switcher, and a global manager with no selection gets an "Organization Required" card in front of the form instead (`CreateEventForm.tsx:210`). The edit form has a `<select>` of every organization, which the original disables for anyone who is not a global manager (`EditEventForm.tsx:226-236`).

  Put the dropdown in the form body of both, so the organization is always visible and always says which one the event will belong to. The rules:

  - A **global manager** may pick any organization. That is the server's own rule: `EventService.kt:20-24` honours the submitted id for a global manager and substitutes the caller's own organization for anyone else, and `EventService.kt:83-89` does the same on update.
  - **Anyone else** is confined to their own organization. The dropdown shows it and does not open — there is no second choice to offer, and offering one would be a promise the server does not keep.
  - The **list** comes from `GET /api/organizations`, which the server gates on `VIEW_ORGANIZATIONS_GLOBAL` — **not** on `MANAGE_EVENTS_GLOBAL`. Fetch it only for a caller who may list organizations, and build the items with `organizationsIncluding` so the current selection always has a matching item and the control cannot assert (the reason that helper exists — `organization_list.dart:66`). A `MANAGE_EVENTS_GLOBAL` caller without `VIEW_ORGANIZATIONS_GLOBAL` cannot be shown a list at all; **10.16** is where that gap gets closed.

  The **"Organization Required" card stays in front of the create form** — it is the original's behaviour, and the one place the form cannot be used at all until an organization exists. Once there is one, the dropdown is the control.

  **One organization, one meaning.** The create form's dropdown, the card's picker and the shell's org switcher must not be able to disagree about which organization is current. The create form already *follows* the shell's switcher (`selectedOrganizationProvider`), so the dropdown should **write through** to it rather than keeping a second copy — which also makes the card's picker, which already sets that same global selection, just another way to set the same value. A non-global manager's own organization is never written anywhere: the global selection is an app-wide preference, not a per-user one, so writing an org-scoped user's organization into it would leak into whoever uses that browser next.
- [ ] **9.17** **Pin the organization on the wire, and say whose decision it is.** "A global manager chooses the organization; everyone else gets their own" is enforced **server-side**, and the client should not pretend otherwise:

  - `EventService.kt:20-24` (create) — for a global manager the submitted id is used; for anyone else it is **replaced** with the caller's own organization, whatever was submitted.
  - `EventService.kt:83-89` (update) — for a global manager the submitted id is used; for anyone else a **differing** id is rejected with `"Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId"`, and a **null** id means "leave the organization alone".

  So: the **update** request sends `organizationId: null` unless the caller is a global manager — the original's behaviour (`EditEventForm.tsx:162`) and the port's. The **create** request must always carry an id, because `CreateEventRequest.kt:19` types it as a non-nullable `Int` and the model mirrors that (`models/event.dart:166`), so the create form sends the **resolved** organization — which for an org-scoped caller is their own, the same value the server substitutes.

  **Do not "fix" the create request by sending null.** The field is required on the wire; omitting it fails deserialization rather than meaning "use mine". A nullable create id is a **backend** change — nullable in `CreateEventRequest.kt`, where the service's existing `?:` already handles it — and backend work is Phase 9–10, so file it separately if it is wanted.
- [ ] **9.18** **Tests for the unified event form.** The unified screen replaces the two the port had, so its cases replace theirs. Cover:

  - the duration field starts at 120 in **both** modes, and a loaded event with a duration of zero shows 120 (9.14)
  - choosing a customer fills the location, stops filling it once the user has typed in the location field, and does not clobber a location loaded with the event (9.15)
  - the organization dropdown is present in both modes, is not selectable for an org-scoped caller, and lists every organization for a global manager (9.16)
  - the **request body**: an org-scoped manager's update carries no organization id, and a global manager's carries the one they picked (9.17)
  - the create form still starts collapsed behind "Add More Details…" and still prefills its date and time from the calendar's query params; the edit form still loads the event and still excludes it from the "other events" list (9.13)

  **Assert on the request body, not on the response.** The behaviour that matters in 9.17 is what goes *out*, and the port's harness already records outgoing requests and their bodies (`test/support/stub_adapter.dart`) — use it rather than asserting on what the screen shows afterwards.

  Record the whole sequence in the progress log (`FLUTTER-CONVERT-NOTES.md`) when it lands, including what the shared form replaced.

---

## Phase 10 — Cutover and cleanup

Once the Flutter web app is verified working locally against the real backend. The trigger for deleting `frontend/` is internal confidence, not a deployment.

- [ ] **10.0** Strip out comments referencing conversion tasks or filename/linenumber combos.  If dart has javadoc-like capabilities for linking use those, otherwise use File.member type references.
- [ ] **10.1** Default `WEB_SOURCE` in `Dockerfile` to `flutter`; keep the React stage for one release cycle, then remove.
- [ ] **10.2** Verify the Flutter build end-to-end against the real backend via `docker compose up --build`: login, org switch, and one full create/read/update/delete pass per resource.
- [ ] **10.3** **Delete `frontend/`.** The last commit touching it is the deletion commit.
- [ ] **10.4** Remove React deps, ESLint config, and node tooling references from the repo.
- [ ] **10.5** Update `AGENTS.md`, `README.md`, and `BACKEND-DESIGN.md` for Flutter conventions.
- [ ] **10.6** Update `API.md` for the drift found during the port (the table in `FLUTTER-CONVERT-DESIGN.md`) — regenerate rather than hand-edit, per `build.gradle.kts:23-87`.
- [ ] **10.7** Remove dead `backend/service/geo/` code if the Flutter app does client-side geocoding, or wire up `GeoRoutes` if it does.
- [ ] **10.8** **Strip dangling `frontend/` references from `flutter_app/lib/`.** 10.3 deletes the directory these comments point at, leaving paths like ``frontend/src/api/apiClient.ts`` that resolve to nothing — a comment that looks like a citation a reader could follow but cannot. 10.4 covers React *dependencies* and node tooling; it does not reach prose in doc comments.

  **Do not delete these references wholesale — they carry the rationale for non-obvious decisions.** Most of the current occurrences explain *why* something is shaped the way it is, and that reasoning is the durable value. Reword to keep the explanation and drop the path, e.g. rather than "Replaces `apiClient` in `frontend/src/api/apiClient.ts`", say "Replaces the React app's hand-rolled `apiClient`, which wrapped `fetch`".

  **The scope is much larger than the table below, which counts only the `frontend/src` occurrences.** A grep for `.ts`/`.tsx` finds **388** citations across **71 files** — 53 in `flutter_app/lib/` and 18 in `flutter_app/test/` — most of them the `Component.tsx:123` form, and `user_list_screen.dart` alone has 33. The table lists the ten `frontend/src` ones because those are the ones a reader cannot possibly reconstruct; the rest are equally dangling. **The calendar screen was swept separately**, as a demonstration of the shape, and the panel and the two event forms with it (task 7.7).

  **`AGENTS.md` now carries the rule this task implements:** no TypeScript file may be named in a code comment. **Keep the reasoning, drop the path** — and the shape to aim for is the calendar screen's: "the calendar this replaced branched on the gesture", not "the React calendar at `EventCalendar.tsx:230`". The React sources stay citable in `FLUTTER-CONVERT-NOTES.md`, which is the historical record.

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

  `Permission` in `flutter_app/lib/models/permissions.dart` mirrors the React 15 for parity. Extend it in the same commit, and re-check the role-assignment path discrepancy already in the table (`FLUTTER-CONVERT-DESIGN.md`; `API.md:632` is wrong; see `RoleRoutes.kt:86`).

- [ ] **10.17** **Decide whether `RsvpRequest.availability` stays a free-form `String`.** The server type is `String` with no validation (`RsvpRequest.kt`) and the app posts `"available"`, `"unavailable"`, and server-initiated `"requested"`. Any string is accepted, so a typo is stored silently and only shows up as a filter that never matches.

  An enum on the server would catch that at the boundary. The cost is a migration for existing rows holding values outside any chosen set — check the data first (`SELECT DISTINCT availability FROM rsvps`) before deciding, since that query is cheap and the answer determines whether this is a small change or a data migration. Client-side, `RsvpAvailability` in `models/event.dart` already names the three values in use; tighten it once the server agrees on a set.

  **Already covered elsewhere, do not duplicate:** `Dockerfile:32-47` (the `frontend-react` builder stage, including its `COPY frontend/src` and `COPY frontend/public` lines) disappears with 10.1. Those are functional build instructions, not comments, so they are not this task's concern. The `FLUTTER-CONVERT*.md` files are *expected* to reference `frontend/` paths throughout — they are a historical record and keep them deliberately; exclude them.

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

  **Scope widened to four links by task 4.7.** `UserList.tsx:123` links to `/users/{id}` and `App.tsx:61-63` declares no `users/:userId`, so the user list has the identical dead link — the fourth. It is recorded here rather than as a row of its own because it is the same defect in the same shape, and building one detail screen out of four dead links is the same work as building one out of three. The three screens' links were confirmed by hand in a browser during the 4.5/4.6 pass; the fourth is confirmed from `App.tsx` and from the port's own route table, where `AppRoutes.userDetails` documents the absence in the same terms as the other three.

  **Work items, in order.**

  1. **The events list is the real work, and it is blocked on the backend.** The intended shape is the customer's past *and* future events, and `GET /api/events` **has no customer filter** — `EventRoutes.kt` takes `search`, `sortBy`, `sortOrder`, `limit`, `offset` and no `customerId`, and neither does `EventDao`. So this is not purely a screen task: it needs a new query parameter on the route and the DAO, which is Phase 10 backend work under the ground rules. If the screen is wanted before that parameter lands, ship the field rendering first — a customer page with no events on it still beats a link to the calendar.
  2. Register the route in the port's table in Phase 5, alongside the forms, behind `VIEW_CUSTOMERS_ORGANIZATION` — the same gate as the list. **Not** `MANAGE_CUSTOMERS_ORGANIZATION`: the rendering is read-only and viewers can see the list, so the `App.tsx:62` create/edit split does not apply to a screen that cannot write.
  3. Render the fields `EditCustomerForm` shows, as disabled rather than absent, so the two stay comparable. Do not build it as "the edit form in read-only mode" — that couples a read path to a write path, and the part that will differ (the events section) is most of the page.
  4. The geo fields (`latitude`, `longitude`, `formattedAddress`) are on the DTO and null in practice, because the backend's geo service is dead code (**10.7**). Render them when the geocoding work lands (**`GEO_FEATURES_PLAN.md`**), not before — otherwise it is a page of empty coordinates.

  **The same shape of problem exists for staff details, and the reason neither is noticed is identical.** `StaffDetails` is a planned surface with a DTO field and no storage (**10.13**), and `GEO_FEATURES_PLAN.md` assumes it too. Two documents promising screens the app does not have is a pattern rather than a coincidence, and it survives review because nothing links to either — so nothing fails, and the only way to notice is to click.

- [x] **10.18** **Make the seeded test users loggable in.** Found while trying to discharge task 3.12's real-browser check. The seed wrote a plaintext `"password"` into `users.password`, which `BCrypt.checkpw` throws on — so every seeded account answered **500 with a stack trace** rather than a 401. **Done**: a real hash at seed time, and a malformed stored hash is a failed login rather than an unhandled error. See the 2026-10-13 entry in `FLUTTER-CONVERT-NOTES.md`.

---

- [ ] **10.21** **Stop `GET /api/inventory` embedding an unbounded `events` list per row.** Found while porting the inventory list (4.5). `InventoryDao.getInventoryItems` builds every row through `toInventoryItemResponse`, which does a second `selectAll` on `EventInventory` for that item with **no `limit`, no `offset` and no filter** — so a list of 25 items is 26 queries, and a heavily-used item brings back every event that has ever drawn on it.

  Two consequences, and only the second one is visible to a user. The **N+1** is a performance problem that no test and no screenshot will report. The **unbounded payload** is a correctness one: the port has to truncate at the client (`maxEventsShown`, 4.5) because there is no server-side way to ask for fewer, so the count a user sees is a number the client invented.

  Options, in increasing order of effort:
  1. **Return a count instead of a list** on the list endpoint — an `eventCount` per item, with the full list kept on `GET /api/inventory/{id}` for whoever needs it. This is the shape the list screen actually wants, and it makes the client's truncation disappear rather than become a permanent workaround.
  2. **Paginate `events`** within `InventoryItemResponse`. Preserves the current shape and costs a nested envelope; a page of events inside a page of items is awkward to consume.
  3. **Batch the lookup** — one `where { EventInventory.inventoryItemId inList ids }` rather than one per row — and leave the list unbounded. Fixes the N+1 only, and leaves the payload problem.

  Whatever is chosen, check the callers before narrowing the response: `getInventoryItemsForEvent` and `getAllInventoryItemsByOrganization` share `toInventoryItemResponse`, so changing it changes three endpoints at once.

  Verify after: a request for 25 items issues a constant number of queries, and the client's `maxEventsShown` truncation is either gone or no longer load-bearing.

- [ ] **10.21** **Accepting an invite errors** The user is created but on the invite UI a server error banner shows.  Looks like something trying to serialize ApiResponse.  Debug logs:
```
DEBUG Exposed -- SELECT invitations.id, invitations.organization_id, invitations.role_id, invitations.token, invitations.expires_at, invitations.used_by_user_id, invitations.created_at, invitations.note, roles.id, roles.role_name, roles.permissions, organizations.id, organizations."name", organizations.contact_information FROM invitations INNER JOIN roles ON roles.id = invitations.role_id INNER JOIN organizations ON organizations.id = invitations.organization_id WHERE invitations.token = '5bd54d87-7846-4770-90f7-e1167b20f3a8'
DEBUG Exposed -- SELECT invitations.id, invitations.organization_id, invitations.role_id, invitations.token, invitations.expires_at, invitations.used_by_user_id, invitations.created_at, invitations.note, roles.id, roles.role_name, roles.permissions, organizations.id, organizations."name", organizations.contact_information FROM invitations INNER JOIN roles ON roles.id = invitations.role_id INNER JOIN organizations ON organizations.id = invitations.organization_id WHERE invitations.token = '5bd54d87-7846-4770-90f7-e1167b20f3a8'
DEBUG Exposed -- SELECT users.id, users.username, users."password", users.email, users.display_name FROM users WHERE users.username = 'neworgadmin'
DEBUG Exposed -- SELECT users.id, users.username, users."password", users.email, users.display_name FROM users WHERE users.email = 'johnjohn@muddyhorse.com'
DEBUG Exposed -- INSERT INTO users (username, email, display_name, "password") VALUES ('neworgadmin', 'johnjohn@muddyhorse.com', 'johnjohn', '$2a$10$Ib6AT7jTuOsQSamfNgpC3umAqzURfpUQkexGnuZJqvg6SnMxS4rCC')
DEBUG Exposed -- INSERT INTO userorganizations (user_id, organization_id) VALUES (66, 34)
DEBUG Exposed -- INSERT INTO userroles (user_id, role_id) VALUES (66, 2)
DEBUG Exposed -- UPDATE invitations SET used_by_user_id=66 WHERE invitations.token = '5bd54d87-7846-4770-90f7-e1167b20f3a8'
kotlinx.serialization.SerializationException: Serializer for class 'ApiResponse' is not found.
Please ensure that class is marked as '@Serializable' and that the serialization compiler plugin is applied.
	at kotlinx.serialization.internal.Platform_commonKt.serializerNotRegistered(Platform.common.kt:90)
	at kotlinx.serialization.SerializersKt__SerializersKt.serializer(Serializers.kt:299)
	at kotlinx.serialization.SerializersKt.serializer(Unknown Source)
	at io.ktor.serialization.kotlinx.SerializerLookupKt.guessSerializer(SerializerLookup.kt:54)
	at io.ktor.serialization.kotlinx.KotlinxSerializationConverter.serialize(KotlinxSerializationConverter.kt:55)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1$2.invokeSuspend(ResponseConverter.kt:66)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1$2.invoke(ResponseConverter.kt)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1$2.invoke(ResponseConverter.kt)
	at io.ktor.server.application.OnCallRespondContext.transformBody(KtorCallContexts.kt:102)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1.invokeSuspend(ResponseConverter.kt:39)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1.invoke(ResponseConverter.kt)
	at io.ktor.server.plugins.contentnegotiation.ResponseConverterKt$convertResponseBody$1.invoke(ResponseConverter.kt)
	at io.ktor.server.application.PluginBuilder$onDefaultPhase$1.invokeSuspend(PluginBuilder.kt:245)
	at io.ktor.server.application.PluginBuilder$onDefaultPhase$1.invoke(PluginBuilder.kt)
	at io.ktor.server.application.PluginBuilder$onDefaultPhase$1.invoke(PluginBuilder.kt)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1$1.invokeSuspend(PluginBuilder.kt:228)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1$1.invoke(PluginBuilder.kt)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1$1.invoke(PluginBuilder.kt)
	at io.ktor.util.debug.ContextUtilsKt.addToContextInDebugMode(ContextUtils.kt:34)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1.invokeSuspend(PluginBuilder.kt:224)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1.invoke(PluginBuilder.kt)
	at io.ktor.server.application.PluginBuilder$onDefaultPhaseWithMessage$1$1.invoke(PluginBuilder.kt)
	at io.ktor.util.pipeline.PipelineJvmKt.pipelineStartCoroutineUninterceptedOrReturn(PipelineJvm.kt:15)
	at io.ktor.util.pipeline.SuspendFunctionGun.loop(SuspendFunctionGun.kt:131)
	at io.ktor.util.pipeline.SuspendFunctionGun.proceed(SuspendFunctionGun.kt:89)
	at io.ktor.util.pipeline.SuspendFunctionGun.execute$ktor_utils(SuspendFunctionGun.kt:109)
	at io.ktor.util.pipeline.Pipeline.execute(Pipeline.kt:92)
	at io.ktor.server.application.PipelineCall$DefaultImpls.respond(PipelineCall.kt:132)
	at io.ktor.server.routing.RoutingPipelineCall.respond(RoutingPipelineCall.kt:23)
	at io.ktor.server.routing.RoutingCall.respond(RoutingNode.kt:248)
	at alphainterplanetary.teven.app.invitation.InvitationRoutesKt$publicInvitationRoutes$1$2.invokeSuspend(InvitationRoutes.kt:165)
```

- [ ] **10.22** **The server's permission check is not enforced.** Found by hand while porting the event details screen (7.6), against the running dev backend rather than by reading the Kotlin. **This is a security defect, and it is the first one the port has found.**

  **What was measured.** Signing in as `alice` — a seeded **Organizer**, whose role grants neither `VIEW_ORGANIZATIONS_GLOBAL` nor `VIEW_EVENTS_GLOBAL` (`InitialSetup.kt:60-77`) — and asking for an endpoint gated on exactly that:

  ```
  GET /api/organizations   →  200, and the full organization list
  ```

  Four organizations, including the `SuperAdmin`'s own, returned to a user with no global permission of any kind. `GET /api/users`, `/api/customers`, `/api/inventory` and `/api/events` all answered 200 for the same caller. **Authentication is enforced** — the same request without a token is a 401 — **and nothing else is.**

  **Where the check is supposed to happen.** `withPermission(...)` (`PermissionInterceptor.kt:7`) installs `AuthorizationPlugin`, whose `onCall` hook looks the caller's permissions up and answers 403 when the check fails (`AuthorizationPlugin.kt:30-33`). The lookup itself is right: `PermissionServiceImpl` returns the caller's real permissions, and `UserPermissions.hasPermission` is a plain membership test.

  **The defect is in how the plugin is wired, not in what it checks.** `AuthorizationPlugin` is built with `createRouteScopedPlugin`, and inside that block `pluginConfig.forEach { permission -> onCall { ... } }` registers **one hook per permission**. Ktor's `onCall` hooks do not short-circuit: the first hook's `call.respond(403)` does not stop the route handler from running, and the handler's own `call.respond(success(...))` is what the client receives. The 403 is written and then overwritten.

  **The obvious suspect is the `vararg`, and it is worth checking before assuming it.** `withPermission(VIEW_ORGANIZATIONS_GLOBAL)` — a single permission — is also not enforced, so this is not an any-of/all-of question. `UserPermissions.hasPermission` returns `true` for a super-admin regardless (`isSuperAdmin || …`), which explains why the `SuperAdmin` account has never noticed.

  **Fix it in one place:** the plugin should answer 403 and **stop the pipeline**, rather than registering a hook per permission and letting the route handler answer over the top. The `onCall` phase is the wrong hook for a decision like this — a route-scoped plugin that short-circuits has to prevent the handler from running at all, which is what `withPermission` should be doing.

  **Why it is not a Phase 9 or Phase 10 task with the rest of the backend work:** it was found during Phase 7, and the ground rules keep the backend frozen until Phase 9. It is filed here for the same reason 10.19 and 10.20 are: **the port found it, and a defect the port found should not be lost.** It is also the one item in this list that is not a matter of taste.

  **What to verify after:** an `Organizer` asking for `GET /api/organizations` gets a 403; the `SuperAdmin` still gets 200; and a user with **one** of two permissions on a two-permission route is still allowed — because the client's route guard is OR-semantics (`ProtectedRoute.tsx:22-25`) and the server has to agree with it, or the app's gates and the server's will disagree in the *other* direction.

  **Until this is fixed, the client-side permission gates are the only thing standing between a user and the whole database.** That is worth saying plainly: the port's route guards, the nav items and the per-screen buttons all work, and none of them is a security boundary.
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
- [ ] **12.6** Ensure the suite runs on both VM and Chrome. **Partly done:** `flutter test` and `flutter test --platform chrome` both work; the socket-based tests skip on web because `dart:io`'s `HttpServer` is unavailable there — they skip explicitly rather than passing vacuously. Every widget test added in Phases 3–7 has been verified on both, and two failure classes found only on Chrome are now written down in the Phase 7 entry of `FLUTTER-CONVERT-NOTES.md`. **Not done:** a green full-suite Chrome run — see that entry for the counts and what is still unowned.
---
