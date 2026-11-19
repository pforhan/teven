import '../models/organization.dart';

/// Shared create-form organization resolution/default-selection mechanics.
///
/// Extracted from the create flows for customers, inventory, and users so the
/// 3-rule policy and its control/submit agreement stay consistent without
/// building a generic create screen. Resource-specific permissions, service
/// calls, request DTOs, routes, and fields remain at the call site.
///
/// This is policy, not UI.
abstract final class CreateFormOrganizationPolicy {
  /// Create-form dropdown visibility: a global manager may pick an organization
  /// only when the shell has no selected organization.
  ///
  /// When a shell organization is selected it wins and no dropdown is shown.
  static bool showGlobalOrganizationField({
    required bool canManageGlobal,
    required OrganizationResponse? selectedOrganization,
  }) => canManageGlobal && selectedOrganization == null;

  /// Default selection for a global-manager create-form dropdown: keep the
  /// caller's chosen organization, otherwise fall back to the first loaded
  /// organization.
  ///
  /// Using the same function for the control and submit resolution keeps the
  /// displayed/defaulted value and the submitted value in agreement.
  static OrganizationResponse? defaultFirstOrganization(
    List<OrganizationResponse> loaded,
    OrganizationResponse? chosen,
  ) => chosen ?? (loaded.isEmpty ? null : loaded.first);
}
