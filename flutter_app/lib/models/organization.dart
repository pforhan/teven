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
    required String timezone,
  }) = _OrganizationResponse;

  factory OrganizationResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationResponseFromJson(json);
}

@freezed
abstract class CreateOrganizationRequest with _$CreateOrganizationRequest {
  const factory CreateOrganizationRequest({
    required String name,
    required String contactInformation,
    required String timezone,
  }) = _CreateOrganizationRequest;

  factory CreateOrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrganizationRequestFromJson(json);
}

/// [name] and [contactInformation] are optional (null means leave unchanged).
/// [timezone] is required — an update always carries the new zone, mirroring
/// `UpdateOrganizationRequest.kt`.
@freezed
abstract class UpdateOrganizationRequest with _$UpdateOrganizationRequest {
  const factory UpdateOrganizationRequest({
    String? name,
    String? contactInformation,
    required String timezone,
  }) = _UpdateOrganizationRequest;

  factory UpdateOrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateOrganizationRequestFromJson(json);
}
