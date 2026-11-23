import '../../models/invitation.dart';
import '../../models/report.dart';
import '../../models/role.dart';
import '../api/api_client.dart';

/// Invitations to join an organization.
///
/// Replaces the original invitation API service.
///
/// Note the two route groups: `GET /api/invitations/validate` and
/// `POST /api/invitations/accept` are **public** (`publicInvitationRoutes`),
/// while the rest require authentication (`invitationRoutes`). The client does
/// not need to distinguish them, but a `TokenStore` with a stale token will
/// still attach an `Authorization` header to the public calls — harmless, since
/// the server ignores it.
class InvitationService {
  const InvitationService(this._client);

  final ApiClient _client;

  /// Outstanding, unused invitations visible to the caller.
  Future<List<InvitationResponse>> getUnusedInvitations({
    String? sortBy,
    String? sortOrder,
  }) => _client.get<List<InvitationResponse>>(
    '/api/invitations',
    query: {'sortBy': ?sortBy, 'sortOrder': ?sortOrder},
    decode: (json) => (json! as List)
        .map((e) => InvitationResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// What a token entitles the bearer to, before they accept.
  ///
  /// Public. Throws `ApiRequestException` with the server's message for an
  /// invalid or expired token — `failure("Invalid or expired invitation
  /// token")` at 404 (`InvitationRoutes.kt`) — which renders on
  /// the acceptance screen.
  Future<ValidateInvitationResponse> validateInvitation(String token) =>
      _client.get<ValidateInvitationResponse>(
        '/api/invitations/validate',
        query: {'token': token},
        decode: (json) =>
            ValidateInvitationResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Accepts an invitation, creating the user.
  ///
  /// Roles come from the invitation, not the request body.
  ///
  /// Throws `ApiRequestException` for every rejection the service reports —
  /// expired, already used, username taken, email taken. Each arrives as
  /// `failure(response.message)` with 400 (`InvitationRoutes.kt`), so the
  /// message is specific and worth showing verbatim.
  ///
  /// The separate "already logged in" rejection (`InvitationRoutes.kt`)
  /// has the same shape but distinct meaning; keys off that message.
  Future<AcceptInvitationResponse> acceptInvitation(
    AcceptInvitationRequest request,
  ) => _client.post<AcceptInvitationResponse>(
    '/api/invitations/accept',
    request: request,
    decode: (json) =>
        AcceptInvitationResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Creates an invitation.
  ///
  /// Passing [organizationId] for anything other than the caller's own
  /// requires `MANAGE_INVITATIONS_GLOBAL`; otherwise the server answers 403
  /// with a message (`InvitationRoutes.kt`).
  Future<InvitationResponse> createInvitation(
    CreateInvitationRequest request,
  ) => _client.post<InvitationResponse>(
    '/api/invitations',
    request: request,
    decode: (json) =>
        InvitationResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Answers `204 No Content`.
  Future<void> deleteInvitation(int invitationId) =>
      _client.delete('/api/invitations/$invitationId');
}

/// Staff-hours and inventory-usage reports.
///
/// Replaces the original report API service.
///
/// **Both endpoints are unpaginated** and scoped server-side. The API requires
/// [organizationId]; callers without `VIEW_REPORTS_GLOBAL` may only request
/// their own organization.
class ReportService {
  const ReportService(this._client);

  final ApiClient _client;

  /// Staff hours between [startDate] and [endDate] (`YYYY-MM-DD`) in [timezone]
  /// for [organizationId].
  Future<List<StaffHoursReportResponse>> getStaffHoursReport({
    required int organizationId,
    required String startDate,
    required String endDate,
    required String timezone,
  }) => _client.post<List<StaffHoursReportResponse>>(
    '/api/reports/staff_hours',
    request: StaffHoursReportRequest(
      organizationId: organizationId,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
    ),
    decode: (json) => (json! as List)
        .map(
          (e) => StaffHoursReportResponse.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
  );

  Future<List<InventoryUsageReportResponse>> getInventoryUsageReport({
    required int organizationId,
  }) => _client.get<List<InventoryUsageReportResponse>>(
    '/api/reports/inventory_usage',
    query: {'organizationId': organizationId},
    decode: (json) => (json! as List)
        .map(
          (e) =>
              InventoryUsageReportResponse.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
  );
}

/// Roles and their permissions.
///
/// `GET /api/roles` is deliberately **ungated**, so any authenticated caller can
/// list roles for selection flows. Role-definition management endpoints are not
/// exposed in the webapp.
class RoleService {
  const RoleService(this._client);

  final ApiClient _client;

  Future<List<RoleResponse>> getAllRoles() => _client.get<List<RoleResponse>>(
    '/api/roles',
    decode: (json) => (json! as List)
        .map((e) => RoleResponse.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<RoleResponse> getRole(int roleId) => _client.get<RoleResponse>(
    '/api/roles/$roleId',
    decode: (json) => RoleResponse.fromJson(json! as Map<String, dynamic>),
  );
}
