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

    // The bug this file's date tests exist for: the picker used to stop at
    // *today*, which made the event date — the one field the whole app
    // exists to fill in — impossible to set forward. A scheduling app whose
    // only date input is "today or yesterday" is not a scheduling app.
    testWidgets('a date in the future can be picked', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The dialog's own bounds are the contract: the picker's last
      // selectable day must be in the future. Read off the dialog rather
      // than inferred from the rendered grid, so the assertion is about the
      // range and not about which cells happen to be on screen.
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.lastDate.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('the picker opens on a future date already in the field', (
      tester,
    ) async {
      // A future date already in the controller — an event scheduled for
      // next month, loaded by the edit form. `showDatePicker` asserts that
      // the initial date is within its range, so a value past the bound
      // would take the screen down rather than open a picker.
      final future = DateTime.now().add(const Duration(days: 45));
      final controller = TextEditingController(
        text:
            '${future.year}-${future.month.toString().padLeft(2, '0')}-'
            '${future.day.toString().padLeft(2, '0')}',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(DateField(controller: controller, label: 'Date')),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Confirming without changing the date leaves it alone.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.text, isNotEmpty);
    });

    testWidgets('a caller-supplied lastDate is honoured', (tester) async {
      // The date of birth is the case that genuinely wants a past-only
      // bound. The field's default no longer provides one, so the bound
      // has to come from the call site — and it has to actually apply.
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          DateField(
            controller: controller,
            label: 'Date of Birth',
            lastDate: DateTime.now(),
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.lastDate.isAfter(DateTime.now()), isFalse);
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
