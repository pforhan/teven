import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../widgets/form_card.dart';
import '../../widgets/picker_fields.dart';
import '../../widgets/time_zone_field.dart';
import '../../widgets/time_zone_fix_dialog.dart';
import '../../widgets/validators.dart';
import '../../providers/time_zone_fix.dart';

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
  bool _isSaving = false;
  bool _includeStaffDetails = false;
  String? _draftOverrideZone;
  bool _draftOverrideInitialized = false;

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
        _error = const ApiRequestException('An unknown error occurred');
        _isLoading = false;
      });
    }
  }

  void _seedFields(UserResponse details) {
    _emailController.text = details.email;
    final staff = details.staffDetails;
    _includeStaffDetails = staff != null;
    if (staff != null) {
      _contactController.text = staff.contactInformation;
      _phoneController.text = staff.phoneNumber;
      _dobController.text = staff.dateOfBirth ?? '';
      _skillsController.text = staff.skills.join('\n');
    } else {
      _contactController.clear();
      _phoneController.clear();
      _dobController.clear();
      _skillsController.clear();
    }
  }

  void _beginEdit() {
    final resolution = ref.read(timeZoneControllerProvider).value;
    setState(() {
      _isEditing = true;
      _error = null;
      _draftOverrideZone = resolution?.overrideZone;
      _draftOverrideInitialized = true;
    });
  }

  void _cancelEdit() {
    final details = _userDetails;
    if (details != null) _seedFields(details);
    setState(() {
      _isEditing = false;
      _error = null;
      _draftOverrideZone = null;
      _draftOverrideInitialized = false;
    });
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
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final request = UpdateUserRequest(
        email: _emailController.text.trim(),
        staffDetails: _includeStaffDetails
            ? UpdateStaffDetails(
                contactInformation: _contactController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                dateOfBirth: _dobController.text.trim(),
                skills: _skillsController.text
                    .split(RegExp(r'\r?\n'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
              )
            : null,
      );
      await ref.read(userServiceProvider).updateUser(userId, request);
      await ref
          .read(timeZoneControllerProvider.notifier)
          .setOverride(_draftOverrideZone);
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _draftOverrideZone = null;
        _draftOverrideInitialized = false;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _isSaving = false;
      });
    }
  }

  Widget _timeZoneReadSection() {
    final resolution = ref.watch(timeZoneControllerProvider).value;
    final effectiveZone = resolution?.effectiveZone ?? 'UTC';
    final theme = Theme.of(context);
    final issues = resolution == null
        ? const <String>[]
        : timeZoneIssuesFor(resolution);
    final hasFixes =
        resolution != null &&
        availableTimeZoneFixOptions(resolution).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Time zone',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(effectiveZone, style: theme.textTheme.titleMedium),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(issue, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
        if (hasFixes) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  showTimeZoneFixDialog(context, resolution: resolution),
              icon: const Icon(Icons.tune),
              label: const Text('Resolve'),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _timeZoneEditSection() {
    final resolution = ref.watch(timeZoneControllerProvider).value;
    final detected = resolution?.detectedZone;
    final organization = resolution?.organizationZone;
    final automaticZone = detected ?? organization ?? 'UTC';
    final effectiveDraftZone = _draftOverrideZone ?? automaticZone;
    final draftResolution = TimeZoneResolution(
      detectedZone: detected,
      overrideZone: _draftOverrideZone,
      organizationZone: organization,
      effectiveZone: effectiveDraftZone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Time zone', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TimeZoneField(
          zone: effectiveDraftZone,
          defaultZone: organization,
          onChanged: (newZone) => setState(() => _draftOverrideZone = newZone),
        ),
        const SizedBox(height: 12),
        TimeZoneFixContent(
          resolution: draftResolution,
          popOnApply: false,
          onApply: (targetZone) async {
            setState(() => _draftOverrideZone = targetZone);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(userContextProvider);
    ref.listen<AsyncValue<TimeZoneResolution>>(timeZoneControllerProvider, (
      prev,
      next,
    ) {
      if (!_isEditing) return;
      final nextOverride = next.value?.overrideZone;
      final prevOverride = prev?.value?.overrideZone;
      if (nextOverride != prevOverride) {
        setState(() {
          _draftOverrideZone = nextOverride;
        });
      }
    });

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
      if (!_draftOverrideInitialized) {
        final resolution = ref.watch(timeZoneControllerProvider).value;
        _draftOverrideZone = resolution?.overrideZone;
        _draftOverrideInitialized = true;
      }
      return FormCard(
        formKey: GlobalKey<FormState>(),
        title: 'Edit Profile',
        submitLabel: 'Save Changes',
        error: _error,
        submitting: _isSaving,
        onSubmit: _handleSave,
        onCancel: _cancelEdit,
        fields: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          _timeZoneEditSection(),
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
            Text(
              'Staff details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
            DateField(
              controller: _dobController,
              label: 'Date of Birth',
              // **Past only, and stated here rather than left to the field's
              // default.** A date of birth is a date that has already
              // happened; picking a future one is not a birth date. The
              // shared `DateField` no longer caps at today — the event
              // forms need to schedule forward — so the constraint that
              // belongs to this field alone is expressed at this call site.
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
              Text('Role: ${details.roles.join(', ')}'),
              Text(
                'Organization: ${userContext?.user.organization.name ?? 'N/A'}',
              ),
              const SizedBox(height: 16),
              _timeZoneReadSection(),
              if (details.staffDetails != null) ...[
                Text(
                  'Contact Information: ${details.staffDetails!.contactInformation}',
                ),
                Text('Phone Number: ${details.staffDetails!.phoneNumber}'),
                Text(
                  'Date of Birth: ${details.staffDetails!.dateOfBirth ?? ''}',
                ),
                Text(
                  details.staffDetails!.skills.isEmpty
                      ? 'Skills:'
                      : 'Skills:\n${details.staffDetails!.skills.join('\n')}',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _beginEdit,
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
