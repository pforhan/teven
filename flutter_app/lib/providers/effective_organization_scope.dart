import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organization.dart';
import '../models/permissions.dart';
import '../widgets/nav_destinations.dart' show isSuperAdminProvider;
import 'auth_controller.dart';
import 'organization_controller.dart';

/// The page-level organization scope derived from who the user is and, for a
/// superadmin, which organization they have selected in the shell.
///
/// Centralizes the "effective organization" concept so call sites do not
/// re-decode the same null checks with subtly different meanings:
///
/// - A **superadmin** with a selected organization acts in that organization.
/// - A **superadmin** with no selection acts in **all organizations** (the
///   "All Organizations" picker state). For list/query screens this means an
///   unscoped query; resource-specific flows that require a concrete
///   organization (for example reports) must still treat this as "no org
///   chosen" themselves.
/// - A **non-superadmin** always acts in their own organization, regardless of
///   any stored picker selection.
///
/// "No picker selection stored" means all-organizations **only** for a
/// superadmin. A non-superadmin with no stored selection is still scoped to
/// their own organization.
class OrganizationScope {
  const OrganizationScope({
    required this.organization,
    required this.isSuperAdmin,
    required this.isAllOrganizations,
  });

  /// The effective organization, or `null` when a superadmin is viewing all
  /// organizations.
  ///
  /// For a non-superadmin this is always their own organization (or `null` only
  /// if the user context carries none, which is not a normal signed-in state).
  final OrganizationResponse? organization;

  /// Whether the signed-in user is a superadmin (holds [Permission.viewUsersGlobal]).
  final bool isSuperAdmin;

  /// Whether a superadmin is in the "All Organizations" context.
  ///
  /// Always `false` for a non-superadmin.
  final bool isAllOrganizations;

  /// The effective organization's id, or `null` when viewing all organizations.
  int? get organizationId => organization?.organizationId;

  /// The organization id to send with list/query requests: the effective
  /// organization id when scoped to one organization, or `null` to query across
  /// all organizations (the superadmin all-organizations context).
  int? get queryOrganizationId => organizationId;

  /// Whether the scope names a specific organization.
  bool get hasSpecificOrganization => organization != null;
}

/// The derived [OrganizationScope] for the current session.
final effectiveOrganizationScopeProvider = Provider<OrganizationScope>((ref) {
  final isSuperAdmin = ref.watch(isSuperAdminProvider);
  final selected = ref.watch(selectedOrganizationProvider);
  final ownOrganization = ref.watch(userContextProvider)?.user.organization;

  if (isSuperAdmin) {
    return OrganizationScope(
      organization: selected,
      isSuperAdmin: true,
      isAllOrganizations: selected == null,
    );
  }

  return OrganizationScope(
    organization: ownOrganization,
    isSuperAdmin: false,
    isAllOrganizations: false,
  );
});

/// The effective organization for the current scope, or `null` for a
/// superadmin viewing all organizations.
final effectiveOrganizationProvider = Provider<OrganizationResponse?>(
  (ref) => ref.watch(effectiveOrganizationScopeProvider).organization,
);

/// The effective organization's id, or `null` when viewing all organizations.
final effectiveOrganizationIdProvider = Provider<int?>(
  (ref) => ref.watch(effectiveOrganizationScopeProvider).organizationId,
);

/// The organization id to use for scoped list/query requests.
///
/// `null` means "do not filter by organization", which is correct for a
/// superadmin viewing all organizations. Non-superadmins always receive their
/// own organization id.
final queryOrganizationIdProvider = Provider<int?>(
  (ref) => ref.watch(effectiveOrganizationScopeProvider).queryOrganizationId,
);

/// Whether the current scope is the superadmin "All Organizations" context.
final isAllOrganizationsProvider = Provider<bool>(
  (ref) => ref.watch(effectiveOrganizationScopeProvider).isAllOrganizations,
);
