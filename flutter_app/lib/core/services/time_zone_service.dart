import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

/// A wall clock that cannot be resolved to an instant, or that does not have a
/// unique one.
///
/// The two cases the design doc calls out are both this exception, with a
/// message that names which: a wall clock that **does not exist** — `02:30` on
/// a spring-forward morning — and one that **happens twice** — `02:30` on a
/// fall-back morning. Neither is silently resolved against an arbitrary
/// occurrence; both are refused, because the caller asked for a fact it cannot
/// state unambiguously.
class TimeZoneException implements Exception {
  TimeZoneException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The IANA zone database, and the wall-clock arithmetic built on it.
///
/// Wraps `package:timezone` behind this app's own interface so the rest of the
/// code never touches the package directly:
///
/// - [locations] is the picker's source of every zone the reader may choose.
/// - [offsetAt] is the DST-aware UTC offset in force at an instant.
/// - [wallClockAt] reads an instant back into a zone's wall clock.
/// - [instantAt] resolves a wall clock — a local date plus a local time of day —
///   to the instant it denotes.
///
/// The database behind all of these is the **embedded** one
/// (`package:timezone/data/latest.dart`, loaded by `initializeTimeZones`), not
/// the browser variant, which fetches a `.tzf` at runtime; see task 7.17.
class TimeZoneService {
  TimeZoneService() {
    // The embedded database, loaded from the data package rather than fetched
    // at runtime the way the browser variant does; see task 7.17. The service is
    // the only reader, so loading here — rather than relying on a boot hook in
    // `main` that tests never reach — is what makes every zone-aware surface
    // answer with a database behind it.
    initializeTimeZones();
  }

  /// Every IANA zone id in the embedded database, sorted.
  ///
  /// The picker's roster. The server validates against the same database
  /// (`ZoneId.getAvailableZoneIds()`), so a zone the client can list is a zone
  /// the server will accept — the pairing the design doc settled on, verified
  /// rather than assumed when the phase lands.
  List<String> get locations {
    final ids = timeZoneDatabase.locations.keys.toList()..sort();
    return ids;
  }

  /// The zone's [Location], with the `UTC` alias the server's zone ids and the
  /// design doc both spell resolved to the database's own `Etc/UTC` entry.
  Location _location(String zoneId) =>
      zoneId == 'UTC' ? getLocation('Etc/UTC') : getLocation(zoneId);

  /// The UTC offset in force at [instant] within [zoneId].
  ///
  /// [instant] is an absolute instant; the offset is the one that applies to it
  /// in [zoneId], which means it is **DST-aware** — `+02:00` for a Berlin summer
  /// instant, `+01:00` for its winter twin.
  Duration offsetAt(String zoneId, DateTime instant) =>
      _location(zoneId).timeZone(instant.millisecondsSinceEpoch).offset;

  /// The wall clock of the instant [instant], read in [zoneId].
  ///
  /// The result's fields — [DateTime.year], [DateTime.month], [DateTime.day],
  /// [DateTime.hour], and so on — are the zone's wall clock, not the UTC fields
  /// of the instant. At `2026-03-04T08:00:00Z` in `Europe/Berlin` the result is
  /// `09:00`, because that instant is `09:00` in Berlin (CET, `+01:00`).
  DateTime wallClockAt(DateTime instant, String zoneId) =>
      TZDateTime.from(instant, _location(zoneId));

  /// The instant denoted by the wall clock of [localDate] plus [localTime], in
  /// [zoneId].
  ///
  /// The wall clock is a **set**, not a value: the date and the time of day are
  /// meaningless apart from the zone that reads them. `(2026-03-04, 09:00,
  /// Europe/Berlin)` is a moment; `2026-03-04` and `09:00` alone are not.
  ///
  /// The resolution refuses the two wall clocks that carry no single answer:
  ///
  /// - **Does not exist.** `2026-03-29 02:30` in `Europe/Berlin` falls inside the
  ///   spring-forward gap and is rejected with a [TimeZoneException]. The
  ///   package's own constructor silently rolls such a clock forward, which is
  ///   the behavior this method exists to avoid.
  /// - **Happens twice.** `2026-10-25 02:30` in `Europe/Berlin` falls inside the
  ///   fall-back overlap and is flagged, not resolved — the caller must say
  ///   which occurrence it meant.
  ///
  /// Returns the instant as a UTC [DateTime]. The caller sends it on the wire as
  /// an offset-bearing ISO 8601 string; see task 7.18.
  DateTime instantAt({
    required String zoneId,
    required DateTime localDate,
    required DateTime localTime,
  }) {
    final location = _location(zoneId);
    final wallClockMs = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
      localTime.millisecond,
    ).millisecondsSinceEpoch;

    // An instant is a wall clock minus the offset in effect at that instant;
    // the offset is itself a function of the instant, so settle both by
    // iteration — the same fixed point the package's own constructor uses.
    var offset = location.timeZone(wallClockMs).offset;
    var instantMs = wallClockMs - offset.inMilliseconds;
    offset = location.timeZone(instantMs).offset;
    instantMs = wallClockMs - offset.inMilliseconds;

    // A wall clock denotes an instant in [zoneId] when that instant falls inside
    // one of the zone's own [TimeZone] intervals — which is exactly when the
    // interval check passes. A wall clock in a gap falls in none, and a wall
    // clock that happens twice falls in two.
    final matches = <int>{};
    for (final zone in location.zones) {
      final candidateMs = wallClockMs - zone.offset.inMilliseconds;
      final interval = location.lookupTimeZone(candidateMs);
      if (interval.timeZone == zone &&
          candidateMs >= interval.start &&
          candidateMs < interval.end) {
        matches.add(candidateMs);
      }
    }

    if (matches.isEmpty) {
      throw TimeZoneException(
        'Wall clock ${formatWallClock(localDate, localTime)} does not exist in '
        '$zoneId',
      );
    }
    if (matches.length > 1) {
      throw TimeZoneException(
        'Wall clock ${formatWallClock(localDate, localTime)} happens twice in '
        '$zoneId',
      );
    }

    return DateTime.fromMillisecondsSinceEpoch(matches.first, isUtc: true);
  }
}

/// The wall clock as the error messages name it: `yyyy-MM-dd HH:mm:ss`.
String formatWallClock(DateTime localDate, DateTime localTime) =>
    '${localDate.year.toString().padLeft(4, '0')}-'
    '${localDate.month.toString().padLeft(2, '0')}-'
    '${localDate.day.toString().padLeft(2, '0')} '
    '${localTime.hour.toString().padLeft(2, '0')}:'
    '${localTime.minute.toString().padLeft(2, '0')}:'
    '${localTime.second.toString().padLeft(2, '0')}';
