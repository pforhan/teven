import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../core/services/list_query.dart';
import '../models/invitation.dart';
import '../models/organization.dart';
import '../models/permissions.dart';
import '../models/role.dart';
import '../providers/auth_controller.dart';
import '../providers/service_providers.dart';
import '../screens/users/user_list_screen.dart' show invitationUrl;

/// Port of `CreateInvitationForm.tsx`.
class CreateInvitationForm extends ConsumerStatefulWidget {
  const CreateInvitationForm({
    super.key,
    required this.onInvitationCreated,
    required this.onCancel,
  });

  final ValueChanged<String> onInvitationCreated;
  final VoidCallback onCancel;

  @override
  ConsumerState<CreateInvitationForm> createState() =>
      _CreateInvitationFormState();
}

class _CreateInvitationFormState extends ConsumerState<CreateInvitationForm> {
  List<RoleResponse> _roles = [];
  List<OrganizationResponse> _organizations = [];
  int? _selectedRoleId;
  int? _selectedOrganizationId;
  final _noteController = TextEditingController();
  String? _invitationLink;
  String? _error;
  bool _loading = false;
  bool _fetching = true;

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
        _selectedRoleId = null;
      });

      final canManageGlobal = ref
          .read(permissionGateProvider)
          .has(Permission.manageInvitationsGlobal);
      if (canManageGlobal) {
        final response = await ref
            .read(organizationServiceProvider)
            .getAllOrganizations(const ListQuery(limit: 1000));
        if (!mounted) return;
        setState(() {
          _organizations = response.items;
          if (response.items.isNotEmpty) {
            _selectedOrganizationId = response.items.first.organizationId;
          }
        });
      } else {
        final orgId = ref
            .read(userContextProvider)
            ?.user
            .organization
            .organizationId;
        _selectedOrganizationId = orgId;
      }
      setState(() => _fetching = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch roles or organizations.';
        _fetching = false;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_selectedRoleId == null) {
      setState(() => _error = "Please select one role.");
      return;
    }

    final selectedRole = _roles
        .where((role) => role.roleId == _selectedRoleId)
        .firstOrNull;
    if (selectedRole?.roleName == "SuperAdmin") {
      setState(
        () => _error = "Invitations can only be created for Organizer or Staff roles. Use Create User instead.",
      );
      return;
    }
    final canManageGlobal = ref
        .read(permissionGateProvider)
        .has(Permission.manageInvitationsGlobal);
    int? organizationId;
    if (canManageGlobal) {
      organizationId = _selectedOrganizationId;
    } else {
      organizationId = ref
          .read(userContextProvider)
          ?.user
          .organization
          .organizationId;
    }
    if (organizationId == null) {
      setState(() => _error = 'Organization ID is not available.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _invitationLink = null;
    });

    try {
      final response = await ref
          .read(invitationServiceProvider)
          .createInvitation(
            CreateInvitationRequest(
              roleId: _selectedRoleId!,
              organizationId: organizationId,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          );
      final link = invitationUrl(response.token);
      setState(() => _invitationLink = link);
      widget.onInvitationCreated(link);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to create invitation.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canManageInvites = gate.hasAny([
      Permission.manageInvitationsOrganization,
      Permission.manageInvitationsGlobal,
    ]);
    if (!canManageInvites) {
      return const Text(
        'You do not have permission to create invitations.',
        style: TextStyle(color: Colors.red),
      );
    }

    final canManageGlobal = gate.has(Permission.manageInvitationsGlobal);

    if (_fetching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invitationLink != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invitation Link:'),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _invitationLink,
            readOnly: true,
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: widget.onCancel,
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        if (canManageGlobal) ...[
          const Text('Select Organization:'),
          DropdownButton<int>(
            value: _selectedOrganizationId,
            isExpanded: true,
            items: [
              for (final org in _organizations)
                DropdownMenuItem<int>(
                  value: org.organizationId,
                  child: Text(org.name),
                ),
            ],
            onChanged: _loading
                ? null
                : (value) => setState(() => _selectedOrganizationId = value),
          ),
          const SizedBox(height: 16),
        ],
        const Text('Select Role:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in _roles)
              ChoiceChip(
                label: Text(role.roleName),
                selected: _selectedRoleId == role.roleId,
                onSelected: _loading
                    ? null
                    : (selected) {
                        setState(() {
                          _selectedRoleId = selected ? role.roleId : null;
                        });
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Note (Optional)'),
          enabled: !_loading,
        ),
        const SizedBox(height: 16),
        if (_roles
                .where((role) => role.roleId == _selectedRoleId)
                .firstOrNull
                ?.roleName ==
            'SuperAdmin') ...[
          const Text(
            'Invitations can only be created for Organizer or Staff roles. Use Create User instead.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              const FilledButton(
                onPressed: null,
                child: Text('Create Invitation'),
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _handleCreate,
                child: Text(_loading ? 'Creating...' : 'Create Invitation'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
