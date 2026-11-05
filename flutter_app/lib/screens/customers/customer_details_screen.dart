import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/customer.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';

/// One customer, in full — task 9.0's sweep.
///
/// The read-only counterpart to [EditCustomerScreen], reached from the customer
/// list's name links. Like the user details screen, the route had been declared
/// as a bare helper with no route behind it, so the list's name link fell through
/// the catch-all to `/events` — the customer could add and edit but never view,
/// which is the shape task 9.0 fixed for users and this sweep repeats for the
/// remaining CRUD screens.
///
/// Task 10.20 deferred this screen pending the backend's missing
/// `customerId` filter on `GET /api/events`; the field rendering below is the
/// half that was always wanted — a page that renders the record beats a link to
/// the calendar — and the customer's events ride along with the backend work.
class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  CustomerResponse? _customer;
  ApiException? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final customer = await ref
          .read(customerServiceProvider)
          .getCustomer(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = customer;
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
    final canEdit = gate.has(Permission.manageCustomersOrganization);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customer = _customer;
    if (customer == null) {
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
                  onPressed: () => context.go(AppRoutes.customers),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Customers'),
                ),
                if (canEdit) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      AppRoutes.customerEditPath(widget.customerId),
                    ),
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
                    'Customer Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Name: ${customer.name}'),
                  Text('Phone: ${customer.phone}'),
                  Text('Address: ${customer.address}'),
                  Text('Notes: ${customer.notes}'),
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
