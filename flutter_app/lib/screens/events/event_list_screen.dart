import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' show TZDateTime;

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/util/local_date.dart';
import '../../models/event.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/effective_organization_scope.dart';
import '../../providers/event_list.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/create_event_button.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/picker_fields.dart';
import '../../widgets/record_link_button.dart';
import '../../widgets/responsive_list_view.dart';
import '../../widgets/rsvp_buttons.dart';

/// The event list.
///
/// Search, a start-date floor with a "Today" button, six columns, inline RSVP,
/// edit and delete.
///
/// **The RSVP column is the reason this screen is more than another
/// [ResponsiveListView].** The original rendered three buttons per row that
/// posted an availability and refetched — a per-row *mutation*, in a table cell,
/// on a screen whose other cells are text. `ListColumn.render` takes a
/// `BuildContext`, which is all that is needed for it; see [_RsvpButton] for why
/// the buttons are one size in both layouts rather than one size per layout.
///
/// **What this screen drops from the original, and why.** The original page had
/// its own Previous/Next pair and a "Showing X - Y of Z" line. It is built on
/// [PagedScrollView] instead, which is the same pagination the other list
/// screens use — infinite scroll with a "Load more" button as the floor. Two
/// pages of a bespoke pager would be a second pagination implementation in the
/// app, and the shared delete dialog is one implementation, not one per screen.
class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({
    super.key,
    this.initialCustomerId,
    this.initialInventoryId,
  });

  /// Optional deep-link/filter: restrict the list to events for this customer.
  final int? initialCustomerId;

  /// Optional deep-link/filter: restrict the list to events using this inventory item.
  final int? initialInventoryId;

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  /// Defaults to today in the reader's zone once that zone resolves.
  late String _startDate = formatLocalDate(DateTime.now());
  bool _startDateSyncedToReaderZone = false;

  /// Holds [_startDate] as text, because `DateField` is a controller-backed
  /// field and the value also has to reach `_buildQuery`.
  late final TextEditingController _startDateController = TextEditingController(
    text: _startDate,
  );

  @override
  void dispose() {
    _startDateController.dispose();
    super.dispose();
  }

  String _searchTerm = '';

  /// `sortBy` defaults to `startsAt` (the Date column) — the server supports
  /// sorting by start time and title.
  String _sortBy = 'startsAt';
  SortOrder _sortOrder = SortOrder.asc;

  /// The query built during the last build, kept so "load more" and "reload
  /// after a delete" reach the same provider the screen is watching. Same
  /// reasoning as the other four list screens — rebuilding it in a handler means
  /// a second copy of the scoping rules.
  ListQuery? _query;

  /// A failed delete or RSVP — a mutation the list itself does not re-render.
  ///
  /// The fetch's own error lives in the provider; the React page held one
  /// `error` for both and rendered it through `TableView`.
  ApiException? _actionError;

  /// Matches the original list: re-tapping the active column reverses it, a
  /// different column starts ascending.
  void _onSort(String key) {
    setState(() {
      if (_sortBy == key) {
        _sortOrder = _sortOrder == SortOrder.asc
            ? SortOrder.desc
            : SortOrder.asc;
      } else {
        _sortBy = key;
        _sortOrder = SortOrder.asc;
      }
    });
  }

  ListQuery _buildQuery(int? organizationId, String readerZone) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // Scoped by the effective organization: a superadmin in "All
    // Organizations" sees every organization, a superadmin with a selection
    // sees that one, and everyone else sees their own.
    organizationId: organizationId,
    customerId: widget.initialCustomerId,
    inventoryId: widget.initialInventoryId,
    // **A floor, not a range.** The original passed `startDate` and left
    // `endDate` undefined, so it showed upcoming events only. The date is
    // interpreted in the reader's zone, so "today" means the same day the reader
    // is looking at.
    startDate: _startDate,
    timezone: readerZone,
  );

  /// The delete confirmation.
  ///
  /// The dialog is shared — see [confirmDestructiveAction] — and what stays here
  /// is this screen's own consequence: the service call, and a **reload from the
  /// first page** rather than an invalidation, because deleting a row shifts
  /// every row after it and the accumulated pages past the deletion are wrong.
  Future<void> _confirmDelete(EventResponse event) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete event',
      message:
          'Are you sure you want to delete "${event.title}"? This cannot be '
          'undone.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(eventServiceProvider).deleteEvent(event.eventId);
      await ref.read(eventListProvider(_query!).notifier).reload();
      if (mounted) setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  /// Posts the availability and updates the affected row in place.
  ///
  /// The server returns the updated event, so reloading the whole list is not
  /// necessary for this in-place mutation.
  Future<void> _rsvp(EventResponse event, String availability) async {
    try {
      final updated = await ref
          .read(eventServiceProvider)
          .rsvpToEvent(event.eventId, RsvpRequest(availability: availability));
      if (!mounted || _query == null) return;
      ref
          .read(eventListProvider(_query!).notifier)
          .replaceItemWhere((e) => e.eventId == event.eventId, updated);
      setState(() => _actionError = null);
      _showRsvpSnackBar('RSVP updated to ${_rsvpLabel(availability)}.');
    } on ApiException catch (error) {
      if (!mounted) return;
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

  List<ListColumn<EventResponse>> _columns(
    int? currentUserId,
    String readerZone, {
    required bool showOrganization,
  }) => [
    ListColumn<EventResponse>(
      key: 'title',
      label: 'Title',
      sortable: true,
      // The original gated the hover actions on the hovered row, which
      // `ResponsiveListView` already does for `actions` — the actions live in
      // their own column here rather than absolutely positioned over the title,
      // for the same reason as the customer screen.
      render: (context, event) => RecordLinkButton(
        label: event.title,
        onPressed: () => context.go(AppRoutes.eventDetailsPath(event.eventId)),
      ),
    ),
    ListColumn<EventResponse>(
      key: 'startsAt',
      label: 'Date / Time',
      sortable: true,
      flex: 2,
      text: (event) =>
          '${event.dateIn(readerZone)} ${event.timeIn(readerZone)}',
    ),
    ListColumn<EventResponse>(
      key: 'description',
      label: 'Description',
      flex: 3,
      text: (event) => event.description ?? '',
    ),
    if (showOrganization)
      ListColumn<EventResponse>(
        key: 'organization',
        label: 'Organization',
        sortable: true,
        flex: 2,
        render: (context, event) => RecordLinkButton(
          label: event.organization.name,
          onPressed: () => context.go(
            AppRoutes.organizationDetailsPath(
              event.organization.organizationId,
            ),
          ),
        ),
      ),
    ListColumn<EventResponse>(
      key: 'customer',
      label: 'Customer',
      flex: 2,
      text: (event) => event.customer?.name ?? 'N/A',
    ),
    ListColumn<EventResponse>(
      key: 'rsvp',
      label: 'RSVP',
      flex: 3,
      render: (context, event) => _RsvpCell(
        event: event,
        currentUserId: currentUserId,
        onRsvp: (availability) => unawaited(_rsvp(event, availability)),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManage = gate.has(Permission.manageEventsOrganization);
    final currentUserId = ref.watch(userContextProvider)?.user.userId;
    final isAllOrganizations = ref.watch(isAllOrganizationsProvider);
    final organizationId = ref.watch(queryOrganizationIdProvider);
    final tz = ref.watch(timeZoneControllerProvider);
    final readerZone = tz.value?.effectiveZone ?? 'UTC';

    if (!_startDateSyncedToReaderZone && tz.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startDateSyncedToReaderZone) return;
        final now = TZDateTime.now(zoneLocation(tz.value!.effectiveZone));
        final today = formatLocalDate(now);
        setState(() {
          _startDateController.text = today;
          _startDate = today;
          _startDateSyncedToReaderZone = true;
        });
      });
    }

    final query = _buildQuery(organizationId, readerZone);
    _query = query;
    final actionError = _actionError;

    Future<void> onRefresh() async {
      if (_query != null) {
        await ref.read(eventListProvider(_query!).notifier).reload();
      }
    }

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(eventListProvider(_query!).notifier).loadMore(),
        onRefresh: onRefresh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListScreenHeader(
              title: 'Events',
              action: CreateEventButton(),
            ),
            const SizedBox(height: 16),
            _Filters(
              onSearch: (value) => setState(() => _searchTerm = value),
              dateController: _startDateController,
              onStartDateChanged: (value) => setState(() => _startDate = value),
              // "Today" resets the floor in the reader's zone.
              onToday: () => setState(() {
                final now = TZDateTime.now(zoneLocation(readerZone));
                final today = formatLocalDate(now);
                _startDateController.text = today;
                _startDate = today;
              }),
            ),
            if (actionError != null) ...[
              const SizedBox(height: 16),
              ErrorDisplay.fromException(actionError),
            ],
            PagedListSection<EventResponse>(
              provider: eventListProvider(query),
              loadMore: () => ref
                  .read(eventListProvider(query).notifier)
                  .loadMore(userInitiated: true),
              onRetry: () => ref.invalidate(eventListProvider(query)),
              columns: _columns(
                currentUserId,
                readerZone,
                showOrganization: isAllOrganizations,
              ),
              idOf: (event) => event.eventId,
              emptyMessage: 'No events found.',
              // The event table is compact enough to stay tabular below the global
              // desktop breakpoint.
              tableMinWidth: 800,
              filtered: _searchTerm.isNotEmpty,
              sortBy: _sortBy,
              sortOrder: _sortOrder,
              onSort: _onSort,
              actions: canManage
                  ? (context, event) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () =>
                            context.go(AppRoutes.eventEditPath(event.eventId)),
                      ),
                      ListRowAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: () => unawaited(_confirmDelete(event)),
                      ),
                    ]
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The search box and the start-date filter.
///
/// `row mb-3` with two `col-md-4` children in the original. Two fields side by
/// side above 700px and stacked below it, which is a [Wrap] for the same reason
/// [ListScreenHeader] is one.
///
/// `DateField` from rather than a raw text field, so the date is picked
/// rather than typed and the value is always a valid `yyyy-MM-dd` — which
/// matters here because it goes straight into the query. **No `lastDate`
/// override**: the field's own default already reaches into the future,
/// which is what this screen's start-date filter needs — it floors the query
/// at a day, and a user picking a start date beyond today is looking for
/// events further out, not being blocked from looking.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.onSearch,
    required this.dateController,
    required this.onStartDateChanged,
    required this.onToday,
  });

  final ValueChanged<String> onSearch;
  final TextEditingController dateController;
  final ValueChanged<String> onStartDateChanged;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **Row one: the search box and the sibling view.**
        //
        // The "Calendar view" button is a **divergence from the original**, and
        // the original had the same gap: it linked nowhere, and the only way
        // back to the calendar was the nav rail's "Events" item — which is a
        // drawer on a phone. The calendar page linked *out* to this list, so the
        // two screens were siblings in one direction only, and a user who arrived
        // here had to know to go back rather than being offered it.
        //
        // It sits **beside the search box** because that is where the calendar's
        // own "View All Events" button sat. The two pages now read as mirror
        // images, and the button is a *view switch* rather than a filter control
        // — which is why the date fields moved to their own row instead of
        // sharing this one.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DebouncedSearchField(
              hintText: 'Search events...',
              onChanged: onSearch,
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.events),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Calendar view'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // **Row two: the start-date floor.**
        //
        // Its own row because it is a *filter*, and it used to share a row with
        // the search box in the original. Separating the two kinds of control is
        // what lets the view switch live where the search box is.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: DateField(
                controller: dateController,
                label: 'Start Date',
                onChanged: (picked) {
                  if (picked != null) {
                    onStartDateChanged(formatLocalDate(picked));
                  }
                },
              ),
            ),
            OutlinedButton(onPressed: onToday, child: const Text('Today')),
          ],
        ),
      ],
    ),
  );
}

/// This user's RSVP controls for one event row.
class _RsvpCell extends StatelessWidget {
  const _RsvpCell({
    required this.event,
    required this.currentUserId,
    required this.onRsvp,
  });

  final EventResponse event;
  final int? currentUserId;
  final ValueChanged<String> onRsvp;

  @override
  Widget build(BuildContext context) {
    final mine = currentUserId == null
        ? null
        : event.rsvps
              .where((rsvp) => rsvp.userId == currentUserId)
              .firstOrNull
              ?.availability;
    return RsvpButtons(
      currentAvailability: mine,
      onSelected: onRsvp,
      wrap: false,
    );
  }
}

/// Compatibility alias: clearing a response now posts `needs_action`.
const String kRsvpCleared = RsvpAvailability.needsAction;
