import '../../models/invitation.dart';
import '../../models/report.dart';
import '../../models/role.dart';
import '../api/api_client.dart';

/// Invitations to join an organization.
///
/// Replaces `InvitationService` in `frontend/src/api/InvitationService.ts`.
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
  Future<List<InvitationResponse>> getUnusedInvitations() =>
      _client.get<List<InvitationResponse>>(
        '/api/invitations',
        decode: (json) => (json! as List)
            .map((e) => InvitationResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// What a token entitles the bearer to, before they accept.
  ///
  /// Public. Throws `ApiRequestException` with the server's message for an
  /// invalid or expired token — `failure("Invalid or expired invitation
  /// token")` at 404 (`InvitationRoutes.kt:41`) — which task 2.10 renders on
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
  /// `failure(response.message)` with 400 (`InvitationRoutes.kt:64`), so the
  /// message is specific and worth showing verbatim.
  ///
  /// The separate "already logged in" rejection (`InvitationRoutes.kt:49`)
  /// has the same shape but distinct meaning; task 2.11 keys off that message.
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
  /// with a message (`InvitationRoutes.kt:77`).
  Future<InvitationResponse> createInvitation(
    CreateInvitationRequest request,
  ) => _client.post<InvitationResponse>(
    '/api/invitations',
    request: request,
    decode: (json) =>
        InvitationResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Answers `success("Created invitation")` — a bare string.
  Future<String> deleteInvitation(int invitationId) =>
      _client.deleteWithBody<String>(
        '/api/invitations/$invitationId',
        decode: (json) => json! as String,
      );
}

/// Staff-hours and inventory-usage reports.
///
/// Replaces `ReportService` in `frontend/src/api/ReportService.ts`.
///
/// **Both endpoints are unpaginated** and return a list over the whole
/// organization — there is no `limit`/`offset`. Task 8.4 flags that org
/// scoping is *not* applied server-side (no `AuthContext` reaches
/// `ReportRoutes`), so the UI must filter; task 8.5 virtualizes the tables.
class ReportService {
  const ReportService(this._client);

  final ApiClient _client;

  /// Staff hours between [startDate] and [endDate] (`YYYY-MM-DD`).
  Future<List<StaffHoursReportResponse>> getStaffHoursReport({
    required String startDate,
    required String endDate,
  }) => _client.get<List<StaffHoursReportResponse>>(
    '/api/reports/staff_hours',
    query: {'startDate': startDate, 'endDate': endDate},
    decode: (json) => (json! as List)
        .map(
          (e) => StaffHoursReportResponse.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
  );

  Future<List<InventoryUsageReportResponse>> getInventoryUsageReport() =>
      _client.get<List<InventoryUsageReportResponse>>(
        '/api/reports/inventory_usage',
        decode: (json) => (json! as List)
            .map(
              (e) => InventoryUsageReportResponse.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

/// Roles and their permissions.
///
/// Replaces `RoleService` in `frontend/src/api/RoleService.ts`.
///
/// `GET /api/roles` is deliberately **ungated** (`RoleRoutes.kt:65` has no
/// `withPermission` wrapper), so any authenticated caller can list roles. Only
/// create/update/delete require `MANAGE_ROLES_GLOBAL`.
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

  // No create/update/delete. The React `RoleService` only ever calls
  // `getAllRoles`, and task 1.3 ported only `RoleResponse` — the create and
  // update request DTOs (`CreateRoleRequest`, `UpdateRoleRequest`) exist
  // server-side but were never needed by the app. Adding role *management*
  // is new feature work, not a port, so it is out of scope here.
}
