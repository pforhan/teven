import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/providers/organization_controller.dart';

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
          '"contactInformation":"acme@example.com"}',
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
}
