import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart';
import 'package:teven_app/core/services/time_zone_service.dart';

/// Task 7.17 — the zone database and the wall-clock arithmetic built on it.
///
/// The `timezone` package's own arithmetic silently resolves the two wall clocks
/// that carry no single answer — a gap rolls forward, an overlap picks one
/// occurrence — so the cases that matter are pinned here: the offset is
/// DST-aware, an unresolvable wall clock is refused, and an ambiguous one is
/// flagged.
void main() {
  final service = TimeZoneService();

  setUpAll(() {
    // Task 7.17: the embedded database, not the browser variant.
    initializeTimeZones();
  });

  group('locations', () {
    test('is the roster of the embedded IANA database', () {
      expect(
        service.locations,
        containsAll(<String>[
          'Etc/UTC',
          'America/New_York',
          'Europe/Berlin',
          'Pacific/Auckland',
        ]),
      );
      expect(service.locations, isNotEmpty);
    });
  });

  group('offsetAt', () {
    test('reads the offset in force at an instant, DST-aware', () {
      // Berlin: CET (+01:00) in winter, CEST (+02:00) in summer.
      expect(
        service.offsetAt('Europe/Berlin', DateTime.utc(2026, 1, 15, 12)),
        const Duration(hours: 1),
      );
      expect(
        service.offsetAt('Europe/Berlin', DateTime.utc(2026, 6, 15, 12)),
        const Duration(hours: 2),
      );

      // New York: EDT (−04:00) in summer, EST (−05:00) in winter.
      expect(
        service.offsetAt('America/New_York', DateTime.utc(2026, 6, 15, 12)),
        const Duration(hours: -4),
      );
      expect(
        service.offsetAt('America/New_York', DateTime.utc(2026, 1, 15, 12)),
        const Duration(hours: -5),
      );

      // Auckland: NZDT (+13:00) in summer, NZST (+12:00) in winter — the two
      // sides of the date line, and the reason the phase picked Auckland as a
      // seed zone.
      expect(
        service.offsetAt('Pacific/Auckland', DateTime.utc(2026, 1, 15, 12)),
        const Duration(hours: 13),
      );
      expect(
        service.offsetAt('Pacific/Auckland', DateTime.utc(2026, 7, 15, 12)),
        const Duration(hours: 12),
      );

      expect(
        service.offsetAt('UTC', DateTime.utc(2026, 3, 4, 8)),
        Duration.zero,
      );
    });
  });

  group('wallClockAt', () {
    test('reads an instant into a zone wall clock', () {
      final berlin = service.wallClockAt(
        DateTime.utc(2026, 3, 4, 8),
        'Europe/Berlin',
      );
      expect(berlin.year, 2026);
      expect(berlin.month, 3);
      expect(berlin.day, 4);
      expect(berlin.hour, 9);

      final newYork = service.wallClockAt(
        DateTime.utc(2026, 3, 4, 8),
        'America/New_York',
      );
      expect(newYork.year, 2026);
      expect(newYork.hour, 3);
    });
  });

  group('instantAt', () {
    test('resolves a wall clock to the instant it denotes', () {
      final instant = service.instantAt(
        zoneId: 'Europe/Berlin',
        localDate: DateTime(2026, 3, 4),
        localTime: DateTime(2026, 3, 4, 9),
      );
      // 09:00 in Berlin (CET, +01:00) is 08:00Z.
      expect(
        instant.millisecondsSinceEpoch,
        DateTime.utc(2026, 3, 4, 8).millisecondsSinceEpoch,
      );
    });

    test('rejects a wall clock that does not exist', () {
      // 02:30 on the Berlin spring-forward morning — a gap, not a time.
      expect(
        () => service.instantAt(
          zoneId: 'Europe/Berlin',
          localDate: DateTime(2026, 3, 29),
          localTime: DateTime(2026, 3, 29, 2, 30),
        ),
        throwsA(isA<TimeZoneException>()),
      );
    });

    test('flags a wall clock that happens twice', () {
      // 02:30 on the Berlin fall-back morning — an overlap, not an ambiguity
      // the resolver should silently resolve.
      expect(
        () => service.instantAt(
          zoneId: 'Europe/Berlin',
          localDate: DateTime(2026, 10, 25),
          localTime: DateTime(2026, 10, 25, 2, 30),
        ),
        throwsA(isA<TimeZoneException>()),
      );
    });

    test('round trips an instant back into the same wall clock', () {
      final instant = service.instantAt(
        zoneId: 'Europe/Berlin',
        localDate: DateTime(2026, 3, 4),
        localTime: DateTime(2026, 3, 4, 9),
      );
      final wall = service.wallClockAt(instant, 'Europe/Berlin');
      expect(wall.hour, 9);
      expect(wall.day, 4);
    });
  });
}
