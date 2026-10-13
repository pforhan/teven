import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../models/organization.dart';
import '../providers/auth_controller.dart';
import '../providers/organization_controller.dart';
import '../providers/organization_list.dart';
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

/// The non-super-admin branch: an organization name and nothing else.
///
/// `MainLayout.tsx:36` — `<span class="navbar-text">{userContext?.user?.organization?.name}</span>`.
/// No picker, because the user cannot change it: the server scopes their
/// requests to their own organization.
class _StaticOrganizationLabel extends ConsumerWidget {
  const _StaticOrganizationLabel({required this.layoutSize});

  final LayoutSize layoutSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(userContextProvider)?.user.organization.name;
    final theme = Theme.of(context);

    // `MainLayout.tsx` renders an empty span when there is no organization, so
    // nothing is shown rather than a placeholder.
    if (organization == null || organization.isEmpty) {
      return const SizedBox.shrink();
    }

    final label = Text(
      organization,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );

    // A 72px rail has room for the glyph and the tooltip, not for the name.
    if (layoutSize == LayoutSize.tablet) {
      return Tooltip(
        message: organization,
        child: Icon(Icons.domain, color: theme.colorScheme.onPrimary),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: label,
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
class _OrganizationDropdown extends ConsumerWidget {
  const _OrganizationDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedOrganizationProvider);
    final organizations = _including(
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
          color: theme.colorScheme.error,
        ),
      );
    }

    return ConstrainedBox(
      // A `<select>` inside `.navbar-nav` sized itself to its content. Without
      // a bound, one long organization name pushes Profile and Logout out of
      // the extended rail.
      constraints: const BoxConstraints(maxWidth: 220),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selected?.organizationId,
          isExpanded: true,
          hint: const Text(allOrganizationsLabel),
          icon: const Icon(Icons.expand_more, color: Colors.white),
          items: [
            // `OrganizationSelector.tsx:52` — the empty option means "no
            // organization filter", not "no organization".
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(allOrganizationsLabel),
            ),
            for (final organization in organizations)
              DropdownMenuItem<int?>(
                value: organization.organizationId,
                child: Text(organization.name, overflow: TextOverflow.ellipsis),
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

/// [loaded], with [selected] appended if it is not already among them.
///
/// **The React original gets this wrong in both directions.** It renders
/// `<select value={selected.organizationId}>` with options built from a list
/// fetched in a `useEffect`, so on the first render — and again on every
/// render before that fetch resolves — the value names an option that does not
/// exist. A browser quietly shows the first option instead; `DropdownButton`
/// asserts, and the assertion takes the screen down with it.
///
/// The list is empty until it resolves, so folding this in means the control
/// always has an item for whatever the control currently says is selected,
/// whether that is "nothing selected" or a restored selection the user cannot
/// otherwise see. An organization that has since been deleted keeps appearing
/// once, which is a smaller lie than pretending the user never chose it.
List<OrganizationResponse> _including(
  List<OrganizationResponse> loaded,
  OrganizationResponse? selected,
) {
  if (selected == null) {
    return loaded;
  }
  for (final organization in loaded) {
    if (organization.organizationId == selected.organizationId) {
      return loaded;
    }
  }
  return [...loaded, selected];
}

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
