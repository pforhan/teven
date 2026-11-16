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
import '../../widgets/error_display.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

/// Unified create/edit customer form.
///
/// The original create and edit forms shared the same four fields and form flow
/// but differed in load, organization rules, submit request, and post-submit
/// behaviour. The differences are expressed as parameters/mode branches rather
/// than a second implementation.
///
/// **Organization rules differ by mode and are kept as-is (9.24).** Create uses
/// the shell's selected organization first, otherwise a global manager's
/// dropdown (shown only when there is no selected organization), otherwise the
/// caller's own organization; the create request always sends an organization
/// id because the server requires one from a global manager. Edit shows the
/// dropdown to any global manager (no selected-organization exemption) and sends
/// `organizationId` only for that caller, because the server refuses an
/// organization change from anyone else.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  /// Null for create, non-null for edit.
  final int? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  CustomerResponse? _customer;
  OrganizationResponse? _organization;

  bool _loading = false;
  bool _submitting = false;
  ApiException? _error;

  bool get _isCreate => widget.customerId == null;
  bool get _isEdit => widget.customerId != null;

  bool get _canManageGlobal =>
      ref.read(permissionGateProvider).has(Permission.manageCustomersGlobal);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _load();
    }
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
    try {
      final customer = await ref
          .read(customerServiceProvider)
          .getCustomer(widget.customerId!);
      if (!mounted) return;
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

  /// The dropdown's value for create: what the user chose, or the first
  /// organization. Shared by the control and submit so they agree.
  static OrganizationResponse? _defaultOrganization(
    List<OrganizationResponse> organizations,
    OrganizationResponse? chosen,
  ) => chosen ?? (organizations.isEmpty ? null : organizations.first);

  int? get _createOrganizationId {
    final selected = ref.read(selectedOrganizationProvider);
    if (selected != null) return selected.organizationId;
    if (_canManageGlobal) {
      return _defaultOrganization(
        ref.read(organizationsProvider),
        _organization,
      )?.organizationId;
    }
    return ref.read(userContextProvider)?.user.organization.organizationId;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isCreate) {
      final organizationId = _createOrganizationId;
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
        if (mounted) context.go(AppRoutes.customers);
      } on ApiException catch (error) {
        if (mounted) setState(() => _error = error);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    final canManageGlobal = _canManageGlobal;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(customerServiceProvider)
          .updateCustomer(
            widget.customerId!,
            UpdateCustomerRequest(
              name: _name.text,
              phone: _phone.text,
              address: _address.text,
              notes: _notes.text,
              organizationId: canManageGlobal
                  ? _organization?.organizationId
                  : null,
            ),
          );
      if (mounted) context.go(AppRoutes.customers);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      if (_loading) {
        return const Scaffold(body: Center(child: Text('Loading customer...')));
      }

      final customer = _customer;
      if (customer == null) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Customer', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
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
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      final canManageGlobal = ref
          .watch(permissionGateProvider)
          .has(Permission.manageCustomersGlobal);

      return FormCard(
        formKey: _formKey,
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
              value: _organization,
              onChanged: (organization) =>
                  setState(() => _organization = organization),
            ),
        ],
      );
    }

    final gate = ref.watch(permissionGateProvider);
    final canManageGlobal = gate.has(Permission.manageCustomersGlobal);
    final hasSelectedOrganization =
        ref.watch(selectedOrganizationProvider) != null;
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
        if (showOrganizationField)
          OrganizationSelectField(
            value: _organization,
            resolve: _CustomerFormScreenState._defaultOrganization,
            onChanged: (organization) =>
                setState(() => _organization = organization),
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}

/// Create wrapper for router/tests.
class CreateCustomerScreen extends StatelessWidget {
  const CreateCustomerScreen({super.key});

  @override
  Widget build(BuildContext context) => const CustomerFormScreen();
}

/// Edit wrapper for router/tests.
class EditCustomerScreen extends StatelessWidget {
  const EditCustomerScreen({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context) =>
      CustomerFormScreen(customerId: customerId);
}
