import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/util/local_date.dart';
import '../../models/permissions.dart';
import '../../models/report.dart';
import '../../providers/auth_controller.dart';
import '../../providers/organization_controller.dart';
import '../../providers/service_providers.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';
import '../../widgets/organization_picker.dart';

/// Staff-hours and inventory-usage reports.
///
/// The report landing page: inventory usage loads when an organization is
/// available, and a staff-hours report is generated for an explicit range of
/// days.
///
/// The staff-hours window is a range of *days*, not a range of instants, so it
/// is interpreted in the reader's zone. The device zone is sent with the
/// request; if detection is unavailable the request falls back to UTC.
///
/// Both report APIs require an [organizationId]. Callers without
/// `VIEW_REPORTS_GLOBAL` may only request their own organization; global
/// callers must still name a specific organization. The UI requires an
/// effective organization before loading reports.
class ReportListScreen extends ConsumerStatefulWidget {
  const ReportListScreen({super.key});

  @override
  ConsumerState<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends ConsumerState<ReportListScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<StaffHoursReportResponse>? _staffHoursReport;
  List<InventoryUsageReportResponse>? _inventoryUsageReport;
  bool _loadingInventory = false;
  bool _loadingStaffHours = false;
  ApiException? _error;
  String? _staffHoursMessage;
  int? _loadedInventoryOrgId;

  Future<void> _fetchInventoryUsageReport(int organizationId) async {
    setState(() {
      _loadingInventory = true;
      _error = null;
      _loadedInventoryOrgId = organizationId;
    });
    try {
      final report = await ref
          .read(reportServiceProvider)
          .getInventoryUsageReport(organizationId: organizationId);
      if (!mounted) return;
      setState(() {
        _inventoryUsageReport = report;
        _loadingInventory = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingInventory = false;
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _fetchStaffHoursReport(int organizationId) async {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) {
      setState(() {
        _staffHoursMessage = 'Please select both start and end dates for the staff hours report.';
        _staffHoursReport = null;
      });
      return;
    }

    final timezone = ref.read(timeZoneDetectorProvider).asData?.value ?? 'UTC';

    setState(() {
      _loadingStaffHours = true;
      _error = null;
      _staffHoursMessage = null;
    });
    try {
      final report = await ref
          .read(reportServiceProvider)
          .getStaffHoursReport(
            organizationId: organizationId,
            startDate: formatLocalDate(start),
            endDate: formatLocalDate(end),
            timezone: timezone,
          );
      if (!mounted) return;
      setState(() {
        _staffHoursReport = report;
        _loadingStaffHours = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingStaffHours = false;
      });
    }
  }

  String _organizationLabel() {
    final selected = ref.watch(selectedOrganizationProvider);
    if (selected != null) return selected.name;
    return ref.watch(userContextProvider)?.user.organization.name ??
        'Unknown organization';
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final gate = ref.watch(permissionGateProvider);
    final selected = ref.watch(selectedOrganizationProvider);
    final userOrgId = ref
        .watch(userContextProvider)
        ?.user
        .organization
        .organizationId;
    final hasGlobal = gate.has(Permission.viewReportsGlobal);
    final effectiveOrgId = selected?.organizationId ?? userOrgId;
    final needsSelection = hasGlobal && selected == null;

    if (effectiveOrgId != null &&
        !needsSelection &&
        _loadedInventoryOrgId != effectiveOrgId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_loadedInventoryOrgId != effectiveOrgId) {
          setState(() {
            _staffHoursReport = null;
            _staffHoursMessage = null;
            _inventoryUsageReport = null;
          });
          _fetchInventoryUsageReport(effectiveOrgId);
        }
      });
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListScreenHeader(title: 'Reports'),
            const SizedBox(height: 8),
            Text(
              'Organization: ${needsSelection ? 'Select an organization to view reports.' : _organizationLabel()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasGlobal) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showOrganizationPicker(context),
                icon: const Icon(Icons.business),
                label: Text(
                  selected == null
                      ? 'Select Organization'
                      : 'Change Organization',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (error != null) ...[
              ErrorDisplay.fromException(error),
              const SizedBox(height: 16),
            ],
            if (needsSelection)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select an organization to access reports. Reports are scoped to one organization.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else ...[
              _buildStaffHoursCard(context, effectiveOrgId!),
              const SizedBox(height: 16),
              _buildInventoryUsageCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffHoursCard(BuildContext context, int organizationId) {
    final message = _staffHoursMessage;
    final report = _staffHoursReport;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Hours Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _DateField(
                  label: 'Start Date',
                  value: _startDate,
                  onPick: () => _pickDate(start: true),
                ),
                _DateField(
                  label: 'End Date',
                  value: _endDate,
                  onPick: () => _pickDate(start: false),
                ),
                FilledButton(
                  onPressed: _loadingStaffHours
                      ? null
                      : () => _fetchStaffHoursReport(organizationId),
                  child: _loadingStaffHours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate Staff Hours Report'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (message != null)
              Text(message, style: Theme.of(context).textTheme.bodyMedium)
            else if (report == null)
              Text(
                'Select a date range and generate the report.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (report.isEmpty)
              Text(
                'No staff hours data available for the selected period.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              _VirtualReportTable<StaffHoursReportResponse>(
                rows: report,
                columns: const [
                  'User ID',
                  'Username',
                  'Display Name',
                  'Total Hours',
                ],
                cells: (item) => [
                  '${item.userId}',
                  item.username,
                  item.displayName,
                  '${item.totalHoursWorked}',
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryUsageCard(BuildContext context) {
    final report = _inventoryUsageReport;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Usage Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loadingInventory)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report == null)
              Text(
                'No inventory usage data available.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (report.isEmpty)
              Text(
                'No inventory usage data available.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              _VirtualReportTable<InventoryUsageReportResponse>(
                rows: report,
                columns: const ['Inventory ID', 'Name', 'Usage Count'],
                cells: (item) => [
                  '${item.inventoryId}',
                  item.name,
                  '${item.usageCount}',
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(value == null ? 'Select date' : formatLocalDate(value!)),
        ),
      ),
    );
  }
}

/// A virtualized, read-only report table.
///
/// Uses [ListView.builder] so only visible rows are built. Report endpoints
/// return unpaginated lists, so a non-virtualized table would build every row
/// up front.
class _VirtualReportTable<T> extends StatelessWidget {
  const _VirtualReportTable({
    required this.rows,
    required this.columns,
    required this.cells,
  });

  final List<T> rows;
  final List<String> columns;
  final List<String> Function(T item) cells;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontWeight: FontWeight.w600);
    const rowHeight = 44.0;
    const headerHeight = 44.0;
    const maxBodyHeight = 320.0;
    final bodyHeight = (rows.length * rowHeight).clamp(0.0, maxBodyHeight);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: i == 0 ? 2 : 3,
                    child: Text(columns[i], style: headerStyle),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: bodyHeight,
            child: ListView.separated(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final values = cells(rows[index]);
                return SizedBox(
                  height: rowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            flex: i == 0 ? 2 : 3,
                            child: Text(
                              values[i],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
