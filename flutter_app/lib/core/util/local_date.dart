/// Date formatting for the wire format the API uses.
///
/// `yyyy-MM-dd`, produced from a [DateTime]'s **local** calendar fields.
///
/// **Never `DateTime.toIso8601String().split('T')[0]`**, which is what the React
/// originals do in two places — `EventListPage.tsx:26-29` for the "Start Date"
/// default, and every `moment(...).format('YYYY-MM-DD')` in
/// `EventCalendar.tsx`. `toIso8601String()` converts to **UTC first**, so the
/// date it reports is the local date only for part of the world.
///
/// Concretely: at local midnight on Tuesday in `UTC+13` — Auckland, for
/// instance — `toIso8601String()` returns Sunday. The default start date would
/// silently be a day early, and the calendar's query window would be shifted by
/// a day for the same reason. Anywhere west of UTC it happens to be right,
/// which is why it survives: nobody testing in `UTC-5` sees anything wrong.
///
/// Formatted from the fields instead, this is a local calendar date by
/// construction and there is no zone to get wrong. This is the same reasoning
/// as `EventResponse.startAt`, which builds its [DateTime] from components
/// rather than parsing a concatenated string — see task 7.9.
library;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

/// Formats [date] as `yyyy-MM-dd`, in its own local calendar fields.
///
/// The padded component form, not [DateFormat], because the output has no
/// locale in it: it is a wire value the server parses with `LocalDate.parse`,
/// and a locale-aware formatter would be free to hand back a different calendar
/// altogether. `intl` is still the right tool everywhere a date is shown to a
/// person — see the calendar header — which is where the *display* format is a
/// separate question from this one.
String formatLocalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Resolves [zoneId] to an IANA [Location], ensuring the embedded database is
/// loaded.
///
/// Maps the bare `UTC` alias the API and the app both use to the database's
/// `Etc/UTC` entry, matching [TimeZoneService._location].
Location zoneLocation(String zoneId) {
  initializeTimeZones();
  return zoneId == 'UTC' ? getLocation('Etc/UTC') : getLocation(zoneId);
}

/// The wall clock of [instant] read in [zoneId].
///
/// The returned [DateTime] is a [TZDateTime] whose fields are the zone's wall
/// clock — so `year`/`month`/`day`/`hour` of the result are what a clock on the
/// wall in [zoneId] would show at [instant].
DateTime wallClockInZone(DateTime instant, String zoneId) =>
    TZDateTime.from(instant.toUtc(), zoneLocation(zoneId));

/// Formats [instant] as `yyyy-MM-dd` in [zoneId].
String formatDateInZone(DateTime instant, String zoneId) =>
    formatLocalDate(wallClockInZone(instant, zoneId));

/// Formats [instant]'s time of day in [zoneId] for display (for example,
/// `9:30 AM`).
String formatTimeInZone(DateTime instant, String zoneId) =>
    DateFormat.jm().format(wallClockInZone(instant, zoneId));

/// Formats an offset-bearing ISO 8601 [timestamp] as `yyyy-MM-dd` in [zoneId].
///
/// Returns [timestamp] unchanged when it cannot be parsed — the same "never
/// silently blank" rule the port uses for values that are not what they claim to
/// be.
String formatInstantDate(String timestamp, String zoneId) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) return timestamp;
  return formatDateInZone(parsed, zoneId);
}
