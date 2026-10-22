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
| Time zones | **An instant plus a zone on the wire; the reader's zone on screen** | Phase 7A. Breaks the React app's event screens at 7.21, restored by 7.22 |

**Deployment is out of scope.** How and where this app is hosted is handled independently of building the app, and nothing in this plan should wait on it or plan for it. The single place hosting touches a code decision is task 1.13.

### Time zones

The app had **no time zone concept anywhere** — not in the database, not in the API, not in the Flutter app. Every date and time was a string, read in whatever zone the reader happened to be in. Phase 7A fixes that, and it settles five decisions that the rest of the phase depends on.

The tasks are in [`FLUTTER-CONVERT.md`](FLUTTER-CONVERT.md) under *Phase 7A*. The survey that produced them is in [`FLUTTER-CONVERT-NOTES.md`](FLUTTER-CONVERT-NOTES.md) under 2026-10-21, and the per-defect inventory is in the *Time zone discrepancies* table below.

#### Three zones, kept apart

Confusing them is the whole bug.

| Zone | Whose it is | Where it lives | What it does |
|---|---|---|---|
| **The organization's zone** | An organization | `organizations.timezone` | Its **home** clock. The reference the picker highlights. Never coerces an event. |
| **The event's zone** | An event | `events.timezone` | The zone the event's wall clock was picked in. It is the event's identity: a 9 AM event stays a 9 AM event. |
| **The reader's zone** | A person, right now | **Local only** — never on the server | The zone every time is *rendered* in. |

#### The reader's zone resolves in four steps

1. A **local override** the reader set — stored in `shared_preferences`, never sent to the server.
2. Otherwise the **device's zone**, detected via `flutter_timezone`.
3. Otherwise the **current organization's zone** — the fallback when detection is unavailable.
4. Otherwise **UTC**.

The organization's zone is **not** the default. The instruction was explicit — *"translate all into the current user timezone and display accordingly"* — so the organization's zone is a **fallback** and a **highlighted reference**, and nothing more. It never coerces an event.

#### Why the override is local-only, and not on the server

**Settled: local only.** The reasoning, because this is the kind of decision that gets re-litigated.

- **A detected zone is a property of the device, not of the account.** One person, one account, a laptop in Auckland and a phone in Berlin. A server-stored "user timezone" would be wrong half the time, and wrong *silently* — it would look authoritative while describing a machine that is not in front of the reader.
- **The server never needs it.** Every request that depends on a zone sends the zone with it. There is no server-side computation that would want a stored per-user zone.
- **It avoids three things that are all cost**: a `users.timezone` column, a field on `UserContextResponse`, and a round-trip on every cold boot — for a value that changes as often as someone travels.
- **It matches how the app already treats `selectedOrganization`.** That is also stored in `shared_preferences` and is explicitly *not* per-account, for the same reason — and with the same caveat task 9.16 records: a browser's preference belongs to the browser, so whoever uses it next inherits it. The timezone override inherits that caveat too.

**What would change the answer:** a product decision that the reader's zone is an *account* property — "my home zone travels with me" — as opposed to a *device* property. That is a different feature, it deserves its own task, and it is not this one.

#### On the wire

**An instant carries an offset and a wall clock carries its zone.** `2026-03-04T08:00:00Z` and `2026-03-04T10:00:00+02:00` are the same moment said two ways, and neither is re-interpreted. A date and a time on their own (`2026-03-04`, `09:00`) are meaningless without the zone they were picked in, so the zone travels with them. **A day is a day** — a date of birth and a staff-hours row's day are calendar days and never gain a zone. And **the server never guesses**: a naive timestamp is a **400**, not a silent assumption.

**The date and time fields are replaced by one pair, not one value.** `startsAt` (the instant) and `timezone` (the zone the wall clock was picked in) travel together, because they are one fact: `startsAt` without `timezone` says when, and `timezone` without `startsAt` says which clock but not when. An update sends both or neither — a lone `startsAt` would mean "keep the old zone, move the wall clock", which is not a thing an event can be.

#### The zone is the interpretation context for the date and time beside it

Changing an event's zone does not move its wall clock: `(2026-03-04, 09:00, Europe/Berlin)` means *9 AM Berlin time*. The alternative — keeping the instant and re-rendering the wall clock — would silently rewrite the form's own fields under the reader's fingers, sometimes onto a different day, and the form would stop looking like the thing it is editing.

The consequence is that changing the zone can move an event by up to 26 hours, which is exactly the difference between 9 AM in Auckland and 9 AM in Los Angeles. That is not a bug — it is what "in this zone" means — and it is why the field is only *de-emphasized* when it matches the organization default and is at full weight otherwise.

**The edit form therefore loads the event's *own* zone, not the reader's.** An event created in `Europe/Berlin` opens in `Europe/Berlin` with its Berlin wall clock, so saving it does not move the event. If the edit form loaded the reader's zone and the reader's wall clock, saving would silently re-zone the event — the event's 9 AM Berlin would become 9 AM Auckland, and the instant with it. **This is the single most damaging thing the form could get wrong**, and an invisible one, because the form looks right and the save succeeds.

#### The order the work lands in, and why

The backend and the client cannot move independently, so the sequence is arranged so that **every commit leaves the Flutter app working against the running server**:

| # | Task | Leaves the app working because |
|---|---|---|
| 7.13 | Server clock and zone pinned | No wire change at all |
| 7.14 | Non-event date columns typed | Additive; the React client still parses the old strings |
| 7.15 | `organizations.timezone` | Additive; an absent zone defaults to UTC |
| 7.16 | `MANAGE_ORGANIZATION` permission | Additive; a new enum member |
| 7.17 | Flutter timezone foundation | New capability; nothing depends on it yet |
| 7.18 | The event becomes an instant + a zone | The server **keeps** sending `date` and `time` alongside the new fields |
| 7.19 | The event forms send the new shape | The server accepts both shapes for one commit |
| 7.20 | Every surface renders in the reader's zone | Pure client-side rendering change |
| 7.21 | The legacy event fields retired | **The React app breaks here** |
| 7.22 | React client patched | Restores the live app |
| 7.23 | The organization's zone in the UI | Additive |
| 7.24 | Zone-aware report windows | The Flutter report screens do not exist yet (Phase 8) |
| 7.25–7.26 | Tests | — |
| 7.27–7.28 | `API.md`, design doc, progress log | — |

**The shape of it: the server speaks the new language first, but keeps speaking the old one until the client is ready.** 7.18 adds the new fields *alongside* the old ones; 7.19 moves the client onto the new ones; 7.21 retires the old ones. Each end of that handshake is one commit, and nothing in between is a broken state.

#### What breaks, and what it costs

**The React app's event screens break at 7.21** and are restored by 7.22. That is an accepted cost: the event wire format changes from a naive date and time to an instant and a zone, and the React client reads the old shape. The plan's "do not modify the backend" rule is amended for it.

**Nothing else breaks.** The invitation expiry (7.14) changes shape but stays readable by the React client, with one rendering shift: a naive string was parsed as the browser's local time and a `Z` string is parsed as UTC, so a reader far from UTC may see a different calendar day for an invitation expiring late in the day. The value is now unambiguous, which is the point.

**One piece of this is a net improvement regardless of the phase.** Two of the defects the phase removes — the same-day sort with no time component, and the invitation expiry compared against a clock in a different container — are not timezone *features*. They are bugs that happen to live in the timezone-shaped part of the code, and they are fixed because the rework passes through them.

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
| **The server's permission check is never enforced** | `withPermission` installs `AuthorizationPlugin`, whose `onCall` hook answers 403 — but `onCall` hooks do not short-circuit, so the route handler answers over the top of it. Measured against the running dev backend: an `Organizer` (no `*_GLOBAL` permission of any kind) got **200 and the whole organization list** from `GET /api/organizations`, and 200 from `/api/users`, `/api/customers`, `/api/inventory` and `/api/events`. Authentication is enforced; **authorization is not**. Found by hand during task 7.6 | **10.22** |

### Time zone discrepancies

Found while surveying the codebase for Phase 7A. These are not "the port did not reproduce a behaviour" rows — they are defects in the server and in the wire format that the zone rework removes.

| Discrepancy | Evidence | Fix |
|---|---|---|
| **The app has no time zone concept anywhere** | `events.date` and `events.time` are `varchar(255)`; `staffhours.date` and `inventoryusage.usage_date` are `varchar`; `invitations.expires_at` is `TIMESTAMP` (no zone). No `ZoneId`, `ZoneOffset`, `Clock`, `TZ` or `PGTZ` anywhere in the repo — verified by grep across `backend/`, `docker-compose.yml`, `Dockerfile` and `.env` | **7.13–7.24** |
| **Every date comparison is a string comparison** | `EventDao.kt:159-160` and `ReportDao.kt:33-34` compare `varchar` columns against `varchar` query parameters. Correct today **only because the writers emit ISO `YYYY-MM-DD`** — a different format would silently misbehave | **7.14**, **7.18** |
| **Two independent zone defaults that agree by accident** | The JVM's zone comes from `/etc/localtime` in the image (`Etc/UTC`); the Postgres session zone comes from the server default (`UTC`). Set `TZ` on one container and `invitations.created_at` (written by Postgres) and `invitations.expires_at` (compared against the JVM's clock) diverge by the offset | **7.13** |
| **`timestamp()` is not a `timestamptz`** | `DataTypeProvider.timestampType()` delegates to `dateTimeType()`, which the Postgres provider returns as `"TIMESTAMP"` — **without** a zone. `timestampWithTimeZone()` is the one that returns `"TIMESTAMP WITH TIME ZONE"`. Getting this backwards is the easy mistake, and it fails silently | **7.14**, **7.18** |
| **A malformed invitation expiry is a 500, not a 400** | `InvitationRoutes.kt:75` calls `LocalDateTime.parse(it)`; a bad value throws `DateTimeParseException`, which the generic `StatusPages` handler turns into a 500 with a stack trace (`Application.kt:77-83`) | **7.14** |
| **Events on the same day sort in an unspecified order** | `EventDao.kt:173` orders by `Events.date` alone. `Events.date` and `Events.time` are **never combined** anywhere — there is no "event start instant" in the system — so same-day ties come back in whatever order Postgres feels like | **7.18** (`ORDER BY startsAt`) |
| **`usage_date` is stamped from the server's wall clock** | `InventoryDao.kt:166` writes `LocalDate.now().toString()` — the **server's** calendar day, in the server's zone, unrelated to when the inventory was used. The column is also **never read** and never surfaced in any DTO | **7.24** (correct source; still write-only) |
| **No `Clock` seam, so no temporal logic is testable** | Five static `now()` calls: `InvitationService.kt:57,67,82`, `InvitationDao.kt:83`, `InventoryDao.kt:166`. All implicitly coupled to the JVM's default zone | **7.13** |
| **The Flutter app has no device-zone detection and no zone database** | `pubspec.yaml` has neither `timezone` nor `flutter_timezone`; `DateTime` can only convert between local and UTC. `DateTime.now().timeZoneName` returns an abbreviation (`"EDT"`), which is ambiguous and unusable as an identifier | **7.17** |
| **The client would render an offset-bearing timestamp in UTC** | `user_list_screen.dart:646`'s `formatDate(String)` parses the timestamp and reads `.year/.month/.day` — with an offset-bearing string that reads the **UTC** date, not the reader's. It is also a **second** wire-date formatter, alongside `lib/core/util/local_date.dart` | **7.20** (folded into the shared helper) |
