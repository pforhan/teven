import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/role.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

class EditUserScreen extends ConsumerStatefulWidget {
  final int userId;

  const EditUserScreen({super.key, required this.userId});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  List<RoleResponse> _roles = [];
  final Set<String> _selectedRoles = {};

  OrganizationResponse? _selectedOrganization;
  ApiException? _error;
  bool _isSubmitting = false;
  UserResponse? _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ref.read(userServiceProvider).getUser(widget.userId),
        ref.read(roleServiceProvider).getAllRoles(),
      ]);
      final user = results[0] as UserResponse;
      final roles = results[1] as List<RoleResponse>;
      if (!mounted) return;
      setState(() {
        _item = user;
        _emailController.text = user.email;
        _displayNameController.text = user.displayName;
        _selectedRoles.addAll(user.roles);
        _roles = roles;
        _selectedOrganization = user.organization;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
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
          .has(Permission.manageUsersGlobal);

      int? organizationIdToUse;
      if (canManageGlobal) {
        organizationIdToUse = _selectedOrganization?.organizationId;
      }

      final request = UpdateUserRequest(
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim(),
        roles: _selectedRoles.toList(),
        organizationId: organizationIdToUse,
      );

      await ref.read(userServiceProvider).updateUser(widget.userId, request);
      if (!mounted) return;
      context.go(AppRoutes.users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = const ApiRequestException('An unknown error occurred'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageUsersGlobal);

    if (_isLoading) {
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

    final Widget rolesField = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final role in _roles)
          FilterChip(
            label: Text(role.roleName),
            selected: _selectedRoles.contains(role.roleName),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedRoles.add(role.roleName);
                } else {
                  _selectedRoles.remove(role.roleName);
                }
              });
            },
          ),
      ],
    );

    return FormCard(
      formKey: _formKey,
      title: 'Edit User: ${_item!.displayName}',
      submitLabel: 'Update User',
      submitting: _isSubmitting,
      error: _error,
      onSubmit: _handleSubmit,
      onCancel: () => context.go(AppRoutes.users),
      fields: [
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        TextFormField(
          controller: _displayNameController,
          decoration: const InputDecoration(labelText: 'Display Name'),
          validator: Validators.requiredText,
        ),
        rolesField,
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
