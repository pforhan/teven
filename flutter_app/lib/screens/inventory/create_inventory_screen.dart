import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/inventory.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/organization_list.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/picker_fields.dart';
import '../../widgets/validators.dart';

/// The create-inventory form.
///
/// The organization resolution follows the same three-rule priority as the
/// customer create form: the shell's selected organization wins; otherwise a
/// global manager uses the dropdown; otherwise the caller's own organization,
/// which the server substitutes for anyone who lacks the global permission.
///
/// The dropdown is shown only when there is no selected organization and the
/// caller holds [Permission.manageInventoryGlobal] — so narrowing the chrome
/// to one organization never quietly creates the item somewhere else. The
/// server requires an organization id from a global manager
/// (`InventoryService`), so the null-organization guard stays even though the
/// form cannot reach it in practice.
class CreateInventoryScreen extends ConsumerStatefulWidget {
  const CreateInventoryScreen({super.key});

  @override
  ConsumerState<CreateInventoryScreen> createState() =>
      _CreateInventoryScreenState();
}

class _CreateInventoryScreenState extends ConsumerState<CreateInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();

  OrganizationResponse? _selectedOrganization;
  ApiException? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool get _canManageGlobal =>
      ref.read(permissionGateProvider).has(Permission.manageInventoryGlobal);

  /// The organization the item will be created in, for the request.
  ///
  /// [ref.read] rather than [ref.watch] because this runs from [_handleSubmit],
  /// not from `build`. The same three-rule priority as the customer create
  /// form: the shell's selected organization wins, then the global manager's
  /// dropdown, then the caller's own organization.
  int? get _organizationId {
    final selected = ref.read(selectedOrganizationProvider);
    if (selected != null) return selected.organizationId;
    if (_canManageGlobal) {
      return _defaultOrganization(
        ref.read(organizationsProvider),
        _selectedOrganization,
      )?.organizationId;
    }
    return ref.read(userContextProvider)?.user.organization.organizationId;
  }

  /// The dropdown's display value: what the user chose, or the first
  /// organization. Shared by the control and [_organizationId] so the
  /// selection the user sees is the one the request submits.
  static OrganizationResponse? _defaultOrganization(
    List<OrganizationResponse> organizations,
    OrganizationResponse? chosen,
  ) => chosen ?? (organizations.isEmpty ? null : organizations.first);

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final organizationId = _organizationId;
    if (organizationId == null) {
      setState(
        () => _error = const ApiRequestException(
          'Organization must be selected.',
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final request = CreateInventoryItemRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 0,
        organizationId: organizationId,
      );

      await ref.read(inventoryServiceProvider).createInventoryItem(request);
      if (!mounted) return;
      context.go(AppRoutes.inventory);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = const ApiRequestException('An unknown error occurred'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOrg = ref.watch(selectedOrganizationProvider);
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageInventoryGlobal);
    final showOrganizationField = canManageGlobal && selectedOrg == null;

    return FormCard(
      formKey: _formKey,
      title: 'Create New Inventory Item',
      submitLabel: 'Create Item',
      submitting: _isSubmitting,
      error: _error,
      onSubmit: _handleSubmit,
      onCancel: () => context.go(AppRoutes.inventory),
      fields: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: Validators.requiredText,
        ),
        NumberField(
          controller: _quantityController,
          label: 'Quantity',
          validator: Validators.requiredNumber,
        ),
        if (showOrganizationField)
          OrganizationSelectField(
            value: _selectedOrganization,
            resolve: _CreateInventoryScreenState._defaultOrganization,
            onChanged: (org) {
              setState(() => _selectedOrganization = org);
            },
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}
