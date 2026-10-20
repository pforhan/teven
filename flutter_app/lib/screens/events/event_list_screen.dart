import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/theme/teven_theme.dart';
import '../../core/util/local_date.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/event_list.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
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

/// The event list — task 7.5.
///
/// `EventListPage.tsx` (240 lines). Search, a start-date floor with a "Today"
/// button, six columns, inline RSVP, edit and delete.
///
/// **The RSVP column is the reason this screen is more than another
/// [ResponsiveListView].** `EventListPage.tsx:130-161` renders three buttons per
/// row that post an availability and refetch — a per-row *mutation*, in a table
/// cell, on a screen whose other cells are text. `ListColumn.render` takes a
/// `BuildContext`, which is all that is needed for it; see [_RsvpButton] for why
/// the buttons are one size in both layouts rather than one size per layout.
///
/// **What this screen drops from the original, and why.** The React page had its
/// own Previous/Next pair and a "Showing X - Y of Z" line. It is built on
/// [PagedScrollView] instead, which is the same pagination the other four list
/// screens gained in task 4.9 — infinite scroll with a "Load more" button as the
/// floor. Two pages of a bespoke pager would be a second pagination
/// implementation in the app, and `4.8`'s rule for the delete dialog applies here
/// too: shared means one implementation, not one per screen.
class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  /// `EventListPage.tsx:26-29` defaults the start date to today.
  ///
  /// **Computed locally rather than with `DateTime.now().toISOString()`,** which
  /// is what the original does — see [formatLocalDate]. `toIso8601String()`
  /// converts to UTC first, so at local midnight east of UTC it reports
  /// *yesterday*, and the whole screen would be filtered to a day that is not
  /// today. Nobody testing west of UTC sees it.
  late String _startDate = formatLocalDate(DateTime.now());

  /// Holds [_startDate] as text, because `DateField` is a controller-backed
  /// field and the value also has to reach `_buildQuery`.
  ///
  /// The two are kept in step by writing both from the same place — the picker
  /// callback and the "Today" button — rather than by listening, so there is no
  /// order in which the field and the query can disagree. A `TextField` that is
  /// rebuilt from state instead would need the reverse: the controller cleared
  /// and refilled on every change, which fights the caret.
  late final TextEditingController _startDateController = TextEditingController(
    text: _startDate,
  );

  @override
  void dispose() {
    _startDateController.dispose();
    super.dispose();
  }

  String _searchTerm = '';

  /// `sortBy` defaults to `'date'` in the original even though the column it is
  /// applied to is the title — see [_buildQuery].
  String _sortBy = 'date';
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

  /// `EventListPage.tsx:94-102`: re-tapping the active column reverses it, a
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

  ListQuery _buildQuery(OrganizationResponse? organization) => ListQuery(
    search: _searchTerm.isEmpty ? null : _searchTerm,
    sortBy: _sortBy,
    sortOrder: _sortOrder,
    // `EventListPage.tsx:39` — scoped to the selected organization, unlike the
    // organization screen, which is the one list that is not.
    organizationId: organization?.organizationId,
    // **A floor, not a range.** `EventListPage.tsx:36-44` passes `startDate` and
    // leaves `endDate` undefined, so the original shows upcoming events only.
    startDate: _startDate,
  );

  /// `EventListPage.tsx:62-76`.
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

  /// `EventListPage.tsx:78-92`.
  ///
  /// Posts the availability and reloads. The server answers `success("OK")`, so
  /// nothing comes back to display and a refetch is the only way to repaint the
  /// three buttons' selected state — which is what the original's
  /// `fetchEvents()` did.
  ///
  /// `'no response'` is the literal the original posts for its clear button
  /// (`:153`), and it is **not** one of [RsvpAvailability]'s named values.
  /// Reproduced verbatim: inventing `''` or `'none'` would change what lands in
  /// the `rsvps.availability` column, and task 10.17 owns the question of
  /// whether that column should hold a closed set at all.
  Future<void> _rsvp(EventResponse event, String availability) async {
    try {
      await ref
          .read(eventServiceProvider)
          .rsvpToEvent(event.eventId, RsvpRequest(availability: availability));
      await ref.read(eventListProvider(_query!).notifier).reload();
      if (mounted) setState(() => _actionError = null);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error);
    }
  }

  List<ListColumn<EventResponse>> _columns(int? currentUserId) => [
    ListColumn<EventResponse>(
      key: 'title',
      label: 'Title',
      sortable: true,
      // `EventListPage.tsx:112` gates the hover actions on the row being hovered,
      // which `ResponsiveListView` already does for `actions` — the actions live
      // in their own column here rather than absolutely positioned over the
      // title, for the same reason as the customer screen.
      render: (context, event) => RecordLinkButton(
        label: event.title,
        onPressed: () => context.go(AppRoutes.eventDetailsPath(event.eventId)),
      ),
    ),
    ListColumn<EventResponse>(
      key: 'date',
      label: 'Date',
      sortable: true,
      text: (event) => event.date,
    ),
    // `EventListPage.tsx:127` — the raw wire `time`, not a formatted one. It is
    // `HH:MM:SS` and the original renders it as-is, so a leading zero is
    // visible. Not worth diverging over.
    ListColumn<EventResponse>(
      key: 'time',
      label: 'Time',
      text: (event) => event.time,
    ),
    ListColumn<EventResponse>(
      key: 'description',
      label: 'Description',
      // Free text written by whoever made the event, and the other end of the
      // width problem task 4.7 documented on the user list. Two shares, not one.
      flex: 2,
      text: (event) => event.description ?? '',
    ),
    ListColumn<EventResponse>(
      key: 'customer',
      label: 'Customer',
      // `EventListPage.tsx:128` — `event.customer?.name || 'N/A'`. The fallback is
      // the original's, and it is not decoration: `customerId` is nullable on
      // both the DTO and the schema, so an event with no customer is a real state.
      text: (event) => event.customer?.name ?? 'N/A',
    ),
    ListColumn<EventResponse>(
      key: 'rsvp',
      label: 'RSVP',
      // Not sortable, matching the original: only `title` and `date` carry
      // `sortable: true` at `EventListPage.tsx:105,125`.
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
    final organization = ref.watch(selectedOrganizationProvider);

    final query = _buildQuery(organization);
    _query = query;
    final actionError = _actionError;

    return Scaffold(
      body: PagedScrollView(
        onLoadMore: () =>
            ref.read(eventListProvider(_query!).notifier).loadMore(),
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
              // `EventListPage.tsx:212` — "Today" resets the floor, and
              // `setOffset(0)` beside it is now the offset reset that a new
              // [ListQuery] performs for free. The controller is written too,
              // or the field would keep showing the old date while the list had
              // already moved.
              onToday: () => setState(() {
                final today = formatLocalDate(DateTime.now());
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
              loadMore: () =>
                  ref.read(eventListProvider(query).notifier).loadMore(),
              columns: _columns(currentUserId),
              idOf: (event) => event.eventId,
              emptyMessage: 'No events found.',
              // Same test `_buildQuery` uses to decide whether to send `search`
              // at all, so the label cannot claim a filter the request did not
              // apply.
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
/// `DateField` from task 5.9 rather than a raw text field, so the date is picked
/// rather than typed and the value is always a valid `yyyy-MM-dd` — which
/// matters here because it goes straight into the query. `lastDate` is pushed
/// out because this screen's whole point is upcoming events, and `DateField`
/// defaults it to *now*, which would make every event past this afternoon
/// unpickable.
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
        // The "Calendar view" button is a **divergence from the React
        // original**, and the original has the same gap: `EventListPage.tsx`
        // links nowhere, and the only way back to the calendar is the nav
        // rail's "Events" item — which is a drawer on a phone. The calendar
        // page links *out* to this list (`EventCalendar.tsx:253`, "View All
        // Events"), so the two screens are siblings in one direction only, and
        // a user who arrived here has to know to go back rather than being
        // offered it.
        //
        // It sits **beside the search box** because that is where the
        // calendar's own "View All Events" button sits
        // (`EventCalendar.tsx:244-252` — the 250px input, then the link, then
        // Create). The two pages now read as mirror images, and the button is a
        // *view switch* rather than a filter control — which is why the date
        // fields moved to their own row instead of sharing this one.
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
        // Its own row because it is a *filter*, and it used to share a row
        // with the search box in the React original (`EventListPage.tsx:190-215`
        // — two `col-md-4` columns). Separating the two kinds of control is
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
                lastDate: DateTime(DateTime.now().year + 5),
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

/// The three RSVP buttons, and which of them is currently selected.
///
/// `EventListPage.tsx:130-161`. The selected button is filled (`btn-success` /
/// `btn-danger`) and the others are neutral (`btn-light`); that is the entire
/// "what is my current answer" display, and it is reproduced rather than
/// improved, because the server has no notion of "cleared" that the client could
/// render differently — the clear button simply posts `'no response'` and the
/// row comes back with the availability the server stored.
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
    // `EventListPage.tsx:131` finds *this* user's RSVP among the event's, rather
    // than reading a field the server denormalizes. Null when the user has not
    // answered, which is also the state where all three buttons are neutral.
    final mine = currentUserId == null
        ? null
        : event.rsvps
              .where((rsvp) => rsvp.userId == currentUserId)
              .firstOrNull
              ?.availability;

    return Wrap(
      spacing: 4,
      children: [
        _RsvpButton(
          icon: Icons.check,
          tooltip: 'RSVP Yes',
          selected: mine == RsvpAvailability.available,
          selectedColor: TevenTheme.success,
          onPressed: () => onRsvp(RsvpAvailability.available),
        ),
        _RsvpButton(
          icon: Icons.close,
          tooltip: 'RSVP No',
          selected: mine == RsvpAvailability.unavailable,
          selectedColor: TevenTheme.danger,
          onPressed: () => onRsvp(RsvpAvailability.unavailable),
        ),
        _RsvpButton(
          icon: Icons.undo,
          tooltip: 'Clear RSVP',
          selected: false,
          onPressed: () => onRsvp(kRsvpCleared),
        ),
      ],
    );
  }
}

/// What the clear button posts.
///
/// `'no response'`, verbatim from `EventListPage.tsx:153`. **Not** `''`, not
/// `'none'`, and not a member of [RsvpAvailability] — the server stores it as a
/// free-form string (`RsvpRequest.availability` has no validation) and the
/// original's own "what did I answer" test is an equality check against
/// `'available'` or `'unavailable'`, so any other value reads as unanswered.
/// Task 10.17 decides whether that column should hold a closed set.
const String kRsvpCleared = 'no response';

/// One RSVP button.
///
/// A [Tooltip] is the accessible name, so there is no `Semantics` wrapper — task
/// 4.3 records why, and this is the same widget reaching the same conclusion.
///
/// **One size for both layouts, deliberately.** `ResponsiveListView` decides
/// table vs card from its *own* `LayoutBuilder` width — after the rail has come
/// off — so a screen cannot ask which layout it is in from the window, and the
/// `context.layoutSize` this file could read is the window and would disagree.
/// [kRsvpButtonSize] is therefore one compromise chosen to fit three across a
/// table cell and still be a usable target in a card. Task 9.4 is the pass that
/// audits touch target sizes across the app, including this one.
const double kRsvpButtonSize = 40;

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    this.selectedColor,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  /// The fill for the selected state. Null leaves the button in the theme's
  /// primary colour, which is what the clear button uses — it has no selected
  /// state to show.
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selectedColor ?? scheme.primary;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: kRsvpButtonSize,
          minHeight: kRsvpButtonSize,
        ),
        style: IconButton.styleFrom(
          backgroundColor: selected ? fill : scheme.surfaceContainerHighest,
          foregroundColor: selected ? Colors.white : scheme.outline,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
