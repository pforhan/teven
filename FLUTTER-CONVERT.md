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
- One task per commit. Conventional commit prefix: `feat(flutter):`, `chore(flutter):`, `fix(flutter):`.
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
| Tests | Deferred until after cutover | Phase 12. Zero tests during the port |

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
- [ ] **1.14** Port `AuthService` (`src/api/AuthService.ts`): login, logout, getToken, getUserContext, getUserDetails, updateUserDetails.
- [ ] **1.15** Port `UserService`, `OrganizationService`, `CustomerService`, `InventoryService`.
- [ ] **1.16** Port `EventService` — note `GET /api/events` **ignores `sortBy`** server-side despite being documented. Do not rely on it.
- [ ] **1.17** Port `InvitationService`, `ReportService`, `RoleService`.
- [ ] **1.18** Set a small default `limit` on event queries. `EventResponse` nests rsvps + inventory + customer + organization with **no server-side compression** (`ktor-server-compression` is absent). Default to `limit: 10`; make it configurable per screen.
- [ ] **1.19** Write unit tests for `ApiClient`: envelope unwrapping, bare-string body, 204, non-JSON 200, 401.

---

## Phase 2 — Auth, permissions, routing

- [ ] **2.1** Port `AuthProvider` → `authControllerProvider` (`AsyncNotifier`). Reproduce the boot sequence from `AuthContext.tsx:29-59`: read token → fetch `/api/users/context` → set or clear.
- [ ] **2.2** Reproduce the single-flight 401 redirect. `AuthContext.tsx:16` uses a module-level `isRedirecting` flag; in Riverpod use a provider guard so concurrent 401s don't trigger repeated navigation.
- [ ] **2.3** Add `hasPermission(permission)` and `permissions` as a Riverpod provider derived from `authControllerProvider`, replacing `usePermissions()` (`AuthContext.tsx:80-92`).
- [ ] **2.4** Port `OrganizationProvider` (`src/OrganizationContext.tsx`): super-admin selected-org scope, persisted under key `selectedOrganization`.
- [ ] **2.5** Port `ProtectedRoute` → `go_router` route guard. **Preserve OR-semantics** for array permissions: `App.tsx:62` passes `[MANAGE_USERS_GLOBAL, MANAGE_USERS_ORGANIZATION]` and `ProtectedRoute.tsx:22-25` treats it as `.some()`.
- [ ] **2.6** Port all 21 routes from `App.tsx:38-68` with matching paths and param names (`eventId`, `customerId`, `inventoryId`, `organizationId`, `userId`).
- [ ] **2.7** Reproduce the unauthorized redirect target. `ProtectedRoute.tsx:27` sends users to `/events`; the catch-all `App.tsx:67` sends to `/` or `/login`.
- [ ] **2.8** Reproduce the branching behavior in `App.tsx:40-65`: when `userContext` is null **only** `/login` and `/register` exist. Otherwise the `/` subtree mounts.
- [ ] **2.9** Port the login screen (`src/Auth.tsx`, 71 lines). Note the current `width: '25rem'` card is desktop-tuned.
- [ ] **2.10** Port `AcceptInvitationPage` (176 lines). Must read the `?token=` query param **on web via path strategy** — this is the reason for task 0.9.
- [ ] **2.11** Port `AlreadyLoggedInError` (16 lines), rendered when `POST /api/invitations/accept` rejects a logged-in caller with 400.
- [ ] **2.12** Tests: permission OR-semantics, both unauthenticated route branches, 401 single-flight redirect.

---

## Phase 3 — Shell and navigation

The React shell is desktop-only (`navbar-expand-lg`). This phase establishes the responsive scaffold both targets share.

- [ ] **3.1** Port `MainLayout` (52 lines) to a `go_router` `ShellRoute`. Reproduce the `loading` → "Loading..." gate from `App.tsx:34-36`.
- [ ] **3.2** Define breakpoints: mobile `< 700`, tablet `700–1100`, desktop `> 1100`. Use `LayoutBuilder`, not device checks, so web resizing behaves.
- [ ] **3.3** Build the responsive chrome: `NavigationDrawer` on mobile, `NavigationRail` at tablet, extended rail or sidebar at desktop.
- [ ] **3.4** Reproduce the conditional nav items from `MainLayout.tsx:22-27` — each link gated on its `VIEW_*` permission. Six items, two of which are OR-gated (`VIEW_USERS_ORGANIZATION || VIEW_USERS_GLOBAL`, line 27).
- [ ] **3.5** Reproduce `isSuperAdmin` determination: `MainLayout.tsx:10` derives it from `hasPermission(VIEW_USERS_GLOBAL)`.
- [ ] **3.6** Port `OrganizationSelector` (64 lines) — super-admin org switcher in the chrome.
- [ ] **3.7** Port `QuickOrganizationPickerModal` (102 lines) — becomes a bottom sheet on mobile, dialog on desktop.
- [ ] **3.8** Build the non-super-admin variant of the org display (`MainLayout.tsx:36`): a static org name label, no picker.
- [ ] **3.9** Port the Profile nav link and Logout action.
- [ ] **3.10** Replace the Bootstrap `#f8f9fa` page background and `#3174ad` primary with a Flutter `ColorScheme`, so screens land close to the current visual weight. Record chosen hex values in a comment for traceability.
- [ ] **3.11** Replace icons. `react-icons/fa` gives ~6 glyphs; **the `bi bi-*` Bootstrap Icons were never installed** and currently render as empty `<i>` tags — do not attempt parity, use Material icons throughout.
- [ ] **3.12** Confirm the shell renders at all three breakpoints on web and on a device.

---

## Phase 4 — CRUD list screens

Covers `TableView.tsx` (90 lines) plus six list screens (~676 lines). **Redesign, not port.** Tables become responsive lists.

- [ ] **4.1** Build a shared `ResponsiveListView` replacing `TableView.tsx`: data-table layout at desktop, card layout at mobile.
- [ ] **4.2** Reproduce hover-revealed row actions. `TableView.tsx:17-18` exposes `onRowMouseEnter`/`onRowMouseLeave` purely so buttons appear on hover, across 6 call sites. On mobile use always-visible trailing actions or a long-press menu; **web may keep hover** behind a `kIsWeb` branch.
- [ ] **4.3** Reproduce hover tooltips (`OverlayTrigger` in 5 files). Same `kIsWeb` treatment; use `Semantics` labels for accessibility on native.
- [ ] **4.4** Port `CustomerList` (134 lines): search, paginated table, create/edit/delete.
- [ ] **4.5** Port `InventoryList` (144 lines). Note `GET /api/inventory/{id}` embeds an **unpaginated** `events` list — cap display client-side.
- [ ] **4.6** Port `OrganizationList` (134 lines), gated on `VIEW_ORGANIZATIONS_GLOBAL`.
- [ ] **4.7** Port `UserList` (264 lines) — the largest list screen. Includes role display and sort controls.
- [ ] **4.8** Port the 6 `window.confirm` delete flows as async dialogs (`CustomerList.tsx:60`, `InventoryList.tsx:60`, `OrganizationList.tsx:51`, `UserList.tsx:79,94`, plus events in Phase 7).
- [ ] **4.9** Port pagination controls against offset/limit. Per-endpoint default limits vary (10 or 1000) — verify each.
- [ ] **4.10** Port the search-debounce pattern. The React lists use plain `useState`; pick a deliberate debounce and note the interval.
- [ ] **4.11** Verify sort controls against each endpoint. **`sortBy` is silently ignored on `/api/events`**, and `GET /api/events` defaults `sortOrder` to `asc`.

---

## Phase 5 — Forms (non-event)

~640 lines across seven forms, plus `CreateInvitationForm` (182). ~70 raw HTML inputs become explicit `TextFormField`s.

- [ ] **5.1** Establish a form convention: `TextFormField` + `InputDecoration` + `Form` `GlobalKey`, validators replacing HTML `required`. **No form library** — the React code has none, so this is a free choice.
- [ ] **5.2** Port `CreateCustomerForm` (146 lines) and `EditCustomerForm` (139 lines).
- [ ] **5.3** Port `CreateInventoryForm` (140 lines) and `EditInventoryForm` (132 lines).
- [ ] **5.4** Port `CreateOrganizationForm` (59 lines) and `EditOrganizationForm` (86 lines).
- [ ] **5.5** Port `CreateUserForm` (168 lines) and `EditUserForm` (153 lines).
- [ ] **5.6** Port `Profile` (78 lines) and `EditProfileForm` (87 lines) to `/profile`.
- [ ] **5.7** Port `CreateInvitationForm` (182 lines).
- [ ] **5.8** Port `InventoryAssociationEditor` (143 lines) — shared component, largest in `common/`.
- [ ] **5.9** Replace HTML input types with Flutter pickers: `type="date"` → `showDatePicker`, `type="time"` → `showTimePicker`, `type="number"` → numeric `TextFormField` with `FilteringTextInputFormatter`, `type="email"` → `RegExp` validator.
- [ ] **5.10** **Fix the invite-link bug surface.** `UserList.tsx:157` and `CreateInvitationForm.tsx:74` build `${window.location.origin}/register?token=`. Derive the origin from `Uri.base` — no native path needed, since invitees receive a link they open in a browser. Ensure the link is not token-dependent on any in-app state.
- [ ] **5.11** Two-column `col-lg-*` layouts become single-column scrolls on mobile; modals become bottom sheets. Apply to all seven forms.
- [ ] **5.12** Verify `EditUserForm` gating. `App.tsx:63` gates it on `MANAGE_USERS_GLOBAL` only, while `App.tsx:62` gates create on either global or org — this asymmetry is likely a bug; confirm intent before porting.

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
- [ ] **7.6** Port `EventDetails` (277 lines), including the two `window.confirm` flows and the `RsvpWidget` (72 lines) — drop-in RSVP posting `availability: "available" | "unavailable"` as a **free-form string**, not an enum.
- [ ] **7.7** Port `OtherEventsPanel` (97 lines).
- [ ] **7.8** Replace `moment` with `intl` + `DateTime`. The existing parsing is fragile — `new Date(event.date + 'T' + event.time)` at `EventCalendar.tsx:230` — so use explicit `DateTime` construction.
- [ ] **7.9** Handle timezone-naive timestamps. The API returns `"YYYY-MM-DD"` / `"HH:MM:SS"` strings with **no timezone**. Do not silently re-interpret as UTC; keep naive local semantics to match current behavior, and note this as a known limitation.
- [ ] **7.10** Route `/events/rsvps/requested` into the UI. It is **undocumented in `API.md`** but real (`EventRoutes.kt:118`). Confirm whether the React app uses it — if not, decide whether to expose it.

---

## Phase 8 — Reports

- [ ] **8.1** Port `ReportList` (133 lines).
- [ ] **8.2** Port `POST /api/reports/staff_hours` (date-range form → `List<StaffHoursReportResponse>`).
- [ ] **8.3** Port `GET /api/reports/inventory_usage` (→ `List<InventoryUsageReportResponse>`).
- [ ] **8.4** **Client-side org filtering is required.** `ReportService` receives no `AuthContext`, so `_GLOBAL`/org scoping is not applied server-side. Decide whether to filter in the UI or fix the backend — flagged, not silently replicated.
- [ ] **8.5** Both report endpoints return **unpaginated** lists over the whole org. Virtualize the tables.

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

---

## Phase 10 — Cutover and cleanup

Once the Flutter web app is verified working locally against the real backend. The trigger for deleting `frontend/` is internal confidence, not a deployment.

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

  **Already covered elsewhere, do not duplicate:** `Dockerfile:32-47` (the `frontend-react` builder stage, including its `COPY frontend/src` and `COPY frontend/public` lines) disappears with 10.1. Those are functional build instructions, not comments, so they are not this task's concern. `FLUTTER-CONVERT.md` itself is *expected* to reference `frontend/` paths throughout — it is a historical record and keeps them deliberately; exclude it.

---

## Phase 11 — Native packaging (deferred, not required for cutover)

Additive: the web app keeps working unchanged. Only do this once web is stable and signing is arranged.

- [ ] **11.1** Add iOS and Android platforms to `flutter_app/` (`flutter create --platforms=android,ios .`). Set `applicationId` to `alphainterplanetary.teven` in `android/app/build.gradle.kts` and the matching bundle identifier in the iOS project, matching the web manifest `id` from task 0.7.
- [ ] **11.2** Set up the API base URL for native via `--dart-define=API_BASE_URL=<host>`, since relative URLs cannot work off-browser. Revisit task 0.6. A reachable host value is a prerequisite for native work and is out of this plan's control.
- [ ] **11.3** Revisit token storage for native. `flutter_secure_storage` works on both platforms already, so this may be a no-op — verify rather than assume.
- [ ] **11.4** Re-test every screen for touch: hover-revealed actions (task 4.2) currently assume a pointer, and dialogs become bottom sheets (tasks 3.7, 5.11).
- [ ] **11.5** Add deep-link handling so `/register?token=...` opens the app when installed, falling back to the web link otherwise (builds on task 5.10).
- [ ] **11.6** Arrange code signing / store distribution.
- [ ] **11.7** **Optional:** a custom week view, restoring the calendar capability dropped in task 7.1. `table_calendar` does not support it, so this means a hand-built grid. Attempt only if users ask for it.

---

## Phase 12 — Tests (deferred, post-conversion)

The React app had **zero** tests, and none are written during the port by decision. Note the consequence: task 10.3 deletes the only executable specification of current behavior, so Phase 12 is what protects against regressions from here on.

- [ ] **12.1** Decide the testing scope now that the app is live and its real failure modes are known.
- [ ] **12.2** Integration tests for login → context fetch → authenticated call, per `AGENTS.md` expectations.
- [ ] **12.3** Unit tests for `ApiClient` (sketched in task 1.19 — worth pulling forward if any defensive-parsing bug turns up during the port).
- [ ] **12.4** Widget tests for the permission guard and the responsive list.
- [ ] **12.5** Golden tests for the calendar month grid and the event forms.
- [ ] **12.6** Ensure the suite runs on both VM and Chrome.

---

## Backend discrepancies found during exploration

Documented here so task 10.6 can address them. **Do not fix these during the port** — parity first, corrections after.

| Discrepancy | Evidence |
|---|---|
| `POST /api/users/register` documented, **does not exist** | `API.md:57` vs `app/user/UserRoutes.kt:28` |
| Staff endpoints documented, **do not exist** | `API.md:343-351`; staffing is via `staffInvites` on event create/update |
| `GET /api/events/rsvps/requested` **undocumented** but real | `app/event/EventRoutes.kt:118` |
| Role-assignment path is wrong | `API.md:632` says `/api/users/{userId}/roles`; actual is `/api/users/{user_id}/roles/{role_id}` (`app/role/RoleRoutes.kt:86`) |
| `sortBy` ignored on `GET /api/events` | `app/event/EventRoutes.kt:80` does not read it |
| Geo fields absent from docs | `latitude`/`longitude`/`formattedAddress` exist on customer/event DTOs but not in `API.md` |
| Geo service is dead code | `service/geo/GeoService.kt:9-19` falls through to a mock; no `GeoRoutes` file exists; no PostGIS |
| `RsvpRequest.availability` is a free-form `String` | No enum validation server-side |
| Permission failures return bare strings, not the envelope | `auth/AuthorizationPlugin.kt:24,31` (note: the file is `AuthorizationPlugin.kt`, not `PermissionInterceptor.kt`) |
| **11 success responses carry a bare-string `data`** instead of a DTO | 5 × `success("... with ID N updated")`, 4 × `success("OK")`, 1 × `success("Created invitation")` |
| **5 deletes return `204 NoContent`** with no envelope, though React types claim `StatusResponse` | customer, inventory, organization, event, role route files |

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

**Verification.** Analyser and formatter are clean and the web build succeeds, but per the plan's decision to defer tests, no test files were kept. Behaviour was checked with a temporary probe covering: failure envelope with `data: {}` (decode provably not invoked), success envelope, list decoding into `EventResponse`, `PaginatedResponse` with nested items, and the naive-local `startAt`/`endAt` arithmetic. All five passed; the probe was then deleted. Task 1.19 is still the first durable test coverage.

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

**Verified against a throwaway `HttpServer` serving the backend's real response shapes**, not mocks: normal envelope, `failure()` envelope with `data: {}` (message and details both survive), 401 inside an envelope, 403 bare string, `index.html` at 200, 204 with no body, 2xx bare-string acknowledgement, and connection-refused. All 8 passed. Per the plan's deferral of tests to Phase 12, the file was then deleted — **task 1.19 remains the first durable coverage** and can lift this probe nearly verbatim.

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
