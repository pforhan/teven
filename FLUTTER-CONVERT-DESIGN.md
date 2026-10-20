# Flutter Conversion — Planning and Design

The decisions behind the Flutter port: what was chosen and what it cost, which React component maps to which phase, and what the backend actually does where the documentation says otherwise. None of it is a task.

- **The checklist is [`FLUTTER-CONVERT.md`](FLUTTER-CONVERT.md)** — the ground rules and every task, with its checkbox.
- **Implementation notes are [`FLUTTER-CONVERT-NOTES.md`](FLUTTER-CONVERT-NOTES.md)** — the dated progress log, one entry per completed phase.

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

Every React component maps to at least one task in the checklist (`FLUTTER-CONVERT.md`). Nothing is silently dropped.

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

## Backend discrepancies found during exploration

Documented here so task 10.6 can address them. **Do not fix these during the port** — parity first, corrections after.

**Every row now has an owning task** in the "Fix" column. A row with no task was documentation nobody would act on, which is how five real defects sat here unowned for the first three phases. If you find a new one during the port, give it a task in the same change — otherwise add it to this table and note in the progress log (`FLUTTER-CONVERT-NOTES.md`) that it is unowned.

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
| **The inventory, organization and user name links are dead, as the customer one is** | `InventoryList.tsx:78` → `/inventory/{id}`, `OrganizationList.tsx:80` → `/organizations/{id}`, `UserList.tsx:123` → `/users/{id}`; `App.tsx` declares none of them. Same defect as the row above, in three more screens | **10.20** (all four screens, or none) |
| **Seeded users cannot log in — `TestDataProvider` writes a plaintext password** | `TestDataProvider.kt` set `it[passwordHash] = "password"` and the column is `users.password`. `BCrypt.checkpw("password", "password")` throws `IllegalArgumentException: Invalid salt version`, which `AuthServiceImpl.loginUser` did not catch — so **every seeded login answered HTTP 500 with a stack trace**, not 401. Found during task 3.12's verification attempt; the seeded `alice`/`bob`/`charlie`/`diana` accounts were unreachable until the seed stored a real hash | **10.18** ✅ |
