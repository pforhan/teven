import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/widgets/create_form_organization.dart';

void main() {
  OrganizationResponse org(int id, String name) => OrganizationResponse(
    organizationId: id,
    name: name,
    contactInformation: '',
    timezone: 'UTC',
  );

  group('showGlobalOrganizationField', () {
    test(
      'shows dropdown only for global manager with no selected organization',
      () {
        expect(
          CreateFormOrganizationPolicy.showGlobalOrganizationField(
            canManageGlobal: true,
            selectedOrganization: null,
          ),
          isTrue,
        );
      },
    );

    test('hides dropdown when shell organization is selected', () {
      expect(
        CreateFormOrganizationPolicy.showGlobalOrganizationField(
          canManageGlobal: true,
          selectedOrganization: org(1, 'Acme'),
        ),
        isFalse,
      );
    });

    test('hides dropdown when caller cannot manage globally', () {
      expect(
        CreateFormOrganizationPolicy.showGlobalOrganizationField(
          canManageGlobal: false,
          selectedOrganization: null,
        ),
        isFalse,
      );
      expect(
        CreateFormOrganizationPolicy.showGlobalOrganizationField(
          canManageGlobal: false,
          selectedOrganization: org(1, 'Acme'),
        ),
        isFalse,
      );
    });
  });

  group('defaultFirstOrganization', () {
    test('keeps an explicit choice', () {
      final loaded = [org(1, 'Acme'), org(2, 'Globex')];
      final chosen = org(2, 'Globex');
      expect(
        CreateFormOrganizationPolicy.defaultFirstOrganization(loaded, chosen),
        same(chosen),
      );
    });

    test('defaults to first loaded organization when none chosen', () {
      final first = org(1, 'Acme');
      final loaded = [first, org(2, 'Globex')];
      expect(
        CreateFormOrganizationPolicy.defaultFirstOrganization(loaded, null),
        same(first),
      );
    });

    test('returns null when nothing is loaded and none chosen', () {
      expect(
        CreateFormOrganizationPolicy.defaultFirstOrganization(const [], null),
        isNull,
      );
    });
  });
}
