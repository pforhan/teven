/// Field validators shared by the forms.
///
/// Task 5.1. The React forms have no validation library — the only rule any of
/// them has is the HTML `required` attribute, which the browser enforces and
/// the React code never reads. Porting that means choosing where the rule
/// lives, and the answer is [TextFormField.validator]: the check happens on
/// submit rather than on every keystroke, exactly as `required` does.
///
/// **No form package.** The plan calls for "no form library — the React code
/// has none, so this is a free choice", and Flutter's own `Form` plus
/// `GlobalKey<FormState>` is already the framework's answer to the same
/// problem. Adding a dependency to do what `Form` does would be the one thing
/// this port should not spend a package on.
abstract final class Validators {
  const Validators._();

  /// Stands in for the HTML `required` attribute.
  ///
  /// The wording matches `LoginScreen`'s private copy, which this replaced —
  /// two copies of one string in seven forms is how the copy drifts.
  static String? required(String? value) =>
      (value == null || value.isEmpty) ? 'This field is required' : null;

  /// `required` plus a non-whitespace check.
  ///
  /// **Not a behaviour change.** HTML `required` rejects a field holding only
  /// spaces, and a bare `isEmpty` check would accept "   " and hand it to the
  /// server, which is the one case a validator exists to stop. Written as a
  /// separate method rather than folded into [required] because not every
  /// required field wants it — see the `notes` field, which is a free-text
  /// field where a space is a legitimate (if unhelpful) answer.
  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  /// `required` for a non-text selection — a `DropdownButtonFormField`.
  ///
  /// Generic rather than specialized because the alternative is one
  /// near-identical method per field type, and the message is identical in all
  /// of them — the field's own label supplies the subject.
  static String? requiredSelection<T>(T? value) =>
      value == null ? 'This field is required' : null;

  /// `required` plus a rudimentary email format check.
  static String? email(String? value) {
    if (required(value) != null) {
      return required(value);
    }
    final trimmed = value!.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Invalid email';
    }
    return null;
  }
}
