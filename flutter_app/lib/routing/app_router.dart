import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/util/local_date.dart';
import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/customers/customer_details_screen.dart';
import '../screens/customers/customer_form_screen.dart';
import '../screens/customers/customer_list_screen.dart';
import '../screens/events/event_form_screen.dart';
import '../screens/events/event_calendar_screen.dart';
import '../screens/events/event_day_screen.dart';
import '../screens/events/event_details_screen.dart';
import '../screens/events/event_list_screen.dart';
import '../screens/inventory/inventory_details_screen.dart';
import '../screens/inventory/inventory_form_screen.dart';
import '../screens/inventory/inventory_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/organizations/organization_list_screen.dart';
import '../screens/organizations/organization_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reports/report_list_screen.dart';
import '../screens/users/user_details_screen.dart';
import '../screens/users/user_form_screen.dart';
import '../screens/users/user_list_screen.dart';
import '../widgets/app_shell.dart';

/// Every path in the app, in one place.
///
/// A direct transcription of the original router. Constants rather than bare
/// strings because the router, the redirects, the login screen and the tests
/// all need to name the same locations, and a typo in a redirect is a silent
/// dead end rather than a compile error.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String events = '/events';
  static const String eventList = '/events/list';
  static const String eventCreate = '/events/create';
  static const String eventDay = '/events/day';
  static const String eventEdit = '/events/edit/:eventId';
  static const String eventDetails = '/events/:eventId';

  /// A concrete link to one day's view.
  ///
  /// the month grid had no day view, which is what kept a touch's
  /// tap from doing anything filed that gap and this is the route
  /// that closes it. Like the create route's `?date=`, the day is a query
  /// parameter rather than a path segment, because a day is a plain calendar
  /// day with no zone attached and no identity to speak of.
  static String eventDayUrlForDay(DateTime day) =>
      '${AppRoutes.eventDay}?date=${formatLocalDate(day)}';

  /// A concrete link to one event's details page.
  ///
  /// **Unlike [customerDetails] and its siblings, this route exists.** The
  /// original router declared `events/:eventId`, so the calendar's pills and the
  /// list's title links both resolved; this port provides the screen at the
  /// other end of it.
  ///
  /// [backToDay], when provided as a `yyyy-MM-dd` date, records that the user
  /// reached this event from that day's view. The details screen's back control
  /// then returns to the day view (and preserves this context when moving between
  /// other events on the same day) instead of returning to the calendar.
  static String eventDetailsPath(int eventId, {String? backToDay}) {
    final path = eventDetails.replaceFirst(':eventId', '$eventId');
    if (backToDay == null || backToDay.isEmpty) return path;
    return '$path?fromDay=$backToDay';
  }

  static String eventEditPath(int eventId) =>
      eventEdit.replaceFirst(':eventId', '$eventId');

  static const String customers = '/customers';
  static const String customerCreate = '/customers/create';
  static const String customerEdit = '/customers/edit/:customerId';

  /// A concrete link to a customer's detail page.
  ///
  /// ** sweep:** the route behind this shape did not exist, so the
  /// customer list's name links fell through the catch-all to `/events` — an
  /// organizer who could add or edit a customer could not view one. The screen
  /// at the other end of it is [CustomerDetailsScreen]; had deferred
  /// the build pending the backend's missing customer-events filter, and this
  /// is the field-rendering half it sanctioned.
  static const String customerDetails = '/customers/:customerId';

  static String customerDetailsPath(int customerId) =>
      customerDetails.replaceFirst(':customerId', '$customerId');

  static const String inventory = '/inventory';
  static const String inventoryCreate = '/inventory/create';
  static const String inventoryEdit = '/inventory/edit/:inventoryId';

  /// A concrete link to an inventory item's detail page.
  ///
  /// ** sweep:** the route behind this shape did not exist, so the
  /// inventory list's name links fell through the catch-all to `/events` — an
  /// organizer who could add or edit an item could not view one. The screen at
  /// the other end of it is [InventoryDetailsScreen].
  static const String inventoryDetails = '/inventory/:inventoryId';

  static String inventoryDetailsPath(int inventoryId) =>
      inventoryDetails.replaceFirst(':inventoryId', '$inventoryId');

  static String inventoryEditPath(int inventoryId) =>
      inventoryEdit.replaceFirst(':inventoryId', '$inventoryId');

  static const String organizations = '/organizations';
  static const String organizationCreate = '/organizations/create';
  static const String organizationEdit = '/organizations/edit/:organizationId';

  /// A concrete link to an organization's detail page.
  ///
  /// the original detail route was dead; link to the edit screen.
  static String organizationDetails(int organizationId) =>
      organizationEditPath(organizationId);

  static String organizationEditPath(int organizationId) =>
      organizationEdit.replaceFirst(':organizationId', '$organizationId');

  static const String users = '/users';
  static const String userCreate = '/users/create';
  static const String userEdit = '/users/edit/:userId';

  /// A concrete link to a user's detail page.
  ///
  /// The read-only screen at the other end of it is [UserDetailsScreen].
  static const String userDetails = '/users/:userId';

  static String userDetailsPath(int userId) =>
      userDetails.replaceFirst(':userId', '$userId');

  static String userEditPath(int userId) =>
      userEdit.replaceFirst(':userId', '$userId');

  static const String reports = '/reports';
  static const String profile = '/profile';

  static const String login = '/login';
  static const String register = '/register';

  /// A concrete link to the edit form for one customer.
  static String customerEditPath(int customerId) =>
      customerEdit.replaceFirst(':customerId', '$customerId');

  /// Where a signed-in user lacking a permission is sent.
  ///
  /// Matches the original protected-route guard.
  static const String unauthorizedFallback = events;

  /// Paths reachable without a session.
  ///
  /// The original router mounted only `/login` when `userContext` was null.
  /// `/register` sat outside that branch and was always mounted, because an
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
    // on it, so calling `router.refresh` synchronously here would re-run the
    // redirects against the previous context — the redirect would see a
    // signed-out user moments after the sign-in landed, and `/login` would
    // simply stay put. By the next microtask the dependency graph has settled.
    scheduleMicrotask(router.refresh);
  });
  ref.onDispose(router.dispose);

  return router;
});

/// The branch-and-guard redirect, reproducing two original mechanisms that
/// collapse into one function here.
///
/// The original router decided *which routes exist* from `userContext`; the
/// protected-route guard decided *who may see them*. go_router keeps the whole
/// table and filters it here, so the first becomes "send anyone signed out to
/// `/login` for every path but the public two", and the second becomes the
/// per-route [_requirePermission].
String? _redirect(Ref ref, GoRouterState state) {
  // The original app rendered "Loading..." while the boot fetch was in flight
  // and skipped routing entirely. Redirecting inside that window would bounce a
  // signed-in user to `/login` before the token had even been read.
  if (ref.read(authControllerProvider).isLoading) {
    return null;
  }

  final path = state.uri.path;

  if (ref.read(userContextProvider) == null) {
    return AppRoutes.public.contains(path) ? null : AppRoutes.login;
  }

  // `/login` stops existing once signed in. The original catch-all sent it to
  // `/`, whose index route redirected to `/events` — so `/events` is the
  // equivalent destination, and going there directly saves a hop.
  return path == AppRoutes.login ? AppRoutes.events : null;
}

/// The protected-route guard, as a per-route redirect.
///
/// Order matters and matches the original guard: unauthenticated before
/// unauthorized, so a signed-out visitor lands on `/login` instead of being
/// bounced to `/events` and then bounced again.
String? _requirePermission(Ref ref, List<Permission> required) {
  if (ref.read(userContextProvider) == null) {
    return AppRoutes.login;
  }

  final gate = ref.read(permissionGateProvider);
  if (gate.hasAny(required)) {
    return null;
  }

  // The original sent an unauthorized user to `/events` without checking
  // whether they may see it. If they cannot — a role holding, say, only a global
  // users permission — that is a redirect to a route that denies them in turn,
  // and go_router resolves it as a loop rather than the original router's silent
  // re-render. `/profile` is the one authenticated route with no permission
  // requirement, so it is always somewhere the user can land.
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
/// takes the first match, where React Router ranked static segments above
/// dynamic ones for free. So `/events/create` and `/events/edit/:eventId` must
/// precede `/events/:eventId`, or every "create" and "edit" link would render
/// the details screen with `eventId` set to `"create"`.
///
/// The authenticated branch is a [ShellRoute] replacing the original layout.
/// `/login` and `/register` sit outside it for the same reason they sat outside
/// the layout in the original app: the chrome assumed a session (it rendered the
/// user's organization and a Logout button), and an invitee following an emailed
/// link had none.
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
    // Reachable signed out — an invitee has no session.
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

  // Catch-all, replacing the original router's wildcard route.
  //
  // Registered last so it cannot shadow a real path. The original redirected to
  // `/` when signed in and `/login` when not; `/` itself redirected to
  // `/events`, so the signed-in destination is spelled out here rather than
  // chained through a second redirect.
  GoRoute(
    path: '/:unmatched(.*)',
    redirect: (context, state) => ref.read(userContextProvider) == null
        ? AppRoutes.login
        : AppRoutes.events,
  ),
];

/// Everything under the shell: the authenticated branch of the original router.
///
/// Nested one level down so the declaration order within it stays adjacent,
/// which is what makes the static-before-dynamic ordering above reviewable at
/// a glance.
List<RouteBase> _shellRoutes(Ref ref) => [
  GoRoute(
    path: '/',
    // The original index route redirected to `/events`.
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
    AppRoutes.eventDay,
    [Permission.viewEventsOrganization],
    (state) => EventDayScreen(
      date:
          state.uri.queryParameters['date'] ?? formatLocalDate(DateTime.now()),
    ),
  ),
  _guarded(
    ref,
    AppRoutes.eventEdit,
    [Permission.manageEventsOrganization],
    (state) =>
        EditEventScreen(eventId: int.parse(state.pathParameters['eventId']!)),
  ),
  _guarded(
    ref,
    AppRoutes.eventDetails,
    [Permission.viewEventsOrganization],
    (state) => EventDetailsScreen(
      // The route declares `:eventId` and every link in the app builds it
      // from an `int`, so a non-numeric value means someone hand-edited the
      // URL. `-1` rather than a throw, for the same reason as the customer
      // and inventory edit routes: the screen then asks for `/api/events/-1`,
      // which 404s, which lands on the error branch.
      eventId: int.tryParse(state.pathParameters['eventId'] ?? '') ?? -1,
      backToDay: state.uri.queryParameters['fromDay'],
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
  _guarded(
    ref,
    AppRoutes.customerDetails,
    [Permission.viewCustomersOrganization],
    (state) => CustomerDetailsScreen(
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
  _guarded(
    ref,
    AppRoutes.inventoryDetails,
    [Permission.viewInventoryOrganization],
    (state) => InventoryDetailsScreen(
      inventoryId:
          int.tryParse(state.pathParameters['inventoryId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.organizations, [
    Permission.viewOrganizationsGlobal,
  ], (_) => const OrganizationListScreen()),
  _guarded(ref, AppRoutes.organizationCreate, [
    Permission.manageOrganizationsGlobal,
  ], (_) => const OrganizationScreen()),
  _guarded(
    ref,
    AppRoutes.organizationEdit,
    [Permission.manageOrganizationsGlobal, Permission.manageOrganization],
    (state) => OrganizationScreen(
      organizationId:
          int.tryParse(state.pathParameters['organizationId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.users, [
    Permission.viewUsersOrganization,
  ], (_) => const UserListScreen()),
  // The original router gated create on *either* scope, unlike every other
  // create route. That asymmetry is deliberate here and the matching asymmetry
  // on the edit route remains worth a second look.
  _guarded(ref, AppRoutes.userCreate, [
    Permission.manageUsersGlobal,
    Permission.manageUsersOrganization,
  ], (_) => const CreateUserScreen()),
  _guarded(
    ref,
    AppRoutes.userEdit,
    [Permission.manageUsersGlobal, Permission.manageUsersOrganization],
    (state) => EditUserScreen(
      userId: int.tryParse(state.pathParameters['userId'] ?? '') ?? -1,
    ),
  ),
  _guarded(
    ref,
    AppRoutes.userDetails,
    [Permission.viewUsersOrganization],
    (state) => UserDetailsScreen(
      userId: int.tryParse(state.pathParameters['userId'] ?? '') ?? -1,
    ),
  ),

  _guarded(ref, AppRoutes.reports, [
    Permission.viewReportsOrganization,
  ], (_) => const ReportListScreen()),

  // The only authenticated route with no permission gate in the original
  // router.
  _guarded(ref, AppRoutes.profile, const [], (_) => const ProfileScreen()),
];
