import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../core/services/time_zone_service.dart';
import '../providers/service_providers.dart';

/// The zone's UTC offset as `+HH:MM` / `-HH:MM` — the shape the reader sees in
/// the event details ("9:00 AM · Europe/Berlin") and the shape the forms send as
/// the `startsAt` offset.
String formatZoneOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.abs().inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// A time zone picker field, shared by the event forms (task 7.19), the
/// organization screen (task 7.23) and the profile row (task 7.17).
///
/// **What it shows:** the zone it holds, with that zone's current offset — the
/// "which clock am I reading this in" question, answered without a detour.
///
/// **What it does:** tapping it opens a searchable picker — a bottom sheet on
/// mobile, a dialog on tablet and desktop, per task 3.2's breakpoint split — and
/// hands the chosen zone back through [onChanged].
///
/// **The organization default:** when the field agrees with [defaultZone] — the
/// organization's home clock, the fallback the reader's resolution falls through
/// to — it is marked as such and de-emphasized rather than presented as a
/// choice the reader made. An event form's zone defaults to the reader's
/// *effective* zone rather than the organization's, so the marker there is
/// guidance, not a value; the two cases read differently and both come through
/// the same `==`.
class TimeZoneField extends ConsumerStatefulWidget {
  const TimeZoneField({
    super.key,
    required this.zone,
    required this.onChanged,
    this.defaultZone,
  });

  /// The zone currently held, an IANA id.
  final String zone;

  /// Called with the zone the reader picked.
  final ValueChanged<String> onChanged;

  /// The zone marked as the organization's default, if there is one. When the
  /// field holds it, the field shows the default marker.
  final String? defaultZone;

  @override
  ConsumerState<TimeZoneField> createState() => _TimeZoneFieldState();
}

class _TimeZoneFieldState extends ConsumerState<TimeZoneField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${widget.zone} (${formatZoneOffset(_offsetFor(widget.zone))})',
    );
  }

  @override
  void didUpdateWidget(TimeZoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone != widget.zone) {
      _controller.text =
          '${widget.zone} (${formatZoneOffset(_offsetFor(widget.zone))})';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TimeZoneService _service() => ref.read(timeZoneServiceProvider);

  Duration _offsetFor(String zoneId) =>
      _service().offsetAt(zoneId, DateTime.now());

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      onTap: _openPicker,
      decoration: InputDecoration(
        labelText: 'Time zone',
        suffixIcon: const Icon(Icons.language),
        helperText: widget.zone == widget.defaultZone
            ? 'The organization default'
            : null,
      ),
    );
  }

  Future<void> _openPicker() async {
    final service = _service();
    final picked = context.layoutSize == LayoutSize.mobile
        ? await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) =>
                _TimeZonePickerSheet(zone: widget.zone, service: service),
          )
        : await showDialog<String>(
            context: context,
            builder: (context) =>
                _TimeZonePickerDialog(zone: widget.zone, service: service),
          );

    if (picked != null) {
      widget.onChanged(picked);
    }
  }
}

/// The picker's body: a search field and the zone list, grouped by offset.
class _TimeZonePickerBody extends StatefulWidget {
  const _TimeZonePickerBody({required this.zone, required this.service});

  final String zone;
  final TimeZoneService service;

  @override
  State<_TimeZonePickerBody> createState() => _TimeZonePickerBodyState();
}

class _TimeZonePickerBodyState extends State<_TimeZonePickerBody> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _zones {
    final query = _search.trim().toLowerCase();
    final all = widget.service.locations;
    if (query.isEmpty) {
      return all;
    }
    return all
        .where((zone) => zone.toLowerCase().contains(query))
        .toList(growable: false);
  }

  /// Every zone the query matched, grouped by the offset that is in effect when
  /// the picker renders — DST-aware, so a European summer shows one group and
  /// its winter twin another.
  List<({Duration offset, List<String> zones})> get _groups {
    final grouped = <Duration, List<String>>{};
    for (final zone in _zones) {
      final offset = widget.service.offsetAt(zone, DateTime.now());
      final zones = grouped[offset];
      if (zones == null) {
        grouped[offset] = [zone];
      } else {
        zones.add(zone);
      }
    }
    final offsets = grouped.keys.toList()
      ..sort((a, b) => a.inMinutes.compareTo(b.inMinutes));
    return [
      for (final offset in offsets)
        (offset: offset, zones: grouped[offset] ?? const <String>[]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final theme = Theme.of(context);

    final list = ListView(
      shrinkWrap: true,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              formatZoneOffset(group.offset),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          for (final zone in group.zones)
            ListTile(
              title: Text(zone),
              selected: zone == widget.zone,
              onTap: () => Navigator.of(context).pop(zone),
            ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            hintText: 'Search time zones...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        list,
      ],
    );
  }
}

class _TimeZonePickerSheet extends StatelessWidget {
  const _TimeZonePickerSheet({required this.zone, required this.service});

  final String zone;
  final TimeZoneService service;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // `isScrollControlled` lets the sheet use most of the viewport, so the
        // search field has to sit above the keyboard, as in the organization
        // picker (`organization_picker.dart`).
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: _TimeZonePickerBody(zone: zone, service: service),
      ),
    );
  }
}

class _TimeZonePickerDialog extends StatelessWidget {
  const _TimeZonePickerDialog({required this.zone, required this.service});

  final String zone;
  final TimeZoneService service;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: SizedBox(
        width: 420,
        child: _TimeZonePickerBody(zone: zone, service: service),
      ),
    );
  }
}
