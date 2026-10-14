import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/theme/teven_theme.dart';
import 'package:teven_app/widgets/confirm_dialog.dart';

/// The shared delete confirmation — task 4.8, first of six call sites.
///
/// The dialog is now this, so the behaviour worth pinning is the *answer*:
/// what each way of dismissing it returns. The scrim and the back gesture are
/// the cases a port is most likely to get wrong, because `window.confirm` has
/// no equivalent — a dismissal there returns `false`, and anything else turns a
/// dialog into a delete button with a delay on it.
void main() {
  /// Opens the dialog and hands its answer to [onAnswer].
  ///
  /// The answer arrives after the dialog closes, so the callback is the only
  /// way to observe it — a test cannot simply `await` the helper.
  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<bool> onAnswer, {
    String message = 'Delete Globex?',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TevenTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                onAnswer(
                  await confirmDestructiveAction(
                    context,
                    title: 'Delete customer',
                    message: message,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the caller its title and message', (tester) async {
    await openDialog(tester, (_) {}, message: 'Delete Globex? This is final.');

    expect(find.text('Delete customer'), findsOneWidget);
    expect(find.text('Delete Globex? This is final.'), findsOneWidget);
  });

  testWidgets('confirming returns true', (tester) async {
    bool? answer;
    await openDialog(tester, (value) => answer = value);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('cancelling returns false', (tester) async {
    bool? answer;
    await openDialog(tester, (value) => answer = value);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });

  testWidgets('dismissing with no answer is a no, not a yes', (tester) async {
    // `showDialog` answers `null` here, so the `?? false` is the only thing
    // standing between a stray scrim tap and a delete.
    bool? answer;
    var completed = false;
    await openDialog(tester, (value) {
      answer = value;
      completed = true;
    });

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(completed, isTrue, reason: 'the call must complete, not hang');
    expect(answer, isFalse);
  });

  testWidgets('the confirm button is styled as destructive', (tester) async {
    // Not visible from the call site, and not implied by the presence of a
    // `TextButton` either — `styleFrom` resolves against the theme, so this
    // only fails if the colour is dropped.
    await openDialog(tester, (_) {});

    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final confirm = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Delete'),
    );

    expect(
      confirm.style!.foregroundColor!.resolve({}),
      TevenTheme.light().colorScheme.error,
    );
    // The cancel button is left as it is found, so the two do not look alike.
    expect(cancel.style?.foregroundColor, isNull);
  });
}
