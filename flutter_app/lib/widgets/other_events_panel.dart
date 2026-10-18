import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/list_query.dart';
import '../models/event.dart';
import '../providers/service_providers.dart';
import '../routing/app_router.dart';

/// The "Other events on {date}" sidebar from `OtherEventsPanel.tsx`.
class OtherEventsPanel extends ConsumerStatefulWidget {
  const OtherEventsPanel({
    super.key,
    required this.date,
    required this.organizationId,
    this.excludeEventId,
  });

  final String date;
  final String organizationId;
  final String? excludeEventId;

  @override
  ConsumerState<OtherEventsPanel> createState() => _OtherEventsPanelState();
}

class _OtherEventsPanelState extends ConsumerState<OtherEventsPanel> {
  List<EventResponse> _events = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant OtherEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.excludeEventId != widget.excludeEventId) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final orgId = int.tryParse(widget.organizationId);
    if (widget.date.isEmpty || orgId == null) {
      setState(() => _events = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await ref
          .read(eventServiceProvider)
          .getAllEvents(
            ListQuery(
              limit: 1000,
              organizationId: orgId,
              startDate: widget.date,
              endDate: widget.date,
            ),
          );
      var items = resp.items;
      if (widget.excludeEventId != null) {
        final exclude = widget.excludeEventId!;
        items = items.where((e) => e.eventId.toString() != exclude).toList();
      }
      items.sort((a, b) => a.time.compareTo(b.time));
      if (mounted) setState(() => _events = items);
    } catch (_) {
      if (mounted) setState(() => _events = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other events on ${widget.date}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_events.isEmpty)
              Text(
                'No other events scheduled for this day.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              )
            else
              for (final event in _events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    event.time,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${event.durationMinutes} min'
                    '${event.location != null && event.location!.isNotEmpty ? '  ${event.location}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => context.go(
                    AppRoutes.eventDetails.replaceFirst(
                      ':eventId',
                      '${event.eventId}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
