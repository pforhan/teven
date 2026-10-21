import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// A read-only text field that opens `showDatePicker` on tap.
///
/// Task 5.9. Replaces `<input type="date">` — the React forms use it for
/// date fields like a date of birth. The browser's native date picker is
/// replaced by Flutter's own, and the field is read-only so the keyboard
/// never opens for a value that must be a valid date.
///
/// The controller text is the `yyyy-MM-dd` string the server expects, which
/// is also what the field displays — the format the React `<input type="date">`
/// submitted, so the wire format does not change.
///
/// **The default range runs from 1900 to the end of 2100, and it includes the
/// future on purpose.** The HTML input this replaces carries no `max`
/// attribute, so the browser never forbade a future date. This widget used
/// to cap the picker at *today* instead, which is wrong for a scheduling
/// app — an event is normally booked for a day that has not arrived yet — and
/// wrong for the original, which never had that cap. A caller with a genuine
/// past-only bound (a date of birth) passes [lastDate] itself.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.validator,
    this.firstDate,
    this.lastDate,
  });

  final TextEditingController controller;
  final String label;

  /// Called with the newly picked date, or null when the picker is dismissed.
  ///
  /// Added for task 7.5's start-date filter, which has to push the value up into
  /// screen state to build a query. The six Phase 6 form fields all own a
  /// controller and read it at submit time, so they did not need a callback and
  /// this was not part of the widget until a screen wanted to react to a change
  /// rather than hold it.
  final ValueChanged<DateTime?>? onChanged;

  final String? Function(String?)? validator;

  /// The earliest date the picker will offer, and the floor the field's own
  /// value is held to.
  ///
  /// Defaults to 1900, which is where the picker used to start.
  final DateTime? firstDate;

  /// The latest date the picker will offer, and the ceiling the field's own
  /// value is held to.
  ///
  /// **Defaults to the end of 2100, not today.** See the class doc.
  final DateTime? lastDate;

  static final _format = DateFormat('yyyy-MM-dd');

  /// The earliest date the picker offers when the caller names no bound.
  static final DateTime _defaultFirstDate = DateTime(1900);

  /// The latest date the picker offers when the caller names no bound.
  ///
  /// **The end of 2100, so that a date in the future is selectable.** The
  /// event forms are for scheduling work that has not happened yet; a
  /// picker that stopped at today made the event date — the one field the
  /// whole app exists to fill in — impossible to set forward. The HTML input
  /// this replaces had no `max` attribute either, so this restores the
  /// original's range rather than inventing a restriction.
  ///
  /// The calendar screen already draws months out to the end of 2100, so
  /// this bound matches what the app can otherwise show.
  static final DateTime _defaultLastDate = DateTime(2100, 12, 31);

  /// Parses the controller text, returning null if it is not a valid date.
  ///
  /// A null result means the picker opens at [DateTime.now] rather than at a
  /// date the field does not understand — which is what an empty field wants
  /// anyway.
  static DateTime? _parse(String text) {
    try {
      return _format.parseStrict(text);
    } on FormatException {
      return null;
    }
  }

  static String _formatDate(DateTime date) => _format.format(date);

  /// Brings [date] inside `[first, last]`.
  ///
  /// `showDatePicker` asserts that its initial date lies within the range it
  /// is given, so a field holding a date outside the range — an event
  /// scheduled for 2200, say — would trip the assertion rather than open.
  /// Clamping keeps the picker openable, and the value the user sees in the
  /// field is untouched either way; only what the picker starts on moves.
  static DateTime _clampToRange(DateTime date, DateTime first, DateTime last) {
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(context),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      validator: validator,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final first = firstDate ?? _defaultFirstDate;
    final last = lastDate ?? _defaultLastDate;
    final initial = _clampToRange(
      _parse(controller.text) ?? DateTime.now(),
      first,
      last,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      controller.text = _formatDate(picked);
    }
    // Reported whether or not anything was picked, so a caller can distinguish
    // "dismissed" from "picked the date that was already there" — the latter is
    // not a no-op for a screen that has just reset its filter.
    onChanged?.call(picked);
  }
}

/// A read-only text field that opens `showTimePicker` on tap.
///
/// Task 5.9. Replaces `<input type="time">` — the React event forms use it
/// for the event time (`CreateEventForm.tsx:272`, `EditEventForm.tsx:215`).
/// No Phase 5 form has a time input; this is here so Phase 6 has one place
/// for the convention.
///
/// The controller text is `HH:MM:00` — the `HH:MM:SS` shape the event
/// system uses, with seconds zeroed because `showTimePicker` cannot pick them.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  /// Parses `HH:MM` or `HH:MM:SS`, returning null if neither matches.
  static TimeOfDay? _parse(String text) {
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(context),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time),
      ),
      validator: validator,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final initial = _parse(controller.text) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      controller.text = _formatTime(picked);
    }
  }
}

/// A text field that only accepts digits.
///
/// Task 5.9. Replaces `<input type="number">` — the React forms use it for
/// quantity fields (`CreateInventoryForm.tsx:110`,
/// `EditInventoryForm.tsx:104`, `InventoryAssociationEditor.tsx:118`).
///
/// `FilteringTextInputFormatter.digitsOnly` strips non-digit characters as
/// the user types, so the validator's `int.tryParse` check is a safety net
/// rather than the primary defense — the formatter means a non-numeric value
/// cannot reach the field in the first place.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: validator,
      textInputAction: textInputAction,
      onChanged: onChanged,
    );
  }
}
