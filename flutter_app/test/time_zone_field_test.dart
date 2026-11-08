import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart';
import 'package:teven_app/core/services/time_zone_service.dart';
import 'package:teven_app/widgets/time_zone_field.dart';

/// Task 7.17 — the shared zone field the event forms, the organization screen
/// and the profile row all read through.
///
/// The picker itself is task 7.25's territory; these cases pin what the field
/// owns: the zone it shows, with its current offset, and the organization
/// default's mark.
void main() {
  final service = TimeZoneService();

  setUpAll(() {
    // Task 7.17: the embedded database, not the browser variant.
    initializeTimeZones();
  });

  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('shows the zone with its current offset', (tester) async {
    await tester.pumpWidget(
      wrap(
        TimeZoneField(
          zone: 'Europe/Berlin',
          defaultZone: 'America/New_York',
          onChanged: (_) {},
        ),
      ),
    );

    final offset = service.offsetAt('Europe/Berlin', DateTime.now());
    expect(
      find.text('${'Europe/Berlin'} (${formatZoneOffset(offset)})'),
      findsOneWidget,
    );
  });

  testWidgets('marks the organization default when the field agrees', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TimeZoneField(
          zone: 'Europe/Berlin',
          defaultZone: 'Europe/Berlin',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('The organization default'), findsOneWidget);
  });

  testWidgets('does not mark the organization default when it differs', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TimeZoneField(
          zone: 'Europe/Berlin',
          defaultZone: 'America/New_York',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('The organization default'), findsNothing);
  });
}
