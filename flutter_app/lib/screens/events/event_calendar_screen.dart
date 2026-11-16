import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' show TZDateTime;

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/theme/teven_theme.dart';
import '../../core/util/local_date.dart';
import '../../models/event.dart';
import '../../providers/auth_controller.dart';
import '../../providers/effective_organization_scope.dart';
import '../../providers/event_list.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/create_event_button.dart';
import '../../widgets/debounced_search_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/rsvp_widget.dart';

/// The month grid
///
/// Rebuilt on `table_calendar`. **Four things are dropped, and they are the four
/// the task names.** The week, work-week, day and agenda views, which the
/// calendar package this replaced had and this one does not; drag-to-select slot
/// creation, which goes with them, because a month grid has no time axis to
/// drag along; and the hover-to-reveal "Create Event" placeholder, which needed
/// a 100ms leave timer purely to avoid flickering, and whose affordance now has
/// a permanent home in the header button.
///
/// Clicking or tapping blank space in a day cell
/// (including the day-number row) opens a small popup for that day with actions
/// to view the day or create an event. Tapping an event pill opens that event;
/// the space between pills is treated as part of the pill hit area so it does
/// not trigger the day popup.
///
/// **This screen does not page.** See [kCalendarEventLimit] — the calendar this
/// replaced was handed the whole visible range and had no paging model to
/// violate, so there is nothing to accumulate here. The list at `/events/list`
/// is the one that pages.
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
  /// `onPageChanged`, and the calendar this replaced refetched from the
  /// displayed date on every navigation — keeping a separate "focused" and
  /// "fetched" month would only allow them to disagree, which is the shape of
  /// a stale-data bug rather than a feature.
  ///
  /// Initialized to the current month in the device's local zone and re-seeded
  /// to the reader's zone once that resolves, so the focused month follows the
  /// reader's zone the same way "today" does.
  DateTime _focusedMonth = _monthOf(DateTime.now());

  /// Whether [_focusedMonth] has been aligned to the reader's resolved zone.
  bool _focusedMonthSyncedToReaderZone = false;

  String _searchTerm = '';

  /// The query for the month on screen.
  ///
  /// The window is the **first and last day of the month, not the visible
  /// six-week grid.** The calendar this replaced took the start and the end of
  /// the month, which excludes the leading and trailing days from the
  /// neighbouring months that the grid draws. Those cells are drawn greyed and
  /// are always empty; widening the query to the grid would be a fix rather
  /// than a port, and would change which events appear where.
  ///
  /// [readerZone] names the zone the month is interpreted in, and the dates are
  /// local dates in that zone — so "March" means March where the reader is,
  /// and an event that lands on a different day in a different zone is bucketed
  /// accordingly.
  ///
  /// `limit` is [kCalendarEventLimit] and `offset` is absent.
  ListQuery _buildQuery(int? organizationId, String readerZone) => ListQuery(
    limit: kCalendarEventLimit,
    startDate: formatLocalDate(
      DateTime(_focusedMonth.year, _focusedMonth.month),
    ),
    // Day 0 of the following month *is* this month's last day, which is one
    // expression rather than arithmetic, and needs no December branch.
    endDate: formatLocalDate(
      DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0),
    ),
    organizationId: organizationId,
    search: _searchTerm.isEmpty ? null : _searchTerm,
    timezone: readerZone,
  );

  /// Shows the actions for a day when its blank space is activated.
  Future<void> _showDayActions(DateTime day) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(DateFormat.yMMMMEEEEd().format(day)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go(AppRoutes.eventDayUrlForDay(day));
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_view_day_outlined),
              title: Text('View Day'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(CreateEventButton.createForDay(context, ref, day));
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add),
              title: Text('Create Event'),
            ),
          ),
        ],
      ),
    );
  }

  /// A day cell's blank space was tapped.
  void _onDaySelected(DateTime day, DateTime focusedDay) {
    _syncFocusedMonth(focusedDay);
    unawaited(_showDayActions(day));
  }

  /// Keeps the loaded month in step with the month the grid is showing.
  ///
  /// Only a *month* change re-queries. `table_calendar` fires the day
  /// callbacks on every tap and long press as well as on every page swipe, and
  /// a query is a request for a month — rebuilding an identical one would
  /// refetch a month already on screen.
  void _syncFocusedMonth(DateTime focusedDay) {
    final month = _monthOf(focusedDay);
    if (month != _focusedMonth) {
      setState(() => _focusedMonth = month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationId = ref.watch(queryOrganizationIdProvider);
    final tz = ref.watch(timeZoneControllerProvider);
    final readerZone = tz.value?.effectiveZone ?? 'UTC';

    if (!_focusedMonthSyncedToReaderZone && tz.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusedMonthSyncedToReaderZone) return;
        final now = TZDateTime.now(zoneLocation(tz.value!.effectiveZone));
        setState(() {
          _focusedMonth = _monthOf(now);
          _focusedMonthSyncedToReaderZone = true;
        });
      });
    }

    final events = ref.watch(
      calendarEventsProvider(_buildQuery(organizationId, readerZone)),
    );

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
            // **The pending-RSVP card.**
            //
            // The original RSVP widget was written in the same commit that added
            // `GET /api/events/rsvps/requested` and was never mounted — so the
            // endpoint had been reachable and unused for the whole life of the
            // app. It lives here because the calendar is where the request is
            // already visible: an event waiting on this user's answer is drawn in
            // orange on its bar, and this is the control that answers it. Task
            // 7.12 owns the question of whether the route should be exposed at
            // all.
            //
            // **It renders nothing at all** when there is nothing pending, so it
            // costs the calendar's layout nothing in the common case.
            const RsvpWidget(),
            const SizedBox(height: 16),
            _Toolbar(onSearch: (value) => setState(() => _searchTerm = value)),
            const SizedBox(height: 16),
            _CalendarCard(
              state: events,
              focusedMonth: _focusedMonth,
              readerZone: readerZone,
              onPageChanged: (month) =>
                  setState(() => _focusedMonth = _monthOf(month)),
              onDaySelected: _onDaySelected,
            ),
            const SizedBox(height: 8),
            Text(
              'Click the day number to open the day, blank space for options, or an event to open it.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
/// **Two controls where the calendar this replaced had three**: a search
/// input, a link to `/events/list`, and the create button — which now sits in
/// [ListScreenHeader] as the screen's primary action, because that is the slot
/// it occupies and the header is what that slot is for.
///
/// The search field and the list link sit in a `Wrap`, so they stack on a
/// narrow viewport and sit side by side when there is room — no fixed width.
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
    required this.readerZone,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  final AsyncValue<List<EventResponse>> state;
  final DateTime focusedMonth;
  final String readerZone;
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
    // than replaced by a spinner. The calendar this replaced did the same
    // thing: it held the previous events across the fetch and never cleared
    // them, so a month change showed the old month until the new one arrived.
    // Replacing the grid outright would be a flash was filed to
    // remove, in a new place.
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
                readerZone: readerZone,
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
    required this.readerZone,
    required this.onPageChanged,
    required this.onDaySelected,
    required this.events,
  });

  final DateTime focusedMonth;
  final String readerZone;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime day, DateTime focusedDay) onDaySelected;
  final List<EventResponse> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A pill is orange when the server is waiting on *this* user's answer, so
    // the id has to be read from the context here rather than passed down.
    final currentUserId = ref.watch(userContextProvider)?.user.userId;

    // The day an event lands on is its date in the reader's zone — an event at
    // 02:00 Berlin is on the previous day in New York, and one at 23:00 Berlin
    // is on the next day in Auckland. The grid keys on `yyyy-MM-dd` of that
    // wall clock, so the bucket is the reader's day.
    final byDay = <String, List<EventResponse>>{};
    for (final event in events) {
      byDay.putIfAbsent(event.dateIn(readerZone), () => []).add(event);
    }
    final readerToday = TZDateTime.now(zoneLocation(readerZone));
    final readerTodayDate = DateTime(
      readerToday.year,
      readerToday.month,
      readerToday.day,
    );

    return TableCalendar<EventResponse>(
      focusedDay: focusedMonth,
      firstDay: DateTime.utc(2000, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      // Sunday, which is the first day of the week the calendar this replaced
      // used — and the one setting carried over without deciding anything.
      startingDayOfWeek: StartingDayOfWeek.sunday,
      // Without this the header renders a format button offering the week and
      // two-week views — exactly what drops.
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      calendarFormat: CalendarFormat.month,
      // **No gestures, and the reason is that the calendar was taking over
      // the page's scrolling.**
      //
      // The default is `AvailableGestures.all`, which gives the month grid a
      // horizontal swipe. The grid is a `PageView`, and a `PageView` answers
      // *scroll signals* as well as drags — so a trackpad's horizontal
      // component slid the month sideways mid-scroll, and a sliver of the
      // neighbouring month appeared at the right edge of a grid whose days
      // were all already on screen.
      //
      // Worse, the grid claimed the signal: `Scrollable` only registers
      // interest in a scroll event if it would actually scroll, and a
      // horizontal `Scrollable` scrolls on the *x* component of the delta.
      // So a diagonal scroll was taken by the calendar and not by the page.
      //
      // `AvailableGestures.none` gives the `PageView`
      // `NeverScrollableScrollPhysics`, which opts out of both. The month is
      // still reachable from the header's chevrons — which is how it was
      // reached before, since a month grid has no time axis to swipe along.
      availableGestures: AvailableGestures.none,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: false,
        leftChevronIcon: Tooltip(
          message: 'Previous month',
          child: Icon(Icons.chevron_left),
        ),
        rightChevronIcon: Tooltip(
          message: 'Next month',
          child: Icon(Icons.chevron_right),
        ),
      ),
      // Tall enough for the day number plus [kMaxEventsPerDay] bars. The
      // height is a budget rather than a preference — `table_calendar` gives
      // every cell a fixed row and clips whatever does not fit — and the
      // budget used to be short: at 64 it held the number and two bars, and a
      // third bar was cut off mid-height along with the "+N more" line a
      // busy day draws.
      rowHeight: _rowHeight,
      // The weekday header's own rules, and the labels that go with them.
      daysOfWeekStyle: _daysOfWeekStyle,
      // `DayBuilder` cells rather than the package's own, and the reason is
      // `#e7f0f7` is a *background* behind the whole cell, and
      // `CalendarStyle` in table_calendar 3.3.0 offers only `todayDecoration` —
      // a small dot — with no full-cell highlight option. Writing the cell is
      // the only way to get a full-cell highlight at all. "Today" is the reader's
      // zone, which may differ from the device's.
      calendarBuilders: CalendarBuilders<EventResponse>(
        defaultBuilder: (context, day, focusedDay) => _DayCell(
          day: day,
          isToday: isSameDay(day, readerTodayDate),
          onViewDay: () => context.go(AppRoutes.eventDayUrlForDay(day)),
        ),
        outsideBuilder: (context, day, focusedDay) => _DayCell(
          day: day,
          outside: true,
          onViewDay: () => context.go(AppRoutes.eventDayUrlForDay(day)),
        ),
        todayBuilder: (context, day, focusedDay) => _DayCell(
          day: day,
          isToday: isSameDay(day, readerTodayDate),
          onViewDay: () => context.go(AppRoutes.eventDayUrlForDay(day)),
        ),
        // The weekday row is written by hand, and the reason is the rules:
        // see [_DayOfWeekCell].
        dowBuilder: (context, day) => _DayOfWeekCell(day: day),
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
            // The bars start where the number's own line box ends, which is
            // what [_dayNumberHeight] is sized for. There is no gap on top of
            // this: the number's box already provides one.
            top: _dayNumberHeight,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in dayEvents.take(kMaxEventsPerDay))
                  _EventPill(
                    key: ValueKey(eventPillKey(event.eventId)),
                    event: event,
                    currentUserId: currentUserId,
                    readerZone: readerZone,
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
/// **A cap, and the reason is the package.** The calendar this replaced
/// rendered every event in a cell and let the grid grow; `table_calendar` gives
/// every cell a fixed [rowHeight] and clips marker overflow by default
/// (`canMarkersOverflow: false`), so a day with a dozen events would render a
/// truncated first bar and lose the rest silently.
///
/// Four-plus-a-count is the same shape `InventoryListScreen` already uses for
/// its unbounded per-row event list, chosen for the same reason — and it is a
/// client-side invention, since there is no server-side way to ask for fewer
/// events on a day.
///
/// **Three was too few, and the row height was the reason.** The cap and the
/// height have to agree: a cap the row cannot fit is a bar that is drawn and
/// then cut off. At 64 the row held the number and two bars, so the third was
/// clipped and the "+N more" line with it — a day with four events showed two
/// bars and a half of a third, and said nothing about the fourth. Four bars
/// and a count is what [_rowHeight] now pays for.
const int kMaxEventsPerDay = 4;

/// Height reserved for the date number.
///
/// `table_calendar` stacks the marker builder *over* the cell content rather
/// than below it, so the number and the bars have to agree on where one ends
/// and the other starts. Sized to one 12px line (16px) plus its top padding.
const double _dayNumberHeight = 20;

/// The bar's font size.
const double _eventPillFontSize = 11;

/// The bar's line height, as a multiple of its font size.
///
/// **Fixed rather than left to the font.** The row is a fixed height and
/// `table_calendar` clips whatever does not fit, so a bar whose height
/// depends on the font's own metrics is a bar that fits in one browser and
/// not in another — the widget test's font is not the browser's font, and it
/// measures taller. A line height is exact: the glyphs are scaled to fit it.
const double _eventPillLineHeight = 1.2;

/// Height of one event bar.
///
/// The text's line height plus the pixel of padding above and below it.
const double _eventPillHeight = _eventPillFontSize * _eventPillLineHeight + 2;

/// Height of the "+N more" line.
///
/// The theme's `labelSmall` — 11px at a line height of 1.45 — plus the pixel
/// of padding above it.
const double _moreLineHeight = 11 * 1.45 + 1;

/// Slack in a week row, so the content does not end flush against the rule
/// under it.
const double _rowSlack = 2.25;

/// Height of one week row.
///
/// **100, and the budget it pays for is written out rather than asserted.** The
/// row holds the date number ([_dayNumberHeight]) and then the bars:
/// [kMaxEventsPerDay] of them at [_eventPillHeight] each, plus the
/// "+N more" line ([_moreLineHeight]) a busier day draws in their place, with
/// [_rowSlack] to spare.
///
/// **Twice the 64 it was, and the arithmetic is the reason.** The row is a
/// budget — the date number, then the bars, then the "+N more" line — and
/// `table_calendar` clips whatever does not fit. 64 held the number and two
/// bars; 100 holds the number, [kMaxEventsPerDay] bars and the count.
///
/// The calendar this replaced had no row height to disagree with: it let the
/// grid grow to fit its events. This is still a cap rather than unbounded
/// growth, and the cap is client-side for the reason on [kMaxEventsPerDay].
///
/// **A whole number, deliberately.** The rules between the week rows are one
/// pixel, and a fractional row height puts them on a half pixel, where they
/// are antialiased into two paler ones.
const double _rowHeight =
    _dayNumberHeight +
    kMaxEventsPerDay * _eventPillHeight +
    _moreLineHeight +
    _rowSlack;

/// The weekday header's rules.
///
/// **The grid is ruled, and always was.** A frame around the month grid, a rule
/// under the weekday names, a rule between the week rows and a rule between the
/// day columns — the calendar this replaced drew all four, and they are what
/// makes a month grid read as a grid rather than as a list of numbers.
///
/// This decoration carries the frame's top edge and the rule under the
/// weekday names; the rule between the columns has to come from the cells
/// themselves, because `CalendarStyle.tableBorder` — the one place
/// table_calendar offers for rules — draws its verticals across the *whole*
/// table, which would put a line through the middle of every label.
const DaysOfWeekStyle _daysOfWeekStyle = DaysOfWeekStyle(
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: TevenTheme.gridline),
      bottom: BorderSide(color: TevenTheme.gridline),
      left: BorderSide(color: TevenTheme.gridline),
      right: BorderSide(color: TevenTheme.gridline),
    ),
  ),
);

/// The column a day sits in, counting from the grid's first column.
///
/// `DateTime.weekday` runs Monday (1) to Sunday (7), and the grid starts on
/// Sunday (`startingDayOfWeek`), so `weekday % 7` puts Sunday at 0 and
/// Saturday at 6. The weekday header and the day cells both ask this
/// question, and they have to agree on the answer or the rules will not line
/// up with the columns they are ruling.
int _columnOf(DateTime day) => day.weekday % 7;

/// One day cell: the number, today's background, and the grid's rules.
///
/// The day number pill opens the day view directly. Activating other blank
/// space in the cell opens the day actions popup; event pills handle their own
/// taps.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.isToday = false,
    this.outside = false,
    this.onViewDay,
  });

  final DateTime day;
  final bool isToday;
  final bool outside;

  /// Opens the day view for [day].
  final VoidCallback? onViewDay;

  @override
  Widget build(BuildContext context) {
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
      // **The rules, drawn over the cell rather than under it.**
      //
      // `foregroundDecoration` rather than `decoration`, for two reasons.
      // Today's fill is opaque, so a rule painted *under* the cell would
      // disappear under it and the grid would have a gap in it exactly where
      // the highlight is. And a `decoration` would inset the cell's child by
      // the rule's width, which is a hair's breadth of layout for no reason.
      //
      // The right edge is ruled on every cell — it is the rule between this
      // column and the next, and the grid's own right edge on the last one —
      // and the left edge only on the first column, where it is the grid's
      // left edge and every other cell's left edge is its neighbour's right.
      foregroundDecoration: BoxDecoration(
        border: Border(
          left: _columnOf(day) == 0
              ? const BorderSide(color: TevenTheme.gridline)
              : BorderSide.none,
          right: const BorderSide(color: TevenTheme.gridline),
          bottom: const BorderSide(color: TevenTheme.gridline),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _dayNumberHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _DayNumberButton(
                  day: day,
                  isToday: isToday,
                  outside: outside,
                  onTap: onViewDay,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A light pill around the day number, always present so the day row reads as
/// an affordance rather than plain text.
class _DayNumberPill extends StatelessWidget {
  const _DayNumberPill({
    required this.day,
    required this.isToday,
    required this.outside,
    this.showViewIcon = false,
  });

  final DateTime day;
  final bool isToday;
  final bool outside;
  final bool showViewIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = outside
        ? theme.colorScheme.outline
        : theme.colorScheme.onSurface;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
      color: color,
      height: 1.1,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${day.day}', style: textStyle),
          const SizedBox(width: 3),
          Opacity(
            opacity: showViewIcon ? 1 : 0,
            child: Icon(
              Icons.calendar_view_day_outlined,
              size: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The interactive day-number pill: opens the day view and reveals a view icon
/// on hover of the region.
class _DayNumberButton extends StatefulWidget {
  const _DayNumberButton({
    required this.day,
    required this.isToday,
    required this.outside,
    this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool outside;
  final VoidCallback? onTap;

  @override
  State<_DayNumberButton> createState() => _DayNumberButtonState();
}

class _DayNumberButtonState extends State<_DayNumberButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final pill = _DayNumberPill(
      day: widget.day,
      isToday: widget.isToday,
      outside: widget.outside,
      showViewIcon: _hovered,
    );
    if (widget.onTap == null) return pill;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: pill,
      ),
    );
  }
}

/// One weekday name, and the rule that separates it from the next column.
///
/// **Written by hand because the rules have to reach the header row.**
/// `table_calendar`'s own weekday row is a bare `Center(Text(...))` — and the
/// one border the package offers, `CalendarStyle.tableBorder`, rules the
/// whole table at once, which would draw a line through the middle of every
/// label. The rules belong *between* the labels, so the row is rebuilt here.
///
/// The labels themselves are the package's own — `DateFormat.E` for the
/// text — in the app's theme colour rather than the package's hard-coded
/// grey, because a row written by hand should not hard-code a colour the rest
/// of the app has already chosen.
class _DayOfWeekCell extends StatelessWidget {
  const _DayOfWeekCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The package's own weekend rule (`_isWeekend`), which is what makes its
    // weekend labels a lighter grey than the rest.
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    return Container(
      alignment: Alignment.center,
      // The rule *between* this column and the one before it. The first
      // column's left edge is the grid's, and the header's frame draws it.
      foregroundDecoration: BoxDecoration(
        border: Border(
          left: _columnOf(day) == 0
              ? BorderSide.none
              : const BorderSide(color: TevenTheme.gridline),
        ),
      ),
      child: Text(
        DateFormat.E().format(day),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isWeekend
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurface,
          // The weekday names are bold.
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The coloured bar under a date.
class _EventPill extends StatelessWidget {
  const _EventPill({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.readerZone,
  });

  final EventResponse event;
  final int? currentUserId;
  final String readerZone;

  @override
  Widget build(BuildContext context) {
    // Orange means the server is waiting on *this* user's answer, which is the
    // one case where the colour carries information rather than decoration. An
    // event with no RSVP from this user at all stays blue, so the check is for
    // the `requested` value specifically and not for "has any RSVP".
    final requested =
        currentUserId != null &&
        event.rsvps.any(
          (rsvp) =>
              rsvp.userId == currentUserId &&
              rsvp.availability == RsvpAvailability.requested,
        );

    // The title, followed by the event's time in the reader's zone.
    final label = '${event.title} ${event.timeIn(readerZone)}';

    return Tooltip(
      message: label,
      // **The pill is its own tap target, and it has to be.**
      // A click on a real event opens `/events/{id}`. The vertical padding is
      // inside the tappable area so the space between visual bars still counts
      // as part of this pill rather than as blank day-cell space.
      child: InkWell(
        onTap: () => context.go(AppRoutes.eventDetailsPath(event.eventId)),
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: requested ? TevenTheme.requestedRsvp : TevenTheme.primary,
              // A 5px radius on the bar.
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 0.8 opacity on the whole pill, applied to the text rather than
              // to the container — a container opacity would also dim the whole
              // bar and make it read as disabled.
              style: const TextStyle(
                color: Colors.white,
                fontSize: _eventPillFontSize,
                // **A fixed line height, so the bar is the height the row's
                // budget says it is.** The row is a fixed height and anything
                // that does not fit is clipped, so a bar whose height depends
                // on the font is a bar that fits in one browser and not in
                // another — see [_eventPillLineHeight].
                height: _eventPillLineHeight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
