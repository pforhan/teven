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

---

## Phase 9 — Responsive, accessibility, polish

- [x] **9.0** missing routes/pages for user details and user edit.  May be able to reuse some of /profile for details 
- [x] **9.01** inventory should not always show the organization field.  Apply the same logic we use in Add/edit customer (for that matter see if it's duplicated elsewhere too)
- [x] **9.1** Audit all 25 former Bootstrap `row`/`col` sites; confirm each degrades to single-column on mobile.
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

  **Update 2026-11-05 (task 9.0's sweep):** the field-rendering half has landed. `CustomerDetailsScreen` is registered at `/customers/:customerId` behind `VIEW_CUSTOMERS_ORGANIZATION`, and the inventory twin at `/inventory/:inventoryId` behind `VIEW_INVENTORY_ORGANIZATION`; both carry the edit affordance, behind the manage gate. The screens render the fields the edit forms show — the customer's Name/Phone/Address/Notes, the item's Name/Description/Quantity — as read-only text rather than disabled form fields, which keeps the reader and editor on the same data without coupling a read path to a write path's validators.

  The events section remains deferred, and item 1 above is unchanged: the backend's missing `customerId` filter on `GET /api/events` is the blocker, and the field rendering was the half that could ship before it.

  The organization-details screen the user list's organization column still links to is likewise still open under this task.

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

- [ ] **10.23** **Add a `backend:app` route-test harness and cover route-only validation gaps.** `backend:service` has JUnit/MockK tests (`./teven verify-backend`), but `backend/app` has no test sources and no test dependencies (`backend/app/build.gradle.kts`). Some request validation happens at the route layer and returns a 400 + envelope before the service runs, so it is not exercised by service tests.

  **General setup needed:**
  - Add `testImplementation` dependencies to `backend:app` (at minimum Ktor test host — `ktor-server-tests-jvm` is in `gradle/libs.versions.toml` — plus JUnit/MockK consistent with the repo).
  - Create `backend/app/src/test/kotlin/...` and a minimal Ktor `testApplication` harness that can install the pieces a route needs (`ContentNegotiation`/JSON, relevant routes from `configureRouting`/routing, and a way to supply an authenticated `AuthContext` principal where required). Routes wired through Koin (`inject<...>()`) will need test-module/Koin setup or an equivalent seam.

  **Specific missing case (7.26 caveat):** authenticated `POST /api/invitations` with a malformed `expiresAt` is rejected in `backend/app/src/main/kotlin/alphainterplanetary/teven/app/invitation/InvitationRoutes.kt` (returns `400` with `failure("Invalid invitation expiry")`) before calling `InvitationService`. Add a route test asserting the 400 status and envelope message for that case. It is a good first route test because the malformed branch does not need a service/DAO happy path.

- [ ] **10.24** **Extract the shared create-form organization resolution.** The create screens for customers, inventory, and users repeat the same 3-rule policy: the shell's selected organization wins; otherwise a global manager uses the dropdown (defaulting to the first loaded organization, with the control and the submit path agreeing on that value); otherwise the caller's own organization. They also repeat the same visibility rule (`canManageGlobal && selectedOrg == null`) and the null-organization guard. Inventory had the wrong global permission until 9.01, which is the class of bug a shared helper makes harder to reintroduce.

  **Share the policy, not the form.** Extract a small helper for the resolution/default-selection and dropdown-visibility mechanics; keep the resource-specific global permission, service call, request DTO, route, and fields at the call site. Do not build a generic create screen.

  **This commit changes no behaviour.** Existing create-form tests (and `./teven verify`) must pass unchanged; treat them as the safety net for the refactor.

- [ ] **10.25** **Standardize edit-form load/error handling and the global-organization submit rule.** The resource edit screens (customer, inventory, user, and any others with the same shape) share a "load record, seed fields, submit, navigate away" flow, but their load/error UX and small policy details are inconsistent. The customer edit renders a recoverable load failure ("Try again") and shows the server message rather than spinning forever; align the others to that behaviour without merging field sets.

  Also make the global-organization rule explicit and consistent where it applies: the dropdown is shown only to a global manager, and `organizationId` is sent on update only for that caller (omitted otherwise), per the server's rule for each resource. **Do not force one implementation across types whose field sets, permissions, or load shapes differ** — 9.13 is the precedent for unifying a form only when the differences can be named as parameters.

  **This commit changes no behaviour** except where it fixes a stuck-loading-on-error case to match the recoverable pattern. Existing edit-form tests must still pass; add or adjust coverage only where behaviour is intentionally brought into line.

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
