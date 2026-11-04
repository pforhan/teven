import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';

/// One user, in full.
///
/// The read-only counterpart to [EditUserScreen], reached from the user list's
/// The fields are the
/// **read-only rendering** of the same record the edit form edits — email, display
/// name, roles, organization — plus the staff block the profile screen renders,
/// so a reader and an editor are looking at the same data. It is deliberately not
/// "the edit form in read-only mode": a read path should not inherit a write
/// path's validators, and the staff block is precisely the part that will
/// eventually diverge from the edit form's fields.
class UserDetailsScreen extends ConsumerStatefulWidget {
  const UserDetailsScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  UserResponse? _user;
  ApiException? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ref.read(userServiceProvider).getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    // The edit route is gated on `MANAGE_USERS_GLOBAL` alone — task 5.12 left
    // that asymmetry open — so the affordance here carries the same single
    // permission, and an organization-scoped manager is never offered a button
    // that would bounce them to `/profile` on tap.
    final canEdit = gate.has(Permission.manageUsersGlobal);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _user;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? ErrorDisplay.fromException(_error!)
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.users),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Users'),
                ),
                if (canEdit) ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go(AppRoutes.userEditPath(widget.userId)),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'User Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Username: ${user.username}'),
                  Text('Display Name: ${user.displayName}'),
                  Text('Email: ${user.email}'),
                  Text('Roles: ${user.roles.join(', ')}'),
                  Text('Organization: ${user.organization.name}'),
                  if (user.staffDetails != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Contact Information: ${user.staffDetails!.contactInformation}',
                    ),
                    Text('Phone Number: ${user.staffDetails!.phoneNumber}'),
                    Text(
                      'Date of Birth: ${user.staffDetails!.dateOfBirth ?? ''}',
                    ),
                    Text('Skills: ${user.staffDetails!.skills.join(', ')}'),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
