/// A permission the backend grants.
///
/// Sent as a bare string over the wire (e.g. `"VIEW_USERS_GLOBAL"`), so the
/// Dart [Permission.name] values are the source of truth for serialization.
/// Use [Permissions.parse] to convert an untrusted server string, and
/// [Permissions.has] to test membership — see the caveat on that method.
///
/// Mirrors `frontend/src/types/permissions.ts` and
/// `backend/core/security/Permission.kt`.
enum Permission {
  manageUsersOrganization('MANAGE_USERS_ORGANIZATION'),
  manageInvitationsOrganization('MANAGE_INVITATIONS_ORGANIZATION'),
  manageInvitationsGlobal('MANAGE_INVITATIONS_GLOBAL'),
  viewUsersOrganization('VIEW_USERS_ORGANIZATION'),
  viewUsersGlobal('VIEW_USERS_GLOBAL'),
  manageUsersGlobal('MANAGE_USERS_GLOBAL'),
  viewEventsOrganization('VIEW_EVENTS_ORGANIZATION'),
  manageEventsOrganization('MANAGE_EVENTS_ORGANIZATION'),
  manageEventsGlobal('MANAGE_EVENTS_GLOBAL'),
  viewCustomersOrganization('VIEW_CUSTOMERS_ORGANIZATION'),
  manageCustomersOrganization('MANAGE_CUSTOMERS_ORGANIZATION'),

  /// **One of the 18 that task 10.16 covers, added early because a Phase 5
  /// form cannot be ported without it.**
  ///
  /// Both customer forms gate their organization `<select>` on
  /// `hasPermission('MANAGE_CUSTOMERS_GLOBAL')`
  /// (`CreateCustomerForm.tsx:29`, `EditCustomerForm.tsx:24`), and the React
  /// `Permission` type does not name it — so under the mirror-the-15 rule the
  /// control would never render for anyone. That is not a cosmetic loss: the
  /// **server requires** it of a global manager.
  /// `CustomerService.kt:62` throws `"organizationId is required for
  /// MANAGE_CUSTOMERS_GLOBAL users"` when the request omits one, and
  /// `:93` refuses an `organizationId` change from anyone who lacks it. So the
  /// gate decides whether the form can create a customer at all.
  ///
  /// The `SuperAdmin` role is seeded with every permission
  /// (`InitialSetup.kt:24` — `Permission.entries.map { it.name }`), so the
  /// permission is genuinely held in practice and the dropdown is live.
  /// `Organizer` and `Staff` are not granted it.
  ///
  /// Added as option (a) of 10.16 — "grant it a client constant and gate the
  /// corresponding UI" — for the one permission this phase could not proceed
  /// without. The other 17 still wait on that task's review.
  manageCustomersGlobal('MANAGE_CUSTOMERS_GLOBAL'),

  /// **One of the 18 that task 10.16 covers, added early because the event
  /// details screen cannot be ported without it.**
  ///
  /// `EventDetails.tsx:20` gates the RSVP buttons on
  /// `hasPermission('ASSIGN_TO_EVENTS_SELF')` — a **raw string**, not the
  /// `Permission` const object. That is why the React app never needed it in
  /// `permissions.ts` to work: `usePermissions().hasPermission` takes a
  /// `string` and compares it against the server's list
  /// (`AuthContext.tsx:84`), so a permission the client cannot *name* is still
  /// a permission it can *ask about*.
  ///
  /// The permission is real and widely held. The server's enum has it
  /// (`Permission.kt:89`), and the seeded `Organizer` and `Staff` roles are
  /// both granted it (`InitialSetup.kt:69,91`), so it is the difference
  /// between a user seeing the "Going" / "Not Going" buttons and seeing
  /// "You don't have permission to RSVP to this event."
  ///
  /// **The server does not check it.** `POST /api/events/{id}/rsvp` carries no
  /// `withPermission` wrapper at all (`EventRoutes.kt:128`), so this
  /// client-side gate is the only one there is. Task 10.14 calls the
  /// permission vestigial, because the route it was written for
  /// (`POST /api/events/{id}/join`) was deleted on the same afternoon it was
  /// added — this is the one place it is still load-bearing.
  assignToEventsSelf('ASSIGN_TO_EVENTS_SELF'),

  viewInventoryOrganization('VIEW_INVENTORY_ORGANIZATION'),
  manageInventoryOrganization('MANAGE_INVENTORY_ORGANIZATION'),
  viewReportsOrganization('VIEW_REPORTS_ORGANIZATION'),
  viewOrganizationsGlobal('VIEW_ORGANIZATIONS_GLOBAL'),
  manageOrganizationsGlobal('MANAGE_ORGANIZATIONS_GLOBAL');

  const Permission(this.wireName);

  /// The exact string the server sends and expects.
  final String wireName;
}

/// Helpers for working with the server's `List<String>` permission list.
abstract final class Permissions {
  const Permissions._();

  /// Parses a wire string, returning `null` if the server sends something this
  /// build does not know about.
  ///
  /// Returning `null` rather than throwing is deliberate: an unrecognized
  /// permission must not break the whole context fetch, it just cannot be
  /// gated on.
  static Permission? parse(String wireName) {
    for (final permission in Permission.values) {
      if (permission.wireName == wireName) {
        return permission;
      }
    }
    return null;
  }

  /// Whether [granted] contains any of [required].
  ///
  /// **OR-semantics**, matching `ProtectedRoute.tsx:22-25`, which treats an
  /// array of permissions as `.some()`. `App.tsx:62` relies on this: it gates
  /// user creation on `[MANAGE_USERS_GLOBAL, MANAGE_USERS_ORGANIZATION]`, and
  /// either one alone is sufficient.
  ///
  /// An empty [required] grants access. That reproduces
  /// `ProtectedRoute.tsx:20`, where a route with no `requiredPermission`
  /// prop renders its children unconditionally.
  static bool has(Iterable<String> granted, Permission permission) =>
      granted.contains(permission.wireName);

  /// Any-of variant of [has].
  static bool hasAny(Iterable<String> granted, List<Permission> required) =>
      required.isEmpty || required.any((p) => granted.contains(p.wireName));
}
