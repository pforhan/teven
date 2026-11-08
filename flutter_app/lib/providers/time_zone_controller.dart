import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'organization_controller.dart';
import 'service_providers.dart';

/// The reader's resolved time zone, with the pieces the UI shows.
///
/// Task 7.17. The reader's zone is resolved in the order the design doc settled:
///
/// 1. A **local override** the reader set — stored in `shared_preferences`, never
///    sent to the server.
/// 2. Otherwise the **device's** zone, detected.
/// 3. Otherwise the **organization's** zone — the fallback when detection is
///    unavailable.
/// 4. Otherwise **UTC**.
///
/// The organization's zone is a fallback, not a default in the "silently coerce"
/// sense: it is the organization's *home* clock, and it never moves an event. It
/// is the last stop before UTC because a reader with neither an override nor a
/// detection still has to render somewhere.
class TimeZoneResolution {
  const TimeZoneResolution({
    required this.detectedZone,
    required this.overrideZone,
    required this.organizationZone,
    required this.effectiveZone,
  });

  /// The device's zone, or `null` when detection was unavailable.
  final String? detectedZone;

  /// The reader's local override, or `null` when they have none.
  final String? overrideZone;

  /// The reader's organization zone, or `null` when they have none.
  final String? organizationZone;

  /// The zone all of the above resolve to: the override when set, else the
  /// detection, else the organization zone, else UTC.
  final String effectiveZone;
}

/// Resolves the reader's time zone and holds the override.
///
/// Task 7.17. Replaces nothing yet — the calendar, list, details, RSVP and form
/// surfaces read through here starting with the foundation.
final timeZoneControllerProvider =
    AsyncNotifierProvider<TimeZoneController, TimeZoneResolution>(
      TimeZoneController.new,
    );

class TimeZoneController extends AsyncNotifier<TimeZoneResolution> {
  /// The `shared_preferences` key the override is persisted under.
  ///
  /// Its own key rather than the auth token's namespace means a zone override
  /// survives logout — it is a device-local preference, like the selected
  /// organization, and "clear on logout" is not the behavior either of them
  /// has.
  static const String storageKey = 'timeZoneOverride';

  @override
  Future<TimeZoneResolution> build() => _resolve();

  /// The reader's zone, in the settled order.
  Future<TimeZoneResolution> _resolve() async {
    // Read the override from the store itself rather than through a cached
    // provider future: a completed future is cached for the life of the
    // container, and an override written after the first resolution would
    // otherwise never be seen by the next one.
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final override = prefs.getString(storageKey);
    final detected = await ref.read(timeZoneDetectorProvider.future);
    final organizationZone =
        ref.read(selectedOrganizationProvider)?.timezone ??
        ref.read(userContextProvider)?.user.organization.timezone;
    return TimeZoneResolution(
      detectedZone: detected,
      overrideZone: override,
      organizationZone: organizationZone,
      effectiveZone: override ?? detected ?? organizationZone ?? 'UTC',
    );
  }

  /// Sets the reader's local override, or clears it.
  ///
  /// `null` clears: the next resolution falls back to detection (and then the
  /// organization zone, then UTC). The override lives in `shared_preferences` —
  /// device-local, never sent to the server.
  Future<void> setOverride(String? zone) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (zone == null) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, zone);
    }
    state = AsyncData(await _resolve());
  }
}
