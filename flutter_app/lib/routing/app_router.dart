import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/customers/create_customer_screen.dart';
import '../screens/events/create_event_screen.dart';
import '../screens/events/edit_event_screen.dart';
import '../screens/events/event_calendar_screen.dart';
import '../screens/events/event_list_screen.dart';
import '../screens/customers/customer_list_screen.dart';
import '../screens/customers/edit_customer_screen.dart';
import '../screens/inventory/create_inventory_screen.dart';
import '../screens/inventory/edit_inventory_screen.dart';
import '../screens/inventory/inventory_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/organizations/create_organization_screen.dart';
import '../screens/organizations/edit_organization_screen.dart';
import '../screens/organizations/organization_list_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/users/create_user_screen.dart';
import '../screens/users/edit_user_screen.dart';
import '../screens/users/user_list_screen.dart';
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

  /// A concrete link to one event's details page.
  ///
  /// **Unlike [customerDetails] and its siblings, this route exists.**
  /// `App.tsx:44` declares `events/:eventId`, so the calendar's pills and the
  /// list's title links both resolve. Task 7.6 replaces the placeholder at the
  /// other end of it.
  static String eventDetailsPath(int eventId) =>
      eventDetails.replaceFirst(':eventId', '$eventId');

  static String eventEditPath(int eventId) =>
      eventEdit.replaceFirst(':eventId', '$eventId');

  static const String customers = '/customers';
  static const String customerCreate = '/customers/create';
  static const String customerEdit = '/customers/edit/:customerId';

  static const String inventory = '/inventory';
  static const String inventoryCreate = '/inventory/create';
  static const String inventoryEdit = '/inventory/edit/:inventoryId';

  static const String organizations = '/organizations';
  static const String organizationCreate = '/organizations/create';
  static const String organizationEdit = '/organizations/edit/:organizationId';

  /// A concrete link to an inventory item's detail page.
  ///
  /// **There is no such route**, for the same reason there is no
  /// [customerDetails] screen: `App.tsx:53-55` declares only `inventory`,
  /// `inventory/create` and `inventory/edit/:inventoryId`, and
  /// `InventoryList.tsx:78` links to a path that matches nothing. Reproduced
  /// rather than fixed, on the same terms — see the discrepancy table.
  static String inventoryDetails(int inventoryId) => '/inventory/$inventoryId';

  static String inventoryEditPath(int inventoryId) =>
      inventoryEdit.replaceFirst(':inventoryId', '$inventoryId');

  /// A concrete link to an organization's detail page.
  ///
  /// Dead in the same way as [customerDetails] and [inventoryDetails]:
  /// `App.tsx:58-60` declares no `organizations/:organizationId` route, and
  /// `OrganizationList.tsx:80` links to one anyway.
  static String organizationDetails(int organizationId) =>
      '/organizations/$organizationId';

  static String organizationEditPath(int organizationId) =>
      organizationEdit.replaceFirst(':organizationId', '$organizationId');

  static const String users = '/users';
  static const String userCreate = '/users/create';
  static const String userEdit = '/users/edit/:userId';

  /// A concrete link to a user's detail page.
  ///
  /// **There is no such route**, the same defect as [customerDetails],
  /// [inventoryDetails] and [organizationDetails] — `App.tsx:61-63` declares
  /// only `users`, `users/create` and `users/edit/:userId`, and
  /// `UserList.tsx:123` links to a path that matches nothing. Reproduced, and
  /// task 10.20 owns all four.
  static String userDetails(int userId) => '/users/$userId';

  static String userEditPath(int userId) =>
      userEdit.replaceFirst(':userId', '$userId');

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
  ], (_) => const EventCalendarScreen()),
  _guarded(ref, AppRoutes.eventList, [
    Permission.viewEventsOrganization,
  ], (_) => const EventListScreen()),
  _guarded(ref, AppRoutes.eventCreate, [
    Permission.manageEventsOrganization,
  ], (_) => const CreateEventScreen()),
  _guarded(
    ref,
    AppRoutes.eventEdit,
    [Permission.manageEventsOrganization],
    (state) =>
        EditEventScreen(eventId: int.parse(state.pathParameters['eventId']!)),
  ),
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

  _guarded(ref, AppRoutes.customers, [
    Permission.viewCustomersOrganization,
  ], (_) => const CustomerListScreen()),
  _guarded(ref, AppRoutes.customerCreate, [
    Permission.manageCustomersOrganization,
  ], (_) => const CreateCustomerScreen()),
  _guarded(
    ref,
    AppRoutes.customerEdit,
    [Permission.manageCustomersOrganization],
    (state) => EditCustomerScreen(
      // The route declares `:customerId` and every link in the app builds it
      // from an `int`, so a non-numeric value means someone hand-edited the
      // URL. `-1` rather than a throw: `int.parse` would take the app down, and
      // a catch-all redirect does not apply to a route that already matched.
      // The screen then asks for `/api/customers/-1`, which 404s, which lands
      // on the error branch — a message saying there is no such customer, which
      // is what happened.
      customerId: int.tryParse(state.pathParameters['customerId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.inventory, [
    Permission.viewInventoryOrganization,
  ], (_) => const InventoryListScreen()),
  _guarded(ref, AppRoutes.inventoryCreate, [
    Permission.manageInventoryOrganization,
  ], (_) => const CreateInventoryScreen()),
  _guarded(
    ref,
    AppRoutes.inventoryEdit,
    [Permission.manageInventoryOrganization],
    (state) => EditInventoryScreen(
      inventoryId:
          int.tryParse(state.pathParameters['inventoryId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.organizations, [
    Permission.viewOrganizationsGlobal,
  ], (_) => const OrganizationListScreen()),
  _guarded(ref, AppRoutes.organizationCreate, [
    Permission.manageOrganizationsGlobal,
  ], (_) => const CreateOrganizationScreen()),
  _guarded(
    ref,
    AppRoutes.organizationEdit,
    [Permission.manageOrganizationsGlobal],
    (state) => EditOrganizationScreen(
      organizationId:
          int.tryParse(state.pathParameters['organizationId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.users, [
    Permission.viewUsersOrganization,
  ], (_) => const UserListScreen()),
  // `App.tsx:62` gates create on *either* scope, unlike every other create
  // route. That asymmetry is deliberate here; task 5.12 flags the matching
  // asymmetry on the edit route for a second look.
  _guarded(ref, AppRoutes.userCreate, [
    Permission.manageUsersGlobal,
    Permission.manageUsersOrganization,
  ], (_) => const CreateUserScreen()),
  _guarded(
    ref,
    AppRoutes.userEdit,
    [Permission.manageUsersGlobal],
    (state) => EditUserScreen(
      userId: int.tryParse(state.pathParameters['userId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.reports, [
    Permission.viewReportsOrganization,
  ], (_) => const PlaceholderScreen.route(AppRoutes.reports)),

  // `App.tsx:59` — the only authenticated route with no permission gate.
  _guarded(ref, AppRoutes.profile, const [], (_) => const ProfileScreen()),
];
