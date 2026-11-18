import '../../models/common.dart';
import '../../models/event.dart';
import '../api/api_client.dart';
import 'list_query.dart';

/// Events — the heaviest resource in the API, and the one with the most
/// response quirks.
///
/// Replaces the original event API service.
class EventService {
  const EventService(this._client);

  /// Page size used when a caller does not specify one.
  ///
  /// Small on purpose. An `EventResponse` embeds the customer, the
  /// organization, every inventory line, and **every RSVP**, and the server
  /// applies no compression (`ktor-server-compression` is not installed). Ten
  /// events with a dozen RSVPs each is already a large JSON payload; an
  /// uncapped query over a busy organization is a multi-megabyte response.
  ///
  /// This matters more than it looks because **omitting `limit` does not mean
  /// "default limit"** — `EventDao.kt` does `limit?.let { query.limit(it) }`,
  /// so a null `limit` applies no cap and returns the entire matching table.
  /// Always send one.
  static const int defaultLimit = 10;

  final ApiClient _client;

  /// Lists events.
  ///
  /// [query] is merged over [defaultLimit]: any caller-supplied `limit` wins,
  /// and a null one becomes the default. The date range, search, organization,
  /// and sort order pass straight through.
  ///
  /// `sortBy` supports `startsAt` and `title`; other values fall back to start
  /// time. `sortOrder` defaults to `asc` server-side when omitted, so the first
  /// event returned is the earliest unless [SortOrder.desc] is passed.
  Future<PaginatedResponse<EventResponse>> getAllEvents([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<EventResponse>>(
    '/api/events',
    query: query.copyWith(limit: query.limit ?? defaultLimit).toParams(),
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
