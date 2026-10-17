import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// A read-only text field that opens `showDatePicker` on tap.
///
/// Task 5.9. Replaces `<input type="date">` — the React forms use it for
/// date fields like `dateOfBirth` (`EditProfileForm.tsx:71`). The browser's
/// native date picker is replaced by Flutter's own, and the field is read-only
/// so the keyboard never opens for a value that must be a valid date.
///
/// The controller text is the `yyyy-MM-dd` string the server expects, which
/// is also what the field displays — the format the React `<input type="date">`
/// submitted, so the wire format does not change.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.firstDate,
    this.lastDate,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static final _format = DateFormat('yyyy-MM-dd');

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
    final initial = _parse(controller.text) ?? DateTime.now();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? now,
    );
    if (picked != null) {
      controller.text = _formatDate(picked);
    }
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
