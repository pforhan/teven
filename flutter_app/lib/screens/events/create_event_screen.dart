// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/services/list_query.dart';
import '../../core/util/local_date.dart';
import '../../models/customer.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';
import '../../widgets/inventory_association_editor.dart';
import '../../widgets/organization_picker.dart';
import '../../widgets/other_events_panel.dart';
import '../../widgets/validators.dart';
import '../../widgets/picker_fields.dart';

/// The create-event form.
///
/// The densest form in the app: ~20 state fields, an organization-required gate
/// for global managers, customer-address autofill with a
/// `locationManuallyEdited` latch, org-scoping cascades for customers and
/// users, and three nested modals (inventory, staffing, customer).
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _duration = TextEditingController(text: '120');
  final _location = TextEditingController();
  final _description = TextEditingController();

  // Quick customer modal.
  final _newCustomerName = TextEditingController();
  final _newCustomerPhone = TextEditingController();
  final _newCustomerAddress = TextEditingController();

  String _customerId = '';
  List<EventInventoryItem> _inventoryItems = [];
  bool _openInvitation = false;
  int _numberOfStaffNeeded = 0;
  List<int> _selectedUserIds = [];
  String _selectedOrganizationId = '';

  /// The day the "other events" panel is showing, mirrored out of [_date].
  ///
  /// **A second copy of [_date.text], and the reason is the controller's
  /// silence.** A `TextEditingController` notifies the field that owns it, not
  /// the widget that read it — so picking a date rebuilt the date field and
  /// left this screen, and the panel in its sidebar, showing the day the
  /// screen was opened on. The original keeps the date in state, so its panel
  /// follows the picker.
  ///
  /// The two are written together: the controller by `DateField`, this by
  /// [DateField.onChanged]. Only the panel reads this one.
  String _dateValue = '';
  bool _showMoreDetails = false;
  ApiException? _error;
  bool _locationManuallyEdited = false;
  bool _submitting = false;

  List<CustomerResponse> _availableCustomers = [];
  List<UserResponse> _availableUsers = [];

  bool _didInitParams = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(selectedOrganizationProvider, (prev, next) {
      _handleOrgChange(next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleOrgChange(ref.read(selectedOrganizationProvider));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitParams) return;
    _didInitParams = true;
    // Query params from the calendar's long-press.
    final params = GoRouterState.of(context).uri.queryParameters;
    final dateParam = params['date'];
    final startTimeParam = params['startTime'];
    final endTimeParam = params['endTime'];
    final timeParam = params['time'];
    if (dateParam != null) _date.text = dateParam;
    if (startTimeParam != null) _time.text = startTimeParam;
    if (dateParam != null && startTimeParam != null && endTimeParam != null) {
      final start = DateTime.tryParse('$dateParam $startTimeParam');
      final end = DateTime.tryParse('$dateParam $endTimeParam');
      if (start != null && end != null) {
        _duration.text = end.difference(start).inMinutes.toString();
      }
    } else if (timeParam != null) {
      _time.text = timeParam;
    }
    if (_date.text.isEmpty) {
      // **Local calendar day, not the UTC one.** `toIso8601String()` converts
      // to UTC before formatting, so at local midnight east of UTC it reports
      // *yesterday* — and the event would be created on the wrong day. The
      // helper that avoids this is [formatLocalDate]; see `local_date.dart`
      // for the full account of why the raw form is wrong here.
      _date.text = formatLocalDate(DateTime.now());
    }
    if (_time.text.isEmpty) {
      _time.text = '10:00:00';
    }
    if (_duration.text.isEmpty) {
      _duration.text = '120';
    }
    _dateValue = _date.text;
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

  void _handleOrgChange(OrganizationResponse? org) {
    final canManageGlobal = _canManageGlobalEvents;
    final userCtx = ref.read(userContextProvider);
    if (org != null) {
      _setOrgId(org.organizationId.toString());
    } else if (canManageGlobal) {
      _setOrgId('');
    } else if (userCtx?.user.organization != null) {
      _setOrgId(userCtx!.user.organization.organizationId.toString());
    }
  }

  void _setOrgId(String id) {
    if (_selectedOrganizationId == id) {
      // Still fetch if empty list? skip.
      if (id.isNotEmpty && _availableCustomers.isEmpty) {
        _fetchCustomers(id);
        _fetchUsers(id);
      }
      return;
    }
    setState(() {
      _selectedOrganizationId = id;
      _availableCustomers = [];
      _availableUsers = [];
      _customerId = '';
    });
    if (id.isNotEmpty) {
      _fetchCustomers(id);
      _fetchUsers(id);
    }
  }

  Future<void> _fetchCustomers(String orgIdStr) async {
    final orgId = int.tryParse(orgIdStr);
    if (orgId == null) return;
    try {
      final resp = await ref
          .read(customerServiceProvider)
          .getAllCustomers(
            ListQuery(
              limit: 1000,
              organizationId: orgId,
              sortBy: 'name',
              sortOrder: SortOrder.asc,
            ),
          );
      if (mounted) setState(() => _availableCustomers = resp.items);
    } catch (_) {}
  }

  Future<void> _fetchUsers(String orgIdStr) async {
    final orgId = int.tryParse(orgIdStr);
    if (orgId == null) return;
    try {
      final resp = await ref
          .read(userServiceProvider)
          .getAllUsers(
            ListQuery(
              limit: 1000,
              organizationId: orgId,
              sortBy: 'displayName',
              sortOrder: SortOrder.asc,
            ),
          );
      if (mounted) setState(() => _availableUsers = resp.items);
    } catch (_) {}
  }

  void _handleCustomerChange(String id) {
    setState(() => _customerId = id);
    final customer = _availableCustomers
        .where((c) => c.customerId.toString() == id)
        .firstOrNull;
    if (customer != null && !_locationManuallyEdited) {
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
        _newCustomerName.clear();
        _newCustomerPhone.clear();
        _newCustomerAddress.clear();
      });
      if (!_locationManuallyEdited) {
        _location.text = created.address;
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final orgId = int.tryParse(_selectedOrganizationId);
    if (orgId == null) {
      setState(
        () => _error = const ApiRequestException(
          'Organization must be selected.',
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = CreateEventRequest(
        title: _title.text,
        date: _date.text,
        time: _time.text,
        durationMinutes: int.tryParse(_duration.text) ?? 0,
        location: _location.text.isEmpty ? null : _location.text,
        description: _description.text.isEmpty ? null : _description.text,
        inventoryItems: _inventoryItems,
        customerId: _customerId.isEmpty ? null : int.tryParse(_customerId),
        staffInvites: StaffInviteDetails(
          openInvitation: _openInvitation,
          numberOfStaffNeeded: _numberOfStaffNeeded,
          specificStaffIds: _selectedUserIds,
        ),
        organizationId: orgId,
      );
      await ref.read(eventServiceProvider).createEvent(request);
      if (mounted) context.go(AppRoutes.events);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickOrg() async {
    await showOrganizationPicker(context);
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
    final theme = Theme.of(context);

    // Organization-required gate.
    if (_canManageGlobalEvents && _selectedOrganizationId.isEmpty) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 48,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Organization Required',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select an organization to proceed with creating an event.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _pickOrg,
                            child: const Text('Select Organization'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(AppRoutes.events),
                            child: const Text('Back to Events'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                  Text('Create New Event', style: theme.textTheme.titleLarge),
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
                          // **The panel follows the picker.** Without this the
                          // "other events" sidebar would keep listing the day
                          // the form was opened on.
                          onChanged: (picked) {
                            if (picked == null) return;
                            setState(
                              () => _dateValue = formatLocalDate(picked),
                            );
                          },
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
                  if (!_showMoreDetails) ...[
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
                              : const Text('Quick Save'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _showMoreDetails = true),
                          child: const Text('Add More Details...'),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    NumberField(
                      controller: _duration,
                      label: 'Duration (min)',
                      validator: Validators.requiredNumber,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // Customer
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
                      onChanged: (_) =>
                          setState(() => _locationManuallyEdited = true),
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
                    // Associations
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
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Chip(
                                              label: Text('${item.quantity}'),
                                            ),
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
                              : const Text('Create Event'),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go(AppRoutes.events),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );

            final sidebar = OtherEventsPanel(
              date: _dateValue,
              organizationId: _selectedOrganizationId,
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
      // Modals
      // Inventory modal
      // Use overlay via if flags with showDialog? We'll use showDialog imperatively.
    );
  }
}
