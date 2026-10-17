import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/organization.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/form_card.dart';
import '../../widgets/validators.dart';

class CreateOrganizationScreen extends ConsumerStatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  ConsumerState<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState
    extends ConsumerState<CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();

  ApiException? _error;
  bool _isSubmitting = false;

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
      await ref
          .read(organizationServiceProvider)
          .createOrganization(
            CreateOrganizationRequest(
              name: _nameController.text.trim(),
              contactInformation: _contactController.text.trim(),
            ),
          );
      if (!mounted) return;
      context.go(AppRoutes.organizations);
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
    return FormCard(
      formKey: _formKey,
      title: 'Create New Organization',
      submitLabel: 'Create Organization',
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
      ],
    );
  }
}
