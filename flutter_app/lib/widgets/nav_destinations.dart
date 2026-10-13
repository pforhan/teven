import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../routing/app_router.dart';

/// One entry in the primary navigation.
///
/// Replaces the six hand-written `<li>` blocks at `MainLayout.tsx:22-27`. Each
/// one carried a label, a path and a permission test; collecting them into a
/// list is what makes the chrome renderable three different ways (drawer, rail,
/// extended rail) without the permission logic being written three times.
@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.required,
  });

  final String label;
  final String route;

  /// Material icon. Task 3.11: the React app renders `react-icons/fa` glyphs
  /// plus `bi bi-*` tags that were never installed and so render as nothing
  /// (`bi bi-chevron-right`, `bi bi-plus`). There is no parity to hit, so the
  /// port uses Material icons throughout.
  final IconData icon;

  /// Permissions that reveal this destination.
  ///
  /// OR-semantics, matching the React ternaries: `MainLayout.tsx:27` shows
  /// "Users" for either `VIEW_USERS_ORGANIZATION` or `VIEW_USERS_GLOBAL`.
  /// [Permissions.hasAny] also treats the empty list as "always", which is why
  /// Profile and Logout can be modelled the same way even though the React
  /// original has no test at all on them.
  final List<Permission> required;

  bool isVisibleTo(PermissionGate gate) => gate.hasAny(required);
}

/// The permission-gated primary navigation, in the order `MainLayout.tsx:22-27`
/// lists it.
const List<NavDestination> kPrimaryNavDestinations = [
  NavDestination(
    label: 'Events',
    route: AppRoutes.events,
    icon: Icons.event,
    required: [Permission.viewEventsOrganization],
  ),
  NavDestination(
    label: 'Customers',
    route: AppRoutes.customers,
    icon: Icons.people_alt,
    required: [Permission.viewCustomersOrganization],
  ),
  NavDestination(
    label: 'Inventory',
    route: AppRoutes.inventory,
    icon: Icons.inventory_2,
    required: [Permission.viewInventoryOrganization],
  ),
  NavDestination(
    label: 'Reports',
    route: AppRoutes.reports,
    icon: Icons.bar_chart,
    required: [Permission.viewReportsOrganization],
  ),
  NavDestination(
    label: 'Organizations',
    route: AppRoutes.organizations,
    icon: Icons.domain,
    required: [Permission.viewOrganizationsGlobal],
  ),
  NavDestination(
    label: 'Users',
    route: AppRoutes.users,
    icon: Icons.group,
    // The one OR-gated item. See [NavDestination.required].
    required: [Permission.viewUsersOrganization, Permission.viewUsersGlobal],
  ),
];

/// Whether the signed-in user is a super-admin.
///
/// `MainLayout.tsx:10` — derived from `VIEW_USERS_GLOBAL`, not from a role
/// name. Task 3.5.
///
/// The same permission the "Users" nav item accepts, which is not a
/// coincidence: a super-admin holds the global user permission, so the two
/// conditions coincide in practice. Kept as one derivation rather than
/// inferring one from the other, so that tightening either does not silently
/// tighten both.
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(permissionGateProvider).has(Permission.viewUsersGlobal);
});
