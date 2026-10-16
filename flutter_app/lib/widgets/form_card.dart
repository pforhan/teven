import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import 'error_display.dart';

/// The shell every Phase 5 form is built from.
///
/// Task 5.1. All seven React forms are the same `card` / `card-body` /
/// `card-title` / `ErrorDisplay` / `<form>` / two buttons, differing only in
/// their fields, their heading and their submit label — `CreateCustomerForm`,
/// `EditCustomerForm`, `CreateInventoryForm`, `EditInventoryForm`,
/// `CreateOrganizationForm`, `EditOrganizationForm`, `CreateUserForm`,
/// `EditUserForm`, `EditProfileForm` and the 182-line `CreateInvitationForm`
/// between them. Seven transcriptions of that skeleton is seven chances for
/// one of them to lose the error banner.
///
/// The skeleton itself is cheap; the two decisions in it are not:
///
/// - **It owns the [Form] and the key.** `validate()` is the whole reason the
///   key exists, so a form that builds its own [Form] can forget to call it
///   and submit unvalidated — which on the web means a request the React
///   `required` attribute would have stopped.
/// - **It owns the scroll view.** None of these forms is `col-lg-*` or
///   multi-column, but all of them are taller than a phone once the keyboard
///   is up, and a form whose submit button cannot be reached is a form that
///   cannot be used. Task 5.11's "single-column scroll on mobile" is applied
///   here once rather than in each of the ten screens.
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.formKey,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
    required this.fields,
    this.error,
    this.submitting = false,
  });

  /// The key the owning form calls `validate()` through.
  final GlobalKey<FormState> formKey;

  /// The `card-title`. Each React form has its own, and two of them interpolate
  /// the record: `Edit Customer: {customer.name}`.
  final String title;

  /// The `btn-primary` label — "Create Customer", "Save Changes", and so on.
  final String submitLabel;

  /// Runs after validation passes. The caller owns the request and the
  /// navigation; this widget does not know about either.
  final VoidCallback onSubmit;

  /// The `btn-secondary` Cancel button, which navigates away in every form
  /// except the profile's, where it is a callback.
  final VoidCallback onCancel;

  /// The fields, in order. Laid out as a single stretching column with 16dp
  /// between them, matching Bootstrap's `mb-3` on each `.mb-3` block.
  final List<Widget> fields;

  /// The form-level failure — a rejected submit, or a failed initial load on
  /// the edit forms. Rendered above the fields, as `ErrorDisplay` sits above
  /// the `<form>` in the React originals.
  ///
  /// Typed as [ApiException] rather than `Object?` because that is what every
  /// Phase 5 form can actually hold: the React originals branch between
  /// `ApiErrorWithDetails`, a bare `Error` and a fallback string, and task 1.9
  /// is what collapsed those three into one type.
  final ApiException? error;

  /// Whether a request is in flight.
  ///
  /// Disables the button and swaps its label for a spinner. The React forms
  /// have no such guard, which on web means a double-click fires two POSTs and
  /// the second creates a second customer. The button is disabled rather than
  /// the handler guarded so the state is visible.
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        // The shell adds no padding of its own — the four list screens get
        // theirs from `PagedScrollView`, so this matches.
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The `card` + `card-body`. A bordered container rather than a
              // `Card`, for the reason `ResponsiveListView` gives: the mobile
              // layouts nest a card per record inside it, and Material's
              // elevation reads as a different app.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      ErrorDisplay.fromException(error!),
                    ],
                    const SizedBox(height: 16),
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      fields[i],
                    ],
                    const SizedBox(height: 24),
                    // `btn-primary` then `btn-secondary ms-2`. A `Wrap` for
                    // the same reason `ListScreenHeader` uses one: at 360px a
                    // `Row` of two buttons with these labels fits, but the
                    // harness found the equivalent overflow at 500px on the
                    // list headers, and a `Wrap` costs nothing to get right.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: submitting ? null : onSubmit,
                          child: submitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(submitLabel),
                        ),
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
