import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../core/services/auth_service.dart';
import '../core/services/crud_services.dart';
import '../core/services/event_service.dart';
import '../core/services/misc_services.dart';
import 'auth_controller.dart';

/// The encrypted token store.
///
/// Overridden in tests that need a token present without touching platform
/// storage — see `test/support/fakes.dart`.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const TokenStore.secure(),
);

/// The HTTP transport, or `null` for the real thing.
///
/// Exists so tests can hand [apiClientProvider] a stubbed dio without
/// duplicating the wiring below — the `onUnauthorized` hook in particular has
/// to be the production one, or the 401 redirect test would be asserting
/// against code it wrote itself.
final dioProvider = Provider<Dio?>((ref) => null);

/// The single HTTP entry point.
///
/// The one place a 401 is turned into navigation. Wiring
/// [ApiClient.onUnauthorized] here, rather than in the client, keeps the client
/// free of routing concerns and keeps the redirect single-flight (task 2.2).
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    ref.watch(tokenStoreProvider),
    dio: ref.watch(dioProvider),
  );
  client.onUnauthorized = (error) =>
      ref.read(unauthorizedRedirectProvider.notifier).report(error);
  ref.onDispose(client.close);
  return client;
});

final authServiceProvider = Provider<AuthService>(
  (ref) =>
      AuthService(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

final userServiceProvider = Provider<UserService>(
  (ref) => UserService(ref.watch(apiClientProvider)),
);

final organizationServiceProvider = Provider<OrganizationService>(
  (ref) => OrganizationService(ref.watch(apiClientProvider)),
);

final customerServiceProvider = Provider<CustomerService>(
  (ref) => CustomerService(ref.watch(apiClientProvider)),
);

final inventoryServiceProvider = Provider<InventoryService>(
  (ref) => InventoryService(ref.watch(apiClientProvider)),
);

final eventServiceProvider = Provider<EventService>(
  (ref) => EventService(ref.watch(apiClientProvider)),
);

final invitationServiceProvider = Provider<InvitationService>(
  (ref) => InvitationService(ref.watch(apiClientProvider)),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(ref.watch(apiClientProvider)),
);

final roleServiceProvider = Provider<RoleService>(
  (ref) => RoleService(ref.watch(apiClientProvider)),
);

/// Shared preferences, for the few values that outlive a session.
///
/// Only the super-admin's selected organization is persisted today (task 2.4);
/// the auth token deliberately is not — see `TokenStore`.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  // Hold the instance for the life of the container. `SharedPreferences`
  // caches internally, but dropping the provider would let a second copy be
  // built with its own cache, and the two could disagree about a write.
  ref.keepAlive();
  return prefs;
});
