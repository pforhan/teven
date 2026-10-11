import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/api_response.dart';
import 'package:teven_app/models/common.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/models/permissions.dart';

/// Model behaviour that is not obvious from reading a call site.
void main() {
  const org = OrganizationResponse(organizationId: 2, name: 'Org');

  EventResponse event({
    String date = '2026-03-04',
    String time = '09:30:00',
    int durationMinutes = 90,
  }) => EventResponse(
    eventId: 1,
    title: 'Gala',
    date: date,
    time: time,
    durationMinutes: durationMinutes,
    organization: org,
  );

  group('ApiResponse — the data:{} hazard', () {
    /// Fails the test if the decoder is ever reached on a failure envelope.
    int mustNotDecode(Object? _) => fail('decode must not run on a failure');

    test('does not decode data on a failure envelope', () {
      // The server's failure() sets data = Unit, which serialises to {}. A
      // generated fromJson would try to decode that {} into T and throw,
      // destroying the error message the caller needs.
      final response = ApiResponse.fromJson({
        'success': false,
        'data': <String, dynamic>{},
        'error': {'message': 'Event not found', 'details': 'stack'},
      }, mustNotDecode);

      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.error?.message, 'Event not found');
      expect(response.error?.details, 'stack');
    });

    test('survives a failure envelope with no error object', () {
      final response = ApiResponse.fromJson({
        'success': false,
        'data': {},
      }, mustNotDecode);
      expect(response.success, isFalse);
      expect(response.error, isNull);
    });

    test('decodes data on success', () {
      final response = ApiResponse.fromJson({
        'success': true,
        'data': {'v': 42},
      }, (json) => (json! as Map<String, dynamic>)['v'] as int);
      expect(response.success, isTrue);
      expect(response.data, 42);
    });

    test('treats a null data field on success as absent, not an error', () {
      final response = ApiResponse.fromJson({
        'success': true,
        'data': null,
      }, mustNotDecode);
      expect(response.success, isTrue);
      expect(response.data, isNull);
    });
  });

  group('naive-local event times', () {
    // The API sends "YYYY-MM-DD" / "HH:MM:SS" with no timezone. These must
    // stay local, never be re-read as UTC — that would shift every event.
    test('startAt is local, not UTC-shifted', () {
      expect(event().startAt, DateTime(2026, 3, 4, 9, 30));
    });

    test('endAt adds durationMinutes', () {
      expect(event().endAt, DateTime(2026, 3, 4, 11, 0));
    });

    test('a bare "HH:MM" time has zero seconds', () {
      expect(event(time: '14:05').startAt, DateTime(2026, 3, 4, 14, 5, 0));
    });

    test('seconds are honoured when present', () {
      expect(event(time: '08:15:45').startAt, DateTime(2026, 3, 4, 8, 15, 45));
    });

    test('zero duration ends where it starts', () {
      expect(
        event(durationMinutes: 0).endAt,
        event(durationMinutes: 0).startAt,
      );
    });

    test('duration crosses midnight', () {
      expect(
        event(time: '23:30', durationMinutes: 60).endAt,
        DateTime(2026, 3, 5, 0, 30),
      );
    });
  });

  group('Permissions — OR semantics', () {
    // ProtectedRoute.tsx treats an array as .some(), and an empty array
    // renders unconditionally. Both matter for the route guard.
    test('has finds a granted permission', () {
      expect(
        Permissions.has(const [
          'VIEW_USERS_GLOBAL',
        ], Permission.viewUsersGlobal),
        isTrue,
      );
    });

    test('has rejects an absent permission', () {
      expect(
        Permissions.has(const [
          'VIEW_USERS_GLOBAL',
        ], Permission.manageUsersGlobal),
        isFalse,
      );
    });

    test('hasAny grants on either of two permissions', () {
      expect(
        Permissions.hasAny(
          const ['VIEW_USERS_ORGANIZATION'],
          const [Permission.viewUsersGlobal, Permission.viewUsersOrganization],
        ),
        isTrue,
      );
    });

    test('hasAny rejects when neither is granted', () {
      expect(
        Permissions.hasAny(
          const ['MANAGE_EVENTS_ORGANIZATION'],
          const [Permission.viewUsersGlobal, Permission.viewUsersOrganization],
        ),
        isFalse,
      );
    });

    test('an empty requirement grants access', () {
      expect(Permissions.hasAny(const [], const []), isTrue);
    });

    test('an unknown wire string does not parse', () {
      expect(Permissions.parse('NOT_A_REAL_PERMISSION'), isNull);
    });

    test('a known wire string parses to its enum value', () {
      expect(
        Permissions.parse('MANAGE_EVENTS_ORGANIZATION'),
        Permission.manageEventsOrganization,
      );
    });
  });

  group('PaginatedResponse', () {
    test('decodes nested items through the supplied decoder', () {
      const orgJson = {'organizationId': 2, 'name': 'Org'};
      final page = PaginatedResponse.fromJson({
        'items': [
          {
            'eventId': 1,
            'title': 'A',
            'date': '2026-03-04',
            'time': '09:00:00',
            'organization': orgJson,
          },
          {
            'eventId': 2,
            'title': 'B',
            'date': '2026-03-05',
            'time': '10:00:00',
            'organization': orgJson,
          },
        ],
        'total': 2,
        'offset': 0,
        'limit': 10,
      }, (json) => EventResponse.fromJson(json! as Map<String, dynamic>));

      expect(page.items.map((e) => e.title), ['A', 'B']);
      expect(page.total, 2);
      expect(page.limit, 10);
    });

    test('defaults the paging fields when absent', () {
      final page = PaginatedResponse.fromJson({
        'items': <dynamic>[],
      }, (json) => json);
      expect(page.total, 0);
      expect(page.offset, 0);
      expect(page.limit, 0);
    });
  });
}
