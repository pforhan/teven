import '../../models/common.dart';
import '../../models/event.dart';
import '../api/api_client.dart';
import 'list_query.dart';

/// Events — the heaviest resource in the API, and the one with the most
/// response quirks.
///
/// Replaces `EventService` in `frontend/src/api/EventService.ts`.
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
  /// "default limit"** — `EventDao.kt:180` does `limit?.let { query.limit(it) }`,
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
  /// **`sortBy` does nothing.** `EventRoutes.kt` accepts a `sortBy` parameter
  /// but `EventDao` never reads it — it always orders by date. Passing it is
  /// accepted and ignored, so do not rely on it; the UI must sort client-side
  /// if it needs to. This is flagged in task 1.16 and in FLUTTER-CONVERT.md's
  /// discrepancy table.
  ///
  /// `sortOrder` **does** work, and defaults to `asc` server-side when
  /// omitted (`EventRoutes.kt:80`) — so the first event returned is the
  /// earliest, not the most recent. Callers wanting recent-first must pass
  /// [SortOrder.desc] explicitly.
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

  /// Updates an event.
  ///
  /// Answers `success("Event with ID N updated")` — a **bare string, not an
  /// `EventResponse`**. The React `EventService.updateEvent` claims
  /// `Promise<EventResponse>` and hands callers an object they never receive;
  /// the `String` return here is what the server actually does. Task 6.9
  /// depends on this, and task 10.10 would change it server-side.
  Future<String> updateEvent(int eventId, UpdateEventRequest request) =>
      _client.put<String>(
        '/api/events/$eventId',
        request: request,
        body: ResponseBody.bareString,
        decode: (json) => json! as String,
      );

  /// Answers `204 NoContent`.
  Future<void> deleteEvent(int eventId) =>
      _client.delete('/api/events/$eventId');

  /// Posts this user's RSVP. Answers `success("OK")`.
  Future<String> rsvpToEvent(int eventId, RsvpRequest request) =>
      _client.post<String>(
        '/api/events/$eventId/rsvp',
        request: request,
        body: ResponseBody.bareString,
        decode: (json) => json! as String,
      );

  /// Events awaiting this user's RSVP.
  ///
  /// **Undocumented** — absent from `API.md`, but real
  /// (`EventRoutes.kt:118`). Task 7.10 decides whether the UI exposes it.
  Future<List<EventResponse>> getRequestedRsvps() =>
      _client.get<List<EventResponse>>(
        '/api/events/rsvps/requested',
        decode: (json) => (json! as List)
            .map((e) => EventResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// **Not implemented.** The React app calls `POST /api/events/{id}/join`
  /// (`EventService.ts:56`), but no such route exists in `EventRoutes.kt` —
  /// the request 404s at the `/api` catch-all. Omitted rather than stubbed so
  /// the compiler surfaces it. See the discrepancy table.
}
