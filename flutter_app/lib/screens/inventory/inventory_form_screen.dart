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

/// Unified create/edit inventory form.
///
/// The create and edit inventory screens share name/description/quantity fields
/// and form flow but differ in load, organization rules, submit request, and
/// post-submit/navigation behavior. Differences are expressed as mode/parameters.
///
/// Organization rules are preserved: create uses the shell's selected
/// organization first, otherwise a global manager's dropdown (shown only when
/// there is no selected organization), otherwise the caller's own organization.
/// Edit shows the dropdown only to a global manager and sends `organizationId`
/// on update only for that caller; the server refuses organization changes from
/// anyone else.
class InventoryFormScreen extends ConsumerStatefulWidget {
  const InventoryFormScreen({super.key, this.inventoryId});

  /// Null for create, non-null for edit.
  final int? inventoryId;

  @override
  ConsumerState<InventoryFormScreen> createState() =>
      _InventoryFormScreenState();
}

class _InventoryFormScreenState extends ConsumerState<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();

  InventoryItemResponse? _item;
  OrganizationResponse? _selectedOrganization;

  bool _loading = false;
  bool _submitting = false;
  ApiException? _error;

  bool get _isCreate => widget.inventoryId == null;
  bool get _isEdit => widget.inventoryId != null;

  bool get _canManageGlobal =>
      ref.read(permissionGateProvider).has(Permission.manageInventoryGlobal);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _loadItem();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    try {
      final item = await ref
          .read(inventoryServiceProvider)
          .getInventoryItem(widget.inventoryId!);
      if (!mounted) return;
      setState(() {
        _item = item;
        _nameController.text = item.name;
        _descriptionController.text = item.description;
        _quantityController.text = item.quantity.toString();
        _selectedOrganization = item.organization;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException(
          'An unknown error occurred while loading item',
        );
        _loading = false;
      });
    }
  }

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
        _selectedOrganization,
      )?.organizationId;
    }
    return ref.read(userContextProvider)?.user.organization.organizationId;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
        final request = CreateInventoryItemRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          quantity: int.tryParse(_quantityController.text) ?? 0,
          organizationId: organizationId,
        );
        await ref.read(inventoryServiceProvider).createInventoryItem(request);
        if (mounted) context.go(AppRoutes.inventory);
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e);
      } catch (_) {
        if (mounted) {
          setState(
            () =>
                _error = const ApiRequestException('An unknown error occurred'),
          );
        }
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
      final request = UpdateInventoryItemRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 0,
        organizationId: canManageGlobal
            ? _selectedOrganization?.organizationId
            : null,
      );
      await ref
          .read(inventoryServiceProvider)
          .updateInventoryItem(widget.inventoryId!, request);
      if (mounted) context.go(AppRoutes.inventory);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const ApiRequestException('An unknown error occurred'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      if (_loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (_item == null) {
        return Scaffold(
          body: Center(
            child: _error != null
                ? Text(_error!.message)
                : const CircularProgressIndicator(),
          ),
        );
      }

      final canManageGlobal = ref
          .watch(permissionGateProvider)
          .has(Permission.manageInventoryGlobal);

      return FormCard(
        formKey: _formKey,
        title: 'Edit Inventory Item: ${_item!.name}',
        submitLabel: 'Update Item',
        submitting: _submitting,
        error: _error,
        onSubmit: _submit,
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
          if (canManageGlobal)
            OrganizationSelectField(
              value: _selectedOrganization,
              onChanged: (org) => setState(() => _selectedOrganization = org),
            ),
        ],
      );
    }

    final selectedOrg = ref.watch(selectedOrganizationProvider);
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageInventoryGlobal);
    final showOrganizationField = canManageGlobal && selectedOrg == null;

    return FormCard(
      formKey: _formKey,
      title: 'Create New Inventory Item',
      submitLabel: 'Create Item',
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
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
            resolve: _InventoryFormScreenState._defaultOrganization,
            onChanged: (org) => setState(() => _selectedOrganization = org),
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}

/// Create wrapper for router.
class CreateInventoryScreen extends StatelessWidget {
  const CreateInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const InventoryFormScreen();
}

/// Edit wrapper for router.
class EditInventoryScreen extends StatelessWidget {
  const EditInventoryScreen({super.key, required this.inventoryId});

  final int inventoryId;

  @override
  Widget build(BuildContext context) =>
      InventoryFormScreen(inventoryId: inventoryId);
}
