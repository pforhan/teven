import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/util/local_date.dart';
import 'customer.dart';
import 'organization.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// An event, with its customer, organization, RSVP list, and inventory all
/// embedded.
///
/// Mirrors `EventResponse` in
/// `backend/api/.../model/event/EventResponse.kt`.
///
/// **Payload weight.** The server does no compression of this nesting —
/// `ktor-server-compression` is not installed — and there is no way to ask
/// for a summary variant. One event with a large RSVP list is a large JSON
/// object. Task 1.18 sets a default `limit` of 10 for that reason.
///
/// **Time.** [startsAt] is the instant (offset-bearing ISO 8601) and [timezone]
/// is the IANA zone the wall clock was picked in — one fact, travelling
/// together. [date] and [time] are the wall clock computed by the server in the
/// event's own zone; they remain on the wire until the legacy fields are retired
/// and existing readers are ported to zone-aware rendering.
@freezed
abstract class EventResponse with _$EventResponse {
  const factory EventResponse({
    required int eventId,
    required String title,
    required String date,
    required String time,
    required String startsAt,
    required String timezone,
    @Default(0) int durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? description,
    @Default(<EventInventoryItem>[]) List<EventInventoryItem> inventoryItems,
    CustomerResponse? customer,
    @Default(<RsvpStatus>[]) List<RsvpStatus> rsvps,
    required OrganizationResponse organization,
    @Default(false) bool openInvitation,
    @Default(0) int numberOfStaffNeeded,
  }) = _EventResponse;

  const EventResponse._();

  factory EventResponse.fromJson(Map<String, dynamic> json) =>
      _$EventResponseFromJson(json);

  /// The event's start as a UTC instant.
  ///
  /// Parsed from [startsAt], which is offset-bearing ISO 8601. Conversions that
  /// render this for a reader take the reader's zone as an argument — the model
  /// never picks a zone itself.
  DateTime get instant => DateTime.parse(startsAt).toUtc();

  /// The wall clock of [instant] read in [zoneId].
  DateTime wallClockIn(String zoneId) => wallClockInZone(instant, zoneId);

  /// The event's local date (`yyyy-MM-dd`) in [zoneId].
  String dateIn(String zoneId) => formatDateInZone(instant, zoneId);

  /// The event's time of day in [zoneId], formatted for display.
  String timeIn(String zoneId) => formatTimeInZone(instant, zoneId);

  /// Start of the event as the wall clock in the event's own [timezone].
  ///
  /// Kept for callers not yet ported to the reader-zone conversions. Prefer
  /// [wallClockIn], [dateIn], and [timeIn] with an explicit zone.
  DateTime get startAt => wallClockIn(timezone);

  /// End of the event, computed as [startAt] plus [durationMinutes].
  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  /// The hour the event starts in its own [timezone].
  int get startHour => startAt.hour;
}

/// One inventory line on an event.
///
/// [itemName] is denormalized onto the event so the calendar can render a
/// label without a second fetch.
@freezed
abstract class EventInventoryItem with _$EventInventoryItem {
  const factory EventInventoryItem({
    required int inventoryId,
    required String itemName,
    @Default(0) int quantity,
  }) = _EventInventoryItem;

  factory EventInventoryItem.fromJson(Map<String, dynamic> json) =>
      _$EventInventoryItemFromJson(json);
}

/// One person's RSVP to an event.
///
/// [availability] is a **free-form string**, not an enum. The server type is
/// `String` with no validation (`RsvpRequest.kt`), and the app posts
/// `"available"`, `"unavailable"`, and `"requested"` — the last of which has
/// no matching constant on the Kotlin side. Modelling it as an enum would
/// mean inventing server-side validation that does not exist, and would throw
/// on an unrecognized value. See [RsvpAvailability].
@freezed
abstract class RsvpStatus with _$RsvpStatus {
  const factory RsvpStatus({
    required int userId,
    required String displayName,
    @Default('') String email,
    @Default('') String availability,
  }) = _RsvpStatus;

  factory RsvpStatus.fromJson(Map<String, dynamic> json) =>
      _$RsvpStatusFromJson(json);
}

/// The availability values this app posts.
///
/// [requested] is server-initiated: it marks an event awaiting the user's
/// RSVP and is never sent by the client.
abstract final class RsvpAvailability {
  const RsvpAvailability._();

  static const String available = 'available';
  static const String unavailable = 'unavailable';
  static const String requested = 'requested';
}

/// How an event asks for staff.
///
/// This is the **only** staffing mechanism. The staff endpoints documented in
/// `API.md:343-351` do not exist server-side — see FLUTTER-CONVERT-DESIGN.md's
/// discrepancy table.
///
/// [specificStaffIds] and [openInvitation] are the two mutually-exclusive
/// modes: invite named staff, or open it to anyone. The server accepts either
/// or both, with no validation, so the form is responsible for not sending
/// both.
@freezed
abstract class StaffInviteDetails with _$StaffInviteDetails {
  const factory StaffInviteDetails({
    List<int>? specificStaffIds,
    @Default(false) bool openInvitation,
    @Default(0) int numberOfStaffNeeded,
  }) = _StaffInviteDetails;

  factory StaffInviteDetails.fromJson(Map<String, dynamic> json) =>
      _$StaffInviteDetailsFromJson(json);
}

@freezed
abstract class CreateEventRequest with _$CreateEventRequest {
  const factory CreateEventRequest({
    required String title,
    required String startsAt,
    required String timezone,
    @Default(0) int durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? description,
    @Default(<EventInventoryItem>[]) List<EventInventoryItem> inventoryItems,
    int? customerId,
    @Default(_noStaffInvites) StaffInviteDetails staffInvites,
    required int organizationId,
  }) = _CreateEventRequest;

  factory CreateEventRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateEventRequestFromJson(json);
}

/// `staffInvites` is required on the wire (`CreateEventRequest.kt` has no
/// default), but "no invites" is a valid state, so it gets a default rather
/// than forcing every caller to spell it out.
const StaffInviteDetails _noStaffInvites = StaffInviteDetails();

/// All fields optional, including [organizationId].
///
/// [organizationId] is nullable here but **required** on
/// [CreateEventRequest], and that asymmetry is the server's rather than an
/// accident. `EventService.kt:20-22` throws `"organizationId is required for
/// MANAGE_EVENTS_GLOBAL users"` on create; on update it treats a missing id as
/// "leave it alone" and throws only when a **non-null, differing** id arrives
/// from someone without `MANAGE_EVENTS_GLOBAL`.
///
/// **Modelling it as required would be a latent 500.** Sending the event's own
/// organization back is harmless only because that is the value the screen seeds
/// from; any change to how the form resolves the organization would turn it
/// into `Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId`,
/// with nothing on the client saying the field was the problem.
///
/// [startsAt] and [timezone] are one fact and travel together — send **both or
/// neither**. [startsAt] carries the zone's offset at the event's date.
///
/// Note `PUT /api/events/{id}` answers with `data: "Event with ID N updated"`
/// — a **bare string, not an [EventResponse]** (`EventRoutes.kt:71`). Task
/// 6.9 handles that.
@freezed
abstract class UpdateEventRequest with _$UpdateEventRequest {
  const factory UpdateEventRequest({
    String? title,
    String? startsAt,
    String? timezone,
    int? durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? description,
    List<EventInventoryItem>? inventoryItems,
    int? customerId,
    StaffInviteDetails? staffInvites,
    int? organizationId,
  }) = _UpdateEventRequest;

  factory UpdateEventRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateEventRequestFromJson(json);
}

@freezed
abstract class RsvpRequest with _$RsvpRequest {
  const factory RsvpRequest({required String availability}) = _RsvpRequest;

  factory RsvpRequest.fromJson(Map<String, dynamic> json) =>
      _$RsvpRequestFromJson(json);
}
