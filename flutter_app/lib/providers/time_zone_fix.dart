import 'time_zone_controller.dart';

enum TimeZoneFixAction { useAutomatic, useSystem, useOrganization }

class TimeZoneFixOption {
  const TimeZoneFixOption({
    required this.action,
    required this.label,
    required this.description,
    required this.targetZone,
  });

  final TimeZoneFixAction action;
  final String label;
  final String description;

  /// The zone to set as override, or null to clear override (automatic).
  final String? targetZone;
}

/// Returns the timezone fix actions available for [resolution].
///
/// Actions are offered only when they would change the effective timezone or
/// change how it is resolved. "Automatic" clears the local override and
/// follows detected -> organization -> UTC.
List<TimeZoneFixOption> availableTimeZoneFixOptions(
  TimeZoneResolution resolution,
) {
  final options = <TimeZoneFixOption>[];
  final effective = resolution.effectiveZone;
  final detected = resolution.detectedZone;
  final organization = resolution.organizationZone;
  final automaticZone = detected ?? organization ?? 'UTC';

  if (resolution.hasOverride) {
    options.add(
      TimeZoneFixOption(
        action: TimeZoneFixAction.useAutomatic,
        label: 'Use automatic',
        description: automaticZone == detected
            ? 'Follow your system timezone ($automaticZone).'
            : 'Clear override and use automatic timezone ($automaticZone).',
        targetZone: null,
      ),
    );
  }

  if (detected != null && effective != detected) {
    options.add(
      TimeZoneFixOption(
        action: TimeZoneFixAction.useSystem,
        label: 'Use system timezone',
        description: 'Set timezone to your system timezone ($detected).',
        targetZone: detected,
      ),
    );
  }

  if (organization != null && effective != organization) {
    options.add(
      TimeZoneFixOption(
        action: TimeZoneFixAction.useOrganization,
        label: 'Use organization timezone',
        description:
            'Set timezone to your organization timezone ($organization).',
        targetZone: organization,
      ),
    );
  }

  return options;
}

List<String> timeZoneIssuesFor(TimeZoneResolution resolution) {
  final issues = <String>[];
  if (resolution.overrideDiffersFromDetected) {
    issues.add(
      'Your saved override (${resolution.overrideZone}) differs from your system timezone (${resolution.detectedZone}).',
    );
  } else if (resolution.hasOverride && resolution.detectedZone == null) {
    issues.add(
      'You have a saved override (${resolution.overrideZone}), but system timezone detection is unavailable.',
    );
  } else if (resolution.hasOverride) {
    issues.add(
      'You have a saved timezone override (${resolution.overrideZone}).',
    );
  }
  if (resolution.effectiveDiffersFromOrganization) {
    issues.add(
      'Your effective timezone (${resolution.effectiveZone}) differs from your organization timezone (${resolution.organizationZone}).',
    );
  }
  if (resolution.detectedZone == null && !resolution.hasOverride) {
    issues.add(
      'System timezone detection is unavailable; using ${resolution.effectiveZone}.',
    );
  }
  return issues;
}
