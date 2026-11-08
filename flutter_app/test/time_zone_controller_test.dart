import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/models/user.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/providers/organization_controller.dart';
import 'package:teven_app/providers/service_providers.dart';
import 'package:teven_app/providers/time_zone_controller.dart';

/// Task 7.17 — the reader's zone resolution, and the override that sits in
/// front of it.
///
/// The detector is overridden, exactly as `tokenStoreProvider` is overridden in
/// the auth harness: `flutter_timezone` is a platform plugin and cannot answer in
/// a headless VM test.
void main() {
  late ProviderContainer container;

  const organization = OrganizationResponse(
    organizationId: 1,
    name: 'Acme',
    contactInformation: '',
    timezone: 'Europe/Berlin',
  );

  const UserContextResponse userContext = UserContextResponse(
    user: UserResponse(userId: 1, username: 'ada', organization: organization),
    permissions: <String>[],
  );

  ProviderContainer build({
    String? detected,
    String? override,
    OrganizationResponse? selected,
    UserContextResponse? userContextOverride,
  }) {
    SharedPreferences.setMockInitialValues(
      override == null
          ? const <String, Object>{}
          : {TimeZoneController.storageKey: override},
    );
    container = ProviderContainer(
      overrides: [
        timeZoneDetectorProvider.overrideWith((ref) async => detected),
        selectedOrganizationProvider.overrideWithValue(selected),
        userContextProvider.overrideWithValue(
          userContextOverride ?? userContext,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('reader zone resolution', () {
    test('an override beats the detection', () async {
      final container = build(
        detected: 'America/New_York',
        override: 'Europe/Berlin',
      );

      final resolution = await container.read(
        timeZoneControllerProvider.future,
      );

      expect(resolution.effectiveZone, 'Europe/Berlin');
      expect(resolution.overrideZone, 'Europe/Berlin');
      expect(resolution.detectedZone, 'America/New_York');
      expect(resolution.organizationZone, 'Europe/Berlin');
    });

    test('clearing the override falls back to the detection', () async {
      final container = build(detected: 'America/New_York');
      final notifier = container.read(timeZoneControllerProvider.notifier);

      await notifier.setOverride('Europe/Berlin');
      expect(
        container.read(timeZoneControllerProvider).value?.effectiveZone,
        'Europe/Berlin',
      );

      await notifier.setOverride(null);
      expect(
        container.read(timeZoneControllerProvider).value?.effectiveZone,
        'America/New_York',
      );
    });

    test('the detection beats the organization zone', () async {
      final container = build(detected: 'America/New_York');

      final resolution = await container.read(
        timeZoneControllerProvider.future,
      );

      expect(resolution.effectiveZone, 'America/New_York');
      expect(resolution.organizationZone, 'Europe/Berlin');
    });

    test('the organization zone beats UTC', () async {
      final container = build(detected: null);

      final resolution = await container.read(
        timeZoneControllerProvider.future,
      );

      expect(resolution.effectiveZone, 'Europe/Berlin');
      expect(resolution.detectedZone, isNull);
    });

    test(
      'with no override, detection or organization, the zone is UTC',
      () async {
        final container = build(
          detected: null,
          selected: null,
          userContextOverride: const UserContextResponse(
            user: UserResponse(
              userId: 2,
              username: 'bob',
              organization: OrganizationResponse(
                organizationId: 2,
                name: 'Globex',
                contactInformation: '',
              ),
            ),
            permissions: <String>[],
          ),
        );

        final resolution = await container.read(
          timeZoneControllerProvider.future,
        );

        expect(resolution.effectiveZone, 'UTC');
        expect(resolution.overrideZone, isNull);
        expect(resolution.detectedZone, isNull);
        expect(resolution.organizationZone, isNull);
      },
    );
  });

  group('setOverride', () {
    test('persists the override and clears it', () async {
      final container = build(detected: 'America/New_York');

      final notifier = container.read(timeZoneControllerProvider.notifier);
      await notifier.setOverride('Europe/Berlin');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TimeZoneController.storageKey), 'Europe/Berlin');

      await notifier.setOverride(null);
      expect(prefs.getString(TimeZoneController.storageKey), isNull);
    });
  });
}
