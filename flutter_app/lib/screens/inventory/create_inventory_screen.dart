import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/inventory.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

/// Task 5.3. Port of `CreateInventoryForm.tsx`.
///
/// The React original handles organization selection by checking `canManageGlobalInventory`.
/// If the user is a global manager and no organization is currently selected in the
/// shell, they can pick one from a dropdown. Otherwise, it defaults to the selected
/// organization or the user's own organization.
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final selectedOrg = ref.read(selectedOrganizationProvider);
      final canManageGlobal = ref
          .read(permissionGateProvider)
          .has(Permission.manageInventoryOrganization);
      final userContext = ref.read(userContextProvider);

      int? organizationId;
      if (selectedOrg != null) {
        organizationId = selectedOrg.organizationId;
      } else if (canManageGlobal) {
        organizationId = _selectedOrganization?.organizationId;
      } else {
        organizationId = userContext == null
            ? null
            : userContext.user.organization.organizationId;
      }

      if (organizationId == null) {
        setState(
          () => _error = const ApiRequestException(
            'Organization must be selected.',
          ),
        );
        _isSubmitting = false;
        return;
      }

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
      setState(() => _error = ApiRequestException('An unknown error occurred'));
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
        .has(Permission.manageInventoryOrganization);

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
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(labelText: 'Quantity'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (Validators.required(value) != null) {
              return Validators.required(value);
            }
            if (int.tryParse(value ?? '') == null) return 'Must be a number';
            return null;
          },
        ),
        if (selectedOrg == null && canManageGlobal)
          OrganizationSelectField(
            value: _selectedOrganization,
            resolve: (loaded, chosen) {
              if (chosen == null && loaded.isNotEmpty) {
                return loaded[0];
              }
              return chosen;
            },
            onChanged: (org) {
              setState(() => _selectedOrganization = org);
            },
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}
