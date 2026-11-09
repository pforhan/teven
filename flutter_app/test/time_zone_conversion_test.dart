import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/models/organization.dart';

/// Zone conversion cases: calendar day bucketing across date lines and the
/// reader-zone conversions that drive it.
///
/// The calendar buckets by the reader's local date of the event instant. Two
/// events at the same Berlin wall clock can land on different reader days, and
/// the two cross-day directions are asserted separately because one example
/// only proves half the mechanism.
void main() {
  const org = OrganizationResponse(
    organizationId: 1,
    name: 'Acme',
    contactInformation: '',
    timezone: 'UTC',
  );

  EventResponse event({
    required String startsAt,
    required String timezone,
    String title = 'Meeting',
  }) => EventResponse(
    eventId: 1,
    title: title,
    startsAt: startsAt,
    timezone: timezone,
    organization: org,
  );

  group('calendar day bucketing', () {
    test('02:00 Berlin is on the previous day in New York', () {
      // 2026-03-04 02:00 CET (UTC+1) = 2026-03-04T01:00:00Z.
      // In America/New_York (EST, UTC-5) that is 2026-03-03 20:00.
      final e = event(
        startsAt: '2026-03-04T01:00:00Z',
        timezone: 'Europe/Berlin',
      );
      expect(e.dateIn('Europe/Berlin'), '2026-03-04');
      expect(e.dateIn('America/New_York'), '2026-03-03');
    });

    test('23:00 Berlin is on the next day in Auckland', () {
      // 2026-03-04 23:00 CET (UTC+1) = 2026-03-04T22:00:00Z.
      // In Pacific/Auckland (NZDT, UTC+13) that is 2026-03-05 11:00.
      final e = event(
        startsAt: '2026-03-04T22:00:00Z',
        timezone: 'Europe/Berlin',
      );
      expect(e.dateIn('Europe/Berlin'), '2026-03-04');
      expect(e.dateIn('Pacific/Auckland'), '2026-03-05');
    });
  });
}
