import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../models/permissions.dart';
import '../../models/inventory.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';

/// One inventory item, in full — task 9.0's sweep.
///
/// The read-only counterpart to [EditInventoryScreen], reached from the
/// inventory list's name links. Like the customer details screen, the route had
/// been declared as a bare helper with no route behind it, so the list's name
/// link fell through the catch-all to `/events` — an organizer who could add
/// or edit an item could not view it.
class InventoryDetailsScreen extends ConsumerStatefulWidget {
  const InventoryDetailsScreen({super.key, required this.inventoryId});

  final int inventoryId;

  @override
  ConsumerState<InventoryDetailsScreen> createState() =>
      _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState
    extends ConsumerState<InventoryDetailsScreen> {
  InventoryItemResponse? _item;
  ApiException? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await ref
          .read(inventoryServiceProvider)
          .getInventoryItem(widget.inventoryId);
      if (!mounted) return;
      setState(() {
        _item = item;
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
    final canEdit = gate.has(Permission.manageInventoryOrganization);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final item = _item;
    if (item == null) {
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
                  onPressed: () => context.go(AppRoutes.inventory),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Inventory'),
                ),
                if (canEdit) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      AppRoutes.inventoryEditPath(widget.inventoryId),
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
                    'Inventory Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Name: ${item.name}'),
                  Text('Description: ${item.description}'),
                  Text('Quantity: ${item.quantity}'),
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
