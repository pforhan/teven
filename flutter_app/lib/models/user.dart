import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// A user, with roles as **names** and their organization embedded.
///
/// Roles are strings, not ids — the server compares them by name against the
/// role table, and the create-user request lets a caller pass names directly
/// (`CreateUserRequest.kt`).
///
/// Mirrors `UserResponse` in `backend/api/.../model/user/UserResponse.kt`.
@freezed
abstract class UserResponse with _$UserResponse {
  const factory UserResponse({
    required int userId,
    required String username,
    @Default('') String email,
    @Default('') String displayName,
    @Default(<String>[]) List<String> roles,
    StaffDetails? staffDetails,
    required OrganizationResponse organization,
  }) = _UserResponse;

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);
}

/// Staff-specific profile fields. Absent for non-staff users.
///
/// Note [hoursWorked] is non-null whenever this object is present, even for a
/// staff member who has never worked an event.
@freezed
abstract class StaffDetails with _$StaffDetails {
  const factory StaffDetails({
    @Default('') String contactInformation,
    @Default(<String>[]) List<String> skills,
    @Default(0) int hoursWorked,
    @Default('') String phoneNumber,
    String? dateOfBirth,
  }) = _StaffDetails;

  factory StaffDetails.fromJson(Map<String, dynamic> json) =>
      _$StaffDetailsFromJson(json);
}

/// Partial staff fields, for `PUT /api/users/{userId}`.
///
/// Separate from [StaffDetails] because [StaffDetails.hoursWorked] is
/// server-computed and not writable.
@freezed
abstract class UpdateStaffDetails with _$UpdateStaffDetails {
  const factory UpdateStaffDetails({
    String? contactInformation,
    List<String>? skills,
    String? phoneNumber,
    String? dateOfBirth,
  }) = _UpdateStaffDetails;

  factory UpdateStaffDetails.fromJson(Map<String, dynamic> json) =>
      _$UpdateStaffDetailsFromJson(json);
}

/// The authenticated user plus the permissions they hold **in the currently
/// selected organization**.
///
/// This is the gating source for the whole UI: every nav item and route guard
/// reads `permissions` from here, not from the user's global roles. Task 2.3
/// derives `hasPermission` from it, and task 2.4 refetches it when a
/// super-admin switches organization — the same URL, different auth context.
///
/// Mirrors `LoggedInContextResponse` in
/// `backend/api/.../model/auth/LoggedInContextResponse.kt`.
///
/// Kept as a `List<String>` rather than `List<Permission>` on purpose: the
/// server may grant a permission this build does not know about, and an
/// unknown value should not fail the whole context fetch. Gate on it with
/// `Permissions.has` / `Permissions.hasAny`.
@freezed
abstract class UserContextResponse with _$UserContextResponse {
  const factory UserContextResponse({
    required UserResponse user,
    @Default(<String>[]) List<String> permissions,
  }) = _UserContextResponse;

  factory UserContextResponse.fromJson(Map<String, dynamic> json) =>
      _$UserContextResponseFromJson(json);
}

@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String username,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

@freezed
abstract class LoginResponse with _$LoginResponse {
  const factory LoginResponse({
    required String token,
    required UserResponse user,
  }) = _LoginResponse;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
}

@freezed
abstract class CreateUserRequest with _$CreateUserRequest {
  const factory CreateUserRequest({
    required String username,
    required String password,
    @Default('') String email,
    @Default('') String displayName,
    @Default(<String>[]) List<String> roles,
    required int organizationId,
  }) = _CreateUserRequest;

  factory CreateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateUserRequestFromJson(json);
}

/// All fields optional. Null means "leave unchanged".
///
/// [roles] and [organizationId] are silently **ignored** unless the caller is
/// a super-admin (`CreateUserRequest.kt` says as much, and `UserService`
/// enforces it) — sending them as a non-super-admin does not error, it just
/// has no effect. That is a footgun worth knowing about before task 5.5.
@freezed
abstract class UpdateUserRequest with _$UpdateUserRequest {
  const factory UpdateUserRequest({
    String? email,
    String? displayName,
    List<String>? roles,
    UpdateStaffDetails? staffDetails,
    int? organizationId,
  }) = _UpdateUserRequest;

  factory UpdateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateUserRequestFromJson(json);
}
