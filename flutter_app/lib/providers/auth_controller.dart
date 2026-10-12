import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../models/permissions.dart';
import '../models/user.dart';
// Deliberate import cycle: the router reads auth state to decide who may see
// which route, and a 401 redirect needs to navigate. Dart resolves library
// cycles fine; the dependency is read lazily inside methods, never at
// construction.
import '../routing/app_router.dart';
import 'service_providers.dart';

/// The signed-in user, or `null` when nobody is signed in.
///
/// Replaces `AuthContext` (`AuthContext.tsx:29-59`) and, with it, `useAuth()`.
/// The boot sequence is preserved: read the token, and only then ask the server
/// who the user is. A token in hand proves nothing — it may be stale, revoked,
/// or for a deleted account — so the context fetch is what decides.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserContextResponse?>(
      AuthController.new,
    );

class AuthController extends AsyncNotifier<UserContextResponse?> {
  @override
  Future<UserContextResponse?> build() async {
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) {
      return null;
    }

    try {
      return await ref.read(authServiceProvider).getUserContext();
    } on UnauthorizedException {
      // Already reported through `ApiClient.onUnauthorized`, which clears the
      // token and navigates. Returning null keeps the app in the logged-out
      // branch; rethrowing would only add an unhandled error on top of that.
      return null;
    } on ApiException catch (error, stack) {
      // Anything else — the server is down, DNS failed — is logged and treated
      // as "not signed in", exactly as `AuthContext.tsx:47` does. That means an
      // outage sends the user to the login screen rather than showing an error,
      // which is worth knowing but is the behaviour we are porting, not
      // inventing.
      debugPrint('AuthController: failed to fetch user context: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  /// Authenticates, then reloads the context.
  ///
  /// The React login screen calls `AuthService.login` and then
  /// `refetchUserContext()` (`Auth.tsx:29-30`). Folding both into one method
  /// means a screen cannot get the second half wrong.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    await ref
        .read(authServiceProvider)
        .login(username: username, password: password);

    // A login re-establishes the session, so the single-flight latch from the
    // previous one has to be released — otherwise the next genuine 401 is
    // swallowed and the user is left staring at a broken screen.
    ref.read(unauthorizedRedirectProvider.notifier).reset();

    await refresh();
  }

  /// Re-runs the boot sequence in place.
  ///
  /// Deliberately **not** `ref.invalidateSelf()`, which would drop the provider
  /// back into `loading`. The gate in `main.dart` would then replace the whole
  /// screen with "Loading..." — a full-page flash on every login and logout, on
  /// top of the redirect. Holding the previous state keeps the current screen
  /// up until the new context is in hand, which is also what the React app does
  /// by simply not clearing `userContext` until the fetch resolves.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(build);
    // Checked after the await, not before: `build` performs I/O, and the
    // provider can be invalidated while it is in flight — notably by a 401
    // landing mid-refresh. Assigning then throws "Cannot use the Ref ... after
    // it has been disposed" and takes the caller down with it.
    if (!ref.mounted) {
      return;
    }
    state = next;
  }

  /// Drops the token and returns to the logged-out branch.
  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    await refresh();
  }
}

/// The current user, or `null` when signed out or still booting.
///
/// The convenience accessor replacing `useAuth().userContext`.
final userContextProvider = Provider<UserContextResponse?>(
  (ref) => ref.watch(authControllerProvider).value,
);

/// The permissions granted to the signed-in user, as raw wire strings.
///
/// Replaces `usePermissions().permissions`, which defaulted to `[]` when
/// signed out. Same default, same reason: a screen must not have to distinguish
/// "no permissions" from "nobody is signed in" just to render.
final permissionsProvider = Provider<List<String>>(
  (ref) => ref.watch(userContextProvider)?.permissions ?? const <String>[],
);

/// Permission tests bound to the current user.
///
/// Replaces `usePermissions()` (`AuthContext.tsx:80-92`). Exists as a value
/// rather than a bare function so the router's guard can `watch` it and be
/// re-evaluated when the context changes, instead of reading a value that
/// could go stale mid-navigation.
final permissionGateProvider = Provider<PermissionGate>(
  (ref) => PermissionGate(ref.watch(permissionsProvider)),
);

/// A bound set of granted permissions.
///
/// The OR-semantics live here rather than at each call site because they are
/// easy to get wrong: an array requirement means "any of", not "all of". See
/// `Permissions.hasAny` for why that matters.
class PermissionGate {
  const PermissionGate(this.granted);

  final List<String> granted;

  /// Whether the user holds [permission].
  ///
  /// Matches `AuthContext.tsx:84`: a straight membership test against the
  /// context's permission list.
  bool has(Permission permission) => Permissions.has(granted, permission);

  /// Whether the user holds **any** of [required].
  ///
  /// Matches `ProtectedRoute.tsx:22-25`, which treats an array as `.some()`.
  /// `App.tsx:62` depends on it, gating user creation on either global or
  /// organization scope.
  bool hasAny(List<Permission> required) =>
      Permissions.hasAny(granted, required);
}

/// Whether a redirect due to a 401 is already under way.
///
/// Replaces the module-level `isRedirecting` flag at `AuthContext.tsx:16`.
/// Riverpod state rather than a bare variable, so that a test can reset it and
/// so that it is scoped to the container instead of the isolate.
final unauthorizedRedirectProvider =
    NotifierProvider<UnauthorizedRedirect, bool>(UnauthorizedRedirect.new);

class UnauthorizedRedirect extends Notifier<bool> {
  /// Build is synchronous, so the latch starts closed.
  @override
  bool build() => false;

  /// Handles one 401.
  ///
  /// Several in-flight requests can each see a 401 from the same dead token —
  /// the boot-time context fetch plus whatever else the first screen started.
  /// The first one through clears the token and navigates; the rest return
  /// immediately, which is what the React flag does. Without the latch, each
  /// would issue its own navigation and the user would watch the router fight
  /// itself to `/login`.
  ///
  /// The React version never resets its flag, which means a *second* 401 later
  /// in the session — after a token expiry, say — is silently ignored. That is
  /// not worth reproducing: [reset] is called on a successful login.
  void report(UnauthorizedException error) {
    if (state) {
      return;
    }
    state = true;
    unawaited(_redirect());
  }

  /// Releases the latch. Called when a login establishes a new session.
  void reset() => state = false;

  Future<void> _redirect() async {
    // Drop the token first. Clearing the context alone would leave a dead
    // token in storage, and the next boot would replay the same failure.
    await ref.read(authServiceProvider).logout();
    // The ref can go away while that write is in flight — the app shutting
    // down, or the container being disposed under a test. There is nothing
    // left to navigate in that case, so bail rather than throw from an
    // unawaited future, where the error would surface nowhere.
    if (!ref.mounted) {
      return;
    }
    await ref.read(authControllerProvider.notifier).refresh();
    if (!ref.mounted) {
      return;
    }
    ref.read(routerProvider).go(AppRoutes.login);
  }
}
