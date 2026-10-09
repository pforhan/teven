import 'package:freezed_annotation/freezed_annotation.dart';

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
/// **Timezones.** [date] is `"YYYY-MM-DD"` and [time] is `"HH:MM:SS"`, both
/// **timezone-naive** strings from the server. They are deliberately left as
/// `String` rather than eagerly converted to `DateTime`: an implicit
/// conversion would have to pick a zone, and picking UTC would silently shift
/// events. See the `DateTime` helpers below and task 7.9.
@freezed
abstract class EventResponse with _$EventResponse {
  const factory EventResponse({
    required int eventId,
    required String title,
    required String date,
    required String time,
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

  /// Start of the event as a local [DateTime].
  ///
  /// Constructed from [date] and [time] directly, never via
  /// `DateTime.parse(date + 'T' + time)`. That expression is what the React
  /// app does (`EventCalendar.tsx:230`) and it is fragile: it depends on
  /// `DateTime.parse` treating a zone-less string as *local*, which is true
  /// but unstated. Building from components makes the naive-local assumption
  /// explicit and fails loudly on a malformed value rather than silently
  /// producing midnight.
  DateTime get startAt {
    final parsedDate = DateTime.parse(date);
    final timeParts = time.split(':');
    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      int.parse(timeParts[0]),
      timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
      timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
    );
  }

  /// End of the event, computed as [startAt] plus [durationMinutes].
  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  /// The hour `time` names, for calendar layout.
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
/// `API.md:343-351` do not exist server-side — see FLUTTER-CONVERT.md's
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
    required String date,
    required String time,
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

/// All fields optional except [organizationId].
///
/// Note `PUT /api/events/{id}` answers with `data: "Event with ID N updated"`
/// — a **bare string, not an [EventResponse]** (`EventRoutes.kt:71`). Task
/// 6.9 handles that.
@freezed
abstract class UpdateEventRequest with _$UpdateEventRequest {
  const factory UpdateEventRequest({
    String? title,
    String? date,
    String? time,
    int? durationMinutes,
    String? location,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? description,
    List<EventInventoryItem>? inventoryItems,
    int? customerId,
    StaffInviteDetails? staffInvites,
    required int organizationId,
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
