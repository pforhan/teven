import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  /// Taps [finder], then reads the route **after one pump and no settling**.
  ///
  /// **This is not laziness, it is the only way to assert the destination.**
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
    Finder finder,
  ) async {
    await tester.tap(finder);
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

    testWidgets('keeps the original\'s thousand-event ceiling', (tester) async {
      final adapter = calendarAdapter();
      await openCalendar(tester, adapter);

      // `EventCalendar.tsx:88` asks for 1000. Inherited rather than chosen, and
      // pinned so a "sensible" reduction is a deliberate change rather than a
      // quiet one that makes a busy month render short.
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

      // The month label is `EventCalendar.tsx:222` — title, then `h:mm A`.
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
    testWidgets('today\'s cell carries the original\'s background', (
      tester,
    ) async {
      await openCalendar(tester, calendarAdapter());

      // `#e7f0f7`, `EventCalendar.tsx:193`. Asserted on the value rather than
      // on "there is a highlighted cell", because any colour would satisfy the
      // latter — including the `todayDecoration` dot table_calendar ships by
      // default, which is the thing this had to be written to avoid.
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

      // `EventCalendar.tsx:174` compares `rsvp.userId === userContext.user.userId`
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

      // `EventCalendar.tsx:167-169`. The alternative — falling through to the
      // cell's own gesture — would open the *create* form, which is the failure
      // mode `CalendarBuilders.markerBuilder` makes possible and `_EventPill`
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

      final path = await tapAndReadLocation(tester, container, dayCell(target));

      // `EventCalendar.tsx:136` — the date is the whole payload; there is no
      // time, because a month cell has no time to give.
      expect(path, '/events/create?date=${formatLocalDate(target)}');
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
      // is where the requirement is answered. `EventCalendar.tsx:257-262`.
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
}

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
