import 'package:freezed_annotation/freezed_annotation.dart';

part 'role.freezed.dart';
part 'role.g.dart';

/// A role and the permissions it grants.
///
/// Mirrors `RoleResponse` in
/// `backend/api/.../model/role/RoleResponse.kt`.
@freezed
abstract class RoleResponse with _$RoleResponse {
  const factory RoleResponse({
    required int roleId,
    required String roleName,
    @Default(<String>[]) List<String> permissions,
  }) = _RoleResponse;

  factory RoleResponse.fromJson(Map<String, dynamic> json) =>
      _$RoleResponseFromJson(json);
}

/// Well-known role names.
///
/// Mirrors `Constants` in `frontend/src/core/Constants.ts`. The server stores
/// roles by name in a string column, so these are compared as strings rather
/// than by id.
abstract final class RoleNames {
  const RoleNames._();

  static const String superAdmin = 'SuperAdmin';
  static const String organizer = 'Organizer';
}
