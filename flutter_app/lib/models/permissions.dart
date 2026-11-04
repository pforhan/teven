/// A permission the backend grants.
///
/// Sent as a bare string over the wire (e.g. `"VIEW_USERS_GLOBAL"`), so the
/// Dart [Permission.name] values are the source of truth for serialization.
/// Use [Permissions.parse] to convert an untrusted server string, and
/// [Permissions.has] to test membership — see the caveat on that method.
///
/// Mirrors the React app's permission list and the server's enum.
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

  /// The global permission for managing customers across organizations. Today it
  /// is the gate that decides whether the customer create/edit forms can be used
  /// at all: the server requires an organization id from a caller holding it, and
  /// refuses an organization change from anyone who lacks it.
  ///
  /// The `SuperAdmin` role is seeded with every permission, so the permission is
  /// genuinely held in practice; the `Organizer` and `Staff` roles are not granted
  /// it.
  manageCustomersGlobal('MANAGE_CUSTOMERS_GLOBAL'),

  /// The permission for assigning oneself to an event — the gate behind the
  /// RSVP buttons on the event details screen.
  ///
  /// The server does not check it: the RSVP route carries no permission
  /// wrapper, so this client-side gate is the only one there is.
  assignToEventsSelf('ASSIGN_TO_EVENTS_SELF'),

  viewInventoryOrganization('VIEW_INVENTORY_ORGANIZATION'),
  manageInventoryOrganization('MANAGE_INVENTORY_ORGANIZATION'),
  viewReportsOrganization('VIEW_REPORTS_ORGANIZATION'),

  /// The organization-scoped counterpart to `MANAGE_ORGANIZATIONS_GLOBAL` — the
  /// permission an Organizer holds to manage their own organization, today
  /// setting its home time zone. The server scopes it to the caller's own
  /// organization, so an Organizer holding it can read and update their own
  /// organization but not another's; the global permission remains the
  /// super-admin's door to any organization.
  ///
  /// The `SuperAdmin` role is seeded with every permission, so the global
  /// variant is held in practice by the super admin; the seeded `Organizer` is
  /// granted this one.
  manageOrganization('MANAGE_ORGANIZATION'),

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
  /// **OR-semantics**: an array of permissions counts as any-of. The route
  /// guard relies on this — user creation is gated on either the global or the
  /// organization-scoped permission, and either one alone is sufficient.
  ///
  /// An empty [required] grants access. That reproduces the route with no
  /// permission requirement, which renders its children unconditionally.
  static bool has(Iterable<String> granted, Permission permission) =>
      granted.contains(permission.wireName);

  /// Any-of variant of [has].
  static bool hasAny(Iterable<String> granted, List<Permission> required) =>
      required.isEmpty || required.any((p) => granted.contains(p.wireName));
}
