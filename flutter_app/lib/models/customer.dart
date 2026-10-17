import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

/// A customer, with its owning organization embedded.
///
/// Mirrors `CustomerResponse` in
/// `backend/api/.../model/customer/CustomerResponse.kt`.
///
/// The geo fields (`latitude`, `longitude`, `formattedAddress`) are absent
/// from the React types in `frontend/src/types/customers.ts` but **are** on
/// the wire. They are included here so the data is not silently dropped; the
/// backend's geo service is currently dead code (see FLUTTER-CONVERT.md's
/// discrepancy table), so these are normally null.
@freezed
abstract class CustomerResponse with _$CustomerResponse {
  const factory CustomerResponse({
    required int customerId,
    required String name,
    @Default('') String phone,
    @Default('') String address,
    @Default('') String notes,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    required OrganizationResponse organization,
  }) = _CustomerResponse;

  factory CustomerResponse.fromJson(Map<String, dynamic> json) =>
      _$CustomerResponseFromJson(json);
}

@freezed
abstract class CreateCustomerRequest with _$CreateCustomerRequest {
  const factory CreateCustomerRequest({
    required String name,
    @Default('') String phone,
    @Default('') String address,
    @Default('') String notes,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    int? organizationId,
  }) = _CreateCustomerRequest;

  factory CreateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCustomerRequestFromJson(json);
}

/// All fields optional. Null means "leave unchanged".
@freezed
abstract class UpdateCustomerRequest with _$UpdateCustomerRequest {
  const factory UpdateCustomerRequest({
    String? name,
    String? phone,
    String? address,
    String? notes,
    double? latitude,
    double? longitude,
    String? formattedAddress,

    /// **Serialized only when set** (`includeIfNull: false`), so "leave
    /// unchanged" is expressed by *omitting* the key rather than by sending an
    /// explicit `null`.
    ///
    /// The distinction is invisible against this server and load-bearing
    /// against the next one: `CustomerService.kt:93` reads
    /// `organizationId != null && organizationId != customer.organizationId`,
    /// so today an explicit `null` is accepted and the customer keeps its
    /// organization. A server that instead tested *presence* — which is how
    /// "omitted" is normally spelled — would see `organizationId: null` from
    /// every `Organizer` edit and throw
    /// `Non-MANAGE_CUSTOMERS_GLOBAL users cannot change customer
    /// organizationId` on each one.
    ///
    /// **Scoped to this one field deliberately.** A global
    /// `includeIfNull: false` would also stop `CreateCustomerRequest` sending
    /// its optional geo fields as null, which changes a payload several other
    /// tests assert on, and the create form's rule is a different one: the
    /// server *requires* an organization id from a global manager
    /// (`CustomerService.kt:62`) and reads "absent" and "null" the same way.
    @JsonKey(includeIfNull: false) int? organizationId,
  }) = _UpdateCustomerRequest;

  factory UpdateCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCustomerRequestFromJson(json);
}
