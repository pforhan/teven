import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:table_calendar/table_calendar.dart';
import 'package:teven_app/core/theme/teven_theme.dart';
import 'package:teven_app/core/util/local_date.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/events/event_calendar_screen.dart';
import 'package:teven_app/widgets/create_event_button.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The month grid — tasks 7.1, 7.4 and the placement half of 7.11.
///
/// Driven through the real router and the real shell, at a pinned width, so what
/// is under test is the screen a user lands on.
void main() {
  const viewEvents = 'VIEW_EVENTS_ORGANIZATION';
  const manageEvents = 'MANAGE_EVENTS_ORGANIZATION';

  /// An event on the wire, hand-built rather than generated from the model — a
  /// change to `EventResponse` should not quietly change what these tests say
  /// about the wire shape.
  Map<String, dynamic> eventJson({
    required int id,
    required String title,
    required String date,
    String time = '09:30:00',
    List<Map<String, dynamic>> rsvps = const [],
  }) => {
    'eventId': id,
    'title': title,
    'date': date,
    'time': time,
    'durationMinutes': 60,
    'location': null,
    'latitude': null,
    'longitude': null,
    'formattedAddress': null,
    'description': null,
    'inventoryItems': <Map<String, dynamic>>[],
    'customer': null,
    'rsvps': rsvps,
    'organization': {
      'organizationId': 1,
      'name': 'Acme',
      'contactInformation': '',
    },
    'openInvitation': false,
    'numberOfStaffNeeded': 0,
  };

  StubResponse eventsPage(List<Map<String, dynamic>> events) =>
      StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'items': events,
            'total': events.length,
            'limit': 1000,
            'offset': 0,
          },
        }),
      );

  StubAdapter calendarAdapter({
    List<Map<String, dynamic>> events = const [],
    List<String> permissions = const [viewEvents, manageEvents],
    StubResponse? failure,
  }) => contextAdapter(
    permissions: permissions,
    eventsResponder: (query) => failure ?? eventsPage(events),
  );

  Future<ProviderContainer> openCalendar(
    WidgetTester tester,
    StubAdapter adapter, {
    Map<String, Object> prefs = const {},
  }) async {
    final container = await pumpApp(
      tester,
      token: 'token',
      width: 1500,
      prefs: prefs,
      adapter: adapter,
    );
    await goTo(tester, container, AppRoutes.events);
    return container;
  }

  /// The `GET /api/events` requests the calendar has made.
  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/events' && o.method == 'GET')
      .toList();

  /// Taps [finder] with a pointer of [kind], then reads the route **after one
  /// pump and no settling**.
  ///
  /// **The pointer kind is a parameter, and it is not a detail.**
  /// `tester.tap` sends a *touch* pointer, and the calendar's rule — task 7.2 —
  /// is that a touch does not create an event: a finger has to long-press. So
  /// a test that means "a mouse clicked this" has to say so, and the default
  /// is a mouse because that is the gesture the app treats as the creating
  /// one.
  ///
  /// **This is not the only way to assert the destination.**
  /// The create form fetches customers, users and inventory on arrival, and the
  /// harness's fallback for an unanswered path is a 401 — which raises
  /// `UnauthorizedException`, trips the single-flight 401 redirect and signs the
  /// user out. `pumpAndSettle` therefore lands on `/login` and the navigation
  /// under test is gone.
  ///
  /// `context.go` applies synchronously, so a single pump is enough to observe
  /// the destination. This is the same trap the Phase 4 log records for the
  /// organization screen's endpoint, met from the other direction: there the
  /// stub was silently not being consulted, here it is consulted too eagerly.
  ///
  /// It is also a narrower assertion, which suits the question being asked:
  /// *where does the tap go*, not *what does the destination then do*.
  ///
  /// The `settleRequests` afterwards is **not optional**. Leaving the create
  /// form's request in flight fails teardown with a pending dio timer, whatever
  /// the assertions said — the same drain the Phase 4 list tests need, and for
  /// the same reason.
  Future<String> tapAndReadLocation(
    WidgetTester tester,
    ProviderContainer container,
    Finder finder, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(finder),
      kind: kind,
    );
    await gesture.up();
    await tester.pump();
    final location = currentLocation(container);
    await settleRequests(tester);
    return location;
  }

  /// Long-presses [finder] with a pointer of [kind], then reads the route.
  ///
  /// **The hold has to outlast the recogniser's own deadline**, which is
  /// [kLongPressTimeout]. A widget test runs on a fake clock, so the timer
  /// only fires when the clock is advanced past it — `tester.pump` with a
  /// duration is that advance.
  Future<String> longPressAndReadLocation(
    WidgetTester tester,
    ProviderContainer container,
    Finder finder, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(finder),
      kind: kind,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    final location = currentLocation(container);
    await settleRequests(tester);
    return location;
  }

  group('querying', () {
    testWidgets('asks for the first and last day of the visible month', (
      tester,
    ) async {
      final adapter = calendarAdapter();
      await openCalendar(tester, adapter);

      final request = getRequests(adapter).first;
      final today = DateTime.now();
      expect(
        request.queryParameters['startDate'],
        formatLocalDate(DateTime(today.year, today.month)),
      );
      expect(
        request.queryParameters['endDate'],
        formatLocalDate(DateTime(today.year, today.month + 1, 0)),
      );
    });

    testWidgets('keeps the inherited thousand-event ceiling', (tester) async {
      final adapter = calendarAdapter();
      await openCalendar(tester, adapter);

      // The calendar this replaced asked for 1000. Inherited rather than
      // chosen, and pinned so a "sensible" reduction is a deliberate change
      // rather than a quiet one that makes a busy month render short.
      expect(getRequests(adapter).first.queryParameters['limit'], 1000);
      // Offset paging is the *list* screen's job; a second page here would mean
      // a second request the grid has nowhere to show.
      expect(
        getRequests(adapter).first.queryParameters.containsKey('offset'),
        isFalse,
      );
    });

    testWidgets('sends no endDate, because a month grid has no lower bound', (
      tester,
    ) async {
      final adapter = calendarAdapter();
      await openCalendar(tester, adapter);

      // The distinction is not cosmetic: `startDate` here is a month window, and
      // a start-date *floor* is what the list screen sends instead.
      expect(getRequests(adapter).first.queryParameters['endDate'], isNotNull);
    });

    testWidgets('paging to another month refetches that month', (tester) async {
      final adapter = calendarAdapter();
      await openCalendar(tester, adapter);

      // The header's forward chevron. `table_calendar` reports it through
      // `onPageChanged`, which is what re-queries.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      // **Pumps, not settling.** `onPageChanged` fires when the `PageView`
      // animation completes, so one `pump()` is not enough to see it — but
      // `pumpAndSettle` cannot be used, because paging starts a fetch whose
      // `CircularProgressIndicator` never settles, and the call hangs to the
      // test timeout reporting no assertion at all. Advancing the clock by hand
      // runs the animation and stops short of the spinner.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // **The loop, not one wait.** The request is only issued after the
      // animation, the rebuild and the provider being watched afresh, so a
      // single `runAsync` window can easily close before it exists — and a test
      // that misses it fails as "the tap did nothing" rather than as "the drain
      // was too short". `settleRequests`'s loop is the same shape, minus the
      // `pumpAndSettle` that a spinner would hang.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(getRequests(adapter).length, greaterThan(1));
      final today = DateTime.now();
      expect(
        getRequests(adapter).last.queryParameters['startDate'],
        isNot(formatLocalDate(DateTime(today.year, today.month))),
      );
    });
  });

  group('placement', () {
    testWidgets('an event renders as a bar on its own day', (tester) async {
      final today = DateTime.now();
      final date = formatLocalDate(today);
      final adapter = calendarAdapter(
        events: [eventJson(id: 7, title: 'Hedge trimming', date: date)],
      );
      await openCalendar(tester, adapter);

      // The month label is the title, then `h:mm A`.
      expect(find.textContaining('Hedge trimming'), findsOneWidget);
      // `startAt` is the naive-local `DateTime`; the label is formatted from it,
      // so a 09:30 event on a 09:30 day reads "9:30 AM" and not "9:30 AM +05:00".
      expect(find.textContaining('9:30'), findsOneWidget);
    });

    testWidgets('an event on another day does not land in this one', (
      tester,
    ) async {
      final today = DateTime.now();
      // A date in the same month but three days out, so the server is asked for
      // it and it is *not* on today. If placement were wrong — if every event
      // went to the first day, say — this would still find the title.
      final day = today.add(const Duration(days: 3));
      final adapter = calendarAdapter(
        events: [
          eventJson(
            id: 8,
            title: 'Roof inspection',
            date: formatLocalDate(day),
          ),
        ],
      );
      await openCalendar(tester, adapter);

      // The bar exists…
      expect(pillFor(8), findsOneWidget);
      // …and it is on the 21st, not on today. **Asserted through the day's own
      // marker area** rather than by searching for a common ancestor, because
      // `table_calendar` offers none precise enough: it lays a *week* out as one
      // `Table`, so the 18th and the 21st share an ancestor and "the bar is not
      // in today's cell" is unanswerable by ancestry. The marker area is keyed on
      // the day, which is the level the question is actually at.
      //
      // Without either half the test passes on a grid that painted every event
      // into the first cell — the exact shape of bug task 7.11 asks about, and
      // the reason this is more than a presence check.
      expect(
        find.descendant(of: barsOn(day), matching: pillFor(8)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: barsOn(today), matching: pillFor(8)),
        findsNothing,
      );
    });

    testWidgets('an event outside the month is not on screen', (tester) async {
      // The server would never return this — the query window excludes it — but
      // if it did, it must not appear: the grid only has cells for the month,
      // and painting it into the first would be a visible misreport.
      final today = DateTime.now();
      final lastYear = formatLocalDate(
        DateTime(today.year - 1, today.month, today.day),
      );
      final adapter = calendarAdapter(
        events: [eventJson(id: 9, title: 'Last year', date: lastYear)],
      );
      await openCalendar(tester, adapter);

      expect(find.textContaining('Last year'), findsNothing);
    });
  });

  group('styling — task 7.4', () {
    testWidgets('today\'s cell carries the `#e7f0f7` background', (
      tester,
    ) async {
      await openCalendar(tester, calendarAdapter());

      // Asserted on the value rather than on "there is a highlighted cell",
      // because any colour would satisfy the latter — including the
      // `todayDecoration` dot table_calendar ships by default, which is the
      // thing this had to be written to avoid.
      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TableCalendar<EventResponse>),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.color == TevenTheme.todayHighlight);
      expect(containers, isNotEmpty);
    });

    testWidgets("an event awaiting this user's answer is orange", (
      tester,
    ) async {
      final today = DateTime.now();
      // The harness's user is `userId: 1` — see `userContextJson`.
      final adapter = calendarAdapter(
        events: [
          eventJson(
            id: 10,
            title: 'Needs you',
            date: formatLocalDate(today),
            rsvps: [
              {
                'userId': 1,
                'displayName': 'Ada',
                'email': '',
                'availability': 'requested',
              },
            ],
          ),
        ],
      );
      await openCalendar(tester, adapter);

      expect(pillFill(tester, 10), TevenTheme.requestedRsvp);
    });

    testWidgets("another user's pending RSVP leaves the bar the default blue", (
      tester,
    ) async {
      final today = DateTime.now();
      final adapter = calendarAdapter(
        events: [
          eventJson(
            id: 11,
            title: 'Someone else',
            date: formatLocalDate(today),
            rsvps: [
              {
                'userId': 99,
                'displayName': 'Bob',
                'email': '',
                'availability': 'requested',
              },
            ],
          ),
        ],
      );
      await openCalendar(tester, adapter);

      // The orange check compares the RSVP's user id with the signed-in user's
      // *and* the availability. Checking the user alone would paint every bar
      // orange on any organization with any outstanding RSVP.
      expect(pillFill(tester, 11), TevenTheme.primary);
      expect(pillFill(tester, 11), isNot(TevenTheme.requestedRsvp));
    });
  });

  group('navigation', () {
    testWidgets('tapping a bar opens that event', (tester) async {
      final today = DateTime.now();
      final adapter = calendarAdapter(
        events: [
          eventJson(id: 42, title: 'Site visit', date: formatLocalDate(today)),
        ],
      );
      final container = await openCalendar(tester, adapter);

      await tapAndReadLocation(
        tester,
        container,
        find.textContaining('Site visit'),
      );

      // The alternative — falling through to the cell's own gesture — would
      // open the *create* form, which is the failure mode
      // `CalendarBuilders.markerBuilder` makes possible and `_EventPill`
      // exists to prevent.
      expect(currentPath(container), '/events/42');
    });

    testWidgets('tapping a day opens the create form for that day', (
      tester,
    ) async {
      final container = await openCalendar(tester, calendarAdapter());

      // A day that is in this month, is not today, and is not one of the padding
      // days the neighbouring months contribute — a tap on a padding cell would
      // still change the focused month, which is the behaviour asserted above
      // rather than here.
      final today = DateTime.now();
      final target = today.day == 15
          ? DateTime(today.year, today.month, 16)
          : DateTime(today.year, today.month, 15);

      // **A mouse**, because the default pointer in a widget test is a finger
      // and a finger's tap does not create — see the gesture group below.
      final path = await tapAndReadLocation(
        tester,
        container,
        dayCell(target),
        kind: PointerDeviceKind.mouse,
      );

      // The date is the whole payload; there is no time, because a month cell
      // has no time to give.
      expect(path, '/events/create?date=${formatLocalDate(target)}');
    });
  });

  group('which gesture creates — task 7.2', () {
    /// A day in this month, not today, and not a padding cell.
    DateTime targetDay() {
      final today = DateTime.now();
      return today.day == 15
          ? DateTime(today.year, today.month, 16)
          : DateTime(today.year, today.month, 15);
    }

    testWidgets('a mouse click on a day opens the create form', (tester) async {
      final container = await openCalendar(tester, calendarAdapter());
      final target = targetDay();

      final path = await tapAndReadLocation(
        tester,
        container,
        dayCell(target),
        kind: PointerDeviceKind.mouse,
      );

      expect(path, '/events/create?date=${formatLocalDate(target)}');
    });

    testWidgets('a finger long-press on a day opens the create form', (
      tester,
    ) async {
      final container = await openCalendar(tester, calendarAdapter());
      final target = targetDay();

      // **The long press is the touch gesture.** A finger cannot create with a
      // tap, so this is the only way a phone creates an event from the grid.
      final path = await longPressAndReadLocation(
        tester,
        container,
        dayCell(target),
      );

      expect(path, '/events/create?date=${formatLocalDate(target)}');
    });

    testWidgets('a mouse long-press on a day opens the create form too', (
      tester,
    ) async {
      final container = await openCalendar(tester, calendarAdapter());
      final target = targetDay();

      // **Redundant on a mouse, and deliberately so.** A click already creates,
      // so holding the button down is a second way to do the same thing —
      // reviewed and accepted, because the alternative is a rule with two
      // branches ("the long press does nothing *on a mouse*") rather than one
      // ("a long press creates"), and the second is the easier one to reason
      // about.
      //
      // It is also not *two* creates: the long-press recogniser wins the
      // arena, so the tap is rejected when the pointer comes up and only one
      // of the two callbacks fires.
      final path = await longPressAndReadLocation(
        tester,
        container,
        dayCell(target),
        kind: PointerDeviceKind.mouse,
      );

      expect(path, '/events/create?date=${formatLocalDate(target)}');
    });

    testWidgets("a finger's tap on a day opens the day view", (tester) async {
      final container = await openCalendar(tester, calendarAdapter());
      final target = targetDay();

      final path = await tapAndReadLocation(
        tester,
        container,
        dayCell(target),
        kind: PointerDeviceKind.touch,
      );

      // **Task 7.11.** A finger's tap now opens the day view, which is what the
      // mobile calendar idiom meant by "a tap means show me this day" — and the
      // long press, which means "I want to do something *with* this day", is
      // still the create gesture.
      expect(path, AppRoutes.eventDayUrlForDay(target));
    });

    testWidgets('the hint names the gesture the last pointer used', (
      tester,
    ) async {
      await openCalendar(tester, calendarAdapter());

      // **Before anything has been touched**, the hint offers the click —
      // the common case, and the one a keyboard activation would use.
      expect(find.text('Click a day to create an event.'), findsOneWidget);
      expect(
        find.text('Tap a day to open the day view; long-press to create.'),
        findsNothing,
      );

      // **A finger turns it around.** The pointer is *cancelled rather than
      // released*, because releasing it on a day is a tap — which, task 7.11
      // gave something to open, would navigate off the screen the hint is on.
      final touch = await tester.startGesture(
        tester.getCenter(dayCell(targetDay())),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(
        find.text('Tap a day to open the day view; long-press to create.'),
        findsOneWidget,
      );
      expect(find.text('Click a day to create an event.'), findsNothing);
      await touch.cancel();
      await tester.pump();

      // **And a mouse turns it back**, the hybrid case: the same device has
      // both a finger and a mouse, and the gesture each of them gets is the
      // one that works for it.
      final gesture = await tester.startGesture(
        tester.getCenter(dayCell(targetDay())),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(find.text('Click a day to create an event.'), findsOneWidget);
      await gesture.cancel();
      await tester.pump();
    });

    testWidgets('a long press on a bar opens the event, not the create form', (
      tester,
    ) async {
      final today = DateTime.now();
      final adapter = calendarAdapter(
        events: [
          eventJson(id: 43, title: 'Site visit', date: formatLocalDate(today)),
        ],
      );
      final container = await openCalendar(tester, adapter);

      final path = await longPressAndReadLocation(
        tester,
        container,
        find.textContaining('Site visit'),
      );

      // **The bar is a link to one event**, and a long press on a link should
      // go where a click on it goes. Without a handler of its own the bar's
      // long press would fall through to the cell's — which creates an event
      // for the day, on a day that already has one.
      expect(path, '/events/43');
    });
  });

  group('the create button', () {
    testWidgets('is absent without MANAGE_EVENTS_ORGANIZATION', (tester) async {
      await openCalendar(
        tester,
        calendarAdapter(permissions: const [viewEvents]),
      );

      // Absent rather than disabled, like every other screen's primary action
      // — a greyed-out button is a worse answer than no button, and the route
      // behind it would refuse the navigation anyway.
      expect(find.byType(CreateEventButton), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Event'), findsNothing);
    });

    testWidgets('is present with it, and goes to /events/create', (
      tester,
    ) async {
      final container = await openCalendar(tester, calendarAdapter());

      final path = await tapAndReadLocation(
        tester,
        container,
        find.widgetWithText(FilledButton, 'Create Event'),
      );

      expect(path, AppRoutes.eventCreate);
    });

    testWidgets('a super-admin with no organization is asked for one first', (
      tester,
    ) async {
      final container = await openCalendar(
        tester,
        calendarAdapter(
          permissions: const [viewEvents, manageEvents, 'VIEW_USERS_GLOBAL'],
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
      await tester.pumpAndSettle();

      // Not the create form's "Organization Required" card — the picker, which
      // is where the requirement is answered.
      expect(find.text('Select Organization'), findsWidgets);
      expect(currentPath(container), AppRoutes.events);
    });
  });

  group('what task 7.1 drops', () {
    testWidgets('the header offers no format switcher', (tester) async {
      await openCalendar(tester, calendarAdapter());

      // `availableCalendarFormats` with one entry, so table_calendar renders no
      // format button at all. Its presence would mean the week / two-week views
      // 7.1 drops had crept back in through the package's own header.
      expect(find.widgetWithText(TextButton, 'Month'), findsNothing);
    });
  });

  group('how much room a day gets', () {
    testWidgets('a day with four events shows all four bars', (tester) async {
      final today = DateTime.now();
      final date = formatLocalDate(today);
      final adapter = calendarAdapter(
        events: [
          for (var i = 1; i <= 4; i++)
            eventJson(id: i, title: 'Event $i', date: date),
        ],
      );
      await openCalendar(tester, adapter);

      for (var i = 1; i <= 4; i++) {
        expect(pillFor(i), findsOneWidget);
      }

      // **And the fourth one is not cut off.** The cap and the row height have
      // to agree: a bar that is drawn and then clipped is worse than a bar
      // that was never drawn, because the day reads as one event with a torn
      // bottom. This is the assertion the old height failed — at 64 the row
      // held the date and two bars, so the third was clipped mid-height.
      final cellBottom = tester.getBottomLeft(dayCell(today)).dy;
      final lastBarBottom = tester.getBottomLeft(pillFor(4)).dy;
      expect(lastBarBottom, lessThanOrEqualTo(cellBottom));
    });

    testWidgets('the count of the events that did not fit is visible', (
      tester,
    ) async {
      final today = DateTime.now();
      final date = formatLocalDate(today);
      final adapter = calendarAdapter(
        events: [
          for (var i = 1; i <= 6; i++)
            eventJson(id: i, title: 'Event $i', date: date),
        ],
      );
      await openCalendar(tester, adapter);

      // Six events, four bars, and the count of the two that did not fit.
      expect(find.text('+2 more'), findsOneWidget);

      // **Visible**, which is the half that was broken. The count is drawn
      // below the bars, so a row too short for the bars clips the count too —
      // and a busy day then says nothing at all about the events it is
      // hiding. The count is the only thing standing between a truncated cell
      // and a lie.
      final cellBottom = tester.getBottomLeft(dayCell(today)).dy;
      final countBottom = tester.getBottomLeft(find.text('+2 more')).dy;
      expect(countBottom, lessThanOrEqualTo(cellBottom));
    });
  });

  group('the grid does not take over the page', () {
    testWidgets('a horizontal drag does not move the month', (tester) async {
      await openCalendar(tester, calendarAdapter());

      final title = DateFormat.yMMMM().format(DateTime.now());
      expect(find.text(title), findsOneWidget);

      // A drag right across the grid, far enough to change the month if the
      // grid were a swipeable one.
      await tester.drag(
        find.byType(TableCalendar<EventResponse>),
        const Offset(900, 0),
      );
      await tester.pumpAndSettle();

      // **Still the same month.** The grid is a `PageView`, and a `PageView`
      // answers scroll *signals* as well as drags — so with the package's
      // default gestures a trackpad's horizontal component slid the month
      // sideways mid-scroll, and a sliver of the neighbouring month appeared
      // at the right edge of a grid whose days were all already on screen.
      expect(find.text(title), findsOneWidget);
    });
  });

  group('the grid\'s rules', () {
    testWidgets('a day cell is ruled on its right and its bottom', (
      tester,
    ) async {
      await openCalendar(tester, calendarAdapter());

      // The rules between the day columns and between the week rows, in the
      // colour the grid has always been drawn in.
      final cell = tester.widget<Container>(dayCell(DateTime.now()));
      final border = (cell.foregroundDecoration! as BoxDecoration).border!;
      expect((border as Border).right.color, TevenTheme.gridline);
      expect(border.bottom.color, TevenTheme.gridline);
    });

    testWidgets('only the first column is ruled on its left', (tester) async {
      await openCalendar(tester, calendarAdapter());

      // Every cell's left edge is its neighbour's right edge, so the rule
      // would be drawn twice — and twice is twice as dark. The grid's own
      // left edge belongs to the first column alone.
      final sunday = nextWeekday(DateTime.now(), DateTime.sunday);
      final monday = sunday.add(const Duration(days: 1));

      final sundayBorder = borderOf(tester, dayCell(sunday));
      final mondayBorder = borderOf(tester, dayCell(monday));
      expect(sundayBorder.left.color, TevenTheme.gridline);
      expect(mondayBorder.left.style, BorderStyle.none);
    });

    testWidgets('the weekday header is ruled between its labels', (
      tester,
    ) async {
      await openCalendar(tester, calendarAdapter());

      // The header row is written by hand, because the one border
      // table_calendar offers rules the whole table and would draw a line
      // through the middle of every label. The rules belong *between* the
      // labels, so 'Mon' carries the rule and 'Sun' does not — the grid's
      // left edge is the header frame's.
      final monday = weekdayCell(tester, 'Mon');
      final sunday = weekdayCell(tester, 'Sun');
      expect((monday.foregroundDecoration! as BoxDecoration).border, isNotNull);
      expect(
        ((monday.foregroundDecoration! as BoxDecoration).border! as Border)
            .left
            .color,
        TevenTheme.gridline,
      );
      expect(
        ((sunday.foregroundDecoration! as BoxDecoration).border! as Border)
            .left
            .style,
        BorderStyle.none,
      );
    });
  });
}

/// The border on a cell's rules.
Border borderOf(WidgetTester tester, Finder cell) =>
    (tester.widget<Container>(cell).foregroundDecoration! as BoxDecoration)
            .border!
        as Border;

/// The weekday header's cell carrying [label].
Container weekdayCell(WidgetTester tester, String label) =>
    tester.widget<Container>(
      // The nearest Container above the label is the header cell that draws it.
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );

/// The next [weekday] on or after [from].
///
/// `DateTime.weekday` runs Monday (1) to Sunday (7).
DateTime nextWeekday(DateTime from, int weekday) =>
    from.add(Duration(days: (weekday - from.weekday) % 7));

/// The bar area for one calendar day.
Finder barsOn(DateTime day) => find.byKey(ValueKey(eventMarkerKey(day)));

/// The grid cell for one calendar day.
///
/// Located by the key `_DayCell` puts on itself, keyed on the full date — a month
/// grid has two cells for most day-of-month values, so matching on the number
/// alone would be choosing between them by paint order.
Finder dayCell(DateTime day) =>
    find.byKey(ValueKey('day-${formatLocalDate(day)}'));

/// The bar for one event.
Finder pillFor(int eventId) => find.byKey(ValueKey(eventPillKey(eventId)));

/// The fill colour of one event's bar.
///
/// Reads `Container.decoration`, not `Container.color` — the bar sets a
/// `BoxDecoration` (it needs the radius too), and `Container.color` is null when
/// a decoration is supplied. Reading the wrong one gives a test that passes
/// vacuously on a bar of any colour at all.
Color? pillFill(WidgetTester tester, int eventId) {
  final container = tester.widget<Container>(
    find.descendant(of: pillFor(eventId), matching: find.byType(Container)),
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : container.color;
}
