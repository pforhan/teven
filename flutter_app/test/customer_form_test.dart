import 'dart:convert';

import 'package:dio/dio.dart' show RequestOptions;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/routing/app_router.dart';
import 'package:teven_app/screens/customers/edit_customer_screen.dart';
import 'package:teven_app/widgets/form_card.dart';
import 'package:teven_app/widgets/organization_select_field.dart';
import 'package:teven_app/widgets/validators.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// The customer forms — task 5.2, and task 5.1's convention as exercised by
/// the first form written against it.
///
/// 5.13 asks for "one representative form rather than all seven", and this is
/// it: four required fields, a conditional `<select>`, an initial load, a
/// redirect on success and an error banner. Every mechanism in the convention
/// has a caller here.
///
/// **The tests that matter are the three-way organization split, not the
/// validators.** `CreateCustomerForm.tsx:76-83` resolves which organization a
/// customer lands in through three mutually exclusive rules, and the server
/// throws for a global manager who sends none (`CustomerService.kt:62`). That
/// is behaviour no single assertion pins — it needs one case per rule, and the
/// rules are only visible as *which of them produced the id*.
void main() {
  const viewCustomers = 'VIEW_CUSTOMERS_ORGANIZATION';
  const manageCustomers = 'MANAGE_CUSTOMERS_ORGANIZATION';
  const manageCustomersGlobal = 'MANAGE_CUSTOMERS_GLOBAL';

  /// A single customer, as the edit form's `GET /api/customers/{id}` answers.
  StubResponse customerBody({
    int customerId = 1,
    String name = 'Globex',
    String phone = '555-0100',
    String address = '1 Example Street',
    String notes = 'A note',
    int organizationId = 1,
    String organizationName = 'Acme',
  }) => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {
        'customerId': customerId,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'organization': {
          'organizationId': organizationId,
          'name': organizationName,
          'contactInformation': '',
        },
      },
    }),
  );

  /// An empty `GET /api/customers` page.
  ///
  /// **The list the form redirects to after a successful save needs an
  /// answer.** Every "lands on the list" assertion here ends by navigating to
  /// `/customers`, which fetches on arrival, and an unstubbed path falls through
  /// to the harness's 401 — which is not neutral here: it trips the real
  /// unauthorized redirect, signs the test out and lands on `/login`, so the
  /// path assertion fails on a signed-out app rather than on the redirect under
  /// test. Empty, because the contents of the list are none of these tests'
  /// business; [customer_list_screen_test.dart] is where rows get asserted.
  StubResponse emptyCustomerPage() => StubResponse.json(
    jsonEncode({
      'success': true,
      'data': {'items': <Object>[], 'total': 0, 'limit': 25, 'offset': 0},
    }),
  );

  /// A backend for the customer forms.
  ///
  /// `POST /api/customers` answers a real `CustomerResponse` — the React client
  /// does not read it, but the service decodes one, so a stub answering a bare
  /// string would fail inside deserialization rather than on an assertion.
  /// `PUT` answers the bare string the server actually sends
  /// (`CustomerService.updateCustomer`), which is the shape task 1.14 pinned.
  StubAdapter customerFormAdapter({
    List<String> permissions = const [viewCustomers, manageCustomers],
    StubResponse? createFailure,
    StubResponse? updateFailure,
    StubResponse? loadFailure,
  }) => contextAdapter(
    permissions: permissions,
    forOtherRoutes: (options) {
      if (options.method == 'POST' && options.path == '/api/customers') {
        return createFailure ?? customerBody(name: 'Created');
      }
      if (options.method == 'PUT' &&
          options.path.startsWith('/api/customers/')) {
        return updateFailure ??
            const StubResponse.json('"Customer with ID 1 updated"');
      }
      if (options.method == 'GET' && options.path == '/api/customers') {
        return emptyCustomerPage();
      }
      if (options.method == 'GET' &&
          options.path.startsWith('/api/customers/')) {
        return loadFailure ?? customerBody();
      }
      return null;
    },
  );

  Future<ProviderContainer> openCreate(
    WidgetTester tester,
    StubAdapter adapter, {
    Map<String, Object> prefs = const {},
    double width = 1200,
  }) async {
    final container = await pumpApp(
      tester,
      width: width,
      token: 'token',
      prefs: prefs,
      adapter: adapter,
    );
    await goTo(tester, container, AppRoutes.customerCreate);
    return container;
  }

  /// Pumps the app and opens the edit form at [path].
  ///
  /// Takes the adapter rather than building one, because three of the four
  /// edit tests need to answer `GET /api/customers/{id}` themselves — one
  /// with a failure, one with a customer in an organization the list does not
  /// contain, one that fails once and then succeeds.
  Future<ProviderContainer> openEdit(
    WidgetTester tester,
    StubAdapter adapter,
    String path,
  ) async {
    final container = await pumpApp(
      tester,
      width: 1200,
      token: 'token',
      adapter: adapter,
    );
    await goTo(tester, container, path);
    return container;
  }

  /// `GET /api/organizations` requests. The harness numbers them 1..N in the
  /// order `organizationNames` is given.
  List<RequestOptions> organizationRequests(StubAdapter adapter) =>
      adapter.requests.where((o) => o.path == '/api/organizations').toList();

  Map<String, dynamic> bodyOf(StubAdapter adapter, String method, String path) {
    final request = adapter.requests.lastWhere(
      (o) => o.method == method && o.path == path,
    );
    return jsonDecode(adapter.bodyOf(request)!) as Map<String, dynamic>;
  }

  Future<void> fillFields(
    WidgetTester tester, {
    String name = 'Globex',
    String phone = '555-0100',
    String address = '1 Example Street',
    String notes = 'A note',
  }) async {
    Future<void> enter(int index, String value) async {
      final field = find.byType(TextFormField).at(index);
      await tester.enterText(field, value);
    }

    await enter(0, name);
    await enter(1, phone);
    await enter(2, address);
    await enter(3, notes);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Create Customer'));
    await settleRequests(tester);
  }

  Future<void> update(WidgetTester tester) async {
    await tester.tap(find.text('Update Customer'));
    await settleRequests(tester);
  }

  /// The validation message rendered **under the field at [index]**, if any.
  ///
  /// Per field rather than a count, and that is the whole point of this
  /// helper. `findsNWidgets(4)` was the first version of the empty-form test
  /// and it pins almost nothing: a form that reported "required" on all four
  /// fields while attributing it to the wrong one — a copy-paste slip in a
  /// validator index — satisfies it exactly. `CreateCustomerForm.tsx:92,96,99,102`
  /// puts `required` on all four, so *which four* is the only question the
  /// count cannot answer.
  String? errorForField(WidgetTester tester, int index) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(TextFormField).at(index),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>();
    for (final text in texts) {
      if (text == 'This field is required') return text;
    }
    return null;
  }

  /// [errorForField] for all four fields.
  List<String?> errorsForAllFields(WidgetTester tester) => [
    for (var i = 0; i < 4; i++) errorForField(tester, i),
  ];

  group('form convention (5.1)', () {
    // Plain Dart rather than widget tests: `Validators` has no Flutter
    // dependency, and asserting it through a form would only prove that a form
    // called it.
    test('required rejects empty and null', () {
      expect(Validators.required(null), 'This field is required');
      expect(Validators.required(''), 'This field is required');
      expect(Validators.required('a'), isNull);
    });

    test('requiredText additionally rejects whitespace', () {
      expect(Validators.requiredText('   '), 'This field is required');
      expect(Validators.requiredText('\t\n'), 'This field is required');
      expect(Validators.requiredText(' a '), isNull);
    });

    test('requiredSelection rejects only null', () {
      expect(Validators.requiredSelection<int>(null), 'This field is required');
      expect(Validators.requiredSelection<int>(0), isNull);
    });

    testWidgets('a form is a FormCard', (tester) async {
      await openCreate(tester, customerFormAdapter());

      // The convention is that a screen *is* a `FormCard`, not that it renders
      // one somewhere inside — so this asserts the widget type directly.
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('submitting with an empty form rejects every required field', (
      tester,
    ) async {
      final adapter = customerFormAdapter();
      final container = await openCreate(tester, adapter);
      await submit(tester);

      // `required` on all four (`CreateCustomerForm.tsx:92,96,99,102`).
      // Asserted **per field**, so a mis-attributed error fails here rather
      // than passing as a count.
      expect(
        errorsForAllFields(tester),
        everyElement('This field is required'),
      );
      // And nothing was sent — the point of a validator.
      expect(adapter.requests.where((o) => o.method == 'POST'), isEmpty);
      expect(currentPath(container), AppRoutes.customerCreate);
    });

    testWidgets('the error lands on the field that is empty, and only there', (
      tester,
    ) async {
      final adapter = customerFormAdapter();
      await openCreate(tester, adapter);

      // Three of the four filled, in field order: name, phone, address, notes.
      await fillFields(tester, phone: '', address: '1 Example Street');
      await submit(tester);

      // The empty field is reported and the three completed ones are not. A
      // count of 1 would be satisfied by a form that reported the wrong field;
      // this says which one, which is the information the user needs in order to
      // know what to fix.
      expect(errorsForAllFields(tester), [
        null, // name
        'This field is required', // phone
        null, // address
        null, // notes
      ]);
      expect(adapter.requests.where((o) => o.method == 'POST'), isEmpty);
    });

    testWidgets('a corrected field clears its error on the next submit', (
      tester,
    ) async {
      final adapter = customerFormAdapter();
      await openCreate(tester, adapter);

      await fillFields(tester, phone: '');
      await submit(tester);
      expect(errorForField(tester, 1), 'This field is required');

      // **The half of validation that is easy to get wrong.** A validator that
      // only ever adds errors passes everything above; `FormState.validate()`
      // recomputes from the current values, so the stale message has to go on
      // its own. Only a second submit can show that.
      await fillFields(tester, phone: '555-0100');
      await submit(tester);

      // **No per-field assertion here, and there cannot be one** — a successful
      // submit navigates to `/customers`, so the form is gone. The request is
      // the proof: it only goes out if `FormState.validate()` returned true,
      // which it cannot do while the phone field is still reporting an error.
      expect(adapter.requests.where((o) => o.method == 'POST'), hasLength(1));
    });

    testWidgets('a whitespace-only field is rejected as empty', (tester) async {
      final adapter = customerFormAdapter();
      await openCreate(tester, adapter);

      // **The one case `isEmpty` alone would miss.** HTML `required` rejects
      // it, so this is parity rather than an addition — but it is also the case
      // a `required`-only port would fail, which is why `requiredText` exists.
      await fillFields(tester, name: '   ');
      await submit(tester);

      // On the name field specifically, not merely somewhere on the screen.
      expect(errorForField(tester, 0), 'This field is required');
      expect(adapter.requests.where((o) => o.method == 'POST'), isEmpty);
    });
  });

  group('create: which organization the customer lands in', () {
    testWidgets('an organizer gets no dropdown and no request', (tester) async {
      final adapter = customerFormAdapter();
      await openCreate(tester, adapter);

      expect(find.byType(OrganizationSelectField), findsNothing);

      await fillFields(tester);
      await submit(tester);

      // `CreateCustomerForm.tsx:82` — the user's own organization, from the
      // context. The harness's context user is in organization 1.
      expect(bodyOf(adapter, 'POST', '/api/customers')['organizationId'], 1);
    });

    testWidgets('an organizer never requests the organization list', (
      tester,
    ) async {
      // **Not cosmetic.** `GET /api/organizations` is gated on
      // `VIEW_ORGANIZATIONS_GLOBAL`, so a request made by an `Organizer` is a
      // guaranteed 403 on every visit to a create screen. The React original
      // guards its `useEffect` with `canManageGlobal` for the same reason;
      // reproducing that means the field's presence is what decides whether
      // the fetch happens at all.
      final adapter = customerFormAdapter();
      await openCreate(tester, adapter);

      expect(organizationRequests(adapter), isEmpty);
    });

    testWidgets('a global manager gets a dropdown defaulting to the first', (
      tester,
    ) async {
      final adapter = customerFormAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
      );
      await openCreate(tester, adapter);

      expect(find.byType(OrganizationSelectField), findsOneWidget);
      // `CreateCustomerForm.tsx:40-42` seeds the selection with `items[0]`.
      expect(organizationRequests(adapter), hasLength(1));

      await fillFields(tester);
      await submit(tester);

      // The harness numbers organizations 1..2, so `items[0]` is 1.
      expect(bodyOf(adapter, 'POST', '/api/customers')['organizationId'], 1);
    });

    testWidgets('a selected organization beats the dropdown entirely', (
      tester,
    ) async {
      // `CreateCustomerForm.tsx:77` — the chrome's selection is checked
      // *before* `canManageGlobal`, so a super-admin who narrowed the app to
      // one organization gets no dropdown and creates into that one even
      // though a global manager would otherwise be offered the full list.
      final adapter = customerFormAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
      );
      await openCreate(tester, adapter, prefs: _selectedOrganization(7));

      expect(find.byType(OrganizationSelectField), findsNothing);
      expect(organizationRequests(adapter), isEmpty);

      await fillFields(tester);
      await submit(tester);

      expect(bodyOf(adapter, 'POST', '/api/customers')['organizationId'], 7);
    });

    testWidgets('a global manager can change the selection', (tester) async {
      final adapter = customerFormAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
      );
      await openCreate(tester, adapter);

      await tester.tap(find.byType(OrganizationSelectField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      await fillFields(tester);
      await submit(tester);

      // The second organization in the harness's canned list, so the assertion
      // distinguishes "picked what was chosen" from "picked the first one".
      expect(bodyOf(adapter, 'POST', '/api/customers')['organizationId'], 2);
    });
  });

  group('create: outcome', () {
    testWidgets('sends every field and lands on the list', (tester) async {
      final adapter = customerFormAdapter();
      final container = await openCreate(tester, adapter);

      await fillFields(
        tester,
        name: 'Initech',
        phone: '555-0199',
        address: '2 Example Street',
        notes: 'Prefers mornings',
      );
      await submit(tester);

      final body = bodyOf(adapter, 'POST', '/api/customers');
      expect(body['name'], 'Initech');
      expect(body['phone'], '555-0199');
      expect(body['address'], '2 Example Street');
      expect(body['notes'], 'Prefers mornings');
      // `navigate('/customers')` (`CreateCustomerForm.tsx:92`).
      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('shows the server message and stays put on failure', (
      tester,
    ) async {
      final adapter = customerFormAdapter(
        createFailure: const StubResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"Customer already exists"}}',
          status: 400,
        ),
      );
      final container = await openCreate(tester, adapter);

      await fillFields(tester);
      await submit(tester);

      expect(find.text('Error: Customer already exists'), findsOneWidget);
      expect(currentPath(container), AppRoutes.customerCreate);
      // The entered values survive, so a correction does not mean retyping.
      expect(find.text('Globex'), findsOneWidget);
    });

    testWidgets('cancel returns to the list', (tester) async {
      final adapter = customerFormAdapter();
      final container = await openCreate(tester, adapter);

      await tester.tap(find.text('Cancel'));
      // `settleRequests`, not `pumpAndSettle`: `/customers` is a list screen that
      // fetches, so a bare settle is called while its `CircularProgressIndicator`
      // is up and times out. Harmless on the VM, fatal on Chrome — see
      // `settleRequests` for why the two halves are not interchangeable.
      await settleRequests(tester);

      expect(adapter.requests.where((o) => o.method == 'POST'), isEmpty);
      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('the organization list failing blocks the submit', (
      tester,
    ) async {
      // The reachable shape of `CreateCustomerForm.tsx:85-88`'s guard: a
      // super-admin with nothing selected, submitting before the list lands —
      // or after it failed. The validator catches it first and reports it on
      // the field, which is what the browser's own `required` did in the
      // original. The banner copy survives for the path a future change to the
      // fields could reopen.
      final adapter = contextAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
        organizationsResponder: (_) => const StubResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"Forbidden"}}',
          status: 403,
        ),
        forOtherRoutes: (options) =>
            options.method == 'POST' && options.path == '/api/customers'
            ? customerBody(name: 'Created')
            : null,
      );
      final container = await openCreate(tester, adapter);

      await fillFields(tester);
      await submit(tester);

      expect(find.text('This field is required'), findsOneWidget);
      // And the reason the dropdown is empty is on screen, rather than the
      // user being told only that they forgot to pick something.
      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(adapter.requests.where((o) => o.method == 'POST'), isEmpty);
      expect(currentPath(container), AppRoutes.customerCreate);
    });
  });

  group('edit', () {
    testWidgets('loads the customer and fills every field', (tester) async {
      await openEdit(tester, customerFormAdapter(), '/customers/edit/1');

      expect(find.byType(EditCustomerScreen), findsOneWidget);
      expect(find.text('Edit Customer: Globex'), findsOneWidget);

      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller?.text, 'Globex');
      expect(fields[1].controller?.text, '555-0100');
      expect(fields[2].controller?.text, '1 Example Street');
      expect(fields[3].controller?.text, 'A note');
    });

    testWidgets('an organizer sees no dropdown and sends no organizationId', (
      tester,
    ) async {
      // **The most load-bearing assertion in this file.**
      // `EditCustomerForm.tsx:64-67` sends `organizationId` only for a global
      // manager, and `CustomerService.kt:89-93` *throws* when anyone else sends
      // one. A port that always sent it would 500 on every edit by an
      // `Organizer`, which is the majority of the app's users.
      final adapter = customerFormAdapter();
      final container = await openEdit(tester, adapter, '/customers/edit/1');

      expect(find.byType(OrganizationSelectField), findsNothing);

      await update(tester);

      final body = bodyOf(adapter, 'PUT', '/api/customers/1');
      expect(body.containsKey('organizationId'), isFalse);
      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('a global manager sees the dropdown and may change it', (
      tester,
    ) async {
      // Note the deliberate difference from the create form: `:115` gates on
      // `canManageGlobal` alone, with no `selectedOrganization` exemption, so
      // a super-admin who has narrowed the chrome still gets to move a
      // customer between organizations.
      final adapter = customerFormAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
      );
      final container = await openEdit(tester, adapter, '/customers/edit/1');

      expect(find.byType(OrganizationSelectField), findsOneWidget);

      await tester.tap(find.byType(OrganizationSelectField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex').last);
      await tester.pumpAndSettle();

      await update(tester);

      expect(bodyOf(adapter, 'PUT', '/api/customers/1')['organizationId'], 2);
      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('a customer in an organization not in the list still renders', (
      tester,
    ) async {
      // The `organizationsIncluding` case. The customer belongs to
      // organization 9; the canned list holds 1 and 2. `DropdownButton`
      // asserts that its value has a matching item, so without folding the
      // selection in this screen takes the app down — which is the assertion
      // Phase 3 hit on the rail's dropdown and moved to a shared helper.
      final adapter = contextAdapter(
        permissions: const [
          viewCustomers,
          manageCustomers,
          manageCustomersGlobal,
        ],
        forOtherRoutes: (options) {
          if (options.method == 'GET' && options.path == '/api/customers') {
            return emptyCustomerPage();
          }
          if (options.method == 'GET' &&
              options.path.startsWith('/api/customers/')) {
            return customerBody(
              organizationId: 9,
              organizationName: 'Missing Inc',
            );
          }
          if (options.method == 'PUT' &&
              options.path.startsWith('/api/customers/')) {
            return const StubResponse.json('"Customer with ID 1 updated"');
          }
          return null;
        },
      );
      final container = await openEdit(tester, adapter, '/customers/edit/1');

      // No exception, and the organization it is in is named on screen.
      expect(tester.takeException(), isNull);
      expect(find.text('Missing Inc'), findsOneWidget);

      await update(tester);

      // And it is what the request carries, rather than the first in the list.
      expect(bodyOf(adapter, 'PUT', '/api/customers/1')['organizationId'], 9);
      expect(currentPath(container), AppRoutes.customers);
    });

    testWidgets('a failed load shows the error, not "Loading customer..."', (
      tester,
    ) async {
      // **A deliberate divergence from the React original.**
      // `EditCustomerForm.tsx:80` returns `Loading customer...` whenever
      // `customer` is null, and `setError` never clears it — so a 404 leaves
      // the original spinning forever with no message anywhere on the screen.
      // The port shows the message instead. Reproducing an error that renders
      // as a loading state is a bug, not parity.
      final adapter = customerFormAdapter(
        loadFailure: const StubResponse.json(
          '{"success":false,"data":{},'
          '"error":{"message":"Customer not found"}}',
          status: 404,
        ),
      );
      final container = await openEdit(tester, adapter, '/customers/edit/1');

      expect(find.text('Loading customer...'), findsNothing);
      expect(find.text('Error: Customer not found'), findsOneWidget);
      expect(currentPath(container), '/customers/edit/1');
    });

    testWidgets(
      'a non-numeric id in the URL fails without taking the app down',
      (tester) async {
        final adapter = customerFormAdapter(
          loadFailure: const StubResponse.json(
            '{"success":false,"data":{},'
            '"error":{"message":"Customer not found"}}',
            status: 404,
          ),
        );
        final container = await openEdit(
          tester,
          adapter,
          '/customers/edit/not-a-number',
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Error: Customer not found'), findsOneWidget);
        expect(currentPath(container), '/customers/edit/not-a-number');
      },
    );

    testWidgets('"Try again" re-requests and can succeed', (tester) async {
      var failNext = true;
      final adapter = contextAdapter(
        permissions: const [viewCustomers, manageCustomers],
        forOtherRoutes: (options) {
          if (options.method == 'GET' &&
              options.path.startsWith('/api/customers/')) {
            if (failNext) {
              failNext = false;
              return const StubResponse.json(
                '{"success":false,"data":{},'
                '"error":{"message":"Customer not found"}}',
                status: 404,
              );
            }
            return customerBody();
          }
          return null;
        },
      );
      await openEdit(tester, adapter, '/customers/edit/1');
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await settleRequests(tester);

      expect(find.text('Edit Customer: Globex'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('responsive (5.11)', () {
    testWidgets('the submit button is reachable at 360px', (tester) async {
      // The form is taller than a phone once the keyboard is up, so the
      // `SingleChildScrollView` `FormCard` owns is what makes the button
      // reachable at all. Asserting reachability rather than "there is a
      // scroll view", because the scroll view existed while the fields could
      // still be taller than the viewport.
      final adapter = customerFormAdapter();
      // One `pumpApp`. The original called it twice — the first result was
      // discarded, leaving two `ProviderContainer`s and two `addTearDown`
      // registrations for one test, and the screen the assertions ran against
      // was whichever tree the second `pumpWidget` replaced.
      final container = await pumpApp(
        tester,
        width: 360,
        height: 640,
        token: 'token',
        adapter: adapter,
      );
      await goTo(tester, container, AppRoutes.customerCreate);

      final button = find.text('Create Customer');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

/// A persisted `selectedOrganization` — the value `OrganizationController`
/// restores on boot.
Map<String, Object> _selectedOrganization(int organizationId, [String? name]) =>
    {
      'selectedOrganization': jsonEncode({
        'organizationId': organizationId,
        'name': name ?? 'Chosen Inc',
        'contactInformation': '',
      }),
    };
