import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../models/event.dart';
import '../providers/event_details.dart';
import '../providers/event_list.dart';
import '../providers/service_providers.dart';
import '../providers/time_zone_controller.dart';
import 'error_display.dart';
import 'rsvp_buttons.dart';

/// The list of events waiting for this user's answer.
///
/// The "You have pending RSVP requests" card, with an Accept and a Decline
/// button on each row.
///
/// **The original component was never mounted.** It was added in `f13ae83`, the
/// same commit that added `GET /api/events/rsvps/requested`, and nothing ever
/// imported it. So the endpoint had been reachable and unused for the whole life
/// of the app, and the widget itself was the only place in the original codebase
/// that knew about it.
///
/// It is mounted here, on the calendar — which is the app's landing page and
/// which already marks a pending request in orange on the event's bar. The card
/// is the action for that mark: without it, a user can see that something is
/// waiting and have no way to answer it except by opening each event in turn.
/// Whether this should live behind a route at all is an open question; this is
/// the answer this port gives it.
///
/// Pending RSVP requests, with Accept/Decline/Tentative actions.
class RsvpWidget extends ConsumerStatefulWidget {
  const RsvpWidget({super.key});

  @override
  ConsumerState<RsvpWidget> createState() => _RsvpWidgetState();
}

class _RsvpWidgetState extends ConsumerState<RsvpWidget> {
  /// The events answered in this sitting.
  ///
  /// **Removed locally rather than refetched,** which is what the original did:
  /// filter the answered event out of local state. The server now holds an
  /// `available` or `unavailable` row instead of a `requested` one, so the event
  /// is no longer in the requested list and a refetch would agree — but it would
  /// cost a round trip to say so.
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
    final readerZone =
        ref.watch(timeZoneControllerProvider).value?.effectiveZone ?? 'UTC';

    final events = (requested.value ?? const <EventResponse>[])
        .where((event) => !_answered.contains(event.eventId))
        .toList();

    // The original returned `null` when there was nothing to show, and the card
    // is not part of the page's furniture — it appears only when there is
    // something to answer.
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
                  readerZone: readerZone,
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
  /// **The row is dropped only on success.** The original did the same, and it
  /// matters: a failed post means the request is still outstanding, and hiding
  /// it would hide the thing the user needs to retry.
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
      _showSnackBar('RSVP updated to ${_rsvpLabel(availability)}.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _pending.remove(event.eventId));
      _showSnackBar(error.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  static String _rsvpLabel(String availability) => switch (availability) {
    RsvpAvailability.accepted => 'Yes',
    RsvpAvailability.declined => 'No',
    RsvpAvailability.tentative => 'Maybe',
    RsvpAvailability.needsAction => 'No response',
    _ => availability,
  };
}

/// One event's row: what it is, and the two answers.
class _RsvpRow extends StatelessWidget {
  const _RsvpRow({
    required this.event,
    required this.readerZone,
    required this.pending,
    required this.onAnswer,
  });

  final EventResponse event;
  final String readerZone;
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
                '${event.dateIn(readerZone)} at ${event.timeIn(readerZone)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RsvpButtons(
          currentAvailability: RsvpAvailability.needsAction,
          enabled: !pending,
          onSelected: onAnswer,
        ),
      ],
    );
  }
}
