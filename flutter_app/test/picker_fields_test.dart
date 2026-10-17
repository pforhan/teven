import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/widgets/picker_fields.dart';
import 'package:teven_app/widgets/validators.dart';

/// Task 5.9. Tests for the picker widgets that replace HTML input types.
///
/// The date and time pickers are Material dialogs, so the tests drive them
/// through their real UI — tap the field, settle the dialog, tap "OK" —
/// rather than mocking the picker. The formatter test is the one that could
/// not be done through the UI: `FilteringTextInputFormatter` operates on the
/// input channel, which `enterText` exercises directly.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DateField', () {
    testWidgets('displays the initial date', (tester) async {
      final controller = TextEditingController(text: '2026-03-04');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date of Birth')),
      );

      expect(find.text('2026-03-04'), findsOneWidget);
    });

    testWidgets('opens the date picker and fills the field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date of Birth')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // The date picker dialog is open.
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Confirm the initial date (today).
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The field now holds today's date in yyyy-MM-dd format.
      expect(controller.text, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('an existing date is preserved when the picker is confirmed', (
      tester,
    ) async {
      final controller = TextEditingController(text: '2026-03-04');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date of Birth')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // Confirm without changing the date.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.text, '2026-03-04');
    });

    testWidgets('cancelling the picker leaves the field unchanged', (
      tester,
    ) async {
      final controller = TextEditingController(text: '2026-03-04');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date of Birth')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.text, '2026-03-04');
    });

    testWidgets('the field is read-only — no keyboard input', (tester) async {
      final controller = TextEditingController(text: '2026-03-04');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date of Birth')),
      );

      // Attempt to type into the field. The formatter-less read-only field
      // should not accept input — the text remains unchanged.
      await tester.enterText(find.byType(TextFormField), 'garbage');
      await tester.pump();

      // The text is either unchanged or the field is read-only. The key
      // assertion is that the field did not become 'garbage'.
      expect(controller.text, isNot('garbage'));
    });
  });

  group('NumberField', () {
    testWidgets('only accepts digits', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(NumberField(controller: controller, label: 'Quantity')),
      );

      // Enter mixed alphanumeric text. The formatter strips non-digits.
      await tester.enterText(find.byType(TextFormField), 'abc123def');
      await tester.pump();

      expect(controller.text, '123');
    });

    testWidgets('accepts a plain integer', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(NumberField(controller: controller, label: 'Quantity')),
      );

      await tester.enterText(find.byType(TextFormField), '42');
      await tester.pump();

      expect(controller.text, '42');
    });

    testWidgets('validator rejects empty input', (tester) async {
      final formKey = GlobalKey<FormState>();
      addTearDown(() {});

      await tester.pumpWidget(
        wrap(
          Form(
            key: formKey,
            child: NumberField(
              controller: TextEditingController(),
              label: 'Quantity',
              validator: Validators.requiredNumber,
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('validator accepts a valid number', (tester) async {
      final controller = TextEditingController(text: '5');
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        wrap(
          Form(
            key: formKey,
            child: NumberField(
              controller: controller,
              label: 'Quantity',
              validator: Validators.requiredNumber,
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  group('TimeField', () {
    testWidgets('displays the initial time', (tester) async {
      final controller = TextEditingController(text: '09:30:00');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(TimeField(controller: controller, label: 'Time')),
      );

      expect(find.text('09:30:00'), findsOneWidget);
    });

    testWidgets('opens the time picker and fills the field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(TimeField(controller: controller, label: 'Time')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      // The time picker dialog is open.
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Confirm the initial time.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The field now holds a time in HH:MM:00 format.
      expect(controller.text, matches(RegExp(r'^\d{2}:\d{2}:00$')));
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('an existing time is preserved when the picker is confirmed', (
      tester,
    ) async {
      final controller = TextEditingController(text: '09:30:00');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(TimeField(controller: controller, label: 'Time')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.text, '09:30:00');
    });

    testWidgets('cancelling the picker leaves the field unchanged', (
      tester,
    ) async {
      final controller = TextEditingController(text: '09:30:00');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(TimeField(controller: controller, label: 'Time')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.text, '09:30:00');
    });
  });
}
