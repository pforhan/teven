import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../widgets/form_card.dart';
import '../../widgets/validators.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserResponse? _userDetails;
  ApiException? _error;
  bool _isEditing = false;
  bool _isLoading = true;

  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _skillsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(userContextProvider)?.user.userId;
    if (userId == null) return;
    try {
      final details = await ref.read(userServiceProvider).getUser(userId);
      if (!mounted) return;
      setState(() {
        _userDetails = details;
        _isLoading = false;
      });
      _seedFields(details);
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

  void _seedFields(UserResponse details) {
    _emailController.text = details.email;
    final staff = details.staffDetails;
    if (staff != null) {
      _contactController.text = staff.contactInformation;
      _phoneController.text = staff.phoneNumber;
      _dobController.text = staff.dateOfBirth ?? '';
      _skillsController.text = staff.skills.join(', ');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final userId = ref.read(userContextProvider)?.user.userId;
    if (userId == null) return;
    try {
      final staff = _userDetails?.staffDetails;
      final request = UpdateUserRequest(
        email: _emailController.text.trim(),
        staffDetails: staff != null
            ? UpdateStaffDetails(
                contactInformation: _contactController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                dateOfBirth: _dobController.text.trim(),
                skills: _skillsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              )
            : null,
      );
      await ref.read(userServiceProvider).updateUser(userId, request);
      if (!mounted) return;
      setState(() => _isEditing = false);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ApiRequestException('An unknown error occurred'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(userContextProvider);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userDetails == null) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? Text(_error!.message)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final details = _userDetails!;

    if (_isEditing) {
      return FormCard(
        formKey: GlobalKey<FormState>(),
        title: 'Edit Profile',
        submitLabel: 'Save Changes',
        error: _error,
        submitting: false,
        onSubmit: _handleSave,
        onCancel: () => setState(() => _isEditing = false),
        fields: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          if (details.staffDetails != null) ...[
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact Information',
              ),
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(labelText: 'Date of Birth'),
            ),
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Skills (comma-separated)',
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
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
              Text('Profile', style: Theme.of(context).textTheme.titleLarge),
              if (_error != null) ...[
                const SizedBox(height: 16),
                // ignore simplified
              ],
              const SizedBox(height: 16),
              Text('Username: ${userContext?.user.username ?? ''}'),
              Text('Display Name: ${userContext?.user.displayName ?? ''}'),
              Text('Email: ${userContext?.user.email ?? ''}'),
              Text('Roles: ${details.roles.join(', ')}'),
              Text(
                'Organization: ${userContext?.user.organization.name ?? 'N/A'}',
              ),
              if (details.staffDetails != null) ...[
                Text(
                  'Contact Information: ${details.staffDetails!.contactInformation}',
                ),
                Text('Phone Number: ${details.staffDetails!.phoneNumber}'),
                Text(
                  'Date of Birth: ${details.staffDetails!.dateOfBirth ?? ''}',
                ),
                Text('Skills: ${details.staffDetails!.skills.join(', ')}'),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _isEditing = true),
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
