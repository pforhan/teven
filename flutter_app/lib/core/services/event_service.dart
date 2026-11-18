import '../../models/common.dart';
import '../../models/event.dart';
import '../api/api_client.dart';
import 'list_query.dart';

/// Events — the heaviest resource in the API.
///
/// Replaces the original event API service.
class EventService {
  const EventService(this._client);

  /// Historical client-side default kept for callers/tests that want an explicit
  /// small page size. The server now applies a default `limit` when omitted and
  /// echoes the applied value in the paginated response.
  static const int defaultLimit = 10;

  final ApiClient _client;

  /// Lists events.
  ///
  /// The date range, search, organization, sort, and pagination parameters pass
  /// straight through. If [ListQuery.limit] is omitted, the server applies its
  /// default and returns the applied limit in the response. Range-bounded event
  /// queries (with `startDate` and/or `endDate`) may request a higher explicit
  /// limit than general list queries, within the server-enforced cap.
  ///
  /// `sortBy` supports `startsAt`/`date` and `title`; other values fall back to
  /// start time. `sortOrder` defaults to `asc` server-side when omitted.
  Future<PaginatedResponse<EventResponse>> getAllEvents([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<EventResponse>>(
    '/api/events',
    query: query.toParams(),
    decode: (json) => PaginatedResponse.fromJson(
      json! as Map<String, dynamic>,
      (item) => EventResponse.fromJson(item! as Map<String, dynamic>),
    ),
  );

  Future<EventResponse> getEvent(int eventId) => _client.get<EventResponse>(
    '/api/events/$eventId',
    decode: (json) => EventResponse.fromJson(json! as Map<String, dynamic>),
  );

  Future<EventResponse> createEvent(CreateEventRequest request) =>
      _client.post<EventResponse>(
        '/api/events',
        request: request,
        decode: (json) => EventResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Updates an event and returns the saved event.
  Future<EventResponse> updateEvent(int eventId, UpdateEventRequest request) =>
      _client.put<EventResponse>(
        '/api/events/$eventId',
        request: request,
        decode: (json) => EventResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Answers `204 NoContent`.
  Future<void> deleteEvent(int eventId) =>
      _client.delete('/api/events/$eventId');

  /// Posts this user's RSVP and returns the updated event.
  Future<EventResponse> rsvpToEvent(int eventId, RsvpRequest request) =>
      _client.post<EventResponse>(
        '/api/events/$eventId/rsvp',
        request: request,
        decode: (json) => EventResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Events awaiting this user's RSVP.
  ///
  /// **Undocumented** — absent from `API.md`, but implemented in
  /// `EventRoutes`.
  Future<List<EventResponse>> getRequestedRsvps() =>
      _client.get<List<EventResponse>>(
        '/api/events/rsvps/requested',
        decode: (json) => (json! as List)
            .map((e) => EventResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
