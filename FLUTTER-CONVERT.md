# Flutter Conversion — Task Checklist

Rewrite of `frontend/` (React + Vite + Bootstrap SPA) into a Flutter app, **web first**.

The React app stays in place and fully functional until the Flutter app is verified working. Each task below is intended to be **one commit**. Work top to bottom; do not reorder without updating this file.

Responsive layout is in scope throughout, because the site will be viewed in mobile browsers. What is *not* in scope for Phases 0–10 is native app packaging — that is Phase 11.

## The four files of this plan

This file is the **checklist**: the ground rules, and every task with its checkbox. `-COMPLETED` holds completed phases. The other two hold everything that is not a task:

| File | Holds | Read it when |
|---|---|---|
| **`FLUTTER-CONVERT.md`** (this file) | The ground rules and every incomplete phase and task, with checkboxes | Working an task, or deciding what is next |
| **`FLUTTER-CONVERT-COMPLETED.md`** | Fully completed phases of work. | Looking up decisions, history, and timing. |
| **[`FLUTTER-CONVERT-DESIGN.md`](FLUTTER-CONVERT-DESIGN.md)** | Planning and design — the resolved decisions, the parity matrix, and the survey of backend discrepancies | Wanting to know *why* the plan is shaped this way, or what the server actually does |
| **[`FLUTTER-CONVERT-NOTES.md`](FLUTTER-CONVERT-NOTES.md)** | Implementation notes — the dated progress log, one entry per completed phase | Looking for what actually happened, and how it was verified |

Task numbers are stable across all three files. Where a task below says "see the progress log", it means `FLUTTER-CONVERT-NOTES.md`; where it says "the discrepancies below", it means the table in `FLUTTER-CONVERT-DESIGN.md`.

---

## Ground rules

- **Do not modify or delete `frontend/`.** It remains the live app until Phase 10. **One exception:** task 7.22, the single React-client patch that restores the event screens broken by 7.21.
- **Do not modify the backend** during Phases 0–8, **except for the timezone work in Phase 7A** (7.13–7.21, 7.24). That work changes the event and invitation wire formats, which breaks the React app's event screens. The break is a known, accepted cost — see *Phase 7A* below. Everything else in the backend stays frozen until Phases 9–10, where it is called out explicitly (9.9, 10.6, 10.7).
- **Do not plan for deployment.** Docker is the deployment mechanism and it is sufficient; do not add hosting, TLS, proxy, or CI/CD work to any task. Verification is local. The single known gap is noted under *The one deployment consideration* in `FLUTTER-CONVERT-DESIGN.md`.
- Every task must leave the repo in a **buildable** state (`teven verify` clean).
- One task per commit. Commit message conventions live in `AGENTS.md`; there is no commit-message tooling in this repo, and a conventional-commit prefix is optional rather than required.
- If completing a task leaves a whole phase completed (all tasks checked) then move all the completed phase to `FLUTTER-CONVERT-COMPLETED.md`
- 2-space indentation, per `AGENTS.md`.
- Run `dart format .` and `flutter analyze` before every commit in `flutter_app/`.
- New Flutter packages must be justified in the commit message.
- **Generated code is not committed.** `*.freezed.dart` and `*.g.dart` are gitignored (`flutter_app/.gitignore`), so `dart run build_runner build` is a required setup step after every clone, not an optional one. This is a deliberate departure from the freezed default of committing generated output.

---

## Phase 10 — Cutover and cleanup

Once the Flutter web app is verified working locally against the real backend. The trigger for deleting `frontend/` is internal confidence, not a deployment.

- [x] **10.0** Strip out comments referencing conversion tasks or filename/linenumber combos.  If dart has javadoc-like capabilities for linking use those, otherwise use File.member type references.
- [x] **10.2** Verify the Flutter build end-to-end against the real backend via `docker compose up --build`: login, org switch, and one full create/read/update/delete pass per resource.
- [x] **10.3** **Delete `frontend/`.** The last commit touching it is the deletion commit.
- [x] **10.1** Remove/inline `WEB_SOURCE` in `Dockerfile` and elsewhere -- replacing it with `flutter` the only remaining frontend.  No longer needs indirection.
- [x] **10.4** Remove React deps, ESLint config, and node tooling references from the repo.
- [x] **10.5** Update `AGENTS.md`, `README.md`, and `BACKEND-DESIGN.md` for Flutter conventions.
- [x] **10.6** Update `API.md` for the drift found during the port (the table in `FLUTTER-CONVERT-DESIGN.md`) — regenerate rather than hand-edit, per `build.gradle.kts:23-87`.
- [x] **10.7** Remove dead `backend/service/geo/` code if the Flutter app does client-side geocoding, or wire up `GeoRoutes` if it does. Deleted the unused backend geo service/provider/mock, DI wiring, and `GeoLocation` model; Flutter has no client-side geocoding and launches maps from address text via `url_launcher`.
- [x] **10.8** **Strip dangling `frontend/` references from `flutter_app/lib/`.** 10.3 deletes the directory these comments point at, leaving paths like ``frontend/src/api/apiClient.ts`` that resolve to nothing — a comment that looks like a citation a reader could follow but cannot. 10.4 covers React *dependencies* and node tooling; it does not reach prose in doc comments.

   Most of the current occurrences explain *why* something is shaped the way it is, and that reasoning is the durable value. Reword to keep the explanation and drop the path, file, or source type, e.g. rather than "Replaces `apiClient` in `frontend/src/api/apiClient.ts`", say "Replaces a hand-rolled `apiClient`, which wrapped `fetch`".

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

- [x] **10.9** **Make the server's error responses conform to the envelope, then remove the client's compensating branches.** The client currently carries permanent defensive code for a server inconsistency that is a two-line fix. `AuthorizationPlugin.kt:24,31` responds with a bare string while every other route uses `failure(...)`; the Flutter client therefore special-cases bare strings in `ApiClient._tryDecode` / `_NonJsonBody`.

  **Ordering is load-bearing.** This must come *after* 10.3. Until `frontend/` is deleted both pipelines are live, and the React `apiClient.ts` unwraps `data` unconditionally — changing these responses now breaks the React app. That is the real reason the Phase 0–8 "do not modify the backend" rule exists, and it is why this is not a Phase 1 task.

  Two commits:
  1. `AuthorizationPlugin.kt` — replace both bare-string `call.respond` calls with `failure(...)`, matching every other error path.
  2. Delete the now-dead branches in `ApiClient`: `_NonJsonBody`, the bare-string path in `_unwrap`, and the bare-string branch in `_errorFor`. Kept separate so it is clear the defensive code was **temporary**, not left behind by oversight.

  **Keep the content-type sniff even after this.** Task 1.12's `index.html`-at-HTTP-200 case is not a server bug — it is a structural consequence of serving the SPA from the same origin as the API (`Routing.kt:56`), and will outlive any change to error formatting. Only the *bare-string* handling is contingent.

  Verify after: a 403 from a permission failure arrives as a normal envelope, and the client still throws `ApiRequestException` carrying the server's message.

- [x] **10.10** **Give the remaining non-conforming *success* responses a real DTO.** Distinct from 10.9, which covers **error** responses only. These are successes whose envelope is intact but whose `data` is a bare string, so callers get `String` where they expect an object. Counted from the source, there are **11 call sites**:

  | Pattern | Sites |
  |---|---|
  | `success("... with ID N updated")` | customer, inventory, organization, event, role (5) |
  | `success("OK")` | role ×2, inventory, event (4) |
  | `success("Created invitation")` | invitation ×1 |
  | 204 `NoContent` with no envelope at all | customer, inventory, organization, event, role (5) |

  The second and third rows are the ones that actually cost the client something: `PUT /api/events/{id}` returning `"Event with ID N updated"` is why task 6.9 exists, and `StatusResponse` in `common.dart` is near-vestigial because deletes return 204 rather than the `{status, message}` shape the React types claimed.

  **This is a bigger change than 10.9 and should be scoped deliberately.** Options, in increasing order of effort: introduce a `MessageDto { message: String }` and wrap; return the updated entity instead of a string; or leave as-is and document. `success("OK")` in particular carries no information — `data: {}` or `204` would be equivalent. Whichever is chosen, the client-side fallout is deleting `ResponseBody.bareString`, `ApiClient.deleteWithBody`, and possibly `StatusResponse`, so that task must land too.

  Verify after: every `success()` response carries a typed payload, and `grep -rn 'success("' backend/app` returns nothing.

- [x] **10.11** **Implement `sortBy` on `GET /api/events`, or delete the parameter.** Confirmed dead: `EventRoutes.kt` never reads `sortBy` (zero occurrences) and neither does `EventDao`. Every other list DAO honours it — `CustomerDao` switches on `"name"` and falls back to id — so events are the outlier. `API.md` documents it as working.

  `sortOrder` **does** work and defaults to `asc`, which is the more surprising half: callers expecting "newest first" get the earliest event unless they pass `sortOrder=desc`. Worth fixing alongside, or at minimum correcting in `API.md`.

  Task 4.11 tells the UI to verify sort controls; this is the task that makes that verification pass. Implemented `sortBy` for events (`title`, `date`/`startsAt`, defaulting to start time) through route/service/DAO, updated `EventServiceTest`, and clarified events query params in `API_TEMPLATE.md` and Flutter client comments.

- [x] **10.12** **Soft-delete (deactivate) users, with super-admin visibility and restore.** **Decision revised: soft delete, not hard delete.** The button exists in the React UI (`UserList.tsx:81`) and has never worked. The goal is to let super-admins see deactivated users and restore them, without losing the history attached to a user account.

  **The load-bearing invariant (the reason 10.12 originally leaned hard-delete): a deactivated user must not be able to authenticate or act.** Soft delete is acceptable only if "deleted" is enforced everywhere an identity is treated as active:
  - `loginUser` / `UserDao.getUserByUsername` (and any email lookup used for auth) must reject deactivated users (same outcome as invalid credentials / not found).
  - Existing sessions must not keep working: `GET /api/users/context`, `getUserById`/auth resolution, and any path that loads the principal must treat a deactivated user as unauthorized/disabled. Centralize an "active user" predicate so login, context, and default reads agree.
  - Keep the 10.12 guard rails: reject **self-deactivation** server-side, prevent deactivating (and consider restoring into) the **last** super-admin, and enforce org scoping (mirror the permission model on `PUT /api/users/{id}`). See the permission-model note below on `MANAGE_USERS_GLOBAL` vs `MANAGE_USERS_ORGANIZATION`.

  **Schema.** Add `deletedAt` (nullable `timestamp with time zone`) to `Users` (`backend/data/.../user/Users.kt`), and thread it through `core.user.User` / `api.model.user.UserResponse` / `UserDao.toUser` / `UserServiceImpl.toUserResponse` as needed so the client can distinguish active vs deactivated users. `SchemaUtils.create` is create-if-missing and never alters existing tables, so this requires dropping and recreating the dev database (no migration tooling); confirm nothing of value lives there.

  **Do not cascade-delete user dependents.** The point of soft delete is to keep the user row and its history: `rsvps`, `staffhours`, `userroles`, `userorganizations`, and `invitations.used_by_user_id` can remain pointing at the user. (Verified against the running dev DB, the five FKs onto `users(id)` are `ON DELETE RESTRICT`; under soft delete no `DELETE FROM users` is issued, so leave them `RESTRICT` rather than adding `CASCADE`. `Invitations.usedByUserId` stays intact — unlike the hard-delete plan, there is no need to null it, because the account row survives for audit/history.) Treat the FK `onDelete` cascades from the earlier hard-delete draft as unnecessary here; `StaffDetails`’ declared `CASCADE` is on a table not currently in `SchemaUtils.create`/the DB (see 10.13) and is a separate issue.

  **Reads and visibility.** Default user-management reads must exclude deactivated users, while preserving historical references elsewhere:
  - `UserDao.getUsers`, `getAllUsers`, `getUsersByOrganization`, and management/detail lookups should exclude deactivated rows by default and keep `total` consistent with the filter (same pattern 10.19 requires for customers). Put the filter in one helper so a new read path cannot forget it.
  - Super-admins need to list and inspect deactivated users: add an explicit query/filter (e.g. `status=active|deactivated|all` or `includeDeleted`) on the list endpoint, gated appropriately.
  - **Do not globally erase historical joins.** Event rosters/RSVPs, staff-hours reports, invitation attribution, etc. may still need to resolve a deactivated user’s display/name for history; decide per path whether "exclude from management lists" vs "unresolvable" is correct, rather than filtering deactivated users out of every join.
  - Decide what `GET /api/users/{id}` returns for a deactivated user and whether edits/reactivation are allowed (a deactivated account should be immutable except restore/reactivation).

  **Uniqueness (`username`, `email`).** Both are unique indexes today. A soft-deleted row would block reuse and can complicate re-invites/restores. Decide explicitly: reserve the values, clear/munge them on deactivation, or enforce uniqueness only for active users (e.g. a partial unique index where `deleted_at IS NULL`, if supported cleanly in the Exposed/DDL story). Whichever is chosen, restore must not violate it.

  **Routes / API.** `UserRoutes` currently has no delete. Add `DELETE /api/users/{id}` to **deactivate** (idempotent) and a **restore** action (e.g. `POST /api/users/{id}/restore`), both server-side guarded and scoped; add the list filter for super-admins. Document in `API.md` (regenerated per 10.6) and cover the route-layer validation/permission behavior (10.23 notes the app lacks a route-test harness). Keep the permission-model hole in mind: `isSuperAdmin` derives from `VIEW_USERS_GLOBAL` while the existing delete affordance is gated on `MANAGE_USERS_GLOBAL || MANAGE_USERS_ORGANIZATION` — resolve this consistently (gate the route on `VIEW_USERS_GLOBAL`, or keep an explicit last-super-admin backstop) so an org-scoped manager cannot deactivate the last super-admin.

  **Flutter.** `UserResponse`/service/provider gain the deactivated marker and restore call. In the user list (`flutter_app/lib/screens/users/user_list_screen.dart`, `providers/user_list.dart`), super-admins can view active/deactivated (and/or all), see status, and **restore** a deactivated user; the destructive flow becomes "deactivate" (not permanent removal). The current client asserts the delete 404s (`user_list_screen_test.dart`), so update it to the new contract. Non-super-admins continue to see only active users.

  **Similar treatment for other CRUD entities (review, don’t assume).** Apply the same "is this a historical reference or an identity/ephemeral record?" test elsewhere, and prefer preserving history over destructive deletes where references matter:
  - **Customers:** already planned as soft delete in **10.19** (events reference them); keep 10.12/10.19 consistent (customer = reference, user = identity that must stop authenticating but whose history can be retained).
  - **Inventory items:** hard-deleted today, but referenced by event-inventory associations / usage history (`InventoryItems`, `EventInventory`, `InventoryUsage`); likely warrant soft delete so past events/usage remain intact. Review before implementing/changing.
  - **Events:** core records with RSVPs, event-inventory, and reporting impact; hard delete destroys history. Consider soft delete/cancel semantics (product decision) rather than irreversible removal.
  - **Organizations:** tenant roots; deletion is highly destructive. Consider disable/soft delete rather than hard delete.
  - **Invitations:** largely ephemeral/revocable tokens (with `usedByUserId` audit); hard delete/revocation may be acceptable — confirm intent.
  - **Roles:** referenced by user roles/invitations and include seeded/system roles; treat as special (restrict/forbid deletion of in-use or system roles) rather than a plain soft-delete case.

  Verify after: a deactivated user cannot log in or use an existing session, disappears from default user-management lists but remains resolvable where history requires, and a super-admin can list and restore them; `./teven verify-backend` and `./teven verify` pass.

- [x] **10.13** **Restore the staff-details feature: create `staff_details`, store `skills` as a proper list, and fix the silent-discard path.** **Decision made: fix it, do not delete it.** Staff profiles are a real feature the app presents, so the table and its read/write path get built properly rather than removed.

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

- [x] **10.14** **Delete the dead `POST /api/events/{id}/join` route and `EventService.joinEvent` from the React app.** **Confirmed leftover from before the RSVP system** — this is settled, not an open question.

  The git history is unambiguous, and all four commits land on **2025-09-14**:

  | Commit | Message |
  |---|---|
  | `f2ca476` | wip users can join events |
  | `13d3ef6` | view joined users on an event |
  | `a6b28e7` | use existing rsvps class |
  | `fdaf271` | **remove the join route, use only the rsvp route** |

  So `join` was built first, then RSVP was introduced alongside it, then `join` was deleted the same afternoon. In `a6b28e7` both routes coexist — `post("{event_id}/rsvp")` at line 142 and `post("{event_id}/join")` at line 161 — and `fdaf271` removes `join`, changing 4 files and −69 lines.

  **Status:** `POST /api/events/{id}/join` is not present in the backend routes, and no `joinEvent` service method remains in backend or Flutter sources. `frontend/` was removed in 10.3, so deleting `joinEvent` from `frontend/src/api/EventService.ts` is satisfied; a repo search confirms no remaining `joinEvent` or `/join` references in active code. A stale Flutter `EventService` note about the omitted join method was removed.

  **The permission is vestigial as a server gate, but retained for now.** `ASSIGN_TO_EVENTS_SELF` is still defined in `Permission.kt`, seeded for Organizer/Staff, and used by the Flutter event details screen and its tests to gate self-RSVP controls (the RSVP route has no server-side permission check). It was **not** removed in this task; 10.16 must decide whether to keep it for client-side RSVP gating, enforce it on the server, or replace it.

- [x] **10.15** **Give list endpoints a real default `limit` instead of returning every row.** Every DAO does `limit?.let { query.limit(it) }` — `CustomerDao.kt:73`, `EventDao.kt:180`, plus `UserDao`, `InventoryDao`, `OrganizationDao`. Omitting `limit` therefore applies **no cap**, and the `limit: 0` echoed in the response is cosmetic. An unfiltered `GET /api/customers` returns the entire customer table.

  **Decision (apply this):** never make “unbounded” the accidental default.
  - **Default:** apply a server-side default `limit` of **25** when omitted for paginated list endpoints (customers, events, users, inventory, organizations, and any similar list routes/DAOs).
  - **Max caps:** enforce a server-side maximum of **100** for general list requests. For events queries that are explicitly bounded by a date/range filter (e.g. calendar views), allow a higher explicit `limit` up to **500** so a dense range can still load in one request; do **not** add an “unlimited” mode.
  - **Response shape:** when `limit` is omitted, the response must echo the **applied** limit (e.g. `25`), not `0`. `total` remains the unpaginated total count so pagination UI continues to work.
  - **Client behavior:** callers that legitimately need “all items in view” (such as a calendar range query) must pass an explicit high `limit` together with a bounding filter, not rely on omission. Review/remove client-side defaults that become redundant once the server enforces defaults (note: events currently default to `limit: 10` on the client in some paths).

  **Verify after:** omitting `limit` never returns an entire unbounded table; responses report the applied limit; range-bounded calendar/event views still load fully within the allowed cap when requested explicitly.

- [x] **10.16** **Close the permission gap between server and Flutter client.** `backend/core/src/main/kotlin/alphainterplanetary/teven/core/security/Permission.kt` defines 35 permissions; `flutter_app/lib/models/permissions.dart` currently defines 21. The 14 not yet named in Flutter are `CAN_ASSIGN_SUPERADMIN`, `CAN_ASSIGN_ORGANIZER`, `CAN_ASSIGN_STAFF`, `MANAGE_USERS_SELF`, `VIEW_ROLES_ORGANIZATION`, `MANAGE_ROLES_ORGANIZATION`, `ASSIGN_ROLES_ORGANIZATION`, `VIEW_ROLES_GLOBAL`, `MANAGE_ROLES_GLOBAL`, `ASSIGN_ROLES_GLOBAL`, `VIEW_CUSTOMERS_GLOBAL`, `VIEW_EVENTS_GLOBAL`, `ASSIGN_STAFF_TO_EVENTS_ORGANIZATION`, and `VIEW_INVENTORY_GLOBAL`.

  **Decision/principle:** keep server permissions that are wired up. If the completed app would end up using a wired permission, add it to the Flutter client (enum/constants and any relevant guards/UI) so the client can represent and gate that capability. If a wired permission will not be used by the completed app, it is acceptable to leave it out of Flutter for now but record why; if a permission is not actually wired/enforced/needed, prefer removing or repurposing it server-side rather than carrying dead policy surface.

  **Implemented (per direction: move clearly wired server permissions into Flutter; remove role view/manage stuff everywhere, no anticipated role management in webapp).**
  - **Added to Flutter:** `CAN_ASSIGN_SUPERADMIN`, `CAN_ASSIGN_ORGANIZER`, `CAN_ASSIGN_STAFF`, `VIEW_EVENTS_GLOBAL`, `VIEW_INVENTORY_GLOBAL` (in addition to existing `VIEW_CUSTOMERS_GLOBAL`). `MANAGE_USERS_SELF` and `ASSIGN_STAFF_TO_EVENTS_ORGANIZATION` remain server-side only for now (seeded/defined but not clearly wired/enforced in current routes/services/UI).
  - **Removed role view/manage permissions from server:** `VIEW_ROLES_ORGANIZATION`, `MANAGE_ROLES_ORGANIZATION`, `ASSIGN_ROLES_ORGANIZATION`, `VIEW_ROLES_GLOBAL`, `MANAGE_ROLES_GLOBAL`, `ASSIGN_ROLES_GLOBAL`.
  - **Removed role-management webapp/API surfaces:** role-definition CRUD endpoints and user-role assign/remove endpoints (`POST/PUT/DELETE /api/roles`, `/api/users/{id}/roles` assign/remove). Kept read-only `GET /api/roles` and `GET /api/roles/{id}` (ungated listing/lookup for selection flows). Role definitions remain seed-managed; internal role read/assign/remove service/DAO methods used by user/invitation flows remain.
  - **Cleanup:** removed `UpdateRoleRequest`, removed role-definition update/delete from core role service/DAO, updated API docs/tests/comments to match. `ASSIGN_TO_EVENTS_SELF` remains as previously noted (client-gated RSVP; server RSVP route does not enforce it).

  **10.14 note (`ASSIGN_TO_EVENTS_SELF`):** retained in client/server for now and used by the Flutter event-details screen to gate self-RSVP, but the RSVP route performs no server-side permission check. Decide whether to keep it as a client-only gate, enforce it on `POST /api/events/{id}/rsvp`, or replace it.

- [x] **10.17** **Replace free-form RSVP `availability` with a validated enum.** **Decision:** use an enum (not a free-form `String`). The current wire/app values are `"available"`, `"unavailable"`, and server-initiated `"requested"`; `Rsvps.availability` is `varchar(50)` with no validation, so typos are stored silently.

  **Canonical wire values (iCalendar `PARTSTAT`-aligned):** `accepted`, `declined`, `tentative`, `needs_action`.
  - `available` → `accepted` (yes/attending)
  - `unavailable` → `declined` (no/not attending)
  - `requested` → `needs_action` (invited, awaiting response / no response yet)
  - `tentative` → maybe (**in scope**: add to server enum/handling and to the Flutter RSVP UI as a selectable response)

  **Important:** `requested`/`needs_action` is currently a real stored, server-initiated state used in code paths (staff invitations insert it, event updates clear/reset requested RSVPs, and requested-RSVP queries/filtering depend on it), not merely the absence of a row. A null/absent column is likely **not** sufficient without changing behavior; verify this before choosing the representation.

  **Work items:** check `SELECT DISTINCT availability FROM rsvps` and audit derived behavior/usages (DAO/service/routes/UI/constants) before migrating; decide migration/compatibility strategy for existing stored values and any client compatibility needed during rollout; enforce the enum server-side (request/response/storage as appropriate), update Flutter `RsvpAvailability`/models and the RSVP UI to include **tentative**, and handle display/mapping for existing/current states as needed. Keep API docs/client types in sync.

  **Implemented (green field).** Server RSVP availability now uses canonical PARTSTAT-aligned values and validates writes in `EventService.rsvpToEvent` (`accepted|declined|tentative|needs_action`); invalid values are rejected as bad requests. Staff-invite insert/update/reset paths and requested-RSVP queries now use `needs_action` as the stored invited/awaiting-response state. Flutter `RsvpAvailability`/models and RSVP flows were updated to the canonical values, added **Tentative/Maybe** responses (pending RSVP widget, event list, event details), and treat clearing a response as posting `needs_action`. Calendar pending markers and event-details roster/grouping now reflect `needs_action`/`accepted`/`tentative`/`declined`. Related Flutter tests were updated for the new contract/UI and both `./teven verify-backend` and `./teven verify` passed. Dev data is green-field (no migration/backfill).

- [x] **10.19** **Soft-delete customers, so deleting one does not destroy the events that reference it.** Found by deleting a real customer during task 4.4's browser check. **Decision made: soft delete**, on the grounds that prior events are business records and a customer row is not.

  **Follow the user-deactivation pattern (10.12) where applicable.**
  - **Flag:** add nullable `deletedAt` (timestamp with time zone) to `Customers`. `SchemaUtils.create` is create-if-missing and never alters existing tables, so this requires dropping/recreating the dev database.
  - **Delete becomes deactivate:** `deleteCustomer` sets `deletedAt` (idempotent), does not remove the row.
  - **Reads/default visibility:** default customer-management reads exclude deactivated customers and keep `total` consistent; require an explicit parameter/filter (e.g. `status=active|deactivated|all` or `includeDeleted`) to retrieve deactivated/all customers so they do **not** appear in normal pickers/lists such as event creation/edit flows. Centralize the filter so new read paths cannot forget it.
  - **History must remain intact:** resolve deactivated customers when loading customers embedded in historical/current event responses (do not erase the customer name/reference from events). `GET /api/customers/{id}` for a deactivated customer should follow the 10.12-style rule (not surfaced as a normal active record; typically 404 for ordinary access unless an explicit include-deleted/admin view is requested) and must not allow accidental resurrection via edit.
  - **Edit/reactivate:** treat deactivated customers as immutable except restore/reactivation, consistent with deactivated users. Add a restore/reactivation action.
  - **Permissions:** follow the general soft-delete rule — if a caller has permission to delete/deactivate, they generally have permission to restore/reactivate (no exceptions unless explicitly decided later). Apply the same org/global scoping model as other customer management actions.

  **Implemented.** Customers now use `deletedAt` soft deletion (deactivate-on-delete, idempotent) with `status=active|deactivated|all` filtering for authorized callers (global viewers/managers and org-scoped customer managers, scoped appropriately), default/normal reads and pickers excluding deactivated customers, and restore via `POST /api/customers/{id}/restore`. Deactivated customers remain resolvable in embedded event responses for historical associations, cannot be edited/accidentally reactivated via update, and the Flutter customer list follows the user list status-filter/restore pattern. `VIEW_CUSTOMERS_GLOBAL` was mirrored in Flutter permissions for parity. Verified with `./teven verify-backend` and `./teven verify`.

  **Bug context:** `CustomerDao.deleteCustomer` currently hard-deletes; `Events.customerId` has no `onDelete`, so deleting a customer referenced by any event fails with FK constraint `fk_events_customer_id__id` and surfaces as a 500/stack trace. Fix by soft delete + correct filtering, not by cascading or nulling historical event references.

- [x] **10.20** **Finish detail screens and the linked "dead link" cases.** Historically, the React app linked to customer/inventory/organization/user detail routes that did not exist. The Flutter app has since added real detail screens/routes for customers (`/customers/:customerId`), inventory (`/inventory/:inventoryId`), and users (`/users/:userId`), so those links are no longer dead-end fallthroughs in the same way.

  **Decisions applied:**
  - **Customer details events:** show **today and upcoming events only** on the customer details screen, with a clear link to **all** events for that customer. For the "all events for this customer" view, reuse the events list’s existing **start-date semantics** (default/start at today), allowing the user to manually change the start date to see earlier/other events for now (no new time-scope parameter required at this stage).
  - **Event filter contract (design for extension):** add support to filter events by customer (e.g. `customerId` on `GET /api/events`, threaded through route/service/DAO) and support linking to the events list filtered by customer under existing event visibility rules. Use this as the starting point for **general filter support on the events list** rather than one-off parameters: define a consistent, extensible query/filter model for common fields (e.g. `customerId`, `organizationId` where applicable, date/start-end range, search/text, status/state as those concepts are added, etc.), with matching Flutter query/state and URL/deep-link support so the events page can be linked to in a filtered state.
  - **Organization details:** create a dedicated read-only **organization details** screen we can return to, with an **Edit** button shown only when the user has permission to manage/edit that organization. Update routing/links (e.g. `AppRoutes.organizationDetails`) to point to the details screen rather than directly to the edit screen.
  - **Geo fields:** **remove all geo UI fields for now** (`latitude`, `longitude`, `formattedAddress`) from detail/form displays; keep geo fields in Flutter model/DTO objects for now.
  - **Paging follow-up:** smarter paging/window navigation for the filtered/all-events view (e.g. earlier/later ranges, “previous/next 25”, or similar) is deferred to a follow-up task (see 10.37, or handle alongside adjacent paging/list work if appropriate).

  **Implemented (reasonable attempt).** Added `customerId` event filtering through backend route/service/DAO and Flutter `ListQuery`/event fetching, with events-list URL/deep-link support (`/events/list?customerId=...`, `AppRoutes.eventListPath`) and initial filter state. `CustomerDetailsScreen` now shows today/upcoming events for the customer (start-date today in the reader zone) and a "View all events" link reusing the events list start-date semantics. Added read-only `OrganizationDetailsScreen` with permission-gated Edit, added `/organizations/:organizationId` details routing after create/edit, and updated org list/selector/user links to details. Audited Flutter detail/form screens for geo UI and found none displayed; geo fields remain in models/DTOs.

  **Remaining work (verify current state before implementing):**
  1. Design/extend the events list filter API and client state/URL params (starting with `customerId`, reusing existing start-date behavior for the “all events for this customer” link), keeping it consistent/extensible for additional event fields.
  2. Add the today/upcoming events section to `CustomerDetailsScreen` plus a link to the filtered all-events view.
  3. Implement the read-only organization details screen/route and permission-gated edit affordance; align navigation targets.
  4. Audit detail/edit screens for geo UI and remove displayed geo fields while leaving model fields intact.
  5. Confirm user details parity is sufficient for existing read-only/detail link use cases.

- [x] **10.18** **Make the seeded test users loggable in.** Found while trying to discharge task 3.12's real-browser check. The seed wrote a plaintext `"password"` into `users.password`, which `BCrypt.checkpw` throws on — so every seeded account answered **500 with a stack trace** rather than a 401. **Done**: a real hash at seed time, and a malformed stored hash is a failed login rather than an unhandled error. See the 2026-10-13 entry in `FLUTTER-CONVERT-NOTES.md`.

---

- [x] **10.21** **Stop `GET /api/inventory` embedding an unbounded `events` list per row.** Found while porting the inventory list (4.5). `InventoryDao.getInventoryItems` builds every row through `toInventoryItemResponse`, which does a second `selectAll` on `EventInventory` for that item with **no `limit`, no `offset` and no filter** — so a list of 25 items is 26 queries, and a heavily-used item brings back every event that has ever drawn on it.

  Two consequences, and only the second one is visible to a user. The **N+1** is a performance problem that no test and no screenshot will report. The **unbounded payload** is a correctness one: the port has to truncate at the client (`maxEventsShown`, 4.5) because there is no server-side way to ask for fewer, so the count a user sees is a number the client invented.

  **Decision (apply this):** for list endpoints, return a **count** (e.g. `eventCount`) instead of embedding event records; do not pull the associated event rows when building list responses.
  - **List responses** (`GET /api/inventory`, and other inventory list/read-many paths where full associations are not needed): include usage count only, computed without loading full event records per row in an N+1 way (prefer an aggregate/batched count query).
  - **Detail response** (`GET /api/inventory/{id}`): keep returning the full event associations needed by the detail view (or an explicitly paginated/limited shape if later required), so detail behavior remains intact.
  - **Shared mapping/callers:** `toInventoryItemResponse` and callers such as `getInventoryItems`, `getAllInventoryItemsByOrganization`, and `getInventoryItemsForEvent` currently share behavior; refactor so list vs detail (and any event-context-specific) responses return the appropriate shape instead of narrowing everything blindly.
  - **Client impact:** update Flutter models/UI to use the count on list screens and remove the `maxEventsShown` truncation workaround once the server provides the correct count. Update API docs/types in the same change.

  **Verify after:** a request for 25 inventory items issues a constant/bounded number of queries, list payloads do not include unbounded embedded event records, detail still provides the associations it needs, and client-side truncation is no longer load-bearing.

- [x] **10.35** **Fix "Accepting an invite errors" (server serialization failure).** The user is created, but the invite UI shows a server error banner. Debug logs show `kotlinx.serialization.SerializationException: Serializer for class 'ApiResponse' is not found` while responding from the invitation accept path.

  **Approach:** reproduce against the current source/build before changing code. There is, however, an obvious likely cause: `InvitationRoutes.publicInvitationRoutes` accepts via `call.respond(HttpStatusCode.Created, success(response))` where `response` is `AcceptInvitationResponse` from `backend/core` (`alphainterplanetary.teven.core.user.AcceptInvitationResponse`, annotated `@Serializable`), but `backend/core/build.gradle.kts` does not apply `kotlin("plugin.serialization")` and does not declare kotlinx-serialization dependencies, so no serializer may be generated for that type; Ktor’s lookup can then fail when encoding `ApiResponse<AcceptInvitationResponse>`. If reproduction confirms this, fix it in the appropriate place (e.g. enable serialization in `core`, or move/reshape the DTO so it is serialized by a properly configured module) and verify the accept flow returns a successful envelope without a server error.

  Debug logs:
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

- [x] **10.22** **The server's permission check is not enforced.** Found by hand while porting the event details screen (7.6), against the running dev backend rather than by reading the Kotlin. **This is a security defect, and it is the first one the port has found.**

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

- [x] **10.23** **Add a `backend:app` route-test harness and cover route-only validation/authorization gaps (broader coverage).** `backend:service` has JUnit/MockK tests (`./teven verify-backend`), but `backend/app` has no test sources and no test dependencies (`backend/app/build.gradle.kts`). Some request validation and route-layer behavior happens before the service runs (or at the HTTP boundary) and is not exercised by service tests.

  **General setup needed:**
  - Add `testImplementation` dependencies to `backend:app` (at minimum Ktor test host — `ktor-server-tests-jvm` is in `gradle/libs.versions.toml` — plus JUnit/MockK consistent with the repo).
  - Create `backend/app/src/test/kotlin/...` and a reusable Ktor `testApplication` harness that can install the pieces routes need (`ContentNegotiation`/JSON, relevant routing, and a way to supply an authenticated `AuthContext` principal where required). Routes wired through Koin (`inject<...>()`) will need test-module/Koin setup or an equivalent seam.

  **Coverage goal (broader than one case):** start with a reusable harness, then add route tests for important app-layer behaviors, including at minimum:
  - malformed/invalid request handling that returns 400 + envelope before service execution (e.g. authenticated `POST /api/invitations` with malformed `expiresAt` rejected in `backend/app/src/main/kotlin/alphainterplanetary/teven/app/invitation/InvitationRoutes.kt` with `failure("Invalid invitation expiry")`);
  - permission/authorization outcomes at the route boundary (especially relevant to 10.22), ensuring denied requests do not execute handlers and allowed requests still pass;
  - representative success/error envelope and status-code behavior for key routes as the harness makes them easy to cover.

  Prioritize cases that are currently untestable at the service layer or have regressed before (validation, authz wiring, envelope/status mapping), and grow coverage incrementally once the harness exists.

- [x] **10.24** **Extract the shared create-form organization resolution.** The create screens for customers, inventory, and users repeat the same 3-rule policy: the shell's selected organization wins; otherwise a global manager uses the dropdown (defaulting to the first loaded organization, with the control and the submit path agreeing on that value); otherwise the caller's own organization. They also repeat the same visibility rule (`canManageGlobal && selectedOrg == null`) and the null-organization guard. Inventory had the wrong global permission until 9.01, which is the class of bug a shared helper makes harder to reintroduce.

  **Share the policy, not the form.** Extract a small helper for the resolution/default-selection and dropdown-visibility mechanics; keep the resource-specific global permission, service call, request DTO, route, and fields at the call site. Do not build a generic create screen.

  **Implemented.** Added `CreateFormOrganizationPolicy` (`flutter_app/lib/widgets/create_form_organization.dart`) for shared create-form dropdown visibility and default-first organization resolution, with focused unit coverage in `flutter_app/test/create_form_organization_policy_test.dart`. Customer, inventory, and user create forms now use the shared helpers for dropdown visibility/default selection while keeping resource-specific permissions, submit resolution, service calls, DTOs, routes, and fields at the call sites; no behavior change intended. Verified with `./teven verify`.

  **Enforce via tests as much as possible.** Keep or add focused tests around the shared policy (and existing create-form tests) so the 3-rule resolution, default selection, dropdown visibility, and null-organization guard are covered explicitly for each resource-specific permission/context case. **This commit changes no behaviour.** Existing create-form tests (and `./teven verify`) must pass unchanged; treat them as the safety net for the refactor.

- [x] **10.25** **Standardize edit-form load/error handling and the global-organization submit rule.** The resource edit screens (customer, inventory, user, and any others with the same shape) share a "load record, seed fields, submit, navigate away" flow, but their load/error UX and small policy details are inconsistent. The customer edit renders a recoverable load failure ("Try again") and shows the server message rather than spinning forever; align the others to that behaviour without merging field sets.

  Also make the global-organization rule explicit and consistent where it applies: the dropdown is shown only to a global manager, and `organizationId` is sent on update only for that caller (omitted otherwise), per the server's rule for each resource. **Do not force one implementation across types whose field sets, permissions, or load shapes differ** — 9.13 is the precedent for unifying a form only when the differences can be named as parameters.

  **Implemented (audit/fix).** Aligned edit-load failure states to the recoverable customer pattern in `inventory_form_screen.dart`, `user_form_screen.dart`, `event_form_screen.dart`, and `organization_screen.dart`: failed/missing edit loads now show an error state with `ErrorDisplay` (or fallback message) plus **Cancel** and **Try again** actions instead of stuck/non-recoverable text/spinner states. Audited global-organization edit behavior in these screens and kept existing resource-specific rules intact (global-manager-only organization selection where applicable, and `organizationId` sent on update only for callers allowed by each resource’s existing behavior). No intended behavior changes in working flows.

  **This commit changes no behaviour** except where it fixes a stuck-loading-on-error case to match the recoverable pattern. Existing edit-form tests must still pass; add or adjust coverage only where behaviour is intentionally brought into line. Verified with `./teven verify`.

- [x] **10.26** **Use returned mutation results to avoid redundant refetches on in-place updates.** Several flows now receive the saved entity back from the server but still reload/refetch. Apply the returned object where the screen stays put:
  - **Event RSVP:** `POST /api/events/{id}/rsvp` returns the updated `EventResponse`. In the event list, update the affected item in the paged/list state instead of `reload()`; in the event details screen, replace the loaded event (and derived RSVP state) instead of calling `_load(initial: false)`.
  - **Inventory usage / other in-place mutations:** if a screen records usage or performs a mutation that returns the updated resource without navigating away, prefer updating local/provider state from the response over a follow-up fetch.

  **Implemented.** Added `replaceItemWhere` to `PagedListController` for in-place row replacement without refetch/reload. Event list RSVP now applies the returned `EventResponse` to the affected row in paged state; event details RSVP now applies the returned event (and derived RSVP status) in place instead of refetching. Updated RSVP tests to assert no redundant list/detail refetch after RSVP. No other in-place inventory-usage mutation UI flow exists in the current app.

  **Behaviour-preserving where possible:** the UI should reflect the same server state; avoid optimistic guesses that disagree with the returned entity. Verified with `./teven verify`.

- [x] **10.27** **Reduce redundant fetches after create/update navigations by reusing returned entities.** Create and edit forms (customers, inventory, organizations, events, users/roles where applicable) currently `await` the mutation, discard the returned saved object, and navigate away; the destination then fetches again. Where practical, avoid the immediate extra round trip:
  - Prefer updating/inserting into the relevant list/detail provider cache (or invalidating in a way that can seed from the returned entity) so the destination can render the known result without a redundant fetch.
  - Alternatively, pass the returned entity to the destination when the route/screen contract makes that straightforward.
  - Keep fetch-on-load as the source of truth for deep links and stale state; do not remove necessary refreshes, only redundant ones immediately after a successful mutation.

  **Implemented (incremental).** Event edit now navigates to event details with the returned `EventResponse` (`go_router` `extra`), and `EventDetailsScreen` can render a matching `initialEvent` immediately without an initial fetch; deep links and normal navigations without `extra` still fetch on load. Other create/edit flows still navigate to list screens whose paged/query-keyed state is rebuilt on arrival, so cache seeding there was not practical in this pass; no navigation behavior was changed.

  Scope this incrementally per resource/screen, with existing tests updated only where behavior (e.g. request counts/timing) intentionally changes. Verified with `./teven verify`.

- [ ] **10.28** **Soft-delete inventory items, so deleting one does not destroy event and usage history.** Inventory items are hard-deleted today (`InventoryDao.deleteInventoryItem` → `InventoryItems.deleteWhere`), but items are referenced by event-inventory associations and inventory usage (`EventInventory`, `InventoryUsage`). Deleting an in-use item risks FK failures or breaks the historical record of what an event used.

  **Decision direction:** treat inventory items as historical references (like customers in 10.19), following the user-deactivation pattern (10.12) where applicable.
  - **State/API:** nullable `deletedAt`; `delete` deactivates (idempotent); add restore/reactivation. Default list/detail reads exclude deactivated items and keep `total` consistent; require an explicit parameter/filter (e.g. `status=active|deactivated|all` or `includeDeleted`) to retrieve deactivated/all items so they do **not** appear in normal pickers/selection flows (e.g. event inventory assignment) unless explicitly requested.
  - **History:** keep associations/usage resolvable for historical event/usage contexts.
  - **Permissions:** if a caller has permission to delete/deactivate, they generally have permission to restore/reactivate (no exceptions unless explicitly decided later), under the same org/global scoping rules.
  - **Still to decide:** whether deactivated items remain selectable/visible in historical event contexts, and whether edits are allowed while deactivated (default: immutable except restore, consistent with users/customers). `SchemaUtils.create` never alters existing tables, so this requires a dev-database recreate.

  Verify after: deleting an item removes it from default inventory management/picker views without breaking events or usage records that reference it, history remains intact, and authorized users can restore it.

- [ ] **10.29** **Decide and implement non-destructive removal semantics for events (soft delete or cancel/archive).** Events are core records tied to RSVPs, event-inventory allocations, customer associations, and reporting/staff-hours context. A hard delete (`EventDao.deleteEvent`) destroys that history and has broad dependent impact.

  **Decision needed (product):** whether "remove" means soft delete, cancellation, archival, or some combination, and how each state behaves in calendars/lists, reports, RSVP flows, and future scheduling. Whatever non-destructive state(s) are chosen, apply the user-deactivation pattern where applicable (see prior soft-delete cases): preserve historical associations, hide removed/inactive events from default views unless explicitly requested via a specific parameter/filter, provide restore/reopen/reactivation as appropriate, and treat "permission to delete/remove" as generally implying "permission to restore/reopen" (no exceptions unless explicitly decided later), under existing org/global scoping.

  **UI/surface area to design:** determine where removed events are visible and how users access them — e.g. status/filter controls on calendar, events list, and day view, and/or a dedicated "deleted/removed events" view if warranted given events are central to the app. Consider audit visibility (e.g. tracking who removed/deleted an event and when) if needed.

  **Dependent effects to decide:** what happens to RSVPs, event-inventory allocations/usage, customer associations, and related reporting/staff-hours context on remove/delete and on restore/reopen (preserve, freeze, recompute, or restrict actions), and what edits/actions remain allowed while removed.

  **Still to decide:** exact state model and labels, default visibility in calendars/lists/day views/pickers, editability/immutability while removed, reporting/RSVP/inventory behavior on remove and restore, audit fields/UI, and API/UI representation.

  Verify after: removing an event does not silently erase dependent history needed for reporting/audit, default views exclude removed events unless explicitly requested, and the chosen state is represented consistently in the API and UI with appropriate restore/reopen behavior.

- [ ] **10.30** **Decide and implement disable/soft-delete semantics for organizations (tenant roots).** Organizations are tenant roots that own users, customers, inventory, events, invitations, and roles context; hard-deleting an organization (`OrganizationDao.deleteOrganization`) is highly destructive and risks widespread FK/orphaning issues.

  **Decision direction:** prefer disable/soft delete over hard delete, following the user-deactivation pattern where applicable. Whatever "disabled" state is chosen, preserve child records/history, hide disabled organizations from default selection/lists unless explicitly requested via a specific parameter/filter, provide restore/reactivation, and treat "permission to disable/delete" as generally implying "permission to restore/reactivate" (no exceptions unless explicitly decided later), subject to org-management/global permission scoping.

  **Still to decide:** exact meaning of "disabled" (hidden from normal selection, blocks login/access and new activity, effects on child resources/users/invitations, etc.), who may disable/restore (likely global/super-admin/manage-org scope as appropriate), and org-switching/selection UI behavior.

  Verify after: disabling an organization prevents normal access/use without destroying tenant data, disabled orgs are excluded from default selection unless explicitly requested, and an authorized actor can restore it.

- [ ] **10.31** **Review invitation deletion/revocation semantics.** Invitations are largely ephemeral, revocable tokens, but they also carry audit-relevant fields (e.g. `usedByUserId`, expiry/creation). Deleting an invitation today is a hard delete (`InvitationDao.deleteInvitation`).

  **Decide:** whether hard-deleting an unused/expired invitation is acceptable, or whether invitations should be explicitly revoked/retained for audit (and, if so, how used vs unused vs expired invitations are represented and filtered). Confirm the interaction with 10.12’s choice to preserve invitation history when a user is deactivated.

  **If a non-destructive revoked/deactivated state is chosen**, follow the user-deactivation pattern where applicable: exclude revoked/inactive invitations from default lists unless explicitly requested via a specific parameter/filter, provide restore/reactivation if meaningful, and treat "permission to delete/revoke" as generally implying "permission to restore/reactivate" (no exceptions unless explicitly decided later), under existing scoping rules.

  Verify after: revoking/removing an invitation prevents its use, and the chosen approach preserves any audit trail the product requires.

- [ ] **10.32** **Make role definitions code/seed-managed; keep role assignment in the API.** Role *definitions* (names, permission sets, which roles exist) are authorization policy: they are referenced by user-role assignments and invitations, include seeded/system roles (`SuperAdmin`/`Organizer`/`Staff`, name-coupled to `CAN_ASSIGN_*` behavior), and runtime mutation can escalate privileges or drift from the seeded source of truth. Role *assignment* (who has which role) is operational data and should remain API-driven.

  **Decision direction:** remove or disable runtime create/update/delete of role definitions via the API (`POST/PUT/DELETE /api/roles`), and forbid mutating or deleting seeded/system roles. Manage definitions in code/seed (e.g. `InitialSetup` / versioned init) as reviewable, deploy-time changes; this repo has no migration framework (`SchemaUtils.create` is create-if-missing, no Flyway/Liquibase), so "migrations" here means deliberate, versioned seed/init or data changes rather than automatic schema migrations. Keep role listing and user-role assignment/removal endpoints for operational use.

  **Custom roles are out of scope of the current shape.** The existing model is effectively global and name-coupled; if tenant-defined custom roles become a real requirement, treat that as an explicit feature (data model + scoping + UI + safety rules), not an extension of the current definition-CRUD endpoints.

  Verify after: role definitions cannot be created/changed/deleted at runtime through the API, seeded/system roles remain intact, and role assignment/removal still works as intended.

- [ ] **10.33** **Let authorized managers adjust other aspects of users in their organization.** Task 10.12 added deactivation (soft delete) and restore, but some account-management actions are still missing, overly restricted, or not exposed for org-scoped managers. Expand user management so people with the right permissions can maintain user accounts within their scope, while preserving 10.12’s guard rails (no self-deactivation, last-active-super-admin protection, deactivated accounts not able to authenticate/act, and org scoping).

  **Scope to decide/implement (as permitted by role):**
  - **Profile and identity edits:** allow updating fields that are not currently mutable where appropriate (notably `username`; also review `email`, `displayName`, and password reset/change flows). `UpdateUserRequest`/`UserDao.updateUser` today only apply `email`/`displayName`; adding username or credential changes requires explicit validation, uniqueness/conflict handling (including the 10.12 decision that deactivated users reserve `username`/`email`), and clear rules for active vs deactivated accounts.
  - **Org-scoped administration:** confirm which actions `MANAGE_USERS_ORGANIZATION` (within the same organization) may perform vs those reserved for `MANAGE_USERS_GLOBAL` — e.g. edit profile fields, role changes (subject to existing `CAN_ASSIGN_*` checks), and deactivation. **Decision:** org-scoped managers who can deactivate users within scope should also be able to **restore/reactivate** users within scope (see 10.36), under the same scoping and safety checks.
  - **Deactivate/restore lifecycle:** ensure deactivate and restore are available in the API and UI wherever the permission model allows, with idempotent behavior and the same safety checks (cannot restore into a uniqueness/last-admin conflict, cannot edit a deactivated account except restore/reactivation). Use the same explicit deactivated/all filter pattern as other soft-deleted entities so deactivated users do not appear in normal flows unless explicitly requested.

  **UI/API:** expose the supported edits and lifecycle actions in the user management/edit flows for authorized callers, return clear errors on conflicts (duplicate username/email, forbidden, last super-admin, etc.), and keep non-authorized callers scoped to active users/read-only behavior as today.

  Verify after: an authorized org manager can adjust the intended user attributes for users in their organization (and cannot affect users outside scope), deactivate/restore behaves per the decided permission model with 10.12’s invariants preserved, and `./teven verify-backend` and `./teven verify` pass.

- [ ] **10.34** **Consider merging StaffDetails into User.** It is effectively 1:1 with `users`, not clearly staff-specific, and adds extra schema/read/write complexity. If merged, move its fields onto `User`/related DTOs and tables (keeping `hoursWorked` derived rather than stored) and update the UI to the new structure; behaviour can remain the same (default collapsed) or be simplified (expanded) as part of the change. This is a design/architecture decision and should be settled before implementation work begins.

- [x] **10.36** **Allow org-scoped managers to restore users within scope.** **Decision (ready to implement):** the general soft-delete rule applies to users too — if a caller has permission to deactivate a user within scope, they must also be able to restore/reactivate that user within scope (org-scoped managers included), not only global managers. No additional product decision is required; implement consistently with 10.12.

  **Implementation notes:** update the restore endpoint/service/DAO permission and scoping checks to match deactivation for org-scoped managers (within the same organization), and ensure the UI/list filtering exposes deactivated users to authorized org-scoped managers when explicitly requested (e.g. status/include-deactivated/all view) so restore is actionable. Preserve all existing guard rails: no self-deactivation, no deactivating/restoring into a last-active-super-admin violation, deactivated users cannot authenticate or act, same-organization scoping for org-scoped managers, global-manager behavior unchanged, and deactivated users never appear in normal flows unless explicitly requested.

  Verify after: an org-scoped manager can deactivate and restore users in their own organization (subject to safety checks), cannot affect users outside scope, and global-manager behavior remains correct.

- [ ] **10.37** **Add smarter paging/window navigation to the events list (follow-up).** For filtered/event views (including the customer “all events” view), support easier navigation through time windows/pages (e.g. earlier/later ranges or previous/next N events) instead of relying only on manually changing the start date. Coordinate with 10.15 (default/applied limits and caps) and 10.20’s extensible event filter/query model; define the UX and API/query semantics (date-window paging vs offset paging, or both) before implementation.

- [x] **10.38** **Restrict `MANAGE_ORGANIZATION` to its own organization (no global org listing/access).** Found during manual verification of 10.22: an authenticated Organizer with `MANAGE_ORGANIZATION` (e.g. seeded `charlie`) can call `GET /api/organizations` and receive all organizations because the route allows `VIEW_ORGANIZATIONS_GLOBAL OR MANAGE_ORGANIZATION` and `OrganizationService.getOrganizations(...)` returns an unscoped list. `MANAGE_ORGANIZATION` should not grant visibility into other organizations.

  **Direction:** prevent org-scoped organization managers from seeing anything except their own organization.
  - **List endpoint:** likely remove `MANAGE_ORGANIZATION` from `GET /api/organizations` so org-scoped managers have no access to the organizations collection/list (global viewers/managers retain access as appropriate). Do not return or expose other organizations.
  - **Own-org read/update:** preserve the ability to read and edit one’s own organization (e.g. timezone/settings). Keep or adjust `GET /api/organizations/{id}` and `PUT /api/organizations/{id}` so callers with `MANAGE_ORGANIZATION` may access/update only their own organization (service-side scoping already exists for get/update; verify route/service alignment). If the UI needs own-org details for editing, ensure a scoped path remains available without granting list/global visibility.
  - **Create/delete and other org operations:** review `POST`/`DELETE /api/organizations` and any related routes/services for the same over-broad `MANAGE_ORGANIZATION` access; restrict cross-org/global organization management to global permissions where intended.
  - **Client/UI impact:** update Flutter route guards, screens, and organization-selection/edit flows as needed so org-scoped users can still edit their own organization settings where supported, but cannot browse all organizations.

  **Implemented.** Backend org routes now restrict `GET /api/organizations` to global org permissions (`VIEW_ORGANIZATIONS_GLOBAL`, `MANAGE_ORGANIZATIONS_GLOBAL`) so `MANAGE_ORGANIZATION` cannot list all organizations; `POST`/`DELETE` are global-manage only; `PUT /{id}` remains allowed for `MANAGE_ORGANIZATION` scoped to own org; `GET /{id}` allows `MANAGE_ORGANIZATION` (and global permissions) with existing service-side own-org scoping so org-scoped managers can view/edit their own organization settings. Flutter org routes/details/edit flows were updated to allow own-org details/edit access for `MANAGE_ORGANIZATION`, while list/create remain global-only and post-edit/cancel navigation falls back to own-org details/profile when list access is unavailable. Added backend route tests covering list denial for `MANAGE_ORGANIZATION` and own-org read/update vs create/delete behavior.

  Verify after: a user with only `MANAGE_ORGANIZATION` cannot list or access other organizations (403 or scoped empty/not-found as appropriate) but can still view/update their own organization settings when allowed; global organization managers/viewers retain intended behavior. Verified with `./teven verify-backend` and `./teven verify`.

- [x] **10.39:** Surface user invitation note in the accept invite UI

  **Implemented.** Added invitation `note` to the validation response (backend API/service) and surfaced it on the accept-invitation screen when present. Updated Flutter invitation model/codegen and backend validation service test. Verified with `./teven verify-backend` and `./teven verify`.

- [x] **10.40** When the create invitation panel is open on the user list, the button remains there but does nothing.  It's almost identical to the actual create invitation button that does the work.  Distinguish these somehow -- perhaps put a chevron on it, or change the color, or something.

  **Implemented.** The header invitation toggle now switches to a distinct outlined "Hide Invitation Form" button (with chevron) when the panel is open and toggles the panel closed, avoiding the no-op/confusing duplicate-looking control. Verified with `./teven verify`.
- [x] **10.41** Users correctly cannot deactivate themselves via a server error.  We can probably check that in the client first for a better ux

  **Implemented.** The users list now hides the Deactivate action for the currently signed-in user (client-side UX guard), while server-side self-deactivation protection remains unchanged. Verified with `./teven verify`.
- [ ] **10.42** _(Merged into 10.29.)_ Soft-delete/events removal semantics, affected UI surfaces (calendar/events list/day view or dedicated removed-events view), audit (who deleted/when), and dependent behavior for RSVPs/inventory/etc. on remove and restore are now captured in **10.29**. Keep 10.42 as a pointer so the user-reported note isn’t lost.
- [x] **10.43** the reports page has its own organization display and change organization prompt, this isn't necessary since the sidebar does that.  Still should maintain the requirement that an organization is selected on visit.

  **Implemented.** Removed the in-page organization label and organization selector button from the Reports screen while keeping the requirement that a specific effective organization be selected before reports load (global users without a selected organization still see the blocking message and no report requests). Updated report screen tests accordingly. Verified with `./teven verify`.
- [x] **10.44** customer edit is not available on customer list for deactivated customers.  it does show up on view customer, and allows entry.  Saving (correctly) doesn't work, server provides a "Customer not found or no changes applied" error.  We can detect and prevent this in client code to make a better UX.  Check all soft delete entities and prevent similar cases.

  **Implemented.** Customer and user details screens hide Edit for deactivated records and show deactivated status; customer and user edit screens block editing of deactivated records with a clear message and navigation back/view details. Audited currently implemented soft-deleted entity UI flows (customers/users). Verified with `./teven verify`.
- [ ] **10.45** we have incosistent rsvp UIs between the events calendar (pending only, rounded filled buttons), events list (icons in two rows), view event (odd round outlined buttons that clip the containing text), and day view (no ui present).  Events calendar and events list are the most polished of these.  Settle on one if possible, and make sure they work reasonably consistently in terms of look and feel, toasts/snackbars/change-confirmations, and availability.  Avoid flicker and screen refreshes (only observed on view event so far)
- [ ] **10.46** all entity list screens -- on hover there's a rounded rect over name/title element; there's not enough padding for the text to fit cleanly in the corners.
- [ ] **10.47** edit timezone -- timezone popup should recommend the browser/system timezone at the top of the list.
- [ ] **10.48** Profile screen has a timezone field -- changes seem to be applied instantly.  but there's an edit profile button that doesn't show time zone.  Probably move to edit profile screen and require a save action like other fields.  Consider if folks that can edit users can also edit their timezones
- [ ] **10.49** selection and text copying seems to be disabled on all view screens
- [ ] **10.50** Profile screen: time zone display is weird, with reading in and override and detected -- at times you can see the same three repeated.
- [ ] **10.51** inconsistent coverage of cancel/try again when server unreachable; works from view -> edit, but not on, say, initial list load, or initial view load
- [ ] **10.52** view inventory should list current/future events it's used in similar to customer's event list
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
- [ ] **11.8** Consider allowing horizontal swipe on event calendar on mobile; AvailableGestures.horizontalSwipe in event_calendar_screen.  Will take some testing in landscape and portrait.


---

## Phase 12 — Tests (deferred, post-conversion)

The React app had **zero** tests, so there is no existing specification to lean on — task 10.3 deletes the last of the original behaviour. Phase 1 onward therefore writes tests **as each layer is built** (see the per-task test tasks), and Phase 12 is where the integration and UI suites live.

The distinction: per-task tests cover logic whose behaviour is not obvious from reading it — response-shape handling, permission semantics, date arithmetic, query defaults. Anything whose correct behaviour is visible at the call site does not need one.

- [ ] **12.1** Decide the testing scope now that the app is live and its real failure modes are known.
- [ ] **12.2** Integration tests for login → context fetch → authenticated call, per `AGENTS.md` expectations.
- [ ] **12.3** Broaden `ApiClient` coverage beyond task 1.19 — currently the five response-shape cases only.
- [ ] **12.4** Widget tests for the permission guard and the responsive list.
- [ ] **12.5** Golden tests for the calendar month grid, day view, view event, and create/edit event forms.
- [ ] **12.6** Ensure the suite runs on both VM and Chrome. **Partly done:** `flutter test` and `flutter test --platform chrome` both work; the socket-based tests skip on web because `dart:io`'s `HttpServer` is unavailable there — they skip explicitly rather than passing vacuously. Every widget test added in Phases 3–7 has been verified on both, and two failure classes found only on Chrome are now written down in the Phase 7 entry of `FLUTTER-CONVERT-NOTES.md`. **Not done:** a green full-suite Chrome run — see that entry for the counts and what is still unowned.
- [ ] **12.7** Add an app-level error boundary surfacing `ApiException.details`. **Note:** `Application.kt:55-75` returns `cause.stackTraceToString()` in `error.details` on 500s, so server internals reach the client. Consider rendering `details` only behind a debug flag.
- [ ] **12.8** Fix the known 500 stack-trace leak server-side, or suppress `details` in the UI.
- [ ] **12.9** Tests for the error boundary from 9.8: an `ApiRequestException` surfaces its message, and `details` is hidden unless the debug flag is on. Also assert cancellation (9.6) does not surface an error to the user.
- [ ] **12.10** Full visual pass at all three size breakpoints, plus mobile browser widths and touch input.
---
