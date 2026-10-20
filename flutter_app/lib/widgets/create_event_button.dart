import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/util/local_date.dart';
import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../providers/organization_controller.dart';
import '../routing/app_router.dart';
import 'organization_picker.dart';

/// The "Create Event" button, and the organization it needs before it will work.
///
/// **Built once rather than per screen, because task 7.3's two versions of this
/// control disagreed and only one of them was right.** The calendar button
/// (`EventCalendar.tsx:254-268`) carried a `pendingNavigateUrl` and resumed the
/// navigation after a selection; the list-page button
/// (`EventListPage.tsx:169-181`) had none, so dismissing the picker did
/// nothing and a selection always went to a bare `/events/create` — losing the
/// `?date=` a calendar click had supplied.
///
/// [resumeUrl] is the one answer to that, and it is a parameter rather than a
/// constant so both callers can pass what they mean: the header buttons pass
/// nothing and get [AppRoutes.eventCreate], and a tapped day cell passes its
/// own URL.
///
/// **Why the picker is asked for *before* navigating rather than after.** A
/// `VIEW_USERS_GLOBAL` user with no organization selected lands on the create
/// form's "Organization Required" card (`CreateEventForm.tsx:210-239`) and has
/// to tap through it. That card exists because the server refuses the create
/// anyway — `EventService.kt:20-22` throws `"organizationId is required for
/// MANAGE_EVENTS_GLOBAL users"` — so the button is where the requirement gets
/// *answered*, and answering it here is the difference between one tap and three.
class CreateEventButton extends ConsumerWidget {
  const CreateEventButton({
    super.key,
    this.label = 'Create Event',
    this.resumeUrl,
  });

  /// The button's text.
  final String label;

  /// Where to navigate, when it is not simply [AppRoutes.eventCreate].
  ///
  /// Null for the header button on either screen. A calendar day tap builds its
  /// own — see [createForDay].
  final String? resumeUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null rather than a disabled button, matching `ListScreenHeader.action`
    // and the React screens, which render the button only when the permission
    // is held. `EventCalendar.tsx:75` and `EventListPage.tsx:23` derive it
    // independently of each other and of the route guard, and the screen you
    // are on is reachable without it — `/events` needs only `VIEW_*`.
    if (!ref
        .watch(permissionGateProvider)
        .has(Permission.manageEventsOrganization)) {
      return const SizedBox.shrink();
    }

    return FilledButton.icon(
      onPressed: () => unawaited(create(context, ref, resumeUrl: resumeUrl)),
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }

  /// Navigates to the create form, asking for an organization first when one is
  /// needed and not held.
  ///
  /// Static, because a tapped calendar day has no button to own it — the day
  /// cell is table_calendar's, and the handler is the screen's.
  static Future<void> create(
    BuildContext context,
    WidgetRef ref, {
    String? resumeUrl,
  }) async {
    final target = resumeUrl ?? AppRoutes.eventCreate;
    final gate = ref.read(permissionGateProvider);
    final organization = ref.read(selectedOrganizationProvider);

    // Both conditions, not either. `EventCalendar.tsx:137` is
    // `hasPermission('VIEW_USERS_GLOBAL') && !selectedOrganization` — the
    // permission decides whether a selection is *possible* at all, since only a
    // global user gets the switcher. Without it the button would demand an
    // organization from someone who has no way to choose one.
    //
    // `read`, not `watch`: this runs from a tap handler, and there is no build
    // here to register a dependency with.
    if (!gate.has(Permission.viewUsersGlobal) || organization != null) {
      context.go(target);
      return;
    }

    // Dismissed with no choice is a cancellation, and `showOrganizationPicker`
    // answers `null` for the barrier tap and the back gesture as well as for the
    // Cancel button. Navigating then would defeat the picker — which is exactly
    // what the list-page button did in the React original, where `onHide` had
    // no pending URL to clear and so could not tell "cancelled" from "chosen".
    final selected = await showOrganizationPicker(context);
    if (selected == null || !context.mounted) return;
    context.go(target);
  }

  /// [create], for a tapped calendar day cell.
  ///
  /// The day becomes `?date=yyyy-MM-dd`, which `CreateEventScreen` reads to
  /// prefill its date field — the same query parameter `EventCalendar.tsx:136`
  /// built. Handed as a [DateTime] rather than a formatted string so the one
  /// place that knows the wire format is [eventCreateUrlForDay].
  static Future<void> createForDay(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
  ) => create(context, ref, resumeUrl: eventCreateUrlForDay(day));
}

/// The create URL for one calendar day.
///
/// `EventCalendar.tsx:136` builds `` `/events/create?date=${date}` `` from a
/// tapped cell. A function rather than an inline string at the call sites
/// because the query parameter is a contract with the create screen, and a
/// format written in two places is one that will be fixed in one.
String eventCreateUrlForDay(DateTime day) =>
    '${AppRoutes.eventCreate}?date=${formatLocalDate(day)}';
