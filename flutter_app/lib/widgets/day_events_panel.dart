import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../core/util/local_date.dart';
import '../models/event.dart';
import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../providers/service_providers.dart';
import '../providers/time_zone_controller.dart';
import '../routing/app_router.dart';
import 'error_display.dart';
import 'rsvp_buttons.dart';

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
    this.interactive = true,
    this.showRsvpActions = false,
    this.organizationName,
    this.eventDetailsBackToDay,
  });

  /// The day, as `YYYY-MM-DD`.
  ///
  /// Empty means "no day", and the panel asks for nothing — the original guards
  /// on an empty date.
  final String date;

  /// The organization to scope the list to, as a decimal string.
  ///
  /// `null` means no organization filter (e.g. a superadmin viewing all
  /// organizations).
  final String? organizationId;

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

  /// Whether event rows can be tapped to navigate to their details.
  ///
  /// Disabled in create/edit flows to avoid leaving unsaved form state.
  final bool interactive;

  /// Whether to show RSVP controls on each event row.
  final bool showRsvpActions;

  /// When set, shown as the scoped organization for this panel's events.
  ///
  /// Used on view-event to clarify which organization's events are listed when
  /// a superadmin may be comparing against all-org views.
  final String? organizationName;

  /// When set, event rows open details with a day-back context so the details
  /// screen can return to that day view (and preserve it across same-day shuffles).
  final String? eventDetailsBackToDay;

  @override
  ConsumerState<DayEventsPanel> createState() => _DayEventsPanelState();
}

class _DayEventsPanelState extends ConsumerState<DayEventsPanel> {
  /// The fetched events for the day, unfiltered by [DayEventsPanel.excludeEventId].
  List<EventResponse> _fetchedItems = const [];

  /// Whether a request is in flight.
  bool _loading = false;

  /// True when a load has been in flight for more than 200ms.
  bool _showLoadingBar = false;
  Timer? _loadingBarTimer;

  /// The failure, when the request failed.
  ApiException? _error;

  /// How many events on the day the server did not send.
  int _notShown = 0;

  /// Counts requests, so a slow answer cannot overwrite a newer one.
  int _request = 0;

  /// Event IDs with an RSVP mutation in flight.
  final Set<int> _rsvpPending = {};

  /// The most events a single day's list may hold.
  static const int _dayLimit = 500;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _loadingBarTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DayEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // excludeEventId and marker are applied client-side; no refetch needed.
    if (oldWidget.date != widget.date ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.queryTimezone != widget.queryTimezone) {
      _fetch();
    }
  }

  void _startLoadingBarTimer() {
    _loadingBarTimer?.cancel();
    _loadingBarTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !_loading) return;
      setState(() => _showLoadingBar = true);
    });
  }

  void _stopLoadingBar() {
    _loadingBarTimer?.cancel();
    _loadingBarTimer = null;
    _showLoadingBar = false;
  }

  Future<void> _fetch() async {
    final rawOrgId = widget.organizationId;
    final orgId = rawOrgId == null ? null : int.tryParse(rawOrgId);
    if (widget.date.isEmpty || (rawOrgId != null && orgId == null)) {
      _set(() {
        _stopLoadingBar();
        _fetchedItems = const [];
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
    _startLoadingBarTimer();

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

      _set(() {
        _stopLoadingBar();
        _fetchedItems = [...response.items]
          ..sort((a, b) => a.instant.compareTo(b.instant));
        _notShown = response.total - response.items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      _set(() {
        _stopLoadingBar();
        _fetchedItems = const [];
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

  Future<void> _rsvp(EventResponse event, String availability) async {
    if (_rsvpPending.contains(event.eventId)) return;
    _set(() => _rsvpPending.add(event.eventId));
    try {
      final updated = await ref
          .read(eventServiceProvider)
          .rsvpToEvent(event.eventId, RsvpRequest(availability: availability));
      if (!mounted) return;
      _set(() {
        _rsvpPending.remove(event.eventId);
        _fetchedItems = _fetchedItems
            .map((e) => e.eventId == event.eventId ? updated : e)
            .toList(growable: false);
      });
      _showRsvpSnackBar('RSVP updated to ${_rsvpLabel(availability)}.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _set(() => _rsvpPending.remove(event.eventId));
      _showRsvpSnackBar(error.message, isError: true);
    }
  }

  void _showRsvpSnackBar(String message, {bool isError = false}) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = _buildHeader(context, theme);
    final readerZone =
        ref.watch(timeZoneControllerProvider).value?.effectiveZone ?? 'UTC';
    final marker = widget.marker;
    final exclude = widget.excludeEventId;
    final events = exclude == null
        ? _fetchedItems
        : _fetchedItems
              .where((event) => event.eventId.toString() != exclude)
              .toList(growable: false);
    final rows = <_PanelEntry>[
      for (final event in events) _EventEntry(event),
      if (marker != null) _MarkerEntry(marker),
    ]..sort((a, b) => a.instant.compareTo(b.instant));

    final hasContent = rows.isNotEmpty || _error != null;
    final showBlockingLoader = _loading && !hasContent;
    final showBar = _showLoadingBar && _loading;
    final showOrganization = widget.organizationId == null;
    final canRsvp =
        widget.showRsvpActions &&
        ref.watch(permissionGateProvider).has(Permission.assignToEventsSelf);
    final currentUserId = ref.watch(userContextProvider)?.user.userId;

    final orgLabel = widget.organizationName;
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header,
            if (orgLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                'Organization: $orgLabel',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ] else if (orgLabel != null) ...[
            Text(
              'Organization: $orgLabel',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showBlockingLoader)
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
                  showOrganization: showOrganization,
                  currentUserId: canRsvp ? currentUserId : null,
                  rsvpPending: _rsvpPending.contains(event.eventId),
                  onRsvp: canRsvp
                      ? (availability) => unawaited(_rsvp(event, availability))
                      : null,
                  onTap: widget.interactive
                      ? () => context.go(
                          AppRoutes.eventDetailsPath(
                            event.eventId,
                            backToDay: widget.eventDetailsBackToDay,
                          ),
                        )
                      : null,
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
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          body,
          if (showBar)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget? _buildHeader(BuildContext context, ThemeData theme) {
    if (widget.headerMode == DayEventsPanelHeaderMode.hidden) return null;
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.secondary,
    );
    if (widget.headerMode == DayEventsPanelHeaderMode.linkToDayView) {
      final text = Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'Events on '),
            TextSpan(
              text: widget.date,
              style: baseStyle?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
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
    return Text('Events on ${widget.date}', style: baseStyle);
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
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.readerZone,
    required this.showOrganization,
    required this.onTap,
    this.currentUserId,
    this.rsvpPending = false,
    this.onRsvp,
  });

  final EventResponse event;
  final String readerZone;
  final bool showOrganization;
  final VoidCallback? onTap;
  final int? currentUserId;
  final bool rsvpPending;
  final ValueChanged<String>? onRsvp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = event.location;
    final hasLocation = location != null && location.isNotEmpty;
    final mine = currentUserId == null
        ? null
        : event.rsvps
              .where((rsvp) => rsvp.userId == currentUserId)
              .firstOrNull
              ?.availability;

    final details = Row(
      children: [
        Icon(Icons.schedule, size: 14, color: theme.colorScheme.secondary),
        const SizedBox(width: 4),
        Text(
          '${event.durationMinutes} min',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        if (hasLocation) ...[
          const SizedBox(width: 16),
          Icon(Icons.place, size: 14, color: theme.colorScheme.secondary),
          const SizedBox(width: 4),
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
    );

    final time = Text(
      event.timeIn(readerZone),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );

    final rsvp = onRsvp == null
        ? null
        : RsvpButtons(
            currentAvailability: mine,
            enabled: !rsvpPending,
            onSelected: onRsvp!,
          );

    Widget tappable(Widget child) =>
        onTap == null ? child : InkWell(onTap: onTap, child: child);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showOrganization) ...[
            Text(
              event.organization.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 420;
              if (wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tappable(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                details,
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          time,
                        ],
                      ),
                    ),
                    if (rsvp != null) ...[
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: rsvp),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tappable(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            time,
                          ],
                        ),
                        const SizedBox(height: 4),
                        details,
                      ],
                    ),
                  ),
                  if (rsvp != null) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: rsvp),
                  ],
                ],
              );
            },
          ),
        ],
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
