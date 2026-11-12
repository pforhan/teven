# Flutter Conversion — Completed phases

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
- [x] **7.8** **Replace `moment` with `intl` + `DateTime`.** **Closed by 7.19:** the last fragile site — `create_event_screen.dart`'s dead `DateTime.tryParse('$dateParam $startTimeParam')` and the `startTime` / `endTime` / `time` query parameters it read — is gone; `?date=` stays. The port never used `moment` (`local_date.dart` formats from `DateTime` fields; `EventResponse.startAt` builds from components). The React app's `moment` usage disappears with 10.3.

- [x] **7.9** **Every timestamp on the wire is unambiguous.** Superseded by Phase 7A; **closed by 7.21** (legacy event `date`/`time` retired; event instants are offset-bearing `startsAt` + `timezone`).

  **The old wording of this task is withdrawn.** It asked for the opposite of what the app should do: *"Do not silently re-interpret as UTC; keep naive local semantics to match current behavior."* Naive-local was right **only** while the app had no way to know a better one. The rules it is replaced with are in the design doc under *Time zones → On the wire*.

  **What "closed" means, concretely:** no DTO carries a naive date-time, no column stores one, and the client has no code path that reads a timestamp without being told which zone to read it in. Phase 7A gets there in stages — 7.14 (invitations), 7.18 (events), 7.21 (the legacy event fields retired) — and **this checkbox closes when 7.21 lands.**

- [x] **7.10** Route `/events/rsvps/requested` into the UI. It is **undocumented in `API.md`** but real (`EventRoutes.kt:118`). Confirm whether the React app uses it — if not, decide whether to expose it. **Both halves are settled: the React app does *not* use it** — `RsvpWidget.tsx` was the only thing that ever fetched it, it was added in the same commit as the route (`f13ae83`), and it has never been imported by anything since. **The port exposes it**, as a card on the calendar — the app's landing page, and the place where a pending request is already marked in orange on the event's bar. What is left here is whether the card belongs there rather than somewhere else; moving it is a one-line change to the calendar screen. See the 2026-10-20 entry in `FLUTTER-CONVERT-NOTES.md`.
- [x] **7.11** **A day view for day selection.** No hourly schedule widget exists that avoids a hand-built grid, so the view reuses [OtherEventsPanel] — its fetch, stale-response guard, sort and states, plus the row render — and carries a create [FloatingActionButton] that reuses [CreateEventButton.createForDay]. Route `/events/day?date=YYYY-MM-DD` (`AppRoutes.eventDayUrlForDay`); the permission gate is the same `VIEW_EVENTS_ORGANIZATION` as the calendar. The split by device from 7.2 is unchanged: a mouse click still creates, a finger's long press still creates, and a finger's tap now opens this view; the hint names both touch gestures. Tests: `test/event_calendar_screen_test.dart` (touch-tap → day view, hint) and `test/event_day_screen_test.dart` (panel, affordance).
- [x] **7.12** Tests for the calendar's date handling, which is where the fragile logic lives: naive-local date construction (7.8/7.9), and the month grid rendering the right events on the right days. Golden tests for the grid itself are 12.5 — here it is the placement logic, not the pixels. **The placement half landed with 7.1** (`test/event_calendar_screen_test.dart`, four cases); the naive-local construction is covered by the existing `models_test.dart` case, so what is left is the golden half, which 12.5 owns. **Marked complete:** placement and date-construction coverage are in place; the calendar month-grid golden lives under task 12.5.

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

- [x] **7.13** **Pin the server's clock and its time zone.**

  The JVM's zone and the Postgres session zone are two independent defaults that agree by accident, and there is no `Clock` seam, so no temporal logic is testable.

  - `docker-compose.yml`: `TZ: UTC` on `db` and `backend`, plus `PGTZ: UTC` on `db`. `Dockerfile` (final stage): `ENV JAVA_TOOL_OPTIONS="-Duser.timezone=UTC"`. `gradle.properties`: `-Duser.timezone=UTC`.
  - Add `single<Clock> { Clock.systemUTC() }` to `app/di/KoinModule.kt`; inject it into `InvitationService`, `InvitationDao` and `InventoryDao`, replacing the five static `now()` calls (`InvitationService.kt:57,67,82`, `InvitationDao.kt:83`, `InventoryDao.kt:166`).
  - **Collapse the duplicated expiry check.** SQL (`InvitationDao.kt:83`) and Kotlin (`InvitationService.kt:67,82`) judge the same expiry against two clocks. The DAO filter should be an index-friendly pre-filter; Kotlin decides.
  - Leave `AuthServiceImpl.kt:46` alone — epoch millis are zone-independent.

  Verify: `./teven verify-backend`; `docker exec teven_backend date` and `psql -c "SHOW timezone"` both UTC; a fixed-`Clock` test drives an invitation past its expiry.

- [x] **7.14** **Type the date columns that are not events, and make an invitation's expiry a real instant.**

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

- [x] **7.15** **Give an organization a home time zone.**

  - `data/organization/Organizations.kt` — `val timezone = varchar("timezone", 64)`.
  - `OrganizationResponse.timezone: String` — **required**, so every consumer sees it. `UserResponse.organization` and `EventResponse.organization` are `OrganizationResponse`s, so the zone rides along everywhere, and the reader's own organization's zone comes from the auth context with **no extra fetch**.
  - `CreateOrganizationRequest.timezone: String` — **required**, so an organization is never created or edited without a zone. `UpdateOrganizationRequest.timezone: String` — **required**; there is no "unchanged" value any more, an update always carries the new zone.
  - **Validate server-side:** an unknown id is a **400**, not a 500 (`ZoneId.of` throws `ZoneIdRulesException`). The check is `ZoneId.getAvailableZoneIds().contains(id)`.
  - **The client owns the picker list, the server owns the validation.** The Dart list is a subset of Java's, which is what makes the pairing safe — the client can only ever send a zone the server accepts. Verify that rather than assuming it.
  - **Seed distinct zones** so the interesting cases are visible: the two seeded test organizations get `America/New_York` and `Pacific/Auckland` (Auckland because it is UTC+13 in summer and UTC+12 in winter, and because it is on the other side of the date line). The bootstrap "Teven" organization gets `UTC`.
  - Schema regeneration, as 7.14.

  Verify: `./teven verify-backend`; `GET /api/organizations` shows the zone; a bogus zone answers 400.

- [x] **7.16** **Add the `MANAGE_ORGANIZATION` permission.**

  The org-scoped counterpart to `MANAGE_ORGANIZATIONS_GLOBAL` — it is what lets an **Organizer** set their organization's zone.

  - `core/security/Permission.kt` — add `MANAGE_ORGANIZATION`. `app/InitialSetup.kt` — grant it to the seeded **Organizer** role. `flutter_app/lib/models/permissions.dart` — add the client constant; this is one of the 18 that 10.16 covers, added early for the same reason `MANAGE_CUSTOMERS_GLOBAL` was.
  - **Enforce it in the service, not only on the route.** 10.22 is still open: the permission plugin does not short-circuit, so a route-level `withPermission` is not a guard today. `OrganizationService.updateOrganization` takes the caller's id and allows the update when the caller holds `MANAGE_ORGANIZATIONS_GLOBAL`, **or** holds `MANAGE_ORGANIZATION` and the target is their own organization. Otherwise `AuthorizationException`.
  - **`OrganizationRoutes` passes the caller's id down**, and the route's `withPermission` widens to accept either permission — the *scoping* lives in the service.
  - **The read path needs the same treatment, or the edit screen cannot load.** `GET /api/organizations/{id}` is gated on `VIEW_ORGANIZATIONS_GLOBAL`, which an Organizer does not hold. Widen it the same way, with the same service-level scoping.

  Verify by signing in as the seeded Organizer: their own organization reads and writes; **another** organization's answers 403.

- [x] **7.17** **Flutter: the time zone foundation.**

  Adds `timezone: ^0.11.2` (the IANA database — Dart's `DateTime` converts between local and UTC and nothing else) and `flutter_timezone: ^5.1.1` (the device's IANA id — `timeZoneName` gives an ambiguous abbreviation). Justify both in the commit message.

  - **Initialize the embedded database** (`timezone/data/latest.dart`), not the browser variant, which fetches a `.tzf` at runtime. Record the bundle-size cost against task 0.11's baseline in the progress log.
  - **A `TimeZoneService`** wrapping the package: `locations` for the picker; `offsetAt(zoneId, instant)` (DST-aware); `wallClockAt(instant, zoneId)`; and `instantAt(localDate, localTime, zoneId)` — which must **reject a wall clock that does not exist** (`02:30` on a spring-forward morning) and **flag one that happens twice** (`02:30` on a fall-back morning), rather than silently picking an occurrence.
  - **A `TimeZoneController`** resolving the reader's zone in the order settled above, exposing the effective zone, the detected zone, the override, and `setOverride(String?)` — `null` clears the override and falls back to detection. The override lives in `shared_preferences` under its own key and is never sent to the server.
  - **A shared `TimeZoneField` widget** (used by 7.19 and 7.23): shows the zone with its current offset; opens a searchable sheet (mobile) or dialog (desktop) listing every zone, grouped by offset, current value pre-selected; **marks the organization's zone** as the default; and **de-emphasizes itself when it agrees with that default**.
  - **A "Time zone" row on the profile screen** showing the detected zone and any override, with the same picker. This is where "see and override the detected timezone" lives.
  - **Tests override the detector** — `flutter_timezone` is a platform plugin and cannot answer in a headless VM test. Follow the `tokenStoreProvider` pattern (`test/support/fakes.dart`). **Verify the web implementation returns an IANA id**, not an abbreviation or an offset: the plugin's web path differs from its native one, and the browser is the platform this app ships on.

- [x] **7.18** **An event becomes an instant plus a zone.**

  - `data/event/Events.kt` — drop `date` and `time`; add `val startsAt = timestampWithTimeZone("starts_at")` (**not** `timestamp()` — see 7.14) and `val timezone = varchar("timezone", 64)`.
  - `EventResponse` **gains** `startsAt: String` (offset-bearing ISO 8601) and `timezone: String`, and **keeps** `date` and `time` — now computed by the server from `startsAt` in the event's own zone. Keeping them is what keeps the React app alive until 7.21.
  - `CreateEventRequest` / `UpdateEventRequest` **accept both shapes** for one commit: the new `startsAt` + `timezone`, and the legacy `date` + `time`, resolved as a wall clock in `timezone` (defaulting to the caller's organization's zone). A naive `startsAt` is a **400**.
  - **`GET /api/events` gains a `timezone` query parameter.** `startDate` and `endDate` stay local dates; the server converts the pair into an instant range. **`timezone` absent** → the caller's organization's zone → UTC when there is no organization scope. The upper bound is **exclusive** (`endDate.plusDays(1).atStartOfDay(zone)`), because a fall-back day is 25 hours long and a naive `23:59:59` would drop its last hour.
  - **`ORDER BY startsAt` replaces `ORDER BY date`** — `date` and `time` were never combined, so same-day ties sorted arbitrarily. Ordering by the instant makes it deterministic and correct.
  - **Seed data** writes `startsAt` and `timezone`, deliberately spread across zones and across a DST boundary.
  - Schema regeneration, as 7.14.

  The Flutter client is unaffected by this commit — it keeps reading `date` and `time`, which now mean "the event's own local date and time".

- [x] **7.19** **The event forms pick a zone, and send an instant.** **Done.** `TimeZoneField` lands between the date and the time on both forms. The create form defaults to the reader's effective zone and to today 10:00 in that zone (wall clock unchanged when the zone changes); the edit form loads the event's own zone and its wall clock. Request models drop `date`/`time` and send `startsAt` (offset-bearing, at the event's date in the chosen zone) + `timezone` — the update always sends both. The dead `?startTime`/`?endTime`/`?time` path and its fragile parse are gone; `?date=` stays (**closes 7.8**). `EventResponse` now carries `startsAt`/`timezone` on the client (keeping `date`/`time` for 7.20's readers). Verified: 09:00 `Europe/Berlin` on 2026-03-04 resolves via `TimeZoneService` to `2026-03-04T08:00:00Z` with `+01:00` (CET); recomputing the same wall clock in the same zone yields the same instant (`./teven verify` green, 442 tests).

- [x] **7.20** **Every event surface renders in the reader's zone.** **Done.** `EventResponse` now exposes `instant` plus explicit zone conversions (`wallClockIn`/`dateIn`/`timeIn`) via `lib/core/util/local_date.dart`; it never picks a zone. Calendar, list, details, day/panel, and RSVP surfaces render in the reader's effective zone (calendar buckets by `dateIn(readerZone)`; details show the event's own zone when different). `ListQuery` gained `timezone`; date-windowed event queries (calendar month, list start-date filter, other-events panel day window) send reader-zone local dates plus `timezone` (forms pass `queryTimezone` for event-zone double-booking checks). Invitation expiry uses `formatInstantDate`; `user_list_screen.dart`'s local `formatDate(String)` was removed. The naive-local `EventResponse` time group was deleted and 7.20-affected tests were rewritten for explicit/UTC reader-zone semantics. Verified: `./teven verify` green (analyze clean, format clean, 436 tests passed).

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

- [x] **7.21** **Retire the legacy event date and time.** **Done (closes 7.9).** Backend drops `date`/`time` from `CreateEventRequest`/`UpdateEventRequest`/`EventResponse` and removes legacy wall-clock resolution (`EventService`); `startsAt`+`timezone` are the only event time input (required together on create, both-or-neither on update). A naive `startsAt` (no offset, `OffsetDateTime.parse` fails) and an unknown `timezone` return **400** (`BadRequestException` → `failure(...)` via `StatusPages`). Flutter `EventResponse` drops `date`/`time`; `edit_event_screen.dart` loads the event’s wall clock via `event.wallClockIn(event.timezone)`. React event screens would break, but **7.22 is will-not-do** (React retired). Verified: `./teven verify-backend` green; `./teven verify` green (436 tests).

- [x] **7.22** **will not do: Patch the React client for the new event shape.**. React app is considered retired as of now.

- [x] **7.23** **The organization's time zone in the UI.** **Done.** `OrganizationResponse`/`CreateOrganizationRequest`/`UpdateOrganizationRequest` now carry required `timezone` (mirroring 7.15 DTOs; `UpdateOrganizationRequest` always carries the new zone). `create/edit` org screens merged into `OrganizationScreen` (nullable `organizationId`): create defaults to the reader's effective zone (full weight, no default marker), edit loads the org and uses `TimeZoneField` with the edited org as its own `defaultZone`. The edit route accepts `MANAGE_ORGANIZATIONS_GLOBAL | MANAGE_ORGANIZATION` (backend enforces own-org scope). Org list adds a "Time Zone" column and its name link points at the edit route (dead `organizationDetails` route repointed). Sidebar: non-super-admin with `MANAGE_ORGANIZATION` gets a tappable org name linking to their org's edit screen; others unchanged. Org JSON fixtures across tests updated for required `timezone`. Verified: `./teven verify` clean (436 tests passed).

  - **A super-admin** selects an organization in the organization list and lands on the **Edit Organization** screen. The list's name column links to `/organizations/{id}` today — a **dead route** (the same defect 10.20 records for the customer, inventory and user name links). **Point it at the edit route**, which resolves the organization half of that row.
  - **Anyone holding `MANAGE_ORGANIZATION`** clicks their own organization's name in the sidebar and lands on the same screen. The sidebar's static label (`organization_selector.dart`'s non-super-admin branch) becomes a link for those who hold the permission and stays plain text otherwise. A super-admin's sidebar control is a **dropdown**, not a name, so the two paths do not overlap.
  - **One screen for create and edit**, following 9.13's pattern: *"edit loads an item first, create starts empty → the initial values."* The port currently has two near-identical files (`create_organization_screen.dart`, `edit_organization_screen.dart`). Merge them into one `OrganizationScreen` with a nullable `organizationId`.
  - **The time zone field** is the shared `TimeZoneField`, with **the organization being edited as its own "organization default"**. On the create screen there is no organization yet, so the field is at full weight and defaults to the reader's effective zone.
  - **The list shows the zone** — a "Time Zone" column, so a super-admin can see which organizations are on which clock.
  - **The Flutter model gains the field**: `OrganizationResponse.timezone` (required), `CreateOrganizationRequest.timezone` (required), `UpdateOrganizationRequest.timezone` (required) — mirroring the server's DTOs.

- [x] **7.24** **Zone-aware report windows, and the inventory usage date.** **Done.** `StaffHoursReportRequest` gains required `timezone` (IANA zone naming the window; `startDate`/`endDate` remain local dates compared against `staffhours.date`, a zone-free `date` column — correct because a day is a day). `ReportService` validates unknown `timezone` / malformed dates as **400**. `InventoryDao.trackInventoryUsage` now sets `usage_date` to the **event's date in the event's own zone** (PK lookup of the event's `startsAt`/`timezone`; no join) instead of the server wall clock. Flutter `StaffHoursReportRequest`/`ReportService.getStaffHoursReport` updated to send `timezone` in the POST body (matching the backend route). Staff-hours aggregate and `usage_date` read-side behavior intentionally unchanged (aggregate → 8.2; `usage_date` remains write-only/all-time report).

- [x] **7.25** **Tests: the zone conversions.** **Done.** Resolution ladder covered (`time_zone_controller_test.dart`: override > detection > org zone > UTC, clearing override falls back). DST cases covered (`time_zone_service_test.dart`): Berlin/NY/Auckland DST offsets, nonexistent wall clock rejected, ambiguous flagged, and 23/25-hour DST days round-trip as query windows. Calendar day bucketing covered (`time_zone_conversion_test.dart`): 02:00 Berlin → previous day in New York and 23:00 Berlin → next day in Auckland (opposite directions). Event form request bodies asserted via stub adapter; edit form does **not** re-zone an event (load Europe/Berlin as America/New_York reader, save untouched → original instant + `Europe/Berlin` timezone). Zone picker pre-selects current value (`time_zone_field_test.dart`); field marks/de-emphasizes when equal to org default. Replaced naive-local tests remain deleted (not edited). Small `TimeZoneField` picker layout fix (scrollable list) to keep the picker usable/testable.

  - **The resolution ladder** — override beats detection, detection beats the organization's zone, the organization's zone beats UTC, and clearing the override falls back to detection.
  - **The DST cases, which are the whole reason the `timezone` package is here:** a Berlin summer event and its winter twin have **different offsets**; a wall clock that **does not exist** is rejected with a message; one that **happens twice** is flagged rather than silently resolved; and a **23-hour** and a **25-hour** day both round-trip through the query window.
  - **The calendar's day bucketing** — 02:00 Berlin is on the **previous** day in New York, and 23:00 Berlin is on the **next** day in Auckland. The two pull in opposite directions, which is what makes them worth two assertions: one example only ever proves half the mechanism.
  - **The event form's request body**, asserted on what goes **out** via `test/support/stub_adapter.dart`, the way 9.18 does.
  - **The edit form does not re-zone an event** — load a `Europe/Berlin` event as a reader in `America/New_York`, save without touching anything, and assert the request carries the original instant. **This guards the most damaging bug in the phase**, the one that is invisible because the form looks right and the save succeeds.
  - **The zone picker** — current value pre-selected, the organization's default marked, the field de-emphasized when the two agree.
  - **The tests this task replaces are deleted, not edited.** `models_test.dart`'s `naive-local event times` group asserts the old model. A test that still says "the local `DateTime`" is asserting the thing this phase removed.

- [x] **7.26** **Tests: the server's zone handling.** **Done.** `EventServiceTest` covers: `Pacific/Auckland` month window bounds (`2026-03-01`–`2026-03-31` → `2026-02-28T11:00Z`..`2026-03-31T11:00Z`, so `2026-02-28T23:00Z` is included and `2026-03-31T23:00Z` excluded); 25-hour fall-back day in `America/New_York` (`2026-11-01` window `[2026-11-01T04:00Z, 2026-11-02T05:00Z)`, containing both 01:30 occurrences with exclusive end); `timezone` absent uses the caller’s organization zone, and falls back to UTC when no organization zone resolves. Bad input throws `BadRequestException` (mapped to 400 by the app): naive `startsAt`, malformed `startsAt` (create/update), and unknown `timezone`. `MANAGE_ORGANIZATION` scoping is asserted at the service in `OrganizationServiceTest` (own org allowed, other org rejected). Fixed `Clock` drives invitation expiry in `InvitationServiceTest`. Malformed invitation `expiresAt` is validated at the route (`InvitationRoutes`) returning 400 with the envelope message; no route test harness exists in `backend/app`.

- [x] **7.27** **Regenerate `API.md`.**

  Regenerate from `API_TEMPLATE.md` and the Dokka output via `generateApiDocs` (`build.gradle.kts:23-87`) — **do not hand-edit**. The models change substantially: the event response and requests lose `date` / `time` and gain `startsAt` / `timezone`; the organization DTOs gain `timezone`; the invitation timestamps change shape.

  **The template's prose needs the new formats described**, not just the models regenerated: what `startsAt` looks like (ISO 8601 **with an offset**), what `timezone` is (an IANA zone id), what the `timezone` query parameter means, and that a naive value is a 400. A regenerated model list with prose still saying *"ISO 8601 date string (e.g., YYYY-MM-DD)"* is worse than the old file, because it looks current.

- [x] **7.28** **Reconcile the design doc, and write the progress log.**

  **The design doc's groundwork is already in place** — the decisions went in when the phase was planned. What this task does is correct them against what was actually built: a plan written before the work is a hypothesis, and a design doc written after it is a record.

  - Re-read each decision against the code. If the implementation diverged, the design doc gets the **implementation's** answer and the progress log records the divergence and its reason.
  - Update the *Time zone discrepancies* table's Fix column to point at the task that actually landed.
  - Add whatever the phase found that the survey missed — the survey was a reading of the source; the work is a reading of the running system.
  - Append a dated entry to `FLUTTER-CONVERT-NOTES.md` covering the phase: what each task did, the React app's state after 7.21 and 7.22, the `timezone` package's bundle-size cost against task 0.11's baseline, and anything that turned out differently from what these tasks say.

  **Do this as the last task of the phase, not as each task's commit.** The plan's convention is one progress entry per phase, and a phase this size earns one.

---

## Phase 8 — Reports

- [x] **8.1** Port `ReportList` (133 lines). `ReportListScreen` at `flutter_app/lib/screens/reports/report_list_screen.dart`, wired at `/reports`.
- [x] **8.2** Port `POST /api/reports/staff_hours` (date-range form → `List<StaffHoursReportResponse>`). **The window is a range of *days*, not a range of instants**, so it is interpreted in the reader's zone — 7.24 makes the endpoint zone-aware and the screen must send the zone with it. **The response is also wrong, in a way 7.24 found but deliberately did not fix:** `ReportDao.getStaffHoursReport` has **no `SUM()` and no `GROUP BY`**, so it returns one row per `staffhours` row rather than a total per user, despite the field being named `totalHoursWorked` — and nothing ever writes a `staffhours` row, so the report is always empty (10.13 records the same finding from the storage side). Fix the aggregate **here**, with the screen in front of it, rather than in the timezone phase.
- [x] **8.3** Port `GET /api/reports/inventory_usage` (→ `List<InventoryUsageReportResponse>`). Loads on screen open, same as the original.
- [x] **8.4** **Client-side org filtering is required.** `ReportService` receives no `AuthContext`, so `_GLOBAL`/org scoping is not applied server-side. Decide whether to filter in the UI or fix the backend — flagged, not silently replicated. **Decision:** cannot filter in the UI because neither report response carries an organization identifier, so the screen states the limitation explicitly and does not pretend to filter. Real scoping requires threading `AuthContext` through `ReportRoutes`/`ReportService`/`ReportDao` and joining report data to organizations — backend work tracked in 8.7–8.10.
- [x] **8.5** Both report endpoints return **unpaginated** lists over the whole org. Virtualize the tables. Rendered with `ListView.builder` in a bounded viewport.
- [x] **8.7** **Add `VIEW_REPORTS_GLOBAL` and wire report auth.** Add `VIEW_REPORTS_GLOBAL` to `backend/core/.../Permission.kt`, seed it for the roles that should hold it (`InitialSetup.kt`; SuperAdmin gets it via `Permission.entries`), mirror it in `flutter_app/lib/models/permissions.dart`, and gate `ReportRoutes` on `VIEW_REPORTS_ORGANIZATION || VIEW_REPORTS_GLOBAL` (same OR-gate pattern as other resources). This is backend work inside Phase 8, authorized as the follow-up to 8.4's scoping decision.
- [x] **8.8** **Thread `AuthContext` through reports and scope server-side.** In `ReportRoutes`, obtain `AuthContext` (`requireAuthContext()`/principal) and pass it to `ReportService`/`ReportDao`. **API requires `organizationId`:** staff hours takes it in `StaffHoursReportRequest`; inventory usage takes required `?organizationId=`. The service authorizes the requested org: if `organizationId != authContext.organizationId`, the caller must have `VIEW_REPORTS_GLOBAL`; otherwise any caller with report access may request their own org. The DAO always filters to that `organizationId`. **Staff hours:** scope rows to users in the requested organization via `UserOrganizations`. **Inventory usage:** scope via `InventoryItems.organizationId`. Keeps the existing date-window/timezone validation and the 8.2 aggregate (`SUM`/`GROUP BY`) intact.
- [x] **8.9** **Decide the report response shape for org visibility.** Current responses (`StaffHoursReportResponse`, `InventoryUsageReportResponse`) carry no organization identifier, which prevents client-side filtering and makes cross-org/global views ambiguous. **Decision:** option (a) — keep responses org-less and rely on 8.8's server scoping/authorization; do not add `organizationId`/`organizationName` to report DTOs. Reports are unambiguous because the API requires a specific `organizationId` and the Flutter UI must require a selected/effective organization before a report can be accessed/generated (see 8.10).
- [x] **8.10** **Flutter follow-up after server scoping.** `ReportListScreen` matches 8.9: removes the old server-limitation notice, requires an effective organization before accessing/generating reports, and passes `organizationId` to both report APIs. Global report viewers (`VIEW_REPORTS_GLOBAL`) are blocked until `selectedOrganizationProvider` is set (with an org picker) and the active organization is shown; org-scoped callers fall back to their own organization. Stale report data clears when the effective organization changes. Covered by tests in 8.11.
- [x] **8.11** **Report scoping tests.** Backend (`backend/service/.../report/ReportServiceTest.kt`, MockK): org-scoped callers cannot request another organization's staff hours or inventory usage; requesting another org requires `VIEW_REPORTS_GLOBAL`; global callers can request another org and the requested `organizationId` is passed to the DAO; invalid timezone/date are rejected. (GET `organizationId` required/400 is enforced in `ReportRoutes`; no `backend:app` route-test harness yet — 10.23. DAO filtering by requested org is exercised by the service/DAO contract; DB-level row isolation is not covered by a service mock test.) Flutter (`flutter_app/test/report_list_screen_test.dart`): selected-organization gating for global viewers, effective org shown, no limitation notice, and `organizationId` passed to inventory usage requests; staff-hours request shape is covered by `test/services_test.dart`.
- [x] **8.12** **Client-side report filtering tests (N/A under 8.9).** 8.9 chose org-less responses with server-side scoping only, and 8.10 requires a selected/effective organization in the UI rather than filtering mixed-org rows. No client-side org filtering logic is introduced; N/A.

---
