import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../core/util/local_date.dart';
import '../models/event.dart';
import '../providers/service_providers.dart';
import '../providers/time_zone_controller.dart';
import '../routing/app_router.dart';
import 'error_display.dart';

/// How the panel's date header is presented.
enum DayEventsPanelHeaderMode {
  /// A plain, non-interactive header.
  staticLabel,

  /// No header — the surrounding screen already shows the day.
  hidden,

  /// A tappable header that opens the day view for [DayEventsPanel.date].
  linkToDayView,
}

/// A ghost marker showing where an event sits or would sit in the day.
class DayEventsPanelMarker {
  const DayEventsPanelMarker({required this.instant, required this.label});

  /// The event's start instant, used to position the marker among fetched rows.
  final DateTime instant;

  /// Text shown for the marker.
  final String label;
}

/// The "Events on {date}" card.
///
/// The sidebar card that lists events scheduled on the same day, in the same
/// organization, so a user can see what they are about to double-book.
///
/// **Mounted in three places:** the event details screen's sidebar, the day
/// view, and the create/edit form sidebars. A persisted event shown alongside
/// the panel may be excluded from fetched results via [excludeEventId] and
/// represented by [marker] so its placement can be shown (and, when editing,
/// move as its time changes).
class DayEventsPanel extends ConsumerStatefulWidget {
  const DayEventsPanel({
    super.key,
    required this.date,
    required this.organizationId,
    this.excludeEventId,
    this.queryTimezone,
    this.headerMode = DayEventsPanelHeaderMode.staticLabel,
    this.marker,
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

  /// A persisted event to leave out of the fetched list.
  ///
  /// Used with [marker] to avoid duplicating an event while still showing its
  /// placement (for example the event being viewed or edited).
  final String? excludeEventId;

  /// The zone [date] is interpreted in for the query.
  ///
  /// Defaults to the reader's effective zone. Event forms pass the event's own
  /// timezone so the double-booking check runs against the day being scheduled,
  /// not the reader's day.
  final String? queryTimezone;

  /// How the date header is shown for this context.
  final DayEventsPanelHeaderMode headerMode;

  /// Optional ghost marker for a current or proposed event placement.
  final DayEventsPanelMarker? marker;

  @override
  ConsumerState<DayEventsPanel> createState() => _DayEventsPanelState();
}

class _DayEventsPanelState extends ConsumerState<DayEventsPanel> {
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
  void didUpdateWidget(covariant DayEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.excludeEventId != widget.excludeEventId ||
        oldWidget.queryTimezone != widget.queryTimezone) {
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

    final readerZone =
        ref.read(timeZoneControllerProvider).value?.effectiveZone ?? 'UTC';
    final queryTimezone = widget.queryTimezone ?? readerZone;

    try {
      final response = await ref
          .read(eventServiceProvider)
          .getAllEvents(
            ListQuery(
              limit: _dayLimit,
              organizationId: orgId,
              startDate: widget.date,
              endDate: widget.date,
              timezone: queryTimezone,
            ),
          );
      // A answer for a day the user has already moved on from.
      if (!mounted || request != _request) return;

      final items = [...response.items];
      final exclude = widget.excludeEventId;
      if (exclude != null) {
        items.removeWhere((event) => event.eventId.toString() == exclude);
      }
      items.sort((a, b) => a.instant.compareTo(b.instant));

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
    final header = _buildHeader(context, theme);
    final readerZone =
        ref.watch(timeZoneControllerProvider).value?.effectiveZone ?? 'UTC';
    final marker = widget.marker;
    final rows = <_PanelEntry>[
      for (final event in _events) _EventEntry(event),
      if (marker != null) _MarkerEntry(marker),
    ]..sort((a, b) => a.instant.compareTo(b.instant));

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[header, const SizedBox(height: 16)],
            if (_loading)
              const _LoadingBody()
            else if (_error != null)
              ErrorDisplay.fromException(_error!)
            else if (rows.isEmpty)
              Text(
                'No events scheduled for this day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              )
            else ...[
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                switch (rows[i]) {
                  _EventEntry(:final event) => _EventRow(
                    event: event,
                    readerZone: readerZone,
                    onTap: () =>
                        context.go(AppRoutes.eventDetailsPath(event.eventId)),
                  ),
                  _MarkerEntry(:final marker) => _MarkerRow(
                    marker: marker,
                    readerZone: readerZone,
                  ),
                },
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

  Widget? _buildHeader(BuildContext context, ThemeData theme) {
    if (widget.headerMode == DayEventsPanelHeaderMode.hidden) return null;
    final text = Text(
      'Events on ${widget.date}',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.secondary,
      ),
    );
    if (widget.headerMode == DayEventsPanelHeaderMode.linkToDayView) {
      return Semantics(
        button: true,
        label: 'View day ${widget.date}',
        child: InkWell(
          onTap: () => context.go('${AppRoutes.eventDay}?date=${widget.date}'),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(alignment: Alignment.centerLeft, child: text),
          ),
        ),
      );
    }
    return text;
  }
}

sealed class _PanelEntry {
  DateTime get instant;
}

class _EventEntry extends _PanelEntry {
  _EventEntry(this.event);
  final EventResponse event;
  @override
  DateTime get instant => event.instant;
}

class _MarkerEntry extends _PanelEntry {
  _MarkerEntry(this.marker);
  final DayEventsPanelMarker marker;
  @override
  DateTime get instant => marker.instant;
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
  const _EventRow({
    required this.event,
    required this.readerZone,
    required this.onTap,
  });

  final EventResponse event;
  final String readerZone;
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
                  event.timeIn(readerZone),
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

/// A non-navigable ghost row showing where an event sits or would sit.
class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.marker, required this.readerZone});

  final DayEventsPanelMarker marker;
  final String readerZone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = formatTimeInZone(marker.instant, readerZone);
    return Semantics(
      label: '${marker.label}, $time',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.arrow_right_alt,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                marker.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
