import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/theme/teven_theme.dart';
import '../models/event.dart';
import '../providers/event_details.dart';
import '../providers/event_list.dart';
import '../providers/service_providers.dart';
import 'error_display.dart';

/// The list of events waiting for this user's answer.
///
/// `RsvpWidget.tsx` (72 lines) — the "You have pending RSVP requests" card,
/// with an Accept and a Decline button on each row.
///
/// **The React component was never mounted.** It was added in `f13ae83`, the
/// same commit that added `GET /api/events/rsvps/requested`, and nothing has
/// imported it since. So the endpoint has been reachable and unused for the
/// whole life of the app, and the widget itself is the only place in the
/// React codebase that knows about it.
///
/// It is mounted here, on the calendar — which is the app's landing page and
/// which already marks a pending request in orange on the event's bar. The
/// card is the action for that mark: without it, a user can see that something
/// is waiting and have no way to answer it except by opening each event in
/// turn. Task 7.10 owns the question of whether the route should be exposed
/// at all; this is the answer this port gives it.
///
/// **The availability is a free-form string, not an enum.** The server type is
/// `String` with no validation (`RsvpRequest.kt`), so anything posted is
/// stored as-is. [RsvpAvailability.available] and
/// [RsvpAvailability.unavailable] are `String` constants for exactly that
/// reason — a Dart enum would be a closed set the server does not enforce.
/// Task 10.17 owns the question of whether the column should hold a closed
/// set.
class RsvpWidget extends ConsumerStatefulWidget {
  const RsvpWidget({super.key});

  @override
  ConsumerState<RsvpWidget> createState() => _RsvpWidgetState();
}

class _RsvpWidgetState extends ConsumerState<RsvpWidget> {
  /// The events answered in this sitting.
  ///
  /// **Removed locally rather than refetched,** which is what the React
  /// original does: `setRsvps(rsvps.filter(rsvp => rsvp.eventId !== eventId))`.
  /// The server now holds an `available` or `unavailable` row instead of a
  /// `requested` one, so the event is no longer in the requested list and a
  /// refetch would agree — but it would cost a round trip to say so.
  final Set<int> _answered = {};

  /// The events with a request in flight.
  ///
  /// Without it, a double click on "Accept" posts twice. The second post is
  /// harmless to the data and not harmless to the UI: the first removes the
  /// row, and the second answers an event that is no longer on screen.
  final Set<int> _pending = {};

  @override
  Widget build(BuildContext context) {
    final requested = ref.watch(requestedRsvpsProvider);
    final error = requested.whenOrNull(error: (error, stackTrace) => error);

    final events = (requested.value ?? const <EventResponse>[])
        .where((event) => !_answered.contains(event.eventId))
        .toList();

    // `RsvpWidget.tsx:43` returns `null` when there is nothing to show, and
    // the card is not part of the page's furniture — it appears only when
    // there is something to answer.
    if (error == null && events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              ErrorDisplay.fromException(
                error is ApiException ? error : ApiRequestException('$error'),
              )
            else ...[
              Text(
                'You have pending RSVP requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < events.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                _RsvpRow(
                  event: events[i],
                  pending: _pending.contains(events[i].eventId),
                  onAnswer: (availability) => _answer(events[i], availability),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Posts one availability and drops the row.
  ///
  /// **The row is dropped only on success.** React does the same
  /// (`RsvpWidget.tsx:31` is inside the `try`), and it matters: a failed post
  /// means the request is still outstanding, and hiding it would hide the
  /// thing the user needs to retry.
  Future<void> _answer(EventResponse event, String availability) async {
    if (_pending.contains(event.eventId)) {
      return;
    }
    setState(() => _pending.add(event.eventId));

    try {
      await ref
          .read(eventServiceProvider)
          .rsvpToEvent(event.eventId, RsvpRequest(availability: availability));
      if (!mounted) return;
      setState(() {
        _answered.add(event.eventId);
        _pending.remove(event.eventId);
      });

      // The calendar marks a pending request in orange on the event's bar, so
      // answering one has to take the mark off — otherwise the bar says
      // "waiting for you" about an event the user has just answered, until
      // the month happens to be re-queried.
      //
      // Invalidating the family rather than one instance: the widget does not
      // know which month the calendar is showing, and the calendar builds its
      // own query from its own state.
      ref.invalidate(calendarEventsProvider);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _pending.remove(event.eventId));
      _showError(context, error);
    }
  }

  /// The failure, in the card.
  ///
  /// **A dialog rather than a banner,** because the card itself is the thing
  /// the user was looking at when they pressed the button, and a banner that
  /// appears *in* it would push the rows down while they are being pressed.
  void _showError(BuildContext context, ApiException error) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not send your RSVP'),
        content: ErrorDisplay.fromException(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// One event's row: what it is, and the two answers.
class _RsvpRow extends StatelessWidget {
  const _RsvpRow({
    required this.event,
    required this.pending,
    required this.onAnswer,
  });

  final EventResponse event;
  final bool pending;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      // `d-flex justify-content-between align-items-center` in the original.
      // The text is `Expanded` rather than sized to its content, so a long
      // event title wraps instead of pushing the buttons off the edge — which
      // is what a `Wrap` of two freely-sized children would do on a phone.
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${event.date} at ${event.time}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TevenTheme.success,
                foregroundColor: Colors.white,
              ),
              onPressed: pending
                  ? null
                  : () => onAnswer(RsvpAvailability.available),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: TevenTheme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: pending
                  ? null
                  : () => onAnswer(RsvpAvailability.unavailable),
              child: const Text('Decline'),
            ),
          ],
        ),
      ],
    );
  }
}
