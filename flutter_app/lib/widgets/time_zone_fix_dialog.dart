import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/time_zone_controller.dart';
import '../providers/time_zone_fix.dart';

Future<void> showTimeZoneFixDialog(
  BuildContext context, {
  TimeZoneResolution? resolution,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => TimeZoneFixDialog(resolution: resolution),
  );
}

class TimeZoneFixDialog extends ConsumerWidget {
  const TimeZoneFixDialog({super.key, this.resolution});

  final TimeZoneResolution? resolution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveResolution =
        resolution ?? ref.watch(timeZoneControllerProvider).value;
    return AlertDialog(
      title: const Text('Possible timezone issue'),
      content: SizedBox(
        width: 480,
        child: effectiveResolution == null
            ? const Text('Timezone information is not available yet.')
            : TimeZoneFixContent(resolution: effectiveResolution),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(timeZoneMismatchDismissedProvider.notifier).dismiss();
            Navigator.of(context).pop();
          },
          child: const Text('Ignore for now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class TimeZoneFixContent extends ConsumerWidget {
  const TimeZoneFixContent({
    super.key,
    required this.resolution,
    this.showCurrent = true,
    this.onApply,
    this.popOnApply = true,
  });

  final TimeZoneResolution resolution;
  final bool showCurrent;

  /// When provided, called instead of persisting directly via the controller.
  /// Used by profile edit mode to stage draft changes.
  final Future<void> Function(String? targetZone)? onApply;
  final bool popOnApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final options = availableTimeZoneFixOptions(resolution);
    final issues = timeZoneIssuesFor(resolution);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrent) ...[
          Text(
            'Current timezone',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(resolution.effectiveZone, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
        ],
        if (issues.isEmpty)
          Text(
            'Your timezone settings look consistent.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue)),
                ],
              ),
            ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Fix options', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                onPressed: () async {
                  if (onApply != null) {
                    await onApply!(option.targetZone);
                  } else {
                    await ref
                        .read(timeZoneControllerProvider.notifier)
                        .setOverride(option.targetZone);
                  }
                  if (popOnApply && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label),
                      const SizedBox(height: 2),
                      Text(
                        option.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
