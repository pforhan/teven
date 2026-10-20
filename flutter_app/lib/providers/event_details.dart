import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/event.dart';
import 'paged_list.dart';
import 'service_providers.dart';

/// The events this user has been asked to RSVP to, and has not answered.
///
/// **`GET /api/events/rsvps/requested` is undocumented** — absent from
/// `API.md` — but real (`EventRoutes.kt:118`). It is the only endpoint that
/// answers "what is waiting for me?", and it is what the React `RsvpWidget`
/// fetches.
///
/// **The React widget was never mounted.** `RsvpWidget.tsx` was added in
/// `f13ae83` — the same commit that added the route — and has never been
/// imported by anything since. It is dead code, and the route behind it has
/// been reachable but unused for the whole life of the app. Task 7.6 ports it
/// and gives it somewhere to live; task 7.10 owns the question of whether the
/// route should be exposed at all.
///
/// **`retry: noRetry`,** for the reason the list providers set it: a 403 is
/// not transient, so Riverpod's automatic retry would spend three requests
/// proving it.
final requestedRsvpsProvider = FutureProvider.autoDispose<List<EventResponse>>(
  (ref) => ref.watch(eventServiceProvider).getRequestedRsvps(),
  retry: noRetry,
);
