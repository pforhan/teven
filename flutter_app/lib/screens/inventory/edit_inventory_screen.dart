import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/inventory.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

/// Task 5.3. Port of `EditInventoryForm.tsx`.
class EditInventoryScreen extends ConsumerStatefulWidget {
  final int inventoryId;

  const EditInventoryScreen({super.key, required this.inventoryId});

  @override
  ConsumerState<EditInventoryScreen> createState() =>
      _EditInventoryScreenState();
}

class _EditInventoryScreenState extends ConsumerState<EditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();

  OrganizationResponse? _selectedOrganization;
  ApiException? _error;
  bool _isSubmitting = false;
  InventoryItemResponse? _item;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    try {
      final item = await ref
          .read(inventoryServiceProvider)
          .getInventoryItem(widget.inventoryId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _nameController.text = item.name;
        _descriptionController.text = item.description;
        _quantityController.text = item.quantity.toString();
        _selectedOrganization = item.organization;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = ApiRequestException(
          'An unknown error occurred while loading item',
        ),
      );
    }
  }

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
      final canManageGlobal = ref
          .read(permissionGateProvider)
          .has(Permission.manageInventoryOrganization);

      int? organizationIdToUse;
      if (canManageGlobal) {
        organizationIdToUse = _selectedOrganization?.organizationId;
      }

      final request = UpdateInventoryItemRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 0,
        organizationId: organizationIdToUse,
      );

      await ref
          .read(inventoryServiceProvider)
          .updateInventoryItem(widget.inventoryId, request);
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
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageInventoryOrganization);

    if (_item == null) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? Text(_error!.message)
              : const CircularProgressIndicator(),
        ),
      );
    }

    return FormCard(
      formKey: _formKey,
      title: 'Edit Inventory Item: ${_item!.name}',
      submitLabel: 'Update Item',
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
        if (canManageGlobal)
          OrganizationSelectField(
            value: _selectedOrganization,
            onChanged: (org) {
              setState(() => _selectedOrganization = org);
            },
          ),
      ],
    );
  }
}
