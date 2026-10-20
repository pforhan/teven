import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:table_calendar/table_calendar.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/theme/teven_theme.dart';
import '../../core/util/local_date.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../providers/auth_controller.dart';
import '../../providers/event_list.dart';
import '../../providers/organization_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/create_event_button.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';

/// The month grid — task 7.1.
///
/// `EventCalendar.tsx` (329 lines), rebuilt on `table_calendar`.
///
/// **Four things are dropped, and they are the four the task names.** The week,
/// work-week, day and agenda views go with react-big-calendar itself, which has
/// no `table_calendar` equivalent; drag-to-select slot creation goes with them,
/// because a month grid has no time axis to drag along; and the hover-to-reveal
/// "Create Event" placeholder goes because it needed a 100ms `mouseleave` timer
/// purely to avoid flickering, and the affordance it stood in for has a
/// permanent home in the header button.
///
/// **Tapping a day still creates an event, and that is not drag-select.**
/// `EventCalendar.tsx:134-143` branches on `action`: `'select'` is the drag,
/// `'click'` is a plain tap on a day cell, and only the latter carries a date
/// with no time attached. That branch is the whole of what survives, and
/// `onDaySelected` is exactly it. Task 7.2 asks for a *long press* instead; a tap
/// is what the original had and `table_calendar` routes both gestures through
/// one callback, so the difference would be a gesture rather than a second
/// affordance. Noted on 7.2 rather than silently re-decided.
///
/// **This screen does not page.** See [kCalendarEventLimit] — react-big-calendar
/// was handed the whole visible range and had no paging model to violate, so
/// there is nothing to accumulate here. The list at `/events/list` is the one
/// that pages.
class EventCalendarScreen extends ConsumerStatefulWidget {
  const EventCalendarScreen({super.key});

  @override
  ConsumerState<EventCalendarScreen> createState() =>
      _EventCalendarScreenState();
}

class _EventCalendarScreenState extends ConsumerState<EventCalendarScreen> {
  /// The month on screen, and the month the query is built around.
  ///
  /// One field, not two. `table_calendar` reports the month it moved to through
  /// `onPageChanged`, and `EventCalendar.tsx:102-126` refetched from `date` on
  /// every navigation — keeping a separate "focused" and "fetched" month would
  /// only allow them to disagree, which is the shape of a stale-data bug rather
  /// than a feature.
  DateTime _focusedMonth = _monthOf(DateTime.now());

  String _searchTerm = '';

  /// The query for the month on screen.
  ///
  /// The window is the **first and last day of the month, not the visible
  /// six-week grid.** `EventCalendar.tsx:119-123` takes
  /// `startOf('month')`/`endOf('month')`, which excludes the leading and
  /// trailing days from the neighbouring months that react-big-calendar draws.
  /// Those cells were always drawn greyed and always empty; widening the query
  /// to the grid would be a fix rather than a port, and would change which
  /// events appear where.
  ///
  /// `limit` is [kCalendarEventLimit] and `offset` is absent.
  ListQuery _buildQuery(OrganizationResponse? organization) => ListQuery(
    limit: kCalendarEventLimit,
    startDate: formatLocalDate(
      DateTime(_focusedMonth.year, _focusedMonth.month),
    ),
    // Day 0 of the following month *is* this month's last day, which is one
    // expression rather than arithmetic, and needs no December branch.
    endDate: formatLocalDate(
      DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0),
    ),
    organizationId: organization?.organizationId,
    search: _searchTerm.isEmpty ? null : _searchTerm,
  );

  /// `EventCalendar.tsx:128-154`, month-view `click` branch.
  ///
  /// The `VIEW_USERS_GLOBAL` / no-organization check is deliberately *not*
  /// repeated here: it belongs to [CreateEventButton], and having it in two
  /// places is how the calendar's version of this control and the list page's
  /// drifted apart in the first place. A day tap carries a date, so it passes
  /// one.
  void _onDaySelected(DateTime day, DateTime focusedDay) {
    // Only a *month* change re-queries. `table_calendar` fires this on every
    // day tap as well as every page swipe, and a query is a request for a
    // month — rebuilding an identical one would refetch a month already on
    // screen.
    final month = _monthOf(focusedDay);
    if (month != _focusedMonth) {
      setState(() => _focusedMonth = month);
    }
    unawaited(CreateEventButton.createForDay(context, ref, day));
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(selectedOrganizationProvider);
    final events = ref.watch(calendarEventsProvider(_buildQuery(organization)));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListScreenHeader(
              title: 'Event Calendar',
              action: CreateEventButton(),
            ),
            const SizedBox(height: 16),
            _Toolbar(onSearch: (value) => setState(() => _searchTerm = value)),
            const SizedBox(height: 16),
            _CalendarCard(
              state: events,
              focusedMonth: _focusedMonth,
              onPageChanged: (month) =>
                  setState(() => _focusedMonth = _monthOf(month)),
              onDaySelected: _onDaySelected,
            ),
          ],
        ),
      ),
    );
  }
}

/// The first of [month], in [month]'s own year and month.
///
/// `table_calendar` reports `focusedDay` as the 1st of the visible month, but a
/// month cell it hands back is the day that was tapped — which is not. Building
/// every `DateTime(y, m)` in this file through one function is what keeps the
/// query window and the grid from disagreeing about which month is loaded, and
/// it is a two-line helper rather than a repeated three-argument constructor.
DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

/// The search box and the "View All Events" link.
///
/// **Two controls where the React original had three**, and the arrangement is
/// `EventCalendar.tsx:244-269`: a search input, a `btn-primary` link to
/// `/events/list`, and the create button — which now sits in [ListScreenHeader]
/// as the screen's primary action, because that is the slot it occupies in the
/// original and the header is what that slot is for.
///
/// The `250px` is gone. Task 9.2 flags it among the fixed pixel sizes tuned for
/// a wide viewport, and a `Wrap` does the same job at every width: full-width
/// search above the link on a phone, beside it on a desktop.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      DebouncedSearchField(hintText: 'Search events...', onChanged: onSearch),
      OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.eventList),
        icon: const Icon(Icons.list),
        label: const Text('View All Events'),
      ),
    ],
  );
}

/// The grid, and the states it can be in.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.state,
    required this.focusedMonth,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  final AsyncValue<List<EventResponse>> state;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime day, DateTime focusedDay) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final error = state.whenOrNull(error: (error, stackTrace) => error);
    final events = state.value;

    if (error != null && events == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: ErrorDisplay.fromException(
            error is ApiException ? error : ApiRequestException('$error'),
          ),
        ),
      );
    }

    // The grid is kept mounted and dimmed while the next month loads, rather
    // than replaced by a spinner. `EventCalendar.tsx` did the same thing: it held
    // the previous `events` in state across the `useEffect` at `:102` and never
    // cleared them, so a month change showed the old month until the new one
    // arrived. Replacing the grid outright would be a flash task 4.14 was filed
    // to remove, in a new place.
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Opacity(
              opacity: state.isLoading && events != null ? 0.4 : 1,
              child: _CalendarGrid(
                focusedMonth: focusedMonth,
                onPageChanged: onPageChanged,
                onDaySelected: onDaySelected,
                events: events ?? const [],
              ),
            ),
            if (state.isLoading && events == null)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// The `TableCalendar` itself.
class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.onPageChanged,
    required this.onDaySelected,
    required this.events,
  });

  final DateTime focusedMonth;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime day, DateTime focusedDay) onDaySelected;
  final List<EventResponse> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `EventCalendar.tsx:174` colours a pill orange when the server is waiting on
    // *this* user's answer, so the id has to be read from the context here
    // rather than passed down.
    final currentUserId = ref.watch(userContextProvider)?.user.userId;

    // Days are keyed on `yyyy-MM-dd` because `eventLoader` is handed a
    // `DateTime` and has to look events up by *date*, and the wire format is the
    // only string that can compare equal across the two. `event.startAt` is the
    // naive-local `DateTime` built from the same two fields, so this is a
    // formatting call rather than a second implementation of the parsing — see
    // `EventResponse.startAt` and task 7.9.
    final byDay = <String, List<EventResponse>>{};
    for (final event in events) {
      byDay.putIfAbsent(formatLocalDate(event.startAt), () => []).add(event);
    }

    return TableCalendar<EventResponse>(
      focusedDay: focusedMonth,
      firstDay: DateTime.utc(2000, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      // react-big-calendar's `startOfWeek` default is Sunday, and this is the
      // one setting the port can carry over without deciding anything.
      startingDayOfWeek: StartingDayOfWeek.sunday,
      // Without this the header renders a format button offering the week and
      // two-week views — exactly what task 7.1 drops.
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: false,
      ),
      // Tall enough for the day number plus `kMaxEventsPerDay` bars, and not
      // much more. `table_calendar`'s default is 52, which fits a number and one
      // marker; `EventCalendar.tsx:297` let the whole grid grow to 800px instead,
      // which a fixed-height screen cannot reproduce — so this trades the
      // original's vertical room for a cap, and the cap is client-side for the
      // reason on `kMaxEventsPerDay`. **Whether two bars is legible at this
      // height is a browser question**, which is why the phase entry flags it.
      rowHeight: 64,
      // `DayBuilder` cells rather than the package's own, and the reason is
      // task 7.4: `#e7f0f7` is a *background* behind the whole cell, and
      // `CalendarStyle` in table_calendar 3.3.0 offers only `todayDecoration` —
      // a small dot — with no full-cell highlight option. Writing the cell is
      // the only way to get the colour the original painted.
      calendarBuilders: CalendarBuilders<EventResponse>(
        defaultBuilder: (context, day, focusedDay) => _DayCell(day: day),
        outsideBuilder: (context, day, focusedDay) =>
            _DayCell(day: day, outside: true),
        todayBuilder: (context, day, focusedDay) =>
            _DayCell(day: day, isToday: true),
        markerBuilder: (context, day, dayEvents) {
          if (dayEvents.isEmpty) return null;
          // `left`/`right`/`bottom` rather than `Positioned.fill`, which leaves
          // them null — an unbounded width, against a bar that asks for
          // `double.infinity`. `top` is the one edge that is not flush.
          return Positioned(
            // Keyed on the day, so "the bars for the 21st" is one findable
            // widget. Without it, asserting that an event landed on *its* day
            // rather than a neighbouring one means walking table_calendar's own
            // layout — a `TableRow` that is not in the element tree, a
            // `TableCell` that does not exist, and a week `Table` shared by
            // seven days. Three plausible ancestors and none of them answers the
            // question; this one does.
            key: ValueKey(eventMarkerKey(day)),
            left: 0,
            right: 0,
            top: _dayNumberHeight + 2,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in dayEvents.take(kMaxEventsPerDay))
                  _EventPill(
                    key: ValueKey(eventPillKey(event.eventId)),
                    event: event,
                    currentUserId: currentUserId,
                  ),
                if (dayEvents.length > kMaxEventsPerDay)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 1),
                    child: Text(
                      '+${dayEvents.length - kMaxEventsPerDay} more',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      eventLoader: (day) => byDay[formatLocalDate(day)] ?? const [],
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
    );
  }
}

/// The key on the bar area for one calendar day.
///
/// Public so a test can ask "which bars are on the 21st" directly, rather than
/// inferring the answer from where table_calendar happens to lay a cell out.
String eventMarkerKey(DateTime day) => 'markers-${formatLocalDate(day)}';

/// The key on an event's bar.
///
/// Public so the placement tests can find one bar by event id rather than by
/// matching on its label — a string two events can share, and one formatted with
/// a locale-dependent time. A key format spelled out twice is a key format that
/// will be fixed in one.
String eventPillKey(int eventId) => 'pill-$eventId';

/// How many event bars one day cell draws before it counts the rest.
///
/// **A cap the original did not have, and the reason is the package.**
/// `EventCalendar.tsx` rendered every event in a cell and let the grid grow;
/// `table_calendar` gives every cell a fixed [rowHeight] and clips marker
/// overflow by default (`canMarkersOverflow: false`), so a day with a dozen
/// events would render a truncated first bar and lose the rest silently.
///
/// Three-plus-a-count is the same shape `InventoryListScreen` already uses for
/// its unbounded per-row event list, chosen for the same reason — and it is a
/// client-side invention for the same reason, since there is no server-side way
/// to ask for fewer events on a day.
const int kMaxEventsPerDay = 3;

/// Height reserved for the date number.
///
/// `table_calendar` stacks the marker builder *over* the cell content rather
/// than below it, so the number and the bars have to agree on where one ends
/// and the other starts. Sized to one 12px line plus its top padding.
const double _dayNumberHeight = 20;

/// One day cell: the number, and today's background.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.isToday = false,
    this.outside = false,
  });

  final DateTime day;
  final bool isToday;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // Keyed on the full date, not the day-of-month. **A month grid has two
      // cells for most day numbers** — this month's, and the neighbouring
      // month's that pads the six-week grid — so a test that located a cell by
      // its number alone would be choosing between them by paint order. Naming
      // the cell makes "the 14th of March" one findable widget, which is what
      // the placement tests need to be about placement.
      key: ValueKey('day-${formatLocalDate(day)}'),
      color: isToday ? TevenTheme.todayHighlight : Colors.transparent,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.only(top: 2, left: 6),
      child: Text(
        '${day.day}',
        style: theme.textTheme.bodySmall?.copyWith(
          // `EventCalendar.tsx:315-322` bolds today's number in the month header
          // and nothing else.
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          color: outside ? theme.colorScheme.outline : null,
        ),
      ),
    );
  }
}

/// The coloured bar under a date — `eventPropGetter` plus the month-view label.
class _EventPill extends StatelessWidget {
  const _EventPill({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  final EventResponse event;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    // `EventCalendar.tsx:174` — orange means the server is waiting on *this*
    // user's answer, which is the one case where the colour carries information
    // rather than decoration. An event with no RSVP from this user at all stays
    // blue, so the check is for the `requested` value specifically and not for
    // "has any RSVP".
    final requested =
        currentUserId != null &&
        event.rsvps.any(
          (rsvp) =>
              rsvp.userId == currentUserId &&
              rsvp.availability == RsvpAvailability.requested,
        );

    // `EventCalendar.tsx:222`: the title followed by a `h:mm A` time.
    final label = '${event.title} ${DateFormat.jm().format(event.startAt)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      child: Tooltip(
        message: label,
        // **The pill is its own tap target, and it has to be.**
        // `EventCalendar.tsx:156-170` routes a click on a real event to
        // `/events/{id}`, which is the difference between opening an event and
        // opening the create form for that day. `table_calendar`'s own
        // `onEventTap` only fires for the marker widget it builds itself, and
        // supplying [CalendarBuilders.markerBuilder] replaces that widget
        // outright — so a pill with no handler here would fall through to the
        // cell's own gesture and create an event instead of opening one.
        child: InkWell(
          onTap: () => context.go(AppRoutes.eventDetailsPath(event.eventId)),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: requested ? TevenTheme.requestedRsvp : TevenTheme.primary,
              // `borderRadius: '5px'`, `EventCalendar.tsx:180`.
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // `opacity: 0.8` on the whole pill, `EventCalendar.tsx:181`.
              // Applied to the text rather than to the container, because a
              // container opacity would also dim the whole bar and make it read
              // as disabled. The one deliberate difference from the original's
              // rendering.
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
