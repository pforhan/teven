import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/providers/paged_list.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/widgets/paged_list_view.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The pagination half of the list screens, driven through the real router.
///
/// [paged_list_test.dart] covers what offsets the controller asks for; this
/// covers what a user gets on screen for each of those states, which is the
/// half the other file cannot see. Everything is asserted on the customer list
/// rather than on the shared widget directly, so the wiring from scroll to
/// request to footer is under test and not just the footer's own rendering.
void main() {
  const desktopWidth = 1500.0;
  const viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
  const manageCustomers = 'MANAGE_CUSTOMERS_ORGANIZATION';

  /// Tall enough to hold a whole page of 25 rows (25 x 48px), the heading, the
  /// search box and the footer, without scrolling.
  ///
  /// A deliberately unusual viewport — a real one is rarely this tall — and it
  /// exists because it is the only geometry in which the footer's button can be
  /// tested at all. Scrolling is the automatic load-more trigger, so scrolling
  /// down to the footer loads the next page before the tap happens. Here there
  /// is nothing to scroll, and the button is the only way to page. See
  /// [tapFooterButton].
  const tallViewport = 2400.0;

  /// A `GET /api/customers` page.
  ///
  /// Answers with whatever rows the offset implies, out of [total], so a second
  /// request genuinely returns *different* rows — which is what makes
  /// accumulation observable. A backend that returned the same page twice would
  /// let a broken implementation pass by showing one page's worth of data.
  StubResponse customersPage(int offset, int total) {
    final count = (total - offset).clamp(0, kListPageSize);
    return StubResponse.json(
      jsonEncode({
        'success': true,
        'data': {
          'items': [
            for (var i = offset; i < offset + count; i++)
              {
                'customerId': i,
                'name': 'Customer $i',
                'phone': '',
                'address': '',
                'notes': '',
                'organization': {
                  'organizationId': 1,
                  'name': 'Acme',
                  'contactInformation': '',
                },
              },
          ],
          'total': total,
          'limit': kListPageSize,
          'offset': offset,
        },
      }),
    );
  }

  /// The customer endpoints, with [total] rows to page through.
  StubAdapter customerAdapter({int total = 60}) => contextAdapter(
    permissions: const [viewCustomers, manageCustomers],
    forOtherRoutes: (options) {
      if (options.path == '/api/customers' && options.method == 'GET') {
        return customersPage(
          (options.queryParameters['offset'] as num?)?.toInt() ?? 0,
          total,
        );
      }
      if (options.method == 'DELETE') return const StubResponse.noContent();
      return null;
    },
  );

  /// Opens the customer list.
  ///
  /// [height] defaults to [tallViewport], which is tall enough for a whole page
  /// of rows plus the footer. See [tapFooterButton] for why that is the default
  /// rather than a nuisance.
  Future<ProviderContainer> openCustomers(
    WidgetTester tester,
    StubAdapter adapter, {
    double width = desktopWidth,
    double height = tallViewport,
  }) async {
    final container = await pumpApp(
      tester,
      width: width,
      height: height,
      token: 'token',
      adapter: adapter,
    );
    await goTo(tester, container, AppRoutes.customers);
    return container;
  }

  List<RequestOptions> getRequests(StubAdapter adapter) => adapter.requests
      .where((o) => o.path == '/api/customers' && o.method == 'GET')
      .toList();

  /// The visible text of the footer, or null when there is no footer.
  ///
  /// Read as a whole widget rather than by `find.text`, because the footer says
  /// one of three different things and the assertion should be about which.
  Finder footerText() => find.textContaining(RegExp(r'Showing|Load more'));

  /// Taps the footer's button.
  ///
  /// **No scrolling first, deliberately, and that is the whole point of these
  /// tests.** Scrolling *is* the load-more trigger, so scrolling down to reach
  /// the footer loads the next page on the way — which appends rows and moves
  /// the footer further away. A helper that scrolled and then tapped would
  /// either never arrive or arrive after having already loaded the page it was
  /// trying to load, and the test would assert nothing about the button.
  ///
  /// So these run in a viewport **tall enough to hold the whole first page**,
  /// where there is nothing to scroll, no scroll notification fires, and the
  /// button is the only route to page two. That is not a contrived setup — it is
  /// exactly the case the button exists for, and it is the case the automatic
  /// path cannot serve: a list that fits on screen produces no scroll events, so
  /// without the button it would stop at 25 rows forever.
  Future<void> tapFooterButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(OutlinedButton, label);
    expect(
      button.hitTestable(),
      findsOneWidget,
      reason:
          'the "$label" button should be on screen without scrolling, '
          'since this viewport holds the whole page',
    );
    await tester.tap(button);
  }

  group('the footer', () {
    testWidgets('counts what is loaded and offers the next page', (
      tester,
    ) async {
      await openCustomers(tester, customerAdapter(total: 60));

      // One page in, so a count of what exists and a way to ask for the rest.
      expect(find.text('Showing 25 of 60'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Load more'), findsOneWidget);
    });

    testWidgets('says when there is nothing more', (tester) async {
      // A total inside one page: the whole collection is already loaded, so the
      // button must be gone and the user told the list is complete.
      await openCustomers(tester, customerAdapter(total: 10));

      expect(find.text('Showing all 10'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Load more'), findsNothing);
    });

    testWidgets('an empty result shows the empty message and no footer', (
      tester,
    ) async {
      await openCustomers(tester, customerAdapter(total: 0));

      expect(find.text('No customers found.'), findsOneWidget);
      // A footer reading "Showing 0 of 0" beside an empty list is noise.
      expect(footerText(), findsNothing);
    });
  });

  group('loading the next page', () {
    testWidgets('the button appends rather than replacing', (tester) async {
      final adapter = customerAdapter(total: 60);
      await openCustomers(tester, adapter);

      expect(find.text('Customer 0'), findsOneWidget);
      expect(getRequests(adapter), hasLength(1));

      await tapFooterButton(tester, 'Load more');
      await settleRequests(tester);

      // Two requests, the second at the running offset.
      expect(getRequests(adapter).map((o) => o.queryParameters['offset']), [
        0,
        25,
      ]);
      // The first page is still there *and* the second is. This is the
      // distinction from a non-accumulating list, which would show 25 rows
      // either way — so this asserts on specific rows from both pages.
      expect(find.text('Customer 0'), findsOneWidget);
      expect(find.text('Customer 25'), findsOneWidget);
      expect(find.text('Showing 50 of 60'), findsOneWidget);
    });

    testWidgets('scrolls the last page in without a click', (tester) async {
      // A short viewport, so the page genuinely overflows and scrolling is what
      // moves it. The default tall viewport would have nothing to scroll, which
      // is the button's case, not this one's.
      final adapter = customerAdapter(total: 60);
      await openCustomers(tester, adapter, height: 600);

      expect(getRequests(adapter), hasLength(1));

      expect(getRequests(adapter), hasLength(1));

      await tester.drag(
        find.byType(PagedScrollView),
        const Offset(0, -3000),
        warnIfMissed: false,
      );
      await settleRequests(tester);

      // The point of the whole scroll listener: reaching the bottom asks for
      // the next page on its own, with nothing tapped.
      expect(getRequests(adapter).map((o) => o.queryParameters['offset']), [
        0,
        25,
      ], reason: 'scrolling to the end should request the next page');
      expect(find.text('Customer 25'), findsOneWidget);
    });

    testWidgets('a search starts again from the first page', (tester) async {
      final adapter = customerAdapter(total: 60);
      await openCustomers(tester, adapter);

      await tapFooterButton(tester, 'Load more');
      await settleRequests(tester);
      expect(find.text('Customer 25'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Customer 1');
      await tester.pump(const Duration(milliseconds: 300));
      await settleRequests(tester);

      final offsets = getRequests(adapter)
          .map((o) => o.queryParameters['offset']);
      // The new query fetches offset 0 — it does not inherit the pages the old
      // one had accumulated, which is what would show a mixture of two searches.
      expect(offsets.last, 0);
      // The "filtered" suffix is the wording task 4.14 settled on, so this
      // assertion moves with it. See `PagedListView.filtered`.
      expect(find.text('Showing 25 of 60 filtered'), findsOneWidget);
    });
  });

  group('a page that fails', () {
    testWidgets('keeps the rows and offers a retry', (tester) async {
      var shouldFail = false;
      final adapter = contextAdapter(
        permissions: const [viewCustomers, manageCustomers],
        forOtherRoutes: (options) {
          if (options.path == '/api/customers' && options.method == 'GET') {
            final offset =
                (options.queryParameters['offset'] as num?)?.toInt() ?? 0;
            if (shouldFail && offset > 0) {
              return const StubResponse.json(
                '{"success":false,"data":{},'
                '"error":{"message":"Customer service unavailable"}}',
                status: 500,
              );
            }
            return customersPage(offset, 60);
          }
          return null;
        },
      );
      await openCustomers(tester, adapter);

      shouldFail = true;
      await tapFooterButton(tester, 'Load more');
      await settleRequests(tester);

      // The twenty-five rows are untouched, the failure is reported beneath
      // them, and the way forward is a retry rather than a blank screen.
      expect(find.text('Customer 0'), findsOneWidget);
      expect(find.text('Error: Customer service unavailable'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);

      shouldFail = false;
      await tapFooterButton(tester, 'Try again');
      await settleRequests(tester);

      expect(find.text('Customer 25'), findsOneWidget);
      expect(find.text('Error: Customer service unavailable'), findsNothing);
    });
  });

  group('mobile', () {
    testWidgets('the footer and paging work in the card layout too', (
      tester,
    ) async {
      final adapter = customerAdapter(total: 60);
      // A much taller viewport than the desktop case needs. A mobile card is
      // roughly 4x the height of a table row, so 25 of them is an 8000px page —
      // and no realistic viewport holds that, which means *at mobile the footer
      // is genuinely below the fold for every user*. That is a real property of
      // the feature rather than a testing artefact: the scroll listener is the
      // only thing that works at a phone width, and the button is unreachable
      // there without scrolling. The viewport here is sized to fit anyway so the
      // button can be exercised at this width at all.
      await openCustomers(tester, adapter, width: 500, height: 9000);

      // Cards rather than a table — and still pageable, because the footer
      // belongs to the screen rather than to either layout.
      expect(find.byType(Table), findsNothing);
      expect(find.text('Showing 25 of 60'), findsOneWidget);

      await tapFooterButton(tester, 'Load more');
      await settleRequests(tester);

      expect(find.text('Customer 25'), findsOneWidget);
      expect(find.text('Showing 50 of 60'), findsOneWidget);
    });
  });
}
