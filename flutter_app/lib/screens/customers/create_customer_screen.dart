import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/customer.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/organization_list.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

/// The create-customer form.
///
/// `CreateCustomerForm.tsx` (146 lines). Four required text fields, a
/// conditional organization `<select>`, and a redirect to the list.
///
/// **The organization resolution is the interesting part, and it is not one
/// rule but three, in priority order** (`CreateCustomerForm.tsx:76-83`):
///
/// 1. a super-admin's selected organization wins, even for a global manager —
///    having narrowed the chrome to one organization, the form should not
///    quietly create the customer somewhere else;
/// 2. otherwise a `MANAGE_CUSTOMERS_GLOBAL` holder uses the dropdown;
/// 3. otherwise the organization in the user's own context, and the server
///    ignores anything sent in its place.
///
/// The dropdown is shown only in case 2 — `!selectedOrganization &&
/// canManageGlobalCustomers` (`:102`). So a super-admin who has picked an
/// organization in the chrome gets no dropdown at all, and an `Organizer`
/// gets none either.
///
/// **The server is not neutral about this.** `CustomerService.kt:62` throws
/// `"organizationId is required for MANAGE_CUSTOMERS_GLOBAL users"` when the
/// request arrives without one, so case 2 is the only path on which the client
/// has to get it right.
class CreateCustomerScreen extends ConsumerStatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  ConsumerState<CreateCustomerScreen> createState() =>
      _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends ConsumerState<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  /// The dropdown's selection. Null means "not chosen", which is not the same
  /// as "nothing" — see [_defaultOrganization].
  OrganizationResponse? _organization;

  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _canManageGlobal =>
      ref.read(permissionGateProvider).has(Permission.manageCustomersGlobal);

  /// The organization the customer will be created in, for the request.
  ///
  /// [ref.read] rather than [ref.watch] because this is called from [_submit],
  /// not from `build` — the whole screen rebuilds on every keystroke anyway, so
  /// there is nothing here to subscribe to.
  int? get _organizationId {
    final selected = ref.read(selectedOrganizationProvider);
    if (selected != null) {
      return selected.organizationId;
    }
    if (_canManageGlobal) {
      return _defaultOrganization(
        ref.read(organizationsProvider),
        _organization,
      )?.organizationId;
    }
    return ref.read(userContextProvider)?.user.organization.organizationId;
  }

  /// The dropdown's value: what the user chose, or the first organization.
  ///
  /// `CreateCustomerForm.tsx:40-42` seeds the selection with `items[0]` as
  /// soon as the list arrives. Reproduced as a derived value rather than as a
  /// `useEffect` writing state, which removes a window the original has: there
  /// is no longer a state meaning "not chosen yet" that the control and the
  /// submit handler could disagree about.
  ///
  /// **A free function, and it has to be.** Both the dropdown and [_submit]
  /// need it, and they are in different widgets — the dropdown is a
  /// `ConsumerWidget` that does its own watching, so the screen cannot pass a
  /// resolved list down without either fetching for users who may not, or
  /// duplicating this rule. See [OrganizationSelectField] for why the fetch is
  /// conditional at all.
  static OrganizationResponse? _defaultOrganization(
    List<OrganizationResponse> organizations,
    OrganizationResponse? chosen,
  ) => chosen ?? (organizations.isEmpty ? null : organizations.first);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final organizationId = _organizationId;

    // `CreateCustomerForm.tsx:85-88`. **Unreachable through the form**, and
    // kept anyway for one reason: `organizationId` is genuinely optional in
    // `CreateCustomerRequest`, the server *requires* it for a global manager
    // (`CustomerService.kt:62`), and the failure mode for getting it wrong is
    // an opaque 500 rather than a message. The original's own guard is
    // unreachable too — the `<select required>` at `:107` fires first, in the
    // browser — so this is not carrying a path React could reach, only the one
    // a future change to the fields could reopen.
    if (organizationId == null) {
      setState(
        () => _error = const ApiRequestException(
          'Organization must be selected.',
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(customerServiceProvider)
          .createCustomer(
            CreateCustomerRequest(
              name: _name.text,
              phone: _phone.text,
              address: _address.text,
              notes: _notes.text,
              organizationId: organizationId,
            ),
          );
      if (mounted) {
        // `navigate('/customers')` (`CreateCustomerForm.tsx:92`).
        //
        // No provider invalidation alongside it, and that is worth stating:
        // `customerListProvider` is `autoDispose`, and `go` replaces the route
        // rather than pushing, so the list is disposed on the way out and
        // refetches on the way back. An `invalidate` here would be a second
        // mechanism for a result the navigation already produces.
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
    final gate = ref.watch(permissionGateProvider);
    final canManageGlobal = gate.has(Permission.manageCustomersGlobal);
    final hasSelectedOrganization =
        ref.watch(selectedOrganizationProvider) != null;

    // `:102` — `!selectedOrganization && canManageGlobalCustomers`.
    final showOrganizationField = canManageGlobal && !hasSelectedOrganization;

    return FormCard(
      formKey: _formKey,
      title: 'Create New Customer',
      submitLabel: 'Create Customer',
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
          // `type="text"` in the original, not `type="tel"`. This is the one
          // place the port diverges and it diverges in the caller's favour:
          // `tel` opens a numeric keypad on a phone, and the server accepts a
          // phone string in any format it did not validate anyway.
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
          // The `<textarea>` at `:99`. Several lines rather than Material's
          // default one-and-a-bit, because the field exists to hold a note
          // rather than a fragment — and `maxLines` above 1 without a `minLines`
          // is what makes a field grow with its content and walk the submit
          // button off the bottom of the screen.
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'Notes'),
          validator: Validators.requiredText,
        ),
        if (showOrganizationField)
          OrganizationSelectField(
            value: _organization,
            resolve: _CreateCustomerScreenState._defaultOrganization,
            onChanged: (organization) =>
                setState(() => _organization = organization),
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}
