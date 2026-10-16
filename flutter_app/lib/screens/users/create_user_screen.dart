import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/role.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/validators.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  List<RoleResponse> _roles = [];
  final Set<String> _selectedRoles = {};

  OrganizationResponse? _selectedOrganization;
  ApiException? _error;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roles = await ref.read(roleServiceProvider).getAllRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
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
        _error = ApiRequestException('An unknown error occurred');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
      final selectedOrg = ref.read(selectedOrganizationProvider);
      final canManageGlobal = ref
          .read(permissionGateProvider)
          .has(Permission.manageUsersGlobal);
      final userContext = ref.read(userContextProvider);

      int? organizationId;
      if (selectedOrg != null) {
        organizationId = selectedOrg.organizationId;
      } else if (canManageGlobal) {
        organizationId = _selectedOrganization?.organizationId;
      } else {
        organizationId = userContext?.user.organization.organizationId;
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

      final request = CreateUserRequest(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim(),
        roles: _selectedRoles.toList(),
        organizationId: organizationId,
      );

      await ref.read(userServiceProvider).createUser(request);
      if (!mounted) return;
      context.go(AppRoutes.users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiRequestException('An unknown error occurred'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOrg = ref.watch(selectedOrganizationProvider);
    final canManageGlobal = ref
        .watch(permissionGateProvider)
        .has(Permission.manageUsersGlobal);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget rolesField = Wrap(
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
      title: 'Create New User',
      submitLabel: 'Create User',
      submitting: _isSubmitting,
      error: _error,
      onSubmit: _handleSubmit,
      onCancel: () => context.go(AppRoutes.users),
      fields: [
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'Username'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          validator: Validators.requiredText,
        ),
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
