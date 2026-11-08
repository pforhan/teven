import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/organization.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/time_zone_field.dart';
import '../../widgets/validators.dart';

/// Create or edit an organization (task 7.23).
///
/// One screen for both: a null [organizationId] starts empty and creates; a
/// non-null id loads the organization and edits it. Create defaults the time
/// zone to the reader's effective zone (full weight — there is no organization
/// yet to mark as a default). Edit loads the organization's own zone and marks
/// that zone as the organization's default in the picker.
class OrganizationScreen extends ConsumerStatefulWidget {
  const OrganizationScreen({super.key, this.organizationId});

  final int? organizationId;

  bool get isCreate => organizationId == null;

  @override
  ConsumerState<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<OrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  ApiException? _error;
  bool _isSubmitting = false;
  bool _loading = false;
  OrganizationResponse? _item;
  String _timezone = 'UTC';
  bool _timezoneInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isCreate) {
      _loading = true;
      _loadItem();
    } else {
      _initCreateTimezone();
    }
  }

  Future<void> _initCreateTimezone() async {
    try {
      final resolution = await ref.read(timeZoneControllerProvider.future);
      if (!mounted || _timezoneInitialized) return;
      setState(() {
        _timezone = resolution.effectiveZone;
        _timezoneInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _timezoneInitialized = true);
    }
  }

  Future<void> _loadItem() async {
    try {
      final item = await ref
          .read(organizationServiceProvider)
          .getOrganization(widget.organizationId!);
      if (!mounted) return;
      setState(() {
        _item = item;
        _nameController.text = item.name;
        _contactController.text = item.contactInformation;
        _timezone = item.timezone;
        _timezoneInitialized = true;
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
          'An unknown error occurred while loading organization',
        );
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      if (widget.isCreate) {
        await ref
            .read(organizationServiceProvider)
            .createOrganization(
              CreateOrganizationRequest(
                name: _nameController.text.trim(),
                contactInformation: _contactController.text.trim(),
                timezone: _timezone,
              ),
            );
      } else {
        await ref
            .read(organizationServiceProvider)
            .updateOrganization(
              widget.organizationId!,
              UpdateOrganizationRequest(
                name: _nameController.text.trim(),
                contactInformation: _contactController.text.trim(),
                timezone: _timezone,
              ),
            );
      }
      if (!mounted) return;
      context.go(AppRoutes.organizations);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (_) {
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
    if (_loading) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? Text(_error!.message)
              : const CircularProgressIndicator(),
        ),
      );
    }

    if (!widget.isCreate && _item == null && _error != null) {
      return Scaffold(body: Center(child: Text(_error!.message)));
    }

    final title = widget.isCreate
        ? 'Create New Organization'
        : 'Edit Organization: ${_item?.name ?? ''}';
    final submitLabel = widget.isCreate
        ? 'Create Organization'
        : 'Update Organization';
    final defaultZone = widget.isCreate ? null : _item?.timezone;

    return FormCard(
      formKey: _formKey,
      title: title,
      submitLabel: submitLabel,
      submitting: _isSubmitting,
      error: _error,
      onSubmit: _handleSubmit,
      onCancel: () => context.go(AppRoutes.organizations),
      fields: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: Validators.requiredText,
        ),
        TextFormField(
          controller: _contactController,
          decoration: const InputDecoration(labelText: 'Contact Information'),
          validator: Validators.requiredText,
        ),
        TimeZoneField(
          zone: _timezone,
          defaultZone: defaultZone,
          onChanged: (zone) => setState(() {
            _timezone = zone;
            _timezoneInitialized = true;
          }),
        ),
      ],
    );
  }
}
