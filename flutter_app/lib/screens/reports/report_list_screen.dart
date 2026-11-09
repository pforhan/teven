import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/util/local_date.dart';
import '../../models/report.dart';
import '../../providers/service_providers.dart';
import '../../widgets/error_display.dart';
import '../../widgets/list_screen_header.dart';

/// Staff-hours and inventory-usage reports.
///
/// The report landing page: inventory usage loads on open, and a staff-hours
/// report is generated for an explicit range of days.
///
/// The staff-hours window is a range of *days*, not a range of instants, so it
/// is interpreted in the reader's zone (task 8.2). The device zone is sent with
/// the request; if detection is unavailable the request falls back to UTC.
///
/// Org scoping is **not** applied server-side — the report endpoints take no
/// caller context — and the responses carry no organization identifier, so the
/// client cannot filter by organization either. This screen does not pretend to
/// filter; it shows the server's result and states the limitation (task 8.4).
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
  bool _loadingInventory = true;
  bool _loadingStaffHours = false;
  ApiException? _error;
  String? _staffHoursMessage;

  @override
  void initState() {
    super.initState();
    _fetchInventoryUsageReport();
  }

  Future<void> _fetchInventoryUsageReport() async {
    setState(() {
      _loadingInventory = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(reportServiceProvider)
          .getInventoryUsageReport();
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

  Future<void> _fetchStaffHoursReport() async {
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

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListScreenHeader(title: 'Reports'),
            const SizedBox(height: 8),
            Text(
              'Reports are not scoped to the selected organization on the server, '
              'and the responses do not identify an organization, so this screen '
              'cannot filter by organization.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            if (error != null) ...[
              ErrorDisplay.fromException(error),
              const SizedBox(height: 16),
            ],
            _buildStaffHoursCard(context),
            const SizedBox(height: 16),
            _buildInventoryUsageCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffHoursCard(BuildContext context) {
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
                  onPressed: _loadingStaffHours ? null : _fetchStaffHoursReport,
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
/// Uses [ListView.builder] so only visible rows are built (task 8.5). Report
/// endpoints return unpaginated lists, so a non-virtualized table would build
/// every row up front.
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
