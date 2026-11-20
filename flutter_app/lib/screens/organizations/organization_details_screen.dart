import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';

/// Read-only organization details.
class OrganizationDetailsScreen extends ConsumerStatefulWidget {
  const OrganizationDetailsScreen({super.key, required this.organizationId});

  final int organizationId;

  @override
  ConsumerState<OrganizationDetailsScreen> createState() =>
      _OrganizationDetailsScreenState();
}

class _OrganizationDetailsScreenState
    extends ConsumerState<OrganizationDetailsScreen> {
  OrganizationResponse? _organization;
  ApiException? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final organization = await ref
          .read(organizationServiceProvider)
          .getOrganization(widget.organizationId);
      if (!mounted) return;
      setState(() {
        _organization = organization;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _isLoading = false;
      });
    }
  }

  bool _canEdit(PermissionGate gate, OrganizationResponse organization) {
    if (gate.has(Permission.manageOrganizationsGlobal)) return true;
    if (!gate.has(Permission.manageOrganization)) return false;
    final userOrgId = ref
        .read(userContextProvider)
        ?.user
        .organization
        .organizationId;
    return userOrgId != null && userOrgId == organization.organizationId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final organization = _organization;
    if (organization == null) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? ErrorDisplay.fromException(_error!)
              : const Text('Organization not found.'),
        ),
      );
    }

    final gate = ref.watch(permissionGateProvider);
    final canEdit = _canEdit(gate, organization);
    final canViewOrganizationList = gate.hasAny([
      Permission.viewOrganizationsGlobal,
      Permission.manageOrganizationsGlobal,
    ]);

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
                  onPressed: () => context.go(
                    canViewOrganizationList
                        ? AppRoutes.organizations
                        : AppRoutes.profile,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    canViewOrganizationList
                        ? 'Back to Organizations'
                        : 'Back to Profile',
                  ),
                ),
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      AppRoutes.organizationEditPath(
                        organization.organizationId,
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
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
                    'Organization Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Name: ${organization.name}'),
                  Text('Time Zone: ${organization.timezone}'),
                  Text(
                    'Contact Information: ${organization.contactInformation}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
