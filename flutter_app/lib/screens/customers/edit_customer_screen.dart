import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/customer.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

/// The edit-customer form.
///
/// `EditCustomerForm.tsx` (139 lines). Loads the customer, fills the four
/// fields, and submits a partial update.
///
/// **Two things differ from [CreateCustomerScreen] and both are load-bearing.**
///
/// The dropdown is shown on `canManageGlobalCustomers` alone (`:115`), with no
/// `selectedOrganization` exemption — so a super-admin who narrowed the chrome
/// to one organization still gets to see (and change) which organization this
/// customer belongs to. That looks like an inconsistency with the create form
/// and is very likely one, but it is also a deliberate difference: the create
/// form's dropdown would be redundant with the chrome's scope, while here it is
/// the only place a customer can be moved.
///
/// And the update sends `organizationId` **only** for a global manager
/// (`:63-67`), where the create form always sends one. That is not a client
/// choice: `CustomerService.kt:89-93` refuses an `organizationId` change from
/// anyone who lacks `MANAGE_CUSTOMERS_GLOBAL`, so sending one unconditionally
/// would be a 500 for every `Organizer` who edited a customer.
///
/// The load is a screen-level concern rather than a provider, because nothing
/// else reads this customer — the list screen has its own rows, and there is no
/// customer detail screen to share one with (task 10.20 builds it).
class EditCustomerScreen extends ConsumerStatefulWidget {
  const EditCustomerScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  CustomerResponse? _customer;

  /// The dropdown's selection.
  ///
  /// Separate from [_customer] rather than a `copyWith` on it: the record is
  /// what was loaded and should not be edited underneath the title, while this
  /// is a pending choice that the request reads and the title ignores.
  /// Seeded from the loaded customer on arrival — `EditCustomerForm.tsx:69`.
  OrganizationResponse? _organization;

  bool _loading = true;
  bool _submitting = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    // Not awaited, and deliberately not awaited-by-`initState`: the load is
    // guarded by [_loading] and every path out of it calls `setState`, so the
    // screen renders its loading state without the caller's help.
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // No `setState` before the request. `initState` cannot call one, and the
    // only caller that can — the "Try again" button — already has `_loading`
    // set to false, so a `setState` here would need to distinguish the two.
    try {
      final customer = await ref
          .read(customerServiceProvider)
          .getCustomer(widget.customerId);
      if (!mounted) return;

      // `EditCustomerForm.tsx:36-39`. The controllers are filled here rather
      // than from an `initialValue`, because the field does not exist until
      // the customer arrives — there is no first build to give an initial
      // value to.
      setState(() {
        _customer = customer;
        _organization = customer.organization;
        _name.text = customer.name;
        _phone.text = customer.phone;
        _address.text = customer.address;
        _notes.text = customer.notes;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final canManageGlobal = ref
        .read(permissionGateProvider)
        .has(Permission.manageCustomersGlobal);

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(customerServiceProvider)
          .updateCustomer(
            widget.customerId,
            UpdateCustomerRequest(
              name: _name.text,
              phone: _phone.text,
              address: _address.text,
              notes: _notes.text,
              // `:64-67` — omitted, not sent-as-null, for anyone who may not
              // change it. See the class comment for why that is the server's
              // rule and not a shortcut.
              organizationId: canManageGlobal
                  ? _organization?.organizationId
                  : null,
            ),
          );
      if (mounted) {
        // `navigate('/customers')` (`:76`). The list refetches because
        // `customerListProvider` is `autoDispose` and `go` disposes it.
        context.go(AppRoutes.customers);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;

    // `EditCustomerForm.tsx:80` — `if (!customer) return <div>Loading customer...</div>`.
    // Reproduced verbatim, including the fact that it is bare text rather than
    // a spinner: the request resolves in well under a frame on a normal
    // network, and a spinner that flashes for 40ms is worse than nothing.
    //
    // An error takes the same branch, which is the original's behaviour too —
    // `setError` runs and `customer` stays null, so the user sees
    // "Loading customer..." with the error banner never rendered. **That is a
    // real defect in the React app and it is not reproduced**: an error that
    // shows a loading message forever is a screen that looks broken rather
    // than one that explains itself.
    if (_loading) {
      return const Scaffold(body: Center(child: Text('Loading customer...')));
    }

    if (customer == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Customer', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              // The message the original failed to render. `_error` is always
              // set on this branch — `_load` only leaves `_customer` null on a
              // failure — and the fallback string is unreachable in practice,
              // but `error` is nullable so the banner needs something to say.
              if (_error != null)
                ErrorDisplay.fromException(_error!)
              else
                Text(
                  'Could not load customer.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.customers),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // `:115` — no `selectedOrganization` exemption here, unlike the create
    // form. See the class comment.
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageCustomersGlobal);

    return FormCard(
      formKey: _formKey,
      // `:85` — the card title interpolates the loaded record, which is why
      // this screen cannot render before the fetch resolves.
      title: 'Edit Customer: ${customer.name}',
      submitLabel: 'Update Customer',
      error: _error,
      submitting: _submitting,
      onSubmit: _submit,
      onCancel: () => context.go(AppRoutes.customers),
      fields: [
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Phone'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _address,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Address'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _notes,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'Notes'),
          validator: Validators.requiredText,
        ),
        if (canManageGlobal)
          OrganizationSelectField(
            // `:69` — seeded from the loaded customer, not from the list's
            // first entry. An organization the caller cannot see (deleted, or
            // beyond the `1000` limit) still shows by name rather than
            // silently presenting a different organization; see
            // `organizationsIncluding`.
            value: _organization,
            onChanged: (organization) =>
                setState(() => _organization = organization),
            // **No validator**, unlike the create form's dropdown. The
            // `<select>` at `EditCustomerForm.tsx:117-119` has no `required`
            // attribute — the only way to end up here with nothing selected is
            // a user who cannot see any organization at all, and blocking the
            // save of four edited fields on that would be a regression rather
            // than a parity fix.
          ),
      ],
    );
  }
}
