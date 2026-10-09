import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization.dart';

part 'inventory.freezed.dart';
part 'inventory.g.dart';

/// An inventory item and the events consuming it.
///
/// Mirrors `InventoryItemResponse` in
/// `backend/api/.../model/inventory/InventoryItemResponse.kt`.
///
/// [events] is **unpaginated** — the server embeds every event that has ever
/// drawn on this item, with no `limit`/`offset`. Task 4.5 caps display
/// client-side. The list can be long for a heavily-used item.
@freezed
abstract class InventoryItemResponse with _$InventoryItemResponse {
  const factory InventoryItemResponse({
    required int inventoryId,
    required String name,
    @Default('') String description,
    @Default(0) int quantity,
    @Default(<EventSummaryResponse>[]) List<EventSummaryResponse> events,
    required OrganizationResponse organization,
  }) = _InventoryItemResponse;

  factory InventoryItemResponse.fromJson(Map<String, dynamic> json) =>
      _$InventoryItemResponseFromJson(json);
}

/// An event's use of an inventory item. Not a full event.
///
/// Mirrors `EventSummaryResponse` in
/// `backend/api/.../model/event/EventSummaryResponse.kt`.
@freezed
abstract class EventSummaryResponse with _$EventSummaryResponse {
  const factory EventSummaryResponse({
    required int eventId,
    required String title,
    @Default(0) int quantity,
  }) = _EventSummaryResponse;

  factory EventSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$EventSummaryResponseFromJson(json);
}

@freezed
abstract class CreateInventoryItemRequest with _$CreateInventoryItemRequest {
  const factory CreateInventoryItemRequest({
    required String name,
    @Default('') String description,
    @Default(0) int quantity,
    int? organizationId,
  }) = _CreateInventoryItemRequest;

  factory CreateInventoryItemRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateInventoryItemRequestFromJson(json);
}

/// All fields optional. Null means "leave unchanged".
@freezed
abstract class UpdateInventoryItemRequest with _$UpdateInventoryItemRequest {
  const factory UpdateInventoryItemRequest({
    String? name,
    String? description,
    int? quantity,
    int? organizationId,
  }) = _UpdateInventoryItemRequest;

  factory UpdateInventoryItemRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateInventoryItemRequestFromJson(json);
}

@freezed
abstract class TrackInventoryUsageRequest with _$TrackInventoryUsageRequest {
  const factory TrackInventoryUsageRequest({
    required int eventId,
    required int quantity,
  }) = _TrackInventoryUsageRequest;

  factory TrackInventoryUsageRequest.fromJson(Map<String, dynamic> json) =>
      _$TrackInventoryUsageRequestFromJson(json);
}
