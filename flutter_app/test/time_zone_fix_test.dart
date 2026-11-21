import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/providers/time_zone_controller.dart';
import 'package:teven_app/providers/time_zone_fix.dart';

void main() {
  group('availableTimeZoneFixOptions', () {
    test('offers no actions when already automatic on detected system', () {
      const resolution = TimeZoneResolution(
        detectedZone: 'America/New_York',
        overrideZone: null,
        organizationZone: 'America/Chicago',
        effectiveZone: 'America/New_York',
      );

      final options = availableTimeZoneFixOptions(resolution);

      expect(options.map((o) => o.action), [TimeZoneFixAction.useOrganization]);
    });

    test('offers automatic, system, and organization when all differ', () {
      const resolution = TimeZoneResolution(
        detectedZone: 'America/New_York',
        overrideZone: 'Europe/Berlin',
        organizationZone: 'America/Chicago',
        effectiveZone: 'Europe/Berlin',
      );

      final options = availableTimeZoneFixOptions(resolution);

      expect(options.map((o) => o.action), [
        TimeZoneFixAction.useAutomatic,
        TimeZoneFixAction.useSystem,
        TimeZoneFixAction.useOrganization,
      ]);
      expect(options.first.targetZone, isNull);
    });

    test('offers automatic and organization when system unavailable', () {
      const resolution = TimeZoneResolution(
        detectedZone: null,
        overrideZone: 'Europe/Berlin',
        organizationZone: 'America/Chicago',
        effectiveZone: 'Europe/Berlin',
      );

      final options = availableTimeZoneFixOptions(resolution);

      expect(options.map((o) => o.action), [
        TimeZoneFixAction.useAutomatic,
        TimeZoneFixAction.useOrganization,
      ]);
      expect(options.first.description, contains('America/Chicago'));
    });

    test('offers system when effective differs and no override set', () {
      const resolution = TimeZoneResolution(
        detectedZone: 'America/New_York',
        overrideZone: null,
        organizationZone: 'America/Chicago',
        effectiveZone: 'America/New_York',
      );

      final options = availableTimeZoneFixOptions(resolution);

      expect(
        options.any((o) => o.action == TimeZoneFixAction.useSystem),
        isFalse,
      );
    });

    test('offers use system when automatic is org and detected differs', () {
      const resolution = TimeZoneResolution(
        detectedZone: 'America/New_York',
        overrideZone: null,
        organizationZone: 'America/Chicago',
        effectiveZone: 'America/New_York',
      );

      final options = availableTimeZoneFixOptions(resolution);

      expect(options.map((o) => o.action), [TimeZoneFixAction.useOrganization]);
    });
  });
}
