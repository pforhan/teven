import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' show TZDateTime;

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/util/local_date.dart';
import '../../models/customer.dart';
import '../../models/event.dart';
import '../../models/permissions.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';
import '../../widgets/record_link_button.dart';

/// One customer, with today/upcoming events and a link to all events for the
/// customer.
class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  CustomerResponse? _customer;
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
      _customer = null;
      _upcomingEvents = null;
      _eventsError = null;
      _isLoadingEvents = true;
    });
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
              customerId: widget.customerId,
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

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final customer = _customer;
    if (customer == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Customer Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                ErrorDisplay.fromException(_error!)
              else
                const Text('Customer not found.'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.customers),
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

    final canEdit =
        (gate.has(Permission.manageCustomersOrganization) ||
            gate.has(Permission.manageCustomersGlobal)) &&
        customer.deletedAt == null;

    final tz = ref.watch(timeZoneControllerProvider);
    final readerZone = tz.value?.effectiveZone ?? 'UTC';

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
                    onPressed: () => context.go(AppRoutes.customers),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Customers'),
                  ),
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () => context.go(
                        AppRoutes.customerEditPath(widget.customerId),
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
                      'Customer Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (customer.deletedAt != null) ...[
                      Text(
                        'Status: Deactivated',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text('Name: ${customer.name}'),
                    Text('Phone: ${customer.phone}'),
                    Text('Address: ${customer.address}'),
                    Text('Notes: ${customer.notes}'),
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
                              customerId: widget.customerId,
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
