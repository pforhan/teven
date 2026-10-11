import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/api/api_client.dart';
import 'package:teven_app/core/services/crud_services.dart';
import 'package:teven_app/core/services/event_service.dart';
import 'package:teven_app/core/services/list_query.dart';
import 'package:teven_app/core/services/misc_services.dart';
import 'package:teven_app/models/customer.dart';
import 'package:teven_app/models/event.dart';
import 'package:teven_app/models/inventory.dart';
import 'package:teven_app/models/user.dart';

import 'support/stub_adapter.dart';

/// Request-level behaviour for the service layer — task 1.20.
///
/// These assert on the *request*: that each method reaches the documented path
/// with the documented query parameters, and that the response *shapes* are
/// handled as the server sends them. The bodies here are crafted stubs, not a
/// live server — parsing HTTP is covered in `api_client_test.dart`, and nothing
/// at this layer should need a socket.
void main() {
  late StubAdapter adapter;
  late ApiClient client;

  setUp(() {
    // The adapter answers by path so each service gets a body that actually
    // matches its return type, and the request can still be inspected.
    adapter = StubAdapter(_responseFor);
    client = ApiClient.forTesting(adapter);
  });

  /// Path of the most recent request.
  String lastPath() => adapter.last.path;

  group('routes', () {
    test('users', () async {
      final service = UserService(client);
      await service.getAllUsers();
      expect(lastPath(), '/api/users');

      await service.getUser(7);
      expect(lastPath(), '/api/users/7');

      await service.createUser(
        const CreateUserRequest(
          username: 'a',
          password: 'b',
          organizationId: 1,
        ),
      );
      expect(lastPath(), '/api/users');
      expect(adapter.last.method, 'POST');
      expect(adapter.lastRequestBody, contains('"username":"a"'));
    });

    test('customers', () async {
      final service = CustomerService(client);
      await service.getAllCustomers();
      expect(lastPath(), '/api/customers');

      await service.getCustomer(3);
      expect(lastPath(), '/api/customers/3');

      await service.createCustomer(const CreateCustomerRequest(name: 'Acme'));
      expect(lastPath(), '/api/customers');
      expect(adapter.lastRequestBody, contains('"name":"Acme"'));
    });

    test('organizations', () async {
      final service = OrganizationService(client);
      await service.getAllOrganizations();
      expect(lastPath(), '/api/organizations');

      await service.getOrganization(4);
      expect(lastPath(), '/api/organizations/4');
    });

    test('inventory, including the usage subpath', () async {
      final service = InventoryService(client);
      await service.getAllInventoryItems();
      expect(lastPath(), '/api/inventory');

      await service.getInventoryItem(9);
      expect(lastPath(), '/api/inventory/9');

      await service.trackInventoryUsage(
        4,
        const TrackInventoryUsageRequest(eventId: 1, quantity: 2),
      );
      expect(lastPath(), '/api/inventory/4/usage');
      expect(adapter.last.method, 'POST');
    });

    test('events', () async {
      final service = EventService(client);
      await service.getEvent(11);
      expect(lastPath(), '/api/events/11');

      await service.getRequestedRsvps();
      expect(lastPath(), '/api/events/rsvps/requested');
    });

    test('invitations pass the token as a query param', () async {
      await InvitationService(client).validateInvitation('abc123');
      expect(lastPath(), '/api/invitations/validate');
      expect(adapter.lastQuery['token'], 'abc123');
    });

    test('reports pass both date bounds', () async {
      await ReportService(client)
          .getStaffHoursReport(startDate: '2026-01-01', endDate: '2026-02-01');
      expect(lastPath(), '/api/reports/staff_hours');
      expect(adapter.lastQuery['startDate'], '2026-01-01');
      expect(adapter.lastQuery['endDate'], '2026-02-01');
    });

    test('roles', () async {
      await RoleService(client).getAllRoles();
      expect(lastPath(), '/api/roles');
    });
  });

  group('task 1.18 — event queries are capped by default', () {
    test('getAllEvents sends limit=10 when unspecified', () async {
      await EventService(client).getAllEvents();
      expect(lastPath(), '/api/events');
      expect(adapter.lastQuery['limit'], 10);
    });

    test('an explicit limit overrides the default', () async {
      await EventService(client).getAllEvents(const ListQuery(limit: 25));
      expect(adapter.lastQuery['limit'], 25);
    });

    test('other filters still pass through alongside the default', () async {
      await EventService(client).getAllEvents(
        const ListQuery(search: 'gala', sortOrder: SortOrder.desc),
      );
      expect(adapter.lastQuery['search'], 'gala');
      expect(adapter.lastQuery['sortOrder'], 'desc');
      expect(adapter.lastQuery['limit'], 10);
    });

    test('non-event lists send no limit, matching the React client', () async {
      // Omitting limit returns the whole table server-side, so this is a
      // deliberate parity choice rather than an oversight.
      await CustomerService(client).getAllCustomers();
      expect(adapter.lastQuery.containsKey('limit'), isFalse);
    });
  });

  group('task 1.16 — sort parameters', () {
    test('sortBy is forwarded even though the server ignores it', () async {
      await EventService(client).getAllEvents(const ListQuery(sortBy: 'title'));
      expect(adapter.lastQuery['sortBy'], 'title');
    });

    test('an empty search is omitted rather than sent blank', () async {
      await CustomerService(client)
          .getAllCustomers(const ListQuery(search: ''));
      expect(adapter.lastQuery.containsKey('search'), isFalse);
    });
  });

  group('response shapes', () {
    test('updateCustomer returns the string, not a model', () async {
      expect(
        await CustomerService(client)
            .updateCustomer(1, const UpdateCustomerRequest()),
        'Customer with ID 1 updated',
      );
    });

    test('updateEvent returns the string, not an EventResponse', () async {
      expect(
        await EventService(client)
            .updateEvent(1, const UpdateEventRequest(organizationId: 1)),
        'Event with ID 1 updated',
      );
    });

    test('a 204 delete completes with no payload', () async {
      final deletes = ApiClient.forTesting(
        StubAdapter((_) => const StubResponse.noContent()),
      );
      await expectLater(CustomerService(deletes).deleteCustomer(1), completes);
    });

    test('a paginated list decodes through the service', () async {
      final page = await CustomerService(client).getAllCustomers();
      expect(page.items, isEmpty);
      expect(page.limit, 10);
    });
  });
}

/// The resource name a bare-string acknowledgement refers to.
String _resourceOf(String path) {
  for (final name in [
    'customer',
    'event',
    'inventory',
    'organization',
    'role',
  ]) {
    if (path.contains(name)) {
      return name[0].toUpperCase() + name.substring(1);
    }
  }
  return 'Resource';
}

/// A response matching what each endpoint's return type expects.
///
/// Bodies are built by string interpolation so the shared id/organization
/// fragments stay in one place, which rules out `const` — hence the
/// per-callsite suppressions below rather than a file-level exclusion.
StubResponse _responseFor(RequestOptions options) {
  final path = options.path;
  const org = '"organization":{"organizationId":1,"name":"O"}';
  const ids = '"customerId":1,"name":"Acme","userId":1,"username":"a"';

  if (path.contains('/usage')) {
    return const StubResponse.json('{"success":true,"data":"OK"}');
  }
  // Every PUT answers a bare-string acknowledgement naming the resource.
  if (options.method == 'PUT') {
    // ignore: prefer_const_constructors
    return StubResponse.json(
      '{"success":true,"data":"${_resourceOf(path)} with ID 1 updated"}',
    );
  }
  if (path.startsWith('/api/events') && options.method == 'GET') {
    if (path.endsWith('/rsvps/requested')) {
      return const StubResponse.json('{"success":true,"data":[]}');
    }
    if (path == '/api/events') {
      return const StubResponse.json(
        '{"success":true,"data":{"items":[],'
        '"total":0,"offset":0,"limit":10}}',
      );
    }
  }
  if (path.startsWith('/api/reports') || path == '/api/roles') {
    return const StubResponse.json('{"success":true,"data":[]}');
  }
  if (path.startsWith('/api/invitations/validate')) {
    return const StubResponse.json(
      '{"success":true,"data":{"organizationId":1,'
      '"organizationName":"O","roleName":"Organizer"}}',
    );
  }
  if (path.startsWith('/api/invitations')) {
    // ignore: prefer_const_constructors
    return StubResponse.json('{"success":true,"data":[]}');
  }
  if (options.method == 'POST') {
    // ignore: prefer_const_constructors
    return StubResponse.json('{"success":true,"data":{$ids,$org}}');
  }
  // A by-id GET. Each resource needs its own id field name.
  if (RegExp(r'/\d+$').hasMatch(path)) {
    if (path.startsWith('/api/events')) {
      // ignore: prefer_const_constructors
      return StubResponse.json(
        '{"success":true,"data":{"eventId":1,"title":"Gala",'
        '"date":"2026-03-04","time":"09:30:00",$org}}',
      );
    }
    if (path.startsWith('/api/inventory')) {
      // ignore: prefer_const_constructors
      return StubResponse.json(
        '{"success":true,"data":{"inventoryId":1,"name":"Chairs",$org}}',
      );
    }
    if (path.startsWith('/api/organizations')) {
      return const StubResponse.json(
        '{"success":true,"data":{"organizationId":1,"name":"O"}}',
      );
    }
    // ignore: prefer_const_constructors
    return StubResponse.json('{"success":true,"data":{$ids,$org}}');
  }

  // Everything else is a list GET.
  return const StubResponse.json(
    '{"success":true,"data":{"items":[],"total":0,"offset":0,"limit":10}}',
  );
}
