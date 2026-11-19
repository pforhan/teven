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
import '../../widgets/create_form_organization.dart';
import '../../widgets/error_display.dart';
import '../../widgets/form_card.dart';
import '../../widgets/organization_select_field.dart';
import '../../widgets/picker_fields.dart';
import '../../widgets/validators.dart';

/// Unified create/edit user form.
///
/// Create and edit share role selection and organization handling but differ in
/// fields and lifecycle: create includes username/password and loads roles;
/// edit loads an existing user and roles, preselects roles/organization, and
/// omits create-only fields. Differences are expressed as mode branches while
/// keeping resource-specific rules explicit.
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.userId});

  /// Null for create, non-null for edit.
  final int? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _skillsController = TextEditingController();

  List<RoleResponse> _roles = [];
  final Set<String> _selectedRoles = {};

  UserResponse? _item;
  OrganizationResponse? _selectedOrganization;
  bool _includeStaffDetails = false;

  bool _loading = true;
  bool _submitting = false;
  ApiException? _error;

  bool get _isCreate => widget.userId == null;
  bool get _isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (_isCreate) {
        final roles = await ref.read(roleServiceProvider).getAllRoles();
        if (!mounted) return;
        setState(() {
          _roles = roles;
          _loading = false;
        });
      } else {
        final results = await Future.wait([
          ref.read(userServiceProvider).getUser(widget.userId!),
          ref.read(roleServiceProvider).getAllRoles(),
        ]);
        final user = results[0] as UserResponse;
        final roles = results[1] as List<RoleResponse>;
        if (!mounted) return;
        setState(() {
          _item = user;
          _emailController.text = user.email;
          _displayNameController.text = user.displayName;
          _selectedRoles
            ..clear()
            ..addAll(user.roles);
          _roles = roles;
          _selectedOrganization = user.organization;
          final staff = user.staffDetails;
          _includeStaffDetails = staff != null;
          if (staff != null) {
            _contactController.text = staff.contactInformation;
            _phoneController.text = staff.phoneNumber;
            _dobController.text = staff.dateOfBirth ?? '';
            _skillsController.text = staff.skills.join('\n');
          }
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _loading = false;
      });
    }
  }

  UpdateStaffDetails _buildStaffDetails() => UpdateStaffDetails(
    contactInformation: _contactController.text.trim(),
    phoneNumber: _phoneController.text.trim(),
    dateOfBirth: _dobController.text.trim(),
    skills: _skillsController.text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
  );

  List<Widget> _staffDetailsFields() => [
    if (!_includeStaffDetails)
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _includeStaffDetails = true),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Add staff details'),
        ),
      )
    else ...[
      Text('Staff details', style: Theme.of(context).textTheme.titleMedium),
      TextFormField(
        controller: _contactController,
        decoration: const InputDecoration(labelText: 'Contact Information'),
      ),
      TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(labelText: 'Phone Number'),
      ),
      DateField(
        controller: _dobController,
        label: 'Date of Birth',
        lastDate: DateTime.now(),
      ),
      TextFormField(
        controller: _skillsController,
        decoration: const InputDecoration(
          labelText: 'Skills (one per line)',
          hintText: 'e.g. animal care, mammals',
        ),
        minLines: 2,
        maxLines: 6,
      ),
    ],
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isCreate) {
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
          _submitting = false;
          return;
        }

        final request = CreateUserRequest(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          email: _emailController.text.trim(),
          displayName: _displayNameController.text.trim(),
          roles: _selectedRoles.toList(),
          organizationId: organizationId,
          staffDetails: _includeStaffDetails ? _buildStaffDetails() : null,
        );
        await ref.read(userServiceProvider).createUser(request);
      } else {
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
          staffDetails: _includeStaffDetails ? _buildStaffDetails() : null,
        );
        await ref.read(userServiceProvider).updateUser(widget.userId!, request);
      }

      if (mounted) context.go(AppRoutes.users);
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

  Widget _rolesField() => Wrap(
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isEdit) {
      final item = _item;
      if (item == null) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('User', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_error != null)
                  ErrorDisplay.fromException(_error!)
                else
                  const Text('Could not load user.'),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.users),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                          _item = null;
                          _roles = [];
                          _selectedRoles.clear();
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
          .has(Permission.manageUsersGlobal);

      return FormCard(
        formKey: _formKey,
        title: 'Edit User: ${item.displayName}',
        submitLabel: 'Update User',
        submitting: _submitting,
        error: _error,
        onSubmit: _submit,
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
          _rolesField(),
          ..._staffDetailsFields(),
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
        .has(Permission.manageUsersGlobal);

    return FormCard(
      formKey: _formKey,
      title: 'Create New User',
      submitLabel: 'Create User',
      submitting: _submitting,
      error: _error,
      onSubmit: _submit,
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
        _rolesField(),
        ..._staffDetailsFields(),
        if (CreateFormOrganizationPolicy.showGlobalOrganizationField(
          canManageGlobal: canManageGlobal,
          selectedOrganization: selectedOrg,
        ))
          OrganizationSelectField(
            value: _selectedOrganization,
            resolve: CreateFormOrganizationPolicy.defaultFirstOrganization,
            onChanged: (org) => setState(() => _selectedOrganization = org),
            validator: Validators.requiredSelection,
          ),
      ],
    );
  }
}

/// Create wrapper for router.
class CreateUserScreen extends StatelessWidget {
  const CreateUserScreen({super.key});

  @override
  Widget build(BuildContext context) => const UserFormScreen();
}

/// Edit wrapper for router.
class EditUserScreen extends StatelessWidget {
  const EditUserScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) => UserFormScreen(userId: userId);
}
