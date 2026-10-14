import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/customers/customer_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/placeholder_screen.dart';
import '../widgets/app_shell.dart';

/// Every path in the app, in one place.
///
/// A direct transcription of `App.tsx:38-68`. Constants rather than bare
/// strings because the router, the redirects, the login screen and the tests
/// all need to name the same locations, and a typo in a redirect is a silent
/// dead end rather than a compile error.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String events = '/events';
  static const String eventList = '/events/list';
  static const String eventCreate = '/events/create';
  static const String eventEdit = '/events/edit/:eventId';
  static const String eventDetails = '/events/:eventId';

  static const String customers = '/customers';
  static const String customerCreate = '/customers/create';
  static const String customerEdit = '/customers/edit/:customerId';

  static const String inventory = '/inventory';
  static const String inventoryCreate = '/inventory/create';
  static const String inventoryEdit = '/inventory/edit/:inventoryId';

  static const String organizations = '/organizations';
  static const String organizationCreate = '/organizations/create';
  static const String organizationEdit = '/organizations/edit/:organizationId';

  static const String users = '/users';
  static const String userCreate = '/users/create';
  static const String userEdit = '/users/edit/:userId';

  static const String reports = '/reports';
  static const String profile = '/profile';

  static const String login = '/login';
  static const String register = '/register';

  /// A concrete link to a customer's detail page.
  ///
  /// **There is no such route — in this app or in the React original.**
  /// `App.tsx` declares only `customers`, `customers/create` and
  /// `customers/edit/:customerId`; `frontend/src/components/customers/` has no
  /// `CustomerDetails` component at all, and `CustomerList.tsx:78` links to a
  /// path that matches nothing. The `*` catch-all (`App.tsx:67`) redirects to
  /// `/`, whose index route redirects to `/events`. That is why clicking a
  /// customer's name lands on the calendar.
  ///
  /// Reproduced rather than fixed, because parity is the rule through Phase 8
  /// and this is a dead link that predates the port rather than a regression
  /// introduced by it. Recorded in the discrepancy table with an owning task,
  /// since the screen it implies is missing from the plan entirely.
  static String customerDetails(int customerId) => '/customers/$customerId';

  /// A concrete link to the edit form for one customer.
  static String customerEditPath(int customerId) =>
      customerEdit.replaceFirst(':customerId', '$customerId');

  /// Where a signed-in user lacking a permission is sent.
  ///
  /// `ProtectedRoute.tsx:27`.
  static const String unauthorizedFallback = events;

  /// Paths reachable without a session — task 2.8.
  ///
  /// `App.tsx:40-41` mounts only `/login` when `userContext` is null.
  /// `/register` sits outside that branch and is always mounted, because an
  /// invitee following an emailed link has no session.
  static const Set<String> public = {login, register};
}

/// The app's router.
///
/// Created once and re-evaluated via [GoRouter.refresh] rather than rebuilt.
/// A provider that `watch`ed the auth state would build a fresh router on
/// every change, discarding the navigation stack and bouncing the user back to
/// `initialLocation` each time.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.events,
    redirect: (context, state) => _redirect(ref, state),
    routes: _routes(ref),
  );

  ref.listen(authControllerProvider, (previous, next) {
    // Deferred to a microtask, and not by accident. Riverpod notifies a
    // provider's own listeners *before* recomputing the providers that depend
    // on it, so calling `router.refresh()` synchronously here would re-run the
    // redirects against the previous context — the redirect would see a
    // signed-out user moments after the sign-in landed, and `/login` would
    // simply stay put. By the next microtask the dependency graph has settled.
    scheduleMicrotask(router.refresh);
  });
  ref.onDispose(router.dispose);

  return router;
});

/// The branch-and-guard redirect, reproducing two React mechanisms that
/// collapse into one function here.
///
/// `App.tsx:40-65` decides *which routes exist* from `userContext`;
/// `ProtectedRoute` decides *who may see them*. go_router keeps the whole table
/// and filters it here, so the first becomes "send anyone signed out to
/// `/login` for every path but the public two", and the second becomes the
/// per-route [_requirePermission].
String? _redirect(Ref ref, GoRouterState state) {
  // `App.tsx:34-36` renders "Loading..." while the boot fetch is in flight and
  // skips routing entirely. Redirecting inside that window would bounce a
  // signed-in user to `/login` before the token had even been read.
  if (ref.read(authControllerProvider).isLoading) {
    return null;
  }

  final path = state.uri.path;

  if (ref.read(userContextProvider) == null) {
    return AppRoutes.public.contains(path) ? null : AppRoutes.login;
  }

  // `/login` stops existing once signed in. The React catch-all (`App.tsx:67`)
  // sends it to `/`, whose index route redirects to `/events` — so `/events`
  // is the equivalent destination, and going there directly saves a hop.
  return path == AppRoutes.login ? AppRoutes.events : null;
}

/// The `ProtectedRoute` guard, as a per-route redirect.
///
/// Order matters and matches `ProtectedRoute.tsx:17-26`: unauthenticated
/// before unauthorized, so a signed-out visitor lands on `/login` instead of
/// being bounced to `/events` and then bounced again.
String? _requirePermission(Ref ref, List<Permission> required) {
  if (ref.read(userContextProvider) == null) {
    return AppRoutes.login;
  }

  final gate = ref.read(permissionGateProvider);
  if (gate.hasAny(required)) {
    return null;
  }

  // The React original sends an unauthorized user to `/events`
  // (`ProtectedRoute.tsx:27`) without checking whether they may see it. If
  // they cannot — a role holding, say, only a global users permission — that
  // is a redirect to a route that denies them in turn, and go_router resolves
  // it as a loop rather than React Router's silent re-render. `/profile` is the
  // one authenticated route with no permission requirement (`App.tsx:59`), so
  // it is always somewhere the user can land.
  return gate.has(Permission.viewEventsOrganization)
      ? AppRoutes.unauthorizedFallback
      : AppRoutes.profile;
}

/// A route behind the permission guard.
///
/// The check lives in a route redirect rather than a wrapper widget so the
/// screen is never built for a user who may not see it.
GoRoute _guarded(
  Ref ref,
  String path,
  List<Permission> required,
  Widget Function(GoRouterState state) builder,
) => GoRoute(
  path: path,
  redirect: (context, state) => _requirePermission(ref, required),
  builder: (context, state) => builder(state),
);

/// The route table.
///
/// **Declaration order is significant and is not alphabetical.** go_router
/// takes the first match, where React Router ranks static segments above
/// dynamic ones for free. So `/events/create` and `/events/edit/:eventId` must
/// precede `/events/:eventId`, or every "create" and "edit" link would render
/// the details screen with `eventId` set to `"create"`.
///
/// The authenticated branch is a [ShellRoute] — task 3.1, replacing
/// `MainLayout`. `/login` and `/register` sit outside it for the same reason
/// they sit outside the `MainLayout` element in `App.tsx:40-66`: the React
/// chrome assumes a session (it renders the user's organization and a Logout
/// button), and an invitee following an emailed link has none.
///
/// Screens land in Phases 4–8. Until then each one resolves to a
/// [PlaceholderScreen] carrying its route path, so the table is complete and
/// testable rather than half-built.
List<RouteBase> _routes(Ref ref) => [
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.register,
    // Reachable signed out — an invitee has no session (`App.tsx:66`).
    //
    // The token is read off the URI rather than passed through a prop by
    // something that already had it, because under the path strategy this *is*
    // the URL the invitee was emailed: `/register?token=...`. Navigation
    // callbacks come in from here so the screen never imports this file.
    builder: (context, state) => AcceptInvitationScreen(
      token: state.uri.queryParameters['token'],
      onReturnToApp: () => context.go(AppRoutes.events),
      onAccepted: () => context.go(AppRoutes.login),
    ),
  ),

  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: _shellRoutes(ref),
  ),

  // Catch-all, replacing `<Route path="*">` (`App.tsx:67`).
  //
  // Registered last so it cannot shadow a real path. The React original
  // redirects to `/` when signed in and `/login` when not; `/` itself
  // redirects to `/events`, so the signed-in destination is spelled out here
  // rather than chained through a second redirect.
  GoRoute(
    path: '/:unmatched(.*)',
    redirect: (context, state) => ref.read(userContextProvider) == null
        ? AppRoutes.login
        : AppRoutes.events,
  ),
];

/// Everything under the shell: the authenticated branch of `App.tsx:43-64`.
///
/// Nested one level down so the declaration order within it stays adjacent,
/// which is what makes the static-before-dynamic ordering above reviewable at
/// a glance.
List<RouteBase> _shellRoutes(Ref ref) => [
  GoRoute(
    path: '/',
    // `App.tsx:41`: the index route redirects to `/events`.
    redirect: (context, state) => AppRoutes.events,
  ),

  _guarded(ref, AppRoutes.events, [
    Permission.viewEventsOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.events)),
  _guarded(ref, AppRoutes.eventList, [
    Permission.viewEventsOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.eventList)),
  // `App.tsx:44`
  _guarded(
    ref,
    AppRoutes.eventDetails,
    [Permission.viewEventsOrganization],
    (state) => PlaceholderScreen.route(
      AppRoutes.eventDetails,
      params: state.pathParameters,
    ),
  ),
  _guarded(ref, AppRoutes.eventCreate, [
    Permission.manageEventsOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.eventCreate)),
  _guarded(
    ref,
    AppRoutes.eventEdit,
    [Permission.manageEventsOrganization],
    (state) => PlaceholderScreen.route(
      AppRoutes.eventEdit,
      params: state.pathParameters,
    ),
  ),

  _guarded(ref, AppRoutes.customers, [
    Permission.viewCustomersOrganization,
  ], (_) => const CustomerListScreen()),
  _guarded(ref, AppRoutes.customerCreate, [
    Permission.manageCustomersOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.customerCreate)),
  _guarded(
    ref,
    AppRoutes.customerEdit,
    [Permission.manageCustomersOrganization],
    (state) => PlaceholderScreen.route(
      AppRoutes.customerEdit,
      params: state.pathParameters,
    ),
  ),

  _guarded(ref, AppRoutes.inventory, [
    Permission.viewInventoryOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.inventory)),
  _guarded(ref, AppRoutes.inventoryCreate, [
    Permission.manageInventoryOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.inventoryCreate)),
  _guarded(
    ref,
    AppRoutes.inventoryEdit,
    [Permission.manageInventoryOrganization],
    (state) => PlaceholderScreen.route(
      AppRoutes.inventoryEdit,
      params: state.pathParameters,
    ),
  ),

  _guarded(ref, AppRoutes.organizations, [
    Permission.viewOrganizationsGlobal,
  ], (_) => const PlaceholderScreen.route(AppRoutes.organizations)),
  _guarded(ref, AppRoutes.organizationCreate, [
    Permission.manageOrganizationsGlobal,
  ], (_) => const PlaceholderScreen.route(AppRoutes.organizationCreate)),
  _guarded(
    ref,
    AppRoutes.organizationEdit,
    [Permission.manageOrganizationsGlobal],
    (state) => PlaceholderScreen.route(
      AppRoutes.organizationEdit,
      params: state.pathParameters,
    ),
  ),

  _guarded(ref, AppRoutes.users, [
    Permission.viewUsersOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.users)),
  // `App.tsx:62` gates create on *either* scope, unlike every other create
  // route. That asymmetry is deliberate here; task 5.12 flags the matching
  // asymmetry on the edit route for a second look.
  _guarded(ref, AppRoutes.userCreate, [
    Permission.manageUsersGlobal,
    Permission.manageUsersOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.userCreate)),
  _guarded(
    ref,
    AppRoutes.userEdit,
    [Permission.manageUsersGlobal],
    (state) => PlaceholderScreen.route(
      AppRoutes.userEdit,
      params: state.pathParameters,
    ),
  ),

  _guarded(ref, AppRoutes.reports, [
    Permission.viewReportsOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.reports)),

  // `App.tsx:59` — the only authenticated route with no permission gate.
  _guarded(
    ref,
    AppRoutes.profile,
    const [],
    (_) => const PlaceholderScreen.route(AppRoutes.profile),
  ),
];
