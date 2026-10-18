// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../models/common.dart';
import '../../models/customer.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/service_providers.dart';
import '../../widgets/error_display.dart';
import '../../widgets/inventory_association_editor.dart';
import '../../widgets/other_events_panel.dart';
import '../../widgets/validators.dart';
import '../../widgets/picker_fields.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key, required this.eventId});

  final int eventId;

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _location = TextEditingController();
  final _description = TextEditingController();

  final _newCustomerName = TextEditingController();
  final _newCustomerPhone = TextEditingController();
  final _newCustomerAddress = TextEditingController();

  String _customerId = '';
  List<EventInventoryItem> _inventoryItems = [];
  bool _openInvitation = false;
  int _numberOfStaffNeeded = 0;
  List<int> _selectedUserIds = [];
  String _selectedOrganizationId = '';
  List<OrganizationResponse> _availableOrganizations = [];
  List<CustomerResponse> _availableCustomers = [];
  List<UserResponse> _availableUsers = [];

  bool _loading = true;
  bool _submitting = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _time.dispose();
    _duration.dispose();
    _location.dispose();
    _description.dispose();
    _newCustomerName.dispose();
    _newCustomerPhone.dispose();
    _newCustomerAddress.dispose();
    super.dispose();
  }

  bool get _canManageGlobalEvents =>
      ref.read(permissionGateProvider).has(Permission.manageEventsGlobal);

  Future<void> _load() async {
    try {
      final event = await ref
          .read(eventServiceProvider)
          .getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _title.text = event.title;
        _date.text = event.date;
        _time.text = event.time;
        _duration.text =
            '${event.durationMinutes == 0 ? 60 : event.durationMinutes}';
        _location.text = event.location ?? '';
        _description.text = event.description ?? '';
        _inventoryItems = List.of(event.inventoryItems);
        _customerId = event.customer?.customerId.toString() ?? '';
        _openInvitation = event.openInvitation;
        _numberOfStaffNeeded = event.numberOfStaffNeeded;
        _selectedUserIds = event.rsvps.map((r) => r.userId).toList();
        _selectedOrganizationId = event.organization.organizationId.toString();
      });
      // Fetch orgs for global managers.
      if (_canManageGlobalEvents) {
        try {
          final orgs = await ref
              .read(organizationServiceProvider)
              .getAllOrganizations(const ListQuery(limit: 1000));
          if (mounted) setState(() => _availableOrganizations = orgs.items);
        } catch (_) {}
      }
      await _fetchCustomersAndUsers(_selectedOrganizationId);
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      // ignore: avoid_print
      print('EDIT LOAD ERROR: ${e.message}');
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchCustomersAndUsers(String orgIdStr) async {
    final orgId = int.tryParse(orgIdStr);
    if (orgId == null) return;
    try {
      final results = await Future.wait([
        ref
            .read(customerServiceProvider)
            .getAllCustomers(
              ListQuery(
                limit: 1000,
                organizationId: orgId,
                sortBy: 'name',
                sortOrder: SortOrder.asc,
              ),
            ),
        ref
            .read(userServiceProvider)
            .getAllUsers(
              ListQuery(
                limit: 1000,
                organizationId: orgId,
                sortBy: 'displayName',
                sortOrder: SortOrder.asc,
              ),
            ),
      ]);
      if (mounted) {
        setState(() {
          _availableCustomers =
              (results[0] as PaginatedResponse<CustomerResponse>).items;
          _availableUsers =
              (results[1] as PaginatedResponse<UserResponse>).items;
        });
      }
    } catch (_) {}
  }

  void _handleCustomerChange(String id) {
    setState(() => _customerId = id);
    final customer = _availableCustomers
        .where((c) => c.customerId.toString() == id)
        .firstOrNull;
    if (customer != null && _location.text.isEmpty) {
      _location.text = customer.address;
    }
  }

  Future<void> _handleCreateCustomer() async {
    if (_newCustomerName.text.trim().isEmpty) return;
    final orgId = int.tryParse(_selectedOrganizationId);
    if (orgId == null) return;
    try {
      final created = await ref
          .read(customerServiceProvider)
          .createCustomer(
            CreateCustomerRequest(
              name: _newCustomerName.text,
              phone: _newCustomerPhone.text,
              address: _newCustomerAddress.text,
              notes: '',
              organizationId: orgId,
            ),
          );
      if (!mounted) return;
      setState(() {
        _availableCustomers = [..._availableCustomers, created];
        _customerId = created.customerId.toString();
      });
      if (_location.text.isEmpty) {
        _location.text = created.address;
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final orgId = int.tryParse(_selectedOrganizationId);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = UpdateEventRequest(
        title: _title.text,
        date: _date.text,
        time: _time.text,
        durationMinutes: int.tryParse(_duration.text),
        location: _location.text.isEmpty ? null : _location.text,
        description: _description.text.isEmpty ? null : _description.text,
        inventoryItems: _inventoryItems,
        customerId: _customerId.isEmpty ? null : int.tryParse(_customerId),
        staffInvites: StaffInviteDetails(
          openInvitation: _openInvitation,
          numberOfStaffNeeded: _numberOfStaffNeeded,
          specificStaffIds: _selectedUserIds,
        ),
        // `EditEventForm.tsx:162` sends the organization **only** for a global
        // manager, and sends `undefined` otherwise. Not a stylistic choice:
        // `EventService.kt:83-89` throws
        // `"Non-MANAGE_EVENTS_GLOBAL users cannot change event organizationId"`
        // when a non-null, differing id arrives from an org-scoped user, and
        // treats null as "leave it alone". Sending the event's own org back
        // happens to be harmless today because that is where the value is
        // seeded from, which is exactly why it is worth not relying on.
        //
        // **No guard on `orgId` being null**, where the create form has one.
        // Here the value is either the loaded event's organization or the
        // dropdown's, and the dropdown is `required` — so a null cannot survive
        // `validate()`. The original has no equivalent check either.
        organizationId: _canManageGlobalEvents ? orgId : null,
      );
      await ref.read(eventServiceProvider).updateEvent(widget.eventId, request);
      if (mounted) context.go('/events/${widget.eventId}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openInventoryModal() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Inventory'),
        content: SizedBox(
          width: 480,
          child: InventoryAssociationEditor(
            initialInventoryItems: _inventoryItems,
            onInventoryItemsChange: (items) =>
                setState(() => _inventoryItems = items),
            organizationId: _selectedOrganizationId,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStaffModal() async {
    final neededController = TextEditingController(
      text: '$_numberOfStaffNeeded',
    );
    bool open = _openInvitation;
    final selected = List<int>.of(_selectedUserIds);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Event Staffing'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NumberField(
                    controller: neededController,
                    label: 'Number of Staff Needed',
                    onChanged: (v) {},
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: open,
                    title: const Text('Open invitation to all staff'),
                    onChanged: (v) => setModalState(() => open = v ?? false),
                  ),
                  const Divider(),
                  Text(
                    'Invite Specific Staff',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView(
                      children: [
                        for (final user in _availableUsers)
                          CheckboxListTile(
                            value: selected.contains(user.userId),
                            title: Text(user.displayName),
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  selected.add(user.userId);
                                } else {
                                  selected.remove(user.userId);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                setState(() {
                  _numberOfStaffNeeded =
                      int.tryParse(neededController.text) ?? 0;
                  _openInvitation = open;
                  _selectedUserIds = List.of(selected);
                });
                neededController.dispose();
                Navigator.of(ctx).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomerModal() async {
    _newCustomerName.clear();
    _newCustomerPhone.clear();
    _newCustomerAddress.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Customer'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newCustomerName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCustomerPhone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCustomerAddress,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _handleCreateCustomer();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create & Select'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _title.text.isEmpty) {
      return Scaffold(body: Center(child: Text(_error!.message)));
    }
    final theme = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final formColumn = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Event', style: theme.textTheme.titleLarge),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorDisplay.fromException(_error!),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Summary',
                    ),
                    validator: Validators.requiredText,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DateField(
                          controller: _date,
                          label: 'Date',
                          validator: Validators.requiredText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TimeField(
                          controller: _time,
                          label: 'Start Time',
                          validator: Validators.requiredText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NumberField(
                    controller: _duration,
                    label: 'Duration (min)',
                    validator: Validators.requiredNumber,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  if (_canManageGlobalEvents) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedOrganizationId.isEmpty
                          ? null
                          : _selectedOrganizationId,
                      decoration: const InputDecoration(
                        labelText: 'Organization',
                      ),
                      items: [
                        for (final org in _availableOrganizations)
                          DropdownMenuItem<String>(
                            value: org.organizationId.toString(),
                            child: Text(org.name),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedOrganizationId = v);
                        _fetchCustomersAndUsers(v);
                      },
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Customer', style: theme.textTheme.titleSmall),
                      TextButton(
                        onPressed: _openCustomerModal,
                        child: const Text('+ New Customer'),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: _customerId.isEmpty ? null : _customerId,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('No Customer Selected'),
                      ),
                      for (final c in _availableCustomers)
                        DropdownMenuItem<String>(
                          value: c.customerId.toString(),
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (v) => _handleCustomerChange(v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _location,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Full Description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Inventory',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    OutlinedButton(
                                      onPressed: _openInventoryModal,
                                      child: const Text('Manage'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_inventoryItems.isEmpty)
                                  Text(
                                    'No items added',
                                    style: theme.textTheme.bodySmall,
                                  )
                                else
                                  for (final item in _inventoryItems)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Chip(label: Text('${item.quantity}')),
                                          const SizedBox(width: 8),
                                          Text(item.itemName),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Staffing',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    OutlinedButton(
                                      onPressed: _openStaffModal,
                                      child: const Text('Manage'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        '$_numberOfStaffNeeded total needed',
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        '${_selectedUserIds.length} invited',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_openInvitation) ...[
                                  const SizedBox(height: 4),
                                  const Chip(label: Text('Open Invitation')),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            context.go('/events/${widget.eventId}'),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final sidebar = OtherEventsPanel(
              date: _date.text,
              organizationId: _selectedOrganizationId,
              excludeEventId: '${widget.eventId}',
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: formColumn),
                  const SizedBox(width: 16),
                  Expanded(child: sidebar),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [formColumn, const SizedBox(height: 16), sidebar],
            );
          },
        ),
      ),
    );
  }
}
