import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization.freezed.dart';
part 'organization.g.dart';

/// An organization. The unit every other resource is scoped to.
///
/// Mirrors `OrganizationResponse` in
/// `backend/api/.../model/organization/OrganizationResponse.kt`.
@freezed
abstract class OrganizationResponse with _$OrganizationResponse {
  const factory OrganizationResponse({
    required int organizationId,
    required String name,
    @Default('') String contactInformation,
  }) = _OrganizationResponse;

  factory OrganizationResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationResponseFromJson(json);
}

@freezed
abstract class CreateOrganizationRequest with _$CreateOrganizationRequest {
  const factory CreateOrganizationRequest({
    required String name,
    required String contactInformation,
  }) = _CreateOrganizationRequest;

  factory CreateOrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrganizationRequestFromJson(json);
}

/// Every field optional — a partial update. Null means "leave unchanged",
/// matching `UpdateOrganizationRequest.kt`, where every property defaults to
/// null.
@freezed
abstract class UpdateOrganizationRequest with _$UpdateOrganizationRequest {
  const factory UpdateOrganizationRequest({
    String? name,
    String? contactInformation,
  }) = _UpdateOrganizationRequest;

  factory UpdateOrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateOrganizationRequestFromJson(json);
}
