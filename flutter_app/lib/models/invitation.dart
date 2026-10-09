import 'package:freezed_annotation/freezed_annotation.dart';

part 'invitation.freezed.dart';
part 'invitation.g.dart';

/// An outstanding invitation to join an organization in a role.
///
/// [token] is the invite link's secret. It travels in the URL the invitee
/// receives, so it must not be treated as a display field.
///
/// Mirrors `InvitationResponse` in
/// `backend/api/.../model/invitation/InvitationResponse.kt`. [expiresAt] and
/// [createdAt] are timezone-naive strings, as everywhere else.
@freezed
abstract class InvitationResponse with _$InvitationResponse {
  const factory InvitationResponse({
    required int invitationId,
    required int organizationId,
    required int roleId,
    @Default('') String roleName,
    required String token,
    @Default('') String expiresAt,
    int? usedByUserId,
    @Default('') String createdAt,
    String? note,
  }) = _InvitationResponse;

  factory InvitationResponse.fromJson(Map<String, dynamic> json) =>
      _$InvitationResponseFromJson(json);
}

/// What a valid token entitles the bearer to, before they accept.
///
/// Fetched by `GET /api/invitations/validate` so the acceptance screen can
/// name the organization and role it is about to join.
@freezed
abstract class ValidateInvitationResponse with _$ValidateInvitationResponse {
  const factory ValidateInvitationResponse({
    required int organizationId,
    required String organizationName,
    @Default('') String roleName,
  }) = _ValidateInvitationResponse;

  factory ValidateInvitationResponse.fromJson(Map<String, dynamic> json) =>
      _$ValidateInvitationResponseFromJson(json);
}

@freezed
abstract class CreateInvitationRequest with _$CreateInvitationRequest {
  const factory CreateInvitationRequest({
    required int roleId,
    String? expiresAt,
    int? organizationId,
    String? note,
  }) = _CreateInvitationRequest;

  factory CreateInvitationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateInvitationRequestFromJson(json);
}

/// The body of `POST /api/invitations/accept`.
///
/// The invitee supplies their own credentials here. Roles come from the
/// invitation, not this body — the server converts it server-side and forces
/// `roles = emptyList()` (`AcceptInvitationRequest.kt`).
@freezed
abstract class AcceptInvitationRequest with _$AcceptInvitationRequest {
  const factory AcceptInvitationRequest({
    required String token,
    required String username,
    required String password,
    @Default('') String email,
    @Default('') String displayName,
  }) = _AcceptInvitationRequest;

  factory AcceptInvitationRequest.fromJson(Map<String, dynamic> json) =>
      _$AcceptInvitationRequestFromJson(json);
}

/// The result of accepting an invitation. Wrapped in the usual
/// `{success, data, error}` envelope, so it unwraps normally.
///
/// The nesting matters: `success` here is the *DTO's* own field, distinct
/// from the envelope's. The service returns `success = false` with a reason
/// (`"Invitation has expired."`, `"Username already taken."`) and the route
/// turns that into an **envelope-level** failure — `failure(response.message)`
/// with HTTP 400 (`InvitationRoutes.kt:64`). So a `success: false` value is
/// never seen by the client; only the message survives, as `ApiError.message`.
///
/// [message] is therefore always present on a successful response too
/// (`"Invitation accepted and user created."`).
///
/// The logged-in-caller rejection is a separate path: `InvitationRoutes.kt:49`
/// answers `failure("Cannot accept invitation while logged in.")` with 400
/// **before** reaching the service. That is the case task 2.11's
/// `AlreadyLoggedInError` renders.
@freezed
abstract class AcceptInvitationResponse with _$AcceptInvitationResponse {
  const factory AcceptInvitationResponse({
    @Default(false) bool success,
    String? message,
  }) = _AcceptInvitationResponse;

  factory AcceptInvitationResponse.fromJson(Map<String, dynamic> json) =>
      _$AcceptInvitationResponseFromJson(json);
}
