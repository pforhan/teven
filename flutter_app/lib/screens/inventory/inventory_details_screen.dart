import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' show TZDateTime;

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/util/local_date.dart';
import '../../models/event.dart';
import '../../models/inventory.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';
import '../../widgets/record_link_button.dart';

/// One inventory item, in full sweep.
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
  List<EventResponse>? _upcomingEvents;
  ApiException? _error;
  ApiException? _eventsError;
  bool _isLoading = true;
  bool _isLoadingEvents = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _item = null;
      _upcomingEvents = null;
      _eventsError = null;
      _isLoadingEvents = true;
    });
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
      await _loadUpcomingEvents();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
        _isLoadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = const ApiRequestException('An unknown error occurred');
        _isLoading = false;
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _loadUpcomingEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });
    try {
      final tz = await ref.read(timeZoneControllerProvider.future);
      final zone = tz.effectiveZone;
      final today = formatLocalDate(TZDateTime.now(zoneLocation(zone)));
      final page = await ref
          .read(eventServiceProvider)
          .getAllEvents(
            ListQuery(
              inventoryId: widget.inventoryId,
              startDate: today,
              timezone: zone,
              limit: 25,
              sortBy: 'startsAt',
              sortOrder: SortOrder.asc,
            ),
          );
      if (!mounted) return;
      setState(() {
        _upcomingEvents = page.items;
        _isLoadingEvents = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _eventsError = error;
        _isLoadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eventsError = const ApiRequestException('An unknown error occurred');
        _isLoadingEvents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(permissionGateProvider);
    final canEdit = gate.has(Permission.manageInventoryOrganization);
    final tz = ref.watch(timeZoneControllerProvider);
    final readerZone = tz.value?.effectiveZone ?? 'UTC';

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final item = _item;
    if (item == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inventory Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                ErrorDisplay.fromException(_error!)
              else
                const Text('Inventory item not found.'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.inventory),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Today and upcoming events',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go(
                            AppRoutes.eventListPath(
                              inventoryId: widget.inventoryId,
                            ),
                          ),
                          child: const Text('View all events'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingEvents)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_eventsError != null)
                      ErrorDisplay.fromException(_eventsError!)
                    else if ((_upcomingEvents ?? const []).isEmpty)
                      const Text('No upcoming events.')
                    else
                      ...?_upcomingEvents?.map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: RecordLinkButton(
                            label: event.title,
                            onPressed: () => context.go(
                              AppRoutes.eventDetailsPath(event.eventId),
                            ),
                          ),
                          subtitle: Text(
                            '${event.dateIn(readerZone)} ${event.timeIn(readerZone)}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
