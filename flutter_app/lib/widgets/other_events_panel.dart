import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../models/event.dart';
import '../providers/service_providers.dart';
import '../routing/app_router.dart';
import 'error_display.dart';

/// The "Other events on {date}" card.
///
/// The sidebar card that lists what else is scheduled on the same day, in the
/// same organization, so a user can see what they are about to double-book.
///
/// **Mounted in three places:** the event details screen's sidebar, the create
/// form's sidebar and the edit form's sidebar. Two of the three pass the
/// event's own id as [excludeEventId], so the event you are looking at is never
/// listed as one of the others.
class OtherEventsPanel extends ConsumerStatefulWidget {
  const OtherEventsPanel({
    super.key,
    required this.date,
    required this.organizationId,
    this.excludeEventId,
  });

  /// The day, as `YYYY-MM-DD`.
  ///
  /// Empty means "no day", and the panel asks for nothing — the original guards
  /// on an empty date.
  final String date;

  /// The organization to scope the list to, as a decimal string.
  ///
  /// A string because every call site holds it as one: the details screen
  /// renders the event's organization id into one, and the two forms keep
  /// theirs in state as one.
  final String organizationId;

  /// An event to leave out of the list.
  ///
  /// The event the panel is shown beside — the details screen and the edit form
  /// both pass the event's own id, so a user does not see the event they are
  /// looking at listed as one of the others.
  final String? excludeEventId;

  @override
  ConsumerState<OtherEventsPanel> createState() => _OtherEventsPanelState();
}

class _OtherEventsPanelState extends ConsumerState<OtherEventsPanel> {
  /// The events listed, already filtered and sorted.
  List<EventResponse> _events = const [];

  /// Whether a request is in flight.
  bool _loading = false;

  /// The failure, when the request failed.
  ApiException? _error;

  /// How many events on the day the server did not send.
  int _notShown = 0;

  /// Counts requests, so a slow answer cannot overwrite a newer one.
  ///
  /// **The React original has no such guard**, and gets away with it because
  /// its refetches are rare. This one refetches whenever the date changes,
  /// which on the create and edit forms is every time the user picks one — so
  /// a slow answer for a day they have moved on from can land after a faster
  /// one for the day they are on, and quietly replace it.
  int _request = 0;

  /// The most events a single day's list may hold.
  ///
  /// **The React original asks for no limit at all**, which the server reads
  /// as "no cap" — `EventDao.kt:176` does `limit?.let { query.limit(it) }`, so
  /// an omitted limit returns every event on the day, however many that is.
  ///
  /// The port has to send one, because `EventService.getAllEvents` defaults to
  /// ten (`EventService.dart:24`) and ten would silently truncate a busy day.
  /// A thousand is far above any real single-day count for one organization.
  ///
  /// It is a ceiling and not a page: there is no "load more" here, so a day
  /// with more events than this says how many it is not showing rather than
  /// pretending they are not there.
  static const int _dayLimit = 1000;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant OtherEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.excludeEventId != widget.excludeEventId) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final orgId = int.tryParse(widget.organizationId);
    if (widget.date.isEmpty || orgId == null) {
      _set(() {
        _events = const [];
        _error = null;
        _notShown = 0;
        _loading = false;
      });
      return;
    }

    final request = ++_request;
    _set(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref
          .read(eventServiceProvider)
          .getAllEvents(
            ListQuery(
              limit: _dayLimit,
              organizationId: orgId,
              startDate: widget.date,
              endDate: widget.date,
            ),
          );
      // A answer for a day the user has already moved on from.
      if (!mounted || request != _request) return;

      final items = [...response.items];
      final exclude = widget.excludeEventId;
      if (exclude != null) {
        items.removeWhere((event) => event.eventId.toString() == exclude);
      }
      items.sort((a, b) => a.time.compareTo(b.time));

      _set(() {
        _events = items;
        // **The rows the server did not send**, not the rows the exclusion
        // removed. The excluded event is the one the panel is shown beside, and
        // the user already knows about it — counting it as "not shown" would
        // put a "and 1 more" under a list that is showing everything.
        _notShown = response.total - response.items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      _set(() {
        _events = const [];
        _error = error is ApiException ? error : ApiRequestException('$error');
        _notShown = 0;
        _loading = false;
      });
    }
  }

  void _set(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `<h5 className="fw-bold mb-3 text-secondary">Other events on
            // {date}</h5>`. The heading stays put while the list loads, which
            // the React original does not do — see the note on the body below.
            Text(
              'Other events on ${widget.date}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _LoadingBody()
            else if (_error != null)
              ErrorDisplay.fromException(_error!)
            else if (_events.isEmpty)
              Text(
                'No other events scheduled for this day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              )
            else ...[
              for (var i = 0; i < _events.length; i++) ...[
                // **The rule between rows.** Every row of the list this
                // replaced carried a bottom border, so the list is ruled
                // rather than floating.
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                _EventRow(
                  event: _events[i],
                  onTap: () => context.go(
                    AppRoutes.eventDetailsPath(_events[i].eventId),
                  ),
                ),
              ],
              if (_notShown > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '…and $_notShown more on this day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The body shown while the list loads.
///
/// **The original replaces the whole card body with this** — heading and all —
/// so the card collapses to the height of a spinner and grows back when the
/// answer lands. Here the heading stays and only the body changes, so the card
/// does not jump.
///
/// The spinner itself is the original's: a small primary-coloured ring, with
/// no label beside it.
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// One event on the day.
///
/// `<Link className="list-group-item list-group-item-action bg-transparent
/// px-0 py-3 border-bottom">` — a title on the left, the time on the right,
/// and a line of detail underneath.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final EventResponse event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = event.location;
    final hasLocation = location != null && location.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // `py-3` — twelve pixels above and below.
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // `align-items-center`, so the time stays level with the first
              // line of a title that wraps.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  event.time,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // The clock. **The Bootstrap Icons were never installed** and
                // the original's icon tags render as empty elements, so there
                // is nothing to match — task 3.11 settles it: Material icons
                // throughout.
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${event.durationMinutes} min',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                if (hasLocation) ...[
                  // `ms-3` — a rem's worth of space between the two details.
                  const SizedBox(width: 16),
                  Icon(
                    Icons.place,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  // Expanded rather than free: the location is the one part of
                  // this row that can be long, and a `Row` of unbounded
                  // children overflows a narrow sidebar rather than wrapping.
                  Expanded(
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
