import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/breakpoints.dart';
import '../core/theme/teven_theme.dart';
import '../models/organization.dart';
import '../models/permissions.dart';
import '../providers/auth_controller.dart';
import '../providers/organization_controller.dart';
import '../providers/organization_list.dart';
import '../routing/app_router.dart';
import 'nav_destinations.dart';
import 'organization_picker.dart';

/// The organization control in the chrome.
///
/// Tasks 3.6 and 3.8 together, because they are two branches of one widget:
/// `MainLayout.tsx:30-38` renders either a super-admin's switcher or a static
/// label, decided by whether the user holds `VIEW_USERS_GLOBAL`.
///
/// **One divergence from the React original.** `OrganizationSelector.tsx` is a
/// `<select>`, which on a phone opens a platform picker sheet anyway. Inside a
/// 72px rail there is no room for one, so the desktop rendering is a real
/// dropdown and the two narrower layouts open the sheet/dialog the event forms
/// use ([showOrganizationPicker]). The state, the persistence and the "All
/// Organizations" option are the same in all three — only the presentation
/// differs.
///
/// The layout size is passed rather than read from the context, because the
/// shell already decided it and this widget is rendered in three different
/// containers (drawer, rail, extended rail) that do not all share a `MediaQuery`
/// of the same width.
class OrganizationSelector extends ConsumerWidget {
  const OrganizationSelector({super.key, required this.layoutSize});

  final LayoutSize layoutSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `MainLayout.tsx:30`. Derived from a permission, not from a role name.
    if (!ref.watch(isSuperAdminProvider)) {
      return _StaticOrganizationLabel(layoutSize: layoutSize);
    }

    return switch (layoutSize) {
      // A `<select>` has room in the 256px extended rail and nowhere else.
      LayoutSize.desktop => const _OrganizationDropdown(),
      LayoutSize.tablet => const _CompactOrganizationButton(iconOnly: true),
      // The drawer is full width, so the name fits next to the icon.
      LayoutSize.mobile => const _CompactOrganizationButton(iconOnly: false),
    };
  }
}

/// The non-super-admin branch: the user's organization name.
///
/// `MainLayout.tsx:36` rendered a static label, because a non-super-admin cannot
/// change their organization scope. Task 7.23 makes it a link to the
/// organization's edit screen for anyone holding `MANAGE_ORGANIZATION` (their
/// own organization only; the backend enforces scope). It stays plain text
/// otherwise.
class _StaticOrganizationLabel extends ConsumerWidget {
  const _StaticOrganizationLabel({required this.layoutSize});

  final LayoutSize layoutSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(userContextProvider)?.user.organization;
    final theme = Theme.of(context);

    // `MainLayout.tsx` renders an empty span when there is no organization, so
    // nothing is shown rather than a placeholder.
    if (organization == null || organization.name.isEmpty) {
      return const SizedBox.shrink();
    }

    final canManageOwnOrg = ref
        .watch(permissionGateProvider)
        .has(Permission.manageOrganization);
    final onTap = canManageOwnOrg
        ? () => context.go(
            AppRoutes.organizationEditPath(organization.organizationId),
          )
        : null;

    final color = _onDarkRail(layoutSize)
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final label = Text(
      organization.name,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: color,
      ),
    );

    // A 72px rail has room for the glyph and the tooltip, not for the name.
    if (layoutSize == LayoutSize.tablet) {
      final icon = Icon(Icons.domain, color: theme.colorScheme.onPrimary);
      return Tooltip(
        message: organization.name,
        child: onTap == null
            ? icon
            : IconButton(
                onPressed: onTap,
                icon: icon,
                tooltip: organization.name,
              ),
      );
    }

    final child = onTap == null
        ? label
        : InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: label,
            ),
          );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: child,
      ),
    );
  }
}

/// The compact super-admin control. Opens [showOrganizationPicker].
///
/// `QuickOrganizationPickerModal.tsx` is the same control in the React app —
/// `OrganizationSelector` is not reachable from a phone-sized layout at all,
/// since the navbar collapses and the select is inside it.
class _CompactOrganizationButton extends ConsumerWidget {
  const _CompactOrganizationButton({required this.iconOnly});

  /// Whether the label is dropped in favour of an icon-plus-tooltip.
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedOrganizationProvider);
    final label = selected?.name ?? allOrganizationsLabel;
    final style = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );

    final button = TextButton.icon(
      onPressed: () => showOrganizationPicker(context),
      icon: const Icon(Icons.domain, size: 20),
      label: iconOnly ? const SizedBox.shrink() : Text(label),
      style: style,
    );

    // `TextButton` has no tooltip of its own, so icon-only needs a wrapper for
    // the name to be reachable by pointer *and* by screen reader.
    return iconOnly ? Tooltip(message: label, child: button) : button;
  }
}

/// The desktop super-admin control. A dropdown, reproducing the `<select>`.
///
/// **Every piece of text here is light, and none of that is the default.**
///
/// `DropdownButton` has three separate text paths which do not agree:
///
/// - the closed state is wrapped in `DefaultTextStyle(style: style)`, so
///   `style` alone fixes it;
/// - the hint is `style.copyWith(color: theme.hintColor)` — **`hintColor` wins
///   over `style`**, so the hint needs its own explicit `Text` style;
/// - menu items apply **no** `DefaultTextStyle` at all
///   (`_DropdownMenuItemContainer` is a bare `Align`), so they inherit the
///   ambient theme — the app's light-container ink.
///
/// Left alone, all three render near-black on the `#212529` rail and the
/// control is invisible except for the chevron. `dropdownColor` follows the
/// rail rather than staying light, because a light popup would need a *second*
/// ink on the same strings, and items render in both the closed and open
/// states — so no style can be scoped to one without breaking the other.
class _OrganizationDropdown extends ConsumerWidget {
  const _OrganizationDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedOrganizationProvider);
    final organizations = organizationsIncluding(
      ref.watch(organizationsProvider),
      selected,
    );

    // `OrganizationSelector.tsx:43-45` replaces the control outright with
    // `<div class="text-danger">Error: {message}</div>`. Reproduced, including
    // the prefix, but kept in place rather than swapped so the chrome keeps its
    // shape. The message is the server's, not a generic one.
    final failure = ref.watch(organizationListProvider).error;
    if (failure != null) {
      return Text(
        'Error: $failure',
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      );
    }

    const ink = TextStyle(color: Colors.white, fontSize: 14);
    const inkFaint = TextStyle(color: Colors.white70, fontSize: 14);

    return ConstrainedBox(
      // A `<select>` inside `.navbar-nav` sized itself to its content. Without
      // a bound, one long organization name pushes Profile and Logout out of
      // the extended rail.
      constraints: const BoxConstraints(maxWidth: 220),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selected?.organizationId,
          isExpanded: true,
          style: ink,
          dropdownColor: TevenTheme.darkSurface,
          // **The hint never renders**, and that is not an oversight.
          // `DropdownButton` resolves `value` with
          // `items.indexWhere((item) => item.value == value)`, so a `null`
          // `value` matches the "All Organizations" item — which is present
          // precisely so that the empty option is selectable — and the hint is
          // used only when *no* item matches. Styled anyway: a control whose
          // visible label depends on which branch of a widget's internal
          // lookup happens to fire is not worth leaving to chance.
          hint: const Text(
            allOrganizationsLabel,
            style: inkFaint,
            overflow: TextOverflow.ellipsis,
          ),
          icon: const Icon(Icons.expand_more, color: Colors.white),
          items: [
            // `OrganizationSelector.tsx:52` — the empty option means "no
            // organization filter", not "no organization".
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(allOrganizationsLabel, style: ink),
            ),
            for (final organization in organizations)
              DropdownMenuItem<int?>(
                value: organization.organizationId,
                child: Text(
                  organization.name,
                  style: ink,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (organizationId) {
            // `OrganizationSelector.tsx:31-41` resolves the id back to the full
            // object — the context stores a whole `OrganizationResponse`, not
            // an id. Choosing the empty option passes null, which clears the
            // stored key.
            ref
                .read(organizationControllerProvider.notifier)
                .select(_byId(organizations, organizationId));
          },
        ),
      ),
    );
  }
}

/// [organizationsIncluding] — see there for the assertion this avoids and for
/// why it was private here until Phase 5 needed it in three places.

/// Whether [size] renders on the dark rail rather than the light drawer.
///
/// Not a coincidence: the shell puts `LayoutSize.mobile` in the drawer and the
/// other two in the rail, so the container is fully determined by the size.
/// Derived once here because every ink decision below depends on it, and one
/// branch getting it wrong is invisible until something is rendered on a dark
/// background.
bool _onDarkRail(LayoutSize size) => size != LayoutSize.mobile;

/// `OrganizationSelector.tsx:52`.
const String allOrganizationsLabel = 'All Organizations';

/// The organization with [id], or null for the "all" option and for an id that
/// is not in the list.
///
/// Null rather than a throw, matching `OrganizationSelector.tsx:38`, which
/// falls back to `organization || null` for an id it cannot resolve.
OrganizationResponse? _byId(List<OrganizationResponse> organizations, int? id) {
  if (id == null) {
    return null;
  }
  for (final organization in organizations) {
    if (organization.organizationId == id) {
      return organization;
    }
  }
  return null;
}
