import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/models/organization.dart';
import 'package:teven_app/models/user.dart';
import 'package:teven_app/providers/auth_controller.dart';
import 'package:teven_app/providers/effective_organization_scope.dart';
import 'package:teven_app/providers/organization_controller.dart';
import 'package:teven_app/widgets/nav_destinations.dart';

void main() {
  const ownOrg = OrganizationResponse(
    organizationId: 1,
    name: 'Own Org',
    contactInformation: 'own@example.com',
    timezone: 'UTC',
  );
  const selectedOrg = OrganizationResponse(
    organizationId: 2,
    name: 'Selected Org',
    contactInformation: 'selected@example.com',
    timezone: 'America/Chicago',
  );
  const user = UserResponse(
    userId: 10,
    username: 'alice',
    email: 'alice@example.com',
    displayName: 'Alice',
    organization: ownOrg,
  );
  const context = UserContextResponse(user: user, permissions: <String>[]);

  ProviderContainer build({
    required bool isSuperAdmin,
    OrganizationResponse? selectedOrganization,
    UserContextResponse? userContext = context,
  }) {
    final container = ProviderContainer(
      overrides: [
        isSuperAdminProvider.overrideWithValue(isSuperAdmin),
        selectedOrganizationProvider.overrideWithValue(selectedOrganization),
        userContextProvider.overrideWithValue(userContext),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('superadmin with a selection acts in that organization', () {
    final container = build(
      isSuperAdmin: true,
      selectedOrganization: selectedOrg,
    );

    final scope = container.read(effectiveOrganizationScopeProvider);

    expect(scope.isSuperAdmin, isTrue);
    expect(scope.isAllOrganizations, isFalse);
    expect(scope.organization, selectedOrg);
    expect(scope.organizationId, 2);
    expect(scope.queryOrganizationId, 2);
    expect(scope.hasSpecificOrganization, isTrue);
  });

  test('superadmin with no selection acts in all organizations', () {
    final container = build(isSuperAdmin: true, selectedOrganization: null);

    final scope = container.read(effectiveOrganizationScopeProvider);

    expect(scope.isSuperAdmin, isTrue);
    expect(scope.isAllOrganizations, isTrue);
    expect(scope.organization, isNull);
    expect(scope.organizationId, isNull);
    expect(scope.queryOrganizationId, isNull);
    expect(scope.hasSpecificOrganization, isFalse);
  });

  test('non-superadmin acts in their own organization', () {
    final container = build(
      isSuperAdmin: false,
      selectedOrganization: selectedOrg,
    );

    final scope = container.read(effectiveOrganizationScopeProvider);

    expect(scope.isSuperAdmin, isFalse);
    expect(scope.isAllOrganizations, isFalse);
    expect(scope.organization, ownOrg);
    expect(scope.organizationId, 1);
    expect(scope.queryOrganizationId, 1);
  });

  test(
    'non-superadmin with no stored selection still uses own organization',
    () {
      final container = build(isSuperAdmin: false, selectedOrganization: null);

      final scope = container.read(effectiveOrganizationScopeProvider);

      expect(scope.isAllOrganizations, isFalse);
      expect(scope.organization, ownOrg);
      expect(scope.queryOrganizationId, 1);
    },
  );
}
