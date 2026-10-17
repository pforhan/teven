import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/main.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/routing/app_router.dart';

import 'support/auth_harness.dart';
import 'support/stub_adapter.dart';

/// Task 2.10 — `AcceptInvitationPage`, driven through the real router.
///
/// The screen is deliberately *not* pumped directly. Its whole reason for
/// existing is that the token arrives in the URL (`/register?token=...`), so a
/// test that handed it the token as a constructor argument would assert the one
/// thing that could break — the query parameter being dropped somewhere between
/// the emailed link and the form.
///
/// ## Why every `pumpAndSettle` is paired with a `runAsync`
///
/// The screen validates the token from `initState`, and the accept call fires
/// from the submit handler. Both go through dio, whose async machinery the fake
/// clock a widget test runs under will not advance — settling without letting
/// real time pass first hangs until the test times out.
///
/// The other half of the constraint: the loading box carries a
/// `CircularProgressIndicator`, which never stops animating. `pumpAndSettle`
/// called *while* the screen is still validating would spin forever. Every test
/// therefore lets the request resolve inside `runAsync` before settling, so the
/// spinner is always gone by the time it runs.
void main() {
  group('signed out', () {
    testWidgets('a URL with no token reports it instead of showing a form', (
      tester,
    ) async {
      await _pumpRegister(tester, '/register');

      expect(
        find.textContaining('Invitation token not found in URL'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);
    });

    testWidgets('a valid token names the organization and role', (
      tester,
    ) async {
      final adapter = invitationAdapter();
      await _pumpRegister(tester, '/register?token=abc123', adapter: adapter);

      expect(
        find.textContaining('You have been invited to join Acme'),
        findsOneWidget,
      );
      expect(find.textContaining('as a Admin'), findsOneWidget);
      // The two `<p>`s of `AcceptInvitationPage.tsx:108-109` are one text node
      // separated by a newline, so this matches the second sentence alone.
      expect(
        find.textContaining('Please create your account below.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Display Name'),
        findsOneWidget,
      );

      // The token has to reach the server, not just the screen.
      final validate = adapter.requests.firstWhere(
        (r) => r.path == '/api/invitations/validate',
      );
      expect(validate.queryParameters['token'], 'abc123');
    });

    testWidgets('an invalid token shows the server message, not the form', (
      tester,
    ) async {
      await _pumpRegister(
        tester,
        '/register?token=stale',
        adapter: invitationAdapter(
          validateStatus: 404,
          validateMessage: 'Invalid or expired invitation token',
        ),
      );

      expect(
        find.textContaining('Invalid or expired invitation token'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);
    });

    testWidgets('empty fields block the submit', (tester) async {
      final adapter = invitationAdapter();
      await _pumpRegister(tester, '/register?token=abc123', adapter: adapter);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsNWidgets(4));
      expect(
        adapter.requests.where((r) => r.path == '/api/invitations/accept'),
        isEmpty,
        reason: 'validation must stop before any request goes out',
      );
    });

    testWidgets('a malformed email is rejected like the browser would', (
      tester,
    ) async {
      final adapter = invitationAdapter();
      await _pumpRegister(tester, '/register?token=abc123', adapter: adapter);

      await _fillForm(tester, email: 'not-an-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Accept Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email'), findsOneWidget);
      expect(
        adapter.requests.where((r) => r.path == '/api/invitations/accept'),
        isEmpty,
      );
    });

    testWidgets('a successful acceptance redirects to /login after 3 seconds', (
      tester,
    ) async {
      final container = await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(),
      );

      await _fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept Invitation'));
      await _settleAsync(tester);

      expect(
        find.text('Invitation accepted and user created.'),
        findsOneWidget,
      );
      // The form is replaced by the success box, per the React ternary at
      // `AcceptInvitationPage.tsx:105`.
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);
      expect(currentPath(container), AppRoutes.register);

      // `setTimeout(..., 3000)` at `AcceptInvitationPage.tsx:73`.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.login);
    });

    testWidgets('the credentials entered are what gets posted', (tester) async {
      final adapter = invitationAdapter();
      await _pumpRegister(tester, '/register?token=abc123', adapter: adapter);

      await _fillForm(
        tester,
        username: 'ada',
        password: 'hunter2',
        email: 'ada@example.com',
        displayName: 'Ada L',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Accept Invitation'));
      await _settleAsync(tester);

      expect(adapter.requests.last.path, '/api/invitations/accept');
      expect(adapter.requests.last.method, 'POST');
      final body = jsonDecode(
        adapter.lastRequestBody! as String,
      ) as Map<String, dynamic>;
      expect(body['username'], 'ada');
      expect(body['password'], 'hunter2');
      expect(body['email'], 'ada@example.com');
      expect(body['displayName'], 'Ada L');
      // The token comes from the URL, not from a field the user could edit.
      expect(body['token'], 'abc123');
    });

    testWidgets('a rejected acceptance shows the server message verbatim', (
      tester,
    ) async {
      await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          acceptStatus: 400,
          acceptMessage: 'Username already taken.',
        ),
      );

      await _fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Accept Invitation'));
      await _settleAsync(tester);

      expect(find.textContaining('Username already taken.'), findsOneWidget);
      // No redirect, and the form comes back so the user can correct one field.
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    });

    testWidgets('the loading box is showing before validation resolves', (
      tester,
    ) async {
      // No `runAsync` and no settle here on purpose: this is the one assertion
      // about the in-flight state, and settling would destroy it.
      final container = authTestContainer(adapter: invitationAdapter());
      await tester.runAsync(
        () => container.read(authControllerProvider.future),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TevenApp(),
        ),
      );
      container.read(routerProvider).go('/register?token=abc123');
      await tester.pump();

      expect(find.text('Loading invitation...'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);

      // Drain the in-flight request, or its dio timer is still pending when the
      // test tears down and the binding reports it as a leak.
      await _settleAsync(tester);
    });
  });

  group('signed in', () {
    testWidgets('an already-logged-in visitor gets the error, not the form', (
      tester,
    ) async {
      await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      expect(find.text('Already Logged In'), findsOneWidget);
      expect(
        find.textContaining(
          'You cannot accept an invitation while you are logged in',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Accept Invitation'),
        findsNothing,
      );
    });

    testWidgets('the sentence around the link is reproduced word for word', (
      tester,
    ) async {
      // A dropped word here reads as a typo to the user and is invisible to
      // every other assertion: the link label is still "here", the tap target
      // still works, and the widget still navigates. Asserting the *whole*
      // sentence is what catches it.
      await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      final sentence = tester.widget<Text>(
        find.textContaining('You can return to the application'),
      );
      expect(
        sentence.textSpan!.toPlainText(),
        'You can return to the application by clicking here.',
      );
    });

    testWidgets('the link is underlined, so it reads as clickable', (
      tester,
    ) async {
      // The browser underlines `<a>`; a Material button does not, and without
      // this the only thing marking the word as interactive is its colour —
      // which is exactly the signal that must not be load-bearing on its own.
      await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      final link = _linkSpan(tester);
      expect(link.text, 'here');
      // The rule, asserted rather than assumed: a link's text may not begin or
      // end with whitespace, or the underline starts in blank space and the hit
      // box runs past the word.
      expect(link.text!.trim(), link.text);
      expect(link.toPlainText().trim(), link.toPlainText());
      expect(link.style?.decoration, TextDecoration.underline);
      expect(
        link.style?.color,
        isNot(
          Theme.of(tester.element(find.byType(Scaffold).first))
              .colorScheme
              .onErrorContainer,
        ),
        reason: 'the link must not be the same colour as the sentence',
      );
    });

    testWidgets('the "here" link returns to the app', (tester) async {
      // The React original is `href="/"`, which the router turns into
      // `/events`. Asserting on the destination is the point: the alternative
      // bug is a link that navigates nowhere at all.
      final container = await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      await _tapHereLink(tester);
      await tester.pumpAndSettle();

      expect(currentPath(container), AppRoutes.events);
    });

    testWidgets('only the link navigates, not the sentence around it', (
      tester,
    ) async {
      // Without this the test above would still pass if the recognizer were
      // wired to the whole sentence rather than to "here": a tap anywhere in
      // the paragraph would navigate, and the destination assertion would hold
      // for the wrong reason.
      final container = await _pumpRegister(
        tester,
        '/register?token=abc123',
        adapter: invitationAdapter(
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      // Offset 0 is the "Y" of "You", well clear of the link.
      final startOfSentence = tester.renderObject<RenderParagraph>(
        find.textContaining('You can return to the application'),
      );
      final bodyBox = startOfSentence
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )
          .first
          .toRect();
      await tester.tapAt(
        MatrixUtils.transformRect(
          startOfSentence.getTransformTo(null),
          bodyBox,
        ).center,
      );
      await tester.pumpAndSettle();

      expect(
        currentPath(container),
        AppRoutes.register,
        reason: 'body text must not be tappable',
      );
    });

    testWidgets('a stale link shows the validation error as well', (
      tester,
    ) async {
      // `AcceptInvitationPage.tsx:95-96` renders the validation error *outside*
      // the logged-in branch, so both appear at once. Reproducing only one of
      // the two would make the screen lose information the original shows.
      await _pumpRegister(
        tester,
        '/register?token=stale',
        adapter: invitationAdapter(
          validateStatus: 404,
          validateMessage: 'Invalid or expired invitation token',
          permissions: const ['VIEW_EVENTS_ORGANIZATION'],
        ),
        token: 'token',
      );

      expect(find.text('Already Logged In'), findsOneWidget);
      expect(
        find.textContaining('Invalid or expired invitation token'),
        findsOneWidget,
      );
    });
  });
}

/// Boots the app signed out, navigates to [location], and settles.
///
/// Returns the container so a test can assert on where it ended up.
Future<ProviderContainer> _pumpRegister(
  WidgetTester tester,
  String location, {
  StubAdapter? adapter,
  String? token,
  List<String> permissions = const [],
}) async {
  final container = authTestContainer(
    adapter: adapter ?? invitationAdapter(permissions: permissions),
    token: token,
  );
  await tester.runAsync(() => container.read(authControllerProvider.future));

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TevenApp()),
  );

  container.read(routerProvider).go(location);
  await _settleAsync(tester);

  return container;
}

/// Lets the stubbed transport finish, then settles the widget tree.
///
/// The order matters and is not interchangeable: `runAsync` first so the real
/// async completes, then `pumpAndSettle` so the rebuilt frame lands. Doing it
/// the other way round would settle against a spinner that never stops.
Future<void> _settleAsync(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// The span carrying the link's gesture recognizer.
///
/// There is no widget to find here — an inline link is a `TextSpan`, not a
/// widget — so it is located the way the framework itself does, by looking for
/// the one span with a recognizer attached.
TextSpan _linkSpan(WidgetTester tester) {
  final sentence = _sentenceSpan(tester);
  final spans = sentence.children!.whereType<TextSpan>();
  return spans.firstWhere((span) => span.recognizer != null);
}

/// The root span of the invitation sentence.
///
/// `Text.textSpan` is typed `InlineSpan`, but `Text.rich` always gets a
/// `TextSpan`, so the cast is safe and saves casting at every use.
TextSpan _sentenceSpan(WidgetTester tester) =>
    tester
            .widget<Text>(
              find.textContaining('You can return to the application'),
            )
            .textSpan!
        as TextSpan;

/// Taps the inline "here" link.
///
/// The hit point is derived from the paragraph's layout for that span's own
/// offsets, rather than from the centre of the whole sentence — a centre tap
/// would land on ordinary body text and silently test nothing.
Future<void> _tapHereLink(WidgetTester tester) async {
  final link = _linkSpan(tester);
  await tester.tapAt(_sentenceRect(tester, _linkStart(tester)).center);
  expect(link.toPlainText().length, greaterThan(0));
}

/// The offset of the link within the sentence.
///
/// The sum of the preceding siblings' plain text. `TextSpan.start` is not
/// public, and `toPlainText().indexOf` would break the moment the same word
/// appeared twice.
int _linkStart(WidgetTester tester) {
  var start = 0;
  for (final span in _sentenceSpan(tester).children!) {
    if (span is TextSpan && span.recognizer != null) {
      break;
    }
    start += span.toPlainText().length;
  }
  return start;
}

/// The global rectangle covering the link.
///
/// `getBoxesForSelection` reports coordinates local to the paragraph, while
/// `tapAt` wants global ones. Without the transform the tap lands at a
/// plausible-looking point that happens to be somewhere else entirely.
Rect _sentenceRect(WidgetTester tester, int start) {
  final finder = find.textContaining('You can return to the application');
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final link = _linkSpan(tester);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: start,
      extentOffset: start + link.toPlainText().length,
    ),
  );

  expect(boxes, isNotEmpty, reason: 'the link must have been laid out');
  return MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    boxes.first.toRect(),
  );
}

/// Fills the four fields, leaving anything unspecified blank.
Future<void> _fillForm(
  WidgetTester tester, {
  String username = 'ada',
  String password = 'hunter2',
  String email = 'ada@example.com',
  String displayName = 'Ada L',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    username,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Display Name'),
    displayName,
  );
  await tester.pump();
}

/// Answers the three endpoints the acceptance flow touches.
///
/// Shapes are hand-written JSON rather than encoded models, so a model change
/// cannot quietly alter what these assert about the wire format.
StubAdapter invitationAdapter({
  int validateStatus = 200,
  String? validateMessage,
  int acceptStatus = 201,
  String? acceptMessage,
  List<String> permissions = const [],
}) => StubAdapter((options) {
  switch (options.path) {
    case '/api/users/context':
      return StubResponse.json(userContextJson(permissions: permissions));

    case '/api/invitations/validate':
      if (validateStatus != 200) {
        return StubResponse.json(
          jsonEncode({
            'success': false,
            'data': {},
            'error': {'message': validateMessage},
          }),
          status: validateStatus,
        );
      }
      return StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'organizationId': 1,
            'organizationName': 'Acme',
            'roleName': 'Admin',
          },
        }),
      );

    case '/api/invitations/accept':
      if (acceptStatus != 201) {
        return StubResponse.json(
          jsonEncode({
            'success': false,
            'data': {},
            'error': {'message': acceptMessage},
          }),
          status: acceptStatus,
        );
      }
      return StubResponse.json(
        jsonEncode({
          'success': true,
          'data': {
            'success': true,
            'message': acceptMessage ?? 'Invitation accepted and user created.',
          },
        }),
        status: acceptStatus,
      );
  }

  return const StubResponse.json(
    '{"success":false,"data":{},"error":{"message":"Unauthorized"}}',
    status: 401,
  );
});
