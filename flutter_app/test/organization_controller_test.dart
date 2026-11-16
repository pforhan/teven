import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teven_app/core/services/crud_services.dart';
import 'package:teven_app/core/services/list_query.dart';
import 'package:teven_app/models/common.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/providers/organization_controller.dart';
import 'package:teven_app/providers/organization_list.dart';
import 'package:teven_app/providers/service_providers.dart';

/// Organization selection and its persistence — task 2.4.
///
/// The real `SharedPreferences` plugin runs against an in-memory backing store
/// here, which is what makes these tests worth writing: the persistence format
/// is part of the contract (it is shared with the React app), and a codec
/// mismatch would only show up at runtime.
void main() {
  const org = OrganizationResponse(
    organizationId: 7,
    name: 'Acme',
    contactInformation: 'acme@example.com',
    timezone: 'UTC',
  );

  late ProviderContainer container;

  ProviderContainer build({String? stored}) {
    // A map comprehension rather than a null-aware element: the `?key: value`
    // form would need `stored` typed as non-nullable `Object`, which defeats the
    // point of seeding it optionally.
    SharedPreferences.setMockInitialValues(
      stored == null
          ? const <String, Object>{}
          : {OrganizationController.storageKey: stored},
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('nothing stored means no selection', () async {
    build();

    expect(await container.read(organizationControllerProvider.future), isNull);
  });

  test('a stored selection is restored on boot', () async {
    // The React original seeds this during the first render
    // (`OrganizationContext.tsx:11-15`); here it arrives a frame later, which
    // is why the provider is async. The restored value has to be a full
    // organization, not an id — the org switcher renders its name.
    build(
      stored:
          '{"organizationId":7,"name":"Acme",'
          '"contactInformation":"acme@example.com","timezone":"UTC"}',
    );

    expect(await container.read(organizationControllerProvider.future), org);
  });

  test('selecting an organization writes it under the React key', () async {
    // The key and the JSON shape are deliberately identical to the React app's,
    // so a user moving between the two mid-migration keeps their selection.
    build();

    await container.read(organizationControllerProvider.notifier).select(org);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('selectedOrganization'),
      contains('"organizationId":7'),
    );
    expect(container.read(selectedOrganizationProvider), org);
  });

  test('clearing removes the key rather than storing null', () async {
    // `OrganizationContext.tsx:22` calls `removeItem`; storing the string
    // "null" would leave a value that survives a reload and then fails to
    // parse.
    build();
    final notifier = container.read(organizationControllerProvider.notifier);
    await notifier.select(org);
    await notifier.select(null);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OrganizationController.storageKey), isNull);
    expect(container.read(selectedOrganizationProvider), isNull);
  });

  test('a corrupt stored value is ignored rather than fatal', () async {
    // `OrganizationContext.tsx:12` calls a bare `JSON.parse` on whatever is in
    // storage, so a value written by an older build throws during the first
    // render and takes the app down. A lost org selection is recoverable; a
    // white screen is not.
    build(stored: 'not json at all');

    expect(await container.read(organizationControllerProvider.future), isNull);
  });

  test('a stored value of the wrong shape is ignored', () async {
    build(stored: '"Acme"');

    expect(await container.read(organizationControllerProvider.future), isNull);
  });

  group('reconcileSelectedOrganization', () {
    ProviderContainer buildWithList(
      List<OrganizationResponse> available, {
      required String stored,
    }) {
      SharedPreferences.setMockInitialValues({
        OrganizationController.storageKey: stored,
      });
      container = ProviderContainer(
        overrides: [
          organizationServiceProvider.overrideWithValue(
            _FakeOrganizationService(available),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('replaces a stale id with the same-name organization', () async {
      buildWithList(
        const [
          OrganizationResponse(
            organizationId: 99,
            name: 'Acme',
            contactInformation: 'new@example.com',
            timezone: 'UTC',
          ),
        ],
        stored:
            '{"organizationId":7,"name":"Acme",'
            '"contactInformation":"acme@example.com","timezone":"UTC"}',
      );

      expect(await container.read(organizationControllerProvider.future), org);
      await container.read(organizationListProvider.future);

      final selected = container.read(selectedOrganizationProvider);
      expect(selected?.organizationId, 99);
      expect(selected?.name, 'Acme');
      expect(selected?.contactInformation, 'new@example.com');
    });

    test('clears the selection when no id or name match remains', () async {
      buildWithList(
        const [
          OrganizationResponse(
            organizationId: 99,
            name: 'Other',
            contactInformation: '',
            timezone: 'UTC',
          ),
        ],
        stored:
            '{"organizationId":7,"name":"Acme",'
            '"contactInformation":"acme@example.com","timezone":"UTC"}',
      );

      await container.read(organizationControllerProvider.future);
      await container.read(organizationListProvider.future);

      expect(container.read(selectedOrganizationProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OrganizationController.storageKey), isNull);
    });

    test('refreshes the stored object when the id still exists', () async {
      buildWithList(
        const [
          OrganizationResponse(
            organizationId: 7,
            name: 'Acme',
            contactInformation: 'updated@example.com',
            timezone: 'UTC',
          ),
        ],
        stored:
            '{"organizationId":7,"name":"Acme",'
            '"contactInformation":"acme@example.com","timezone":"UTC"}',
      );

      await container.read(organizationControllerProvider.future);
      await container.read(organizationListProvider.future);

      expect(
        container.read(selectedOrganizationProvider)?.contactInformation,
        'updated@example.com',
      );
    });
  });
}

class _FakeOrganizationService implements OrganizationService {
  _FakeOrganizationService(this._items);

  final List<OrganizationResponse> _items;

  @override
  Future<PaginatedResponse<OrganizationResponse>> getAllOrganizations([
    ListQuery query = const ListQuery(),
  ]) async {
    return PaginatedResponse<OrganizationResponse>(
      items: _items,
      total: _items.length,
      limit: query.limit ?? 0,
      offset: query.offset ?? 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
