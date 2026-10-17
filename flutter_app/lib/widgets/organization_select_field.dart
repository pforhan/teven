import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organization.dart';
import '../providers/organization_list.dart';

/// The organization `<select>` the customer and user forms share.
///
/// `CreateCustomerForm.tsx:104-119` and `CreateUserForm.tsx` render the same
/// control — a `form-select` over `getAllOrganizations(1000).items`, holding an
/// `organizationId` — and differ only in what they do with it. React wrote
/// each one out again; this is the one widget both use.
///
/// **It watches [organizationListProvider] itself, and that is the load-bearing
/// part.** The React forms fetch inside a `useEffect` guarded by
/// `canManageGlobal`, precisely so that a user without it never asks — and
/// `GET /api/organizations` is gated on `VIEW_ORGANIZATIONS_GLOBAL` server-side
/// (`OrganizationRoutes.kt`), so an `Organizer` who made that request would get
/// a 403. Watching it unconditionally would put a guaranteed-403 request on
/// every create screen for every non-super-admin.
///
/// So the condition belongs to the *caller*: build this widget only when the
/// user may use it, and no request is made for anyone else. That is the same
/// arrangement as the chrome's picker, and the reason this widget is a leaf
/// rather than something that decides for itself.
///
/// A `Form`-participating variant of `DropdownButton`, because the React
/// `<select required>` validates.
class OrganizationSelectField extends ConsumerWidget {
  const OrganizationSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.resolve,
    this.validator,
  });

  /// The organization currently chosen, or null for none.
  ///
  /// The whole object rather than an id, because that is what the caller needs
  /// to submit and because [organizationsIncluding] needs to fold an absent
  /// selection back in — an id cannot be labelled without looking it up in a
  /// list that may not have loaded yet.
  final OrganizationResponse? value;

  /// Derives the value to *display* when the caller has not chosen one.
  ///
  /// Exists because `CreateCustomerForm.tsx:40-42` and `CreateUserForm.tsx:42`
  /// both seed their `<select>` with `items[0]`, and the rule has to be the
  /// same one the submit handler applies — otherwise the control shows one
  /// organization while the request names another, and nothing on screen
  /// disagrees. `CreateCustomerScreen` passes the same function to both.
  ///
  /// Null (the default) shows exactly what the caller chose, which is what the
  /// edit forms want: their value comes from the record they loaded.
  final OrganizationResponse? Function(
    List<OrganizationResponse> loaded,
    OrganizationResponse? chosen,
  )?
  resolve;

  final ValueChanged<OrganizationResponse?> onChanged;

  /// Form validation for the selection, when the caller's form requires one.
  final String? Function(OrganizationResponse?)? validator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(organizationsProvider);
    final chosen = resolve?.call(loaded, value) ?? value;
    final organizations = organizationsIncluding(loaded, chosen);
    // A failed fetch renders the same empty control a pending one does, which
    // is what the React original does — it has no error state for this and
    // lets the submit fail instead. The message goes *beside* the control
    // rather than replacing it, because a super-admin staring at an empty
    // dropdown has no other way to tell "still loading" from "broken", and the
    // difference decides whether they wait or give up. Swapping the control out
    // for an error string would also leave the form un-submittable with no
    // explanation attached to the thing they tried to submit.
    final failure = ref.watch(organizationListProvider).error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<OrganizationResponse>(
          // `value:` is deprecated on `DropdownButtonFormField` in favour of
          // `initialValue`, which is the honest name here: the field's value
          // comes and goes with the owning form's state, and
          // `DropdownButtonFormField` only reads it on first build.
          initialValue: chosen,
          isExpanded: true,
          onChanged: onChanged,
          validator: validator,
          decoration: const InputDecoration(labelText: 'Organization'),
          items: [
            for (final organization in organizations)
              DropdownMenuItem<OrganizationResponse>(
                value: organization,
                child: Text(organization.name, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        // **A sibling of the control, not its `helperText`.**
        //
        // `InputDecorator` shows `errorText` *instead of* `helperText` — the
        // two are mutually exclusive, and validation wins. Since the symptom of
        // a failed fetch is an empty dropdown, the user reaches it by hitting
        // submit, so the very act that needs explaining replaced the
        // explanation with "This field is required". That is the worst possible
        // pairing: the message blames the user for a fault they did not cause,
        // and it is the only moment they could have learned the list had
        // failed to load.
        //
        // Rendered below the control for the same reason. It is not styled as
        // a validation error — nothing about the *selection* is invalid, and
        // colouring it as one would double up with the real error that
        // `validator` returns a line above.
        if (failure != null) ...[
          const SizedBox(height: 8),
          Text(
            'Could not load: $failure',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
