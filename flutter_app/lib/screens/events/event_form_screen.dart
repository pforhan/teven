import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/services/list_query.dart';
import '../../core/services/time_zone_service.dart';
import '../../core/util/local_date.dart';
import '../../models/common.dart';
import '../../models/customer.dart';
import '../../models/event.dart';
import '../../models/organization.dart';
import '../../models/permissions.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/organization_list.dart';
import '../../providers/service_providers.dart';
import '../../providers/time_zone_controller.dart';
import '../../routing/app_router.dart';
import '../../widgets/error_display.dart';
import '../../widgets/inventory_association_editor.dart';
import '../../widgets/organization_picker.dart';
import '../../widgets/other_events_panel.dart';
import '../../widgets/picker_fields.dart';
import '../../widgets/time_zone_field.dart';
import '../../widgets/validators.dart';

/// Unified create/edit event form.
///
/// Both routes use this screen. Differences are parameters and mode, not a
/// second implementation.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId});

  /// Null for create, non-null for edit.
  final int? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _duration = TextEditingController(text: '120');
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

  /// The zone the date and time are a wall clock in.
  String _eventZone = 'UTC';
  bool _didSetDefaultZone = false;

  /// Mirrored out of [_date] so the "other events" panel follows the picker.
  String _dateValue = '';
  bool _showMoreDetails = false;
  ApiException? _error;

  /// Location autofill latch: set by the user's own typing and by
  /// loading an event whose location is non-empty. Programmatic writes do not
  /// set it.
  bool _locationTakenOver = false;
  bool _submitting = false;
  bool _loading = false;

  List<CustomerResponse> _availableCustomers = [];
  List<UserResponse> _availableUsers = [];
  List<OrganizationResponse> _availableOrganizations = [];
  bool _didLoadOrganizations = false;

  bool _didInitParams = false;
  ProviderSubscription<OrganizationResponse?>? _orgSub;

  bool get _isCreate => widget.eventId == null;
  bool get _isEdit => widget.eventId != null;

  bool get _canManageGlobalEvents =>
      ref.read(permissionGateProvider).has(Permission.manageEventsGlobal);

  bool get _canViewOrganizationsGlobal =>
      ref.read(permissionGateProvider).has(Permission.viewOrganizationsGlobal);

  @override
  void initState() {
    super.initState();
    _showMoreDetails = _isEdit;
    if (_isCreate) {
      _orgSub = ref.listenManual(selectedOrganizationProvider, (prev, next) {
        _handleShellOrgChange(next);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleShellOrgChange(ref.read(selectedOrganizationProvider));
        unawaited(_loadOrganizationsIfNeeded());
      });
    } else {
      _loading = true;
      _loadEvent();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitParams) return;
    _didInitParams = true;
    if (_isCreate) {
      final params = GoRouterState.of(context).uri.queryParameters;
      final dateParam = params['date'];
      if (dateParam != null) _date.text = dateParam;
      if (_time.text.isEmpty) {
        _time.text = '10:00:00';
      }
      _dateValue = _date.text;
    }
  }

  @override
  void dispose() {
    _orgSub?.close();
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

  DateTime _parseTimeText(String text) {
    final parts = text.split(':');
    return DateTime(
      0,
      1,
      1,
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  String _formatStartsAt(String zone) {
    final service = ref.read(timeZoneServiceProvider);
    final date = DateTime.parse(_date.text);
    final time = _parseTimeText(_time.text);
    final instant = service.instantAt(
      zoneId: zone,
      localDate: date,
      localTime: time,
    );
    final offset = formatZoneOffset(service.offsetAt(zone, instant));
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '${_date.text}T$hh:$mm:$ss$offset';
  }

  void _handleShellOrgChange(OrganizationResponse? org) {
    if (!_isCreate) return;
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

  void _setOrgId(String id, {bool reload = true}) {
    if (_selectedOrganizationId == id) {
      if (reload && id.isNotEmpty && _availableCustomers.isEmpty) {
        unawaited(_fetchCustomers(id));
        unawaited(_fetchUsers(id));
      }
      return;
    }
    setState(() {
      _selectedOrganizationId = id;
      _availableCustomers = [];
      _availableUsers = [];
      _customerId = '';
    });
    if (reload && id.isNotEmpty) {
      unawaited(_fetchCustomers(id));
      unawaited(_fetchUsers(id));
    }
  }

  Future<void> _loadOrganizationsIfNeeded() async {
    if (_didLoadOrganizations ||
        !_canManageGlobalEvents ||
        !_canViewOrganizationsGlobal) {
      return;
    }
    _didLoadOrganizations = true;
    try {
      final orgs = await ref
          .read(organizationServiceProvider)
          .getAllOrganizations(const ListQuery(limit: 1000));
      if (!mounted) return;
      setState(() => _availableOrganizations = orgs.items);
    } catch (_) {
      // Best effort: organizationsIncluding keeps the current selection usable.
    }
  }

  Future<void> _loadEvent() async {
    try {
      final event = await ref
          .read(eventServiceProvider)
          .getEvent(widget.eventId!);
      if (!mounted) return;
      final wallClock = event.wallClockIn(event.timezone);
      final hh = wallClock.hour.toString().padLeft(2, '0');
      final mm = wallClock.minute.toString().padLeft(2, '0');
      final ss = wallClock.second.toString().padLeft(2, '0');
      final loadedLocation = event.location ?? '';
      setState(() {
        _title.text = event.title;
        _date.text = formatLocalDate(wallClock);
        _time.text = '$hh:$mm:$ss';
        _duration.text =
            '${event.durationMinutes == 0 ? 120 : event.durationMinutes}';
        _location.text = loadedLocation;
        _description.text = event.description ?? '';
        _inventoryItems = List.of(event.inventoryItems);
        _customerId = event.customer?.customerId.toString() ?? '';
        _openInvitation = event.openInvitation;
        _numberOfStaffNeeded = event.numberOfStaffNeeded;
        _selectedUserIds = event.rsvps.map((r) => r.userId).toList();
        _selectedOrganizationId = event.organization.organizationId.toString();
        _eventZone = event.timezone;
        _dateValue = _date.text;
        _locationTakenOver = loadedLocation.trim().isNotEmpty;
        if (event.customer != null) {
          _availableCustomers = [event.customer!];
        }
      });
      await _loadOrganizationsIfNeeded();
      await _fetchCustomersAndUsers(_selectedOrganizationId);
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
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
    if (customer != null && !_locationTakenOver) {
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
      if (!_locationTakenOver) {
        _location.text = created.address;
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final orgId = int.tryParse(_selectedOrganizationId);
    if (_isCreate && orgId == null) {
      setState(
        () => _error = const ApiRequestException(
          'Organization must be selected.',
        ),
      );
      return;
    }
    String startsAt;
    try {
      startsAt = _formatStartsAt(_eventZone);
    } on TimeZoneException catch (e) {
      setState(() => _error = ApiRequestException(e.message));
      return;
    } on FormatException catch (e) {
      setState(() => _error = ApiRequestException(e.message));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isCreate) {
        final request = CreateEventRequest(
          title: _title.text,
          startsAt: startsAt,
          timezone: _eventZone,
          durationMinutes: int.tryParse(_duration.text) ?? 120,
          location: _location.text.isEmpty ? null : _location.text,
          description: _description.text.isEmpty ? null : _description.text,
          inventoryItems: _inventoryItems,
          customerId: _customerId.isEmpty ? null : int.tryParse(_customerId),
          staffInvites: StaffInviteDetails(
            openInvitation: _openInvitation,
            numberOfStaffNeeded: _numberOfStaffNeeded,
            specificStaffIds: _selectedUserIds,
          ),
          organizationId: orgId!,
        );
        await ref.read(eventServiceProvider).createEvent(request);
        if (mounted) context.go(AppRoutes.events);
      } else {
        final request = UpdateEventRequest(
          title: _title.text,
          startsAt: startsAt,
          timezone: _eventZone,
          durationMinutes: int.tryParse(_duration.text) ?? 120,
          location: _location.text.isEmpty ? null : _location.text,
          description: _description.text.isEmpty ? null : _description.text,
          inventoryItems: _inventoryItems,
          customerId: _customerId.isEmpty ? null : int.tryParse(_customerId),
          staffInvites: StaffInviteDetails(
            openInvitation: _openInvitation,
            numberOfStaffNeeded: _numberOfStaffNeeded,
            specificStaffIds: _selectedUserIds,
          ),
          // Organization is sent only for a global manager; null means "leave
          // it alone" to the server.
          organizationId: _canManageGlobalEvents ? orgId : null,
        );
        await ref
            .read(eventServiceProvider)
            .updateEvent(widget.eventId!, request);
        if (mounted) context.go('/events/${widget.eventId}');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickOrg() async {
    await showOrganizationPicker(context);
  }

  OrganizationResponse? get _currentOrganizationSelection {
    final id = int.tryParse(_selectedOrganizationId);
    if (id == null) return null;
    for (final org in _availableOrganizations) {
      if (org.organizationId == id) return org;
    }
    final selected = ref.read(selectedOrganizationProvider);
    if (selected != null && selected.organizationId == id) return selected;
    final userOrg = ref.read(userContextProvider)?.user.organization;
    if (userOrg != null && userOrg.organizationId == id) return userOrg;
    if (id != 0) {
      return OrganizationResponse(
        organizationId: id,
        name: 'Organization $id',
        contactInformation: '',
        timezone: 'UTC',
      );
    }
    return null;
  }

  void _onOrganizationDropdownChanged(OrganizationResponse? org) {
    if (org == null) return;
    if (!_canManageGlobalEvents) return;
    if (_isCreate) {
      // Write through to the shell's global selection so the form, gate picker
      // and shell cannot disagree.
      unawaited(ref.read(organizationControllerProvider.notifier).select(org));
    } else {
      final id = org.organizationId.toString();
      setState(() {
        _selectedOrganizationId = id;
        _availableCustomers = [];
        _availableUsers = [];
        _customerId = '';
      });
      unawaited(_fetchCustomers(id));
      unawaited(_fetchUsers(id));
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

  Widget _buildOrganizationField(ThemeData theme) {
    // Always visible in the form body. Global managers can pick any org when
    // the org list is available to them; others see their own org and cannot
    // change it.
    final canPick = _canManageGlobalEvents && _canViewOrganizationsGlobal;
    final chosen = _currentOrganizationSelection;
    final items = organizationsIncluding(_availableOrganizations, chosen);

    if (_isEdit) {
      // Historically the edit form showed the dropdown only for global managers;
      // makes it visible for both but non-interactive for org-scoped callers.
      if (_canManageGlobalEvents) {
        return DropdownButtonFormField<OrganizationResponse>(
          // ignore: deprecated_member_use
          value: chosen,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Organization'),
          items: canPick
              ? [
                  for (final org in items)
                    DropdownMenuItem<OrganizationResponse>(
                      value: org,
                      child: Text(org.name, overflow: TextOverflow.ellipsis),
                    ),
                ]
              : (chosen == null
                    ? const <DropdownMenuItem<OrganizationResponse>>[]
                    : [
                        DropdownMenuItem<OrganizationResponse>(
                          value: chosen,
                          child: Text(
                            chosen.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
          onChanged: canPick ? _onOrganizationDropdownChanged : null,
          validator: Validators.requiredSelection,
        );
      }
      // Org-scoped: show their organization, not selectable.
      return DropdownButtonFormField<OrganizationResponse>(
        // ignore: deprecated_member_use
        value: chosen,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Organization'),
        items: chosen == null
            ? const []
            : [
                DropdownMenuItem<OrganizationResponse>(
                  value: chosen,
                  child: Text(chosen.name, overflow: TextOverflow.ellipsis),
                ),
              ],
        onChanged: null,
      );
    }

    // Create form: organization always visible once past gate.
    if (_canManageGlobalEvents) {
      return DropdownButtonFormField<OrganizationResponse>(
        // ignore: deprecated_member_use
        value: chosen,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Organization'),
        items: canPick
            ? [
                for (final org in items)
                  DropdownMenuItem<OrganizationResponse>(
                    value: org,
                    child: Text(org.name, overflow: TextOverflow.ellipsis),
                  ),
              ]
            : (chosen == null
                  ? const <DropdownMenuItem<OrganizationResponse>>[]
                  : [
                      DropdownMenuItem<OrganizationResponse>(
                        value: chosen,
                        child: Text(
                          chosen.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
        onChanged: canPick ? _onOrganizationDropdownChanged : null,
        validator: Validators.requiredSelection,
      );
    }

    return DropdownButtonFormField<OrganizationResponse>(
      // ignore: deprecated_member_use
      value: chosen,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Organization'),
      items: chosen == null
          ? const []
          : [
              DropdownMenuItem<OrganizationResponse>(
                value: chosen,
                child: Text(chosen.name, overflow: TextOverflow.ellipsis),
              ),
            ],
      onChanged: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isEdit && _error != null && _title.text.isEmpty) {
      return Scaffold(body: Center(child: Text(_error!.message)));
    }

    final theme = Theme.of(context);
    final zoneState = ref.watch(timeZoneControllerProvider);
    final resolvedZone = zoneState.asData?.value.effectiveZone;
    if (!_didSetDefaultZone && resolvedZone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didSetDefaultZone) return;
        if (_isCreate) {
          final service = ref.read(timeZoneServiceProvider);
          final todayInZone = service.wallClockAt(
            DateTime.now().toUtc(),
            resolvedZone,
          );
          setState(() {
            _eventZone = resolvedZone;
            _didSetDefaultZone = true;
            if (_date.text.isEmpty) {
              _date.text = formatLocalDate(todayInZone);
              _dateValue = _date.text;
            }
          });
        } else {
          setState(() => _didSetDefaultZone = true);
        }
      });
    } else if (_isEdit && !_didSetDefaultZone) {
      // No resolved zone needed for edit; mark as set to avoid repeated work.
      _didSetDefaultZone = true;
    }

    // Organization-required gate for create: stays in front of the form.
    if (_isCreate &&
        _canManageGlobalEvents &&
        _selectedOrganizationId.isEmpty) {
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
                  Text(
                    _isCreate ? 'Create New Event' : 'Edit Event',
                    style: theme.textTheme.titleLarge,
                  ),
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
                  DateField(
                    controller: _date,
                    label: 'Date',
                    validator: Validators.requiredText,
                    onChanged: (picked) {
                      if (picked == null) return;
                      setState(() => _dateValue = formatLocalDate(picked));
                    },
                  ),
                  const SizedBox(height: 16),
                  TimeZoneField(
                    zone: _eventZone,
                    onChanged: (zone) => setState(() => _eventZone = zone),
                  ),
                  const SizedBox(height: 16),
                  TimeField(
                    controller: _time,
                    label: 'Start Time',
                    validator: Validators.requiredText,
                  ),
                  const SizedBox(height: 16),
                  _buildOrganizationField(theme),
                  if (_isCreate && !_showMoreDetails) ...[
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
                    Builder(
                      builder: (context) {
                        final hasSelected =
                            _customerId.isNotEmpty &&
                            _availableCustomers.any(
                              (c) => c.customerId.toString() == _customerId,
                            );
                        return DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _customerId.isEmpty ? null : _customerId,
                          decoration: const InputDecoration(
                            labelText: 'Customer',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('No Customer Selected'),
                            ),
                            if (_customerId.isNotEmpty && !hasSelected)
                              DropdownMenuItem<String>(
                                value: _customerId,
                                child: const Text('Selected customer'),
                              ),
                            for (final c in _availableCustomers)
                              DropdownMenuItem<String>(
                                value: c.customerId.toString(),
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: (v) => _handleCustomerChange(v ?? ''),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _location,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Location'),
                      onChanged: (_) =>
                          setState(() => _locationTakenOver = true),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final inventoryCard = Card(
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
                        );
                        final staffingCard = Card(
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
                        );
                        if (constraints.maxWidth >= AppBreakpoints.tablet) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: inventoryCard),
                              const SizedBox(width: 12),
                              Expanded(child: staffingCard),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            inventoryCard,
                            const SizedBox(height: 12),
                            staffingCard,
                          ],
                        );
                      },
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
                              : Text(
                                  _isCreate ? 'Create Event' : 'Save Changes',
                                ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go(
                            _isCreate
                                ? AppRoutes.events
                                : '/events/${widget.eventId}',
                          ),
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
              excludeEventId: _isEdit ? '${widget.eventId}' : null,
              queryTimezone: _eventZone,
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

/// Create wrapper for router/tests.
class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context) => const EventFormScreen();
}

/// Edit wrapper for router/tests.
class EditEventScreen extends StatelessWidget {
  const EditEventScreen({super.key, required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context) => EventFormScreen(eventId: eventId);
}
