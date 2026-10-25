import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/create_event_button.dart';
import '../../widgets/other_events_panel.dart';

/// The day view — task 7.11, plus day-to-day navigation.
///
/// The screen a selected day opens on. The month grid has no day view of its
/// own — task 7.1 dropped the one the calendar this replaced had — and task 7.2
/// filed the gap: a touch's tap is inert because there was nowhere for it to go,
/// and when that landed (task 7.11) it opens **here**.
///
/// **It reuses [OtherEventsPanel] rather than growing a second event list**, for
/// the reason task 9.13 records twice and task 9.18 tests once: a second copy
/// of a list is how the two event forms drifted in the first place.
///
/// The chevrons move one calendar day at a time. A previous/next gesture turns
/// into a fresh route target so that the day in the URL is the day on screen,
/// the same way the create gesture builds a `?date=` URL from a [DateTime].
class EventDayScreen extends ConsumerStatefulWidget {
  const EventDayScreen({super.key, required this.date});

  /// The day under view, as `yyyy-MM-dd` — the same wire format and the same
  /// value the calendar hands to the create form's `?date=` parameter, and the
  /// panel's contract.
  final String date;

  @override
  ConsumerState<EventDayScreen> createState() => _EventDayScreenState();
}

class _EventDayScreenState extends ConsumerState<EventDayScreen> {
  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(selectedOrganizationProvider);
    final organizationId = organization?.organizationId.toString() ?? '';

    // The day is a wire date (`YYYY-MM-DD`); the previous and next gestures
    // move a single calendar day in the reader's local date, which is the only
    // date the day view claims to show.
    final day = DateTime.tryParse(widget.date) ?? DateTime.now();
    final previous = day.subtract(const Duration(days: 1));
    final next = day.add(const Duration(days: 1));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () =>
                      context.go(AppRoutes.eventDayUrlForDay(previous)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMMEEEEd().format(day),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () =>
                      context.go(AppRoutes.eventDayUrlForDay(next)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: OtherEventsPanel(
                date: widget.date,
                organizationId: organizationId,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          ref
              .read(permissionGateProvider)
              .has(Permission.manageEventsOrganization)
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(
                CreateEventButton.createForDay(
                  context,
                  ref,
                  DateTime.tryParse(widget.date) ?? DateTime.now(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            )
          : null,
    );
  }
}
