import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/breakpoints.dart';
import '../core/theme/teven_theme.dart';
import '../providers/auth_controller.dart';
import '../providers/time_zone_controller.dart';
import '../routing/app_router.dart';
import 'nav_destinations.dart';
import 'organization_selector.dart';
import 'time_zone_fix_dialog.dart';

/// The chrome every authenticated screen sits inside.
///
/// Replaces the original layout's `<nav>` plus main container: a `go_router`
/// `ShellRoute` wrapping the authenticated branch, so the routes under it
/// declare only their own path and permissions.
///
/// The React original is desktop-only: `navbar-expand-lg` collapses the whole
/// bar behind a hamburger below Bootstrap's 992px breakpoint, and there is no
/// second layout. This is a redesign at three sizes rather than a transcription:
///
/// | Width | Chrome |
/// |---|---|
/// | `< 700` | `NavigationDrawer` behind a hamburger, plus a `AppBar` |
/// | `700–1100` | `NavigationRail`, labels below icons |
/// | `>= 1100` | `NavigationRail`, `extended` — the rail *is* the sidebar |
///
/// The nav destinations, their order, their labels and their permission gates
/// are unchanged from the React original at every size. Only the container
/// changes.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  /// The routed screen. A `Scaffold` in every case, since each screen brings
  /// its own; the shell supplies only the surrounding chrome.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(timeZoneControllerProvider, (prev, next) {
      final mismatch = timeZoneMismatchFor(next.value);
      if (mismatch == null) {
        ref.read(timeZoneMismatchDismissedProvider.notifier).clear();
      }
    });
    // `LayoutBuilder` rather than a device or `MediaQuery` check, because on
    // web the meaningful event is a window resize and both of the others are
    // evaluated against the physical device rather than the space actually
    // available.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = AppBreakpoints.of(constraints.maxWidth);

        return switch (size) {
          LayoutSize.mobile => _DrawerShell(child: child),
          LayoutSize.tablet => _RailShell(extended: false, child: child),
          LayoutSize.desktop => _RailShell(extended: true, child: child),
        };
      },
    );
  }
}

/// The path the router is currently on.
///
/// Read from `GoRouterState` rather than passed in, so the rail's selection
/// follows a back-button press as well as an in-app tap — `NavigationRail` is
/// otherwise a widget that renders the index it was given and nothing else.
String _currentPath(BuildContext context) => GoRouterState.of(context).uri.path;

/// Mobile: a hamburger and a drawer.
class _DrawerShell extends ConsumerWidget {
  const _DrawerShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(timeZoneControllerProvider).value;
    final mismatch = timeZoneMismatchFor(resolution);
    final dismissed = ref.watch(timeZoneMismatchDismissedProvider);
    final showBadge = mismatch != null && !dismissed;

    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        // The brand was a link to `/` in the original layout; in the drawer it
        // has to stay a button, since `AppBar.title` is not a navigation target.
        leading: Builder(
          builder: (context) => IconButton(
            icon: showBadge
                ? Badge(
                    smallSize: 8,
                    backgroundColor: mismatch.hasWarning
                        ? Colors.amber
                        : Colors.lightBlueAccent,
                    child: const Icon(Icons.menu),
                  )
                : const Icon(Icons.menu),
            tooltip: showBadge
                ? 'Open navigation (timezone issue)'
                : 'Open navigation',
            onPressed: Scaffold.of(context).openDrawer,
          ),
        ),
      ),
      drawer: Drawer(
        child: _DrawerContents(onNavigate: () => Navigator.of(context).pop()),
      ),
      body: child,
    );
  }
}

/// Rail widths, set explicitly on the rail and reused to bound its trailing
/// group.
///
/// `NavigationRail` lays its own `Column` out with `CrossAxisAlignment.center`,
/// which hands every child *loose* width constraints — so anything in the
/// trailing slot that wants to stretch has to supply its own width. Relying on
/// the theme's `minWidth`/`minExtendedWidth` to happen to match would couple
/// the two silently, and a theme change would become an infinite-width layout
/// failure rather than a narrower rail.
const double _railWidth = 72;
const double _railExtendedWidth = 256;

/// Tablet and desktop: a rail, extended or not.
class _RailShell extends ConsumerWidget {
  const _RailShell({required this.extended, required this.child});

  final bool extended;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _visibleDestinations(ref);

    return Scaffold(
      body: FocusTraversalGroup(
        child: Row(
          children: [
            FocusTraversalGroup(
              child: NavigationRail(
                minWidth: _railWidth,
                minExtendedWidth: _railExtendedWidth,
                selectedIndex: _selectedIndex(
                  destinations,
                  _currentPath(context),
                ),
                onDestinationSelected: (index) =>
                    _go(context, destinations[index].route),
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _Brand(compact: !extended),
                ),
                trailing: Expanded(child: _RailTrailing(extended: extended)),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.icon),
                      // Always rendered, never just the selected one: a rail whose
                      // labels appear on selection makes the chrome reflow on every
                      // tap, which is what the collapsed Material default does.
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            // Bootstrap drew the navbar's bottom edge as a full-width border.
            // The rail's right edge is the same line.
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: FocusTraversalGroup(child: child)),
          ],
        ),
      ),
    );
  }
}

/// The brand.
///
/// The original layout rendered the text "Teven" linking to `/`. Collapsed into
/// a 72px rail there is no room for the word, so a calendar glyph stands in.
/// The original app's icon set was never fully installed, so there is no
/// existing glyph to match — and the navbar never carried a logo image, only
/// this text.
class _Brand extends StatelessWidget {
  const _Brand({this.color, this.compact = false});

  /// Overrides the default ink. The rail sits on [TevenTheme.darkSurface] and
  /// the drawer on the light page background, so the two cannot share a
  /// default — white-on-dark and dark-on-white are both required, and only the
  /// call site knows which it is.
  final Color? color;

  /// Whether to drop the word for a glyph.
  ///
  /// True in the collapsed rail, which is 72px wide. The word is not truncated
  /// there — a `Text` given 40px simply wraps, so "Teven" would render as two
  /// lines in the middle of the rail.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onPrimary;

    if (compact) {
      return Tooltip(
        message: 'Teven',
        child: Icon(Icons.calendar_month, color: ink),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Teven',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: ink),
      ),
    );
  }
}

/// The nav destinations the signed-in user may see.
///
/// The original layout wrapped each navigation item in its own permission test,
/// so an item the user cannot reach is absent rather than disabled.
List<NavDestination> _visibleDestinations(WidgetRef ref) {
  final gate = ref.watch(permissionGateProvider);
  return kPrimaryNavDestinations.where((d) => d.isVisibleTo(gate)).toList();
}

/// Index of the destination matching [path], or null.
///
/// **Longest-prefix, not equality.** `/events` is a prefix of `/events/list`
/// and of `/events/42`, and both of those render inside the Events item. A
/// first-match scan would put `/events/list` on whichever of the two happened
/// to come first in the list.
int? _selectedIndex(List<NavDestination> destinations, String path) {
  int? best;

  for (var i = 0; i < destinations.length; i++) {
    final route = destinations[i].route;
    if (path != route && !path.startsWith('$route/')) {
      continue;
    }
    if (best == null || route.length > destinations[best].route.length) {
      best = i;
    }
  }

  return best;
}

/// The rail's bottom group: organization, Profile, Logout.
///
/// The original layout's second list held the org selector, the Profile link and
/// the Logout button, as opposed to the first which held the gated navigation.
class _RailTrailing extends ConsumerWidget {
  const _RailTrailing({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = extended ? LayoutSize.desktop : LayoutSize.tablet;
    final trailingItems = <Widget>[
      OrganizationSelector(layoutSize: size),
      _ProfileAction(extended: extended),
      _LogoutAction(extended: extended),
    ];

    return SizedBox(
      width: extended ? _railExtendedWidth : _railWidth,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          // `Expanded` fills the leftover height, but a `MainAxisSize.min`
          // column still hugs the *top* of it — which put Profile and Logout
          // directly under the destinations instead of at the foot of the
          // rail, the way the original layout pushed them to the end of the
          // navbar. Invisible to a presence-only widget test; obvious the first
          // time the shell was rendered in a browser.
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in trailingItems)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: extended ? item : Center(child: item),
              ),
          ],
        ),
      ),
    );
  }
}

/// The drawer's contents: navigation, then the trailing group.
///
/// Same order as the rail — gated navigation first, session controls after —
/// which is the reading order the React navbar established.
class _DrawerContents extends ConsumerWidget {
  const _DrawerContents({required this.onNavigate});

  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _visibleDestinations(ref);
    final selectedIndex = _selectedIndex(destinations, _currentPath(context));

    void goTo(String route) {
      // Close first, navigate second. The other way round leaves the drawer
      // open over the new screen, and its scrim intercepts the first tap.
      onNavigate();
      _go(context, route);
    }

    return SafeArea(
      child: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => goTo(destinations[index].route),
        children: [
          // The brand, which the original layout put in the navbar rather than
          // the collapsed menu. In a drawer it is the one heading the panel
          // has, and it is the only place to say what the app is.
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 8),
            child: _Brand(color: TevenTheme.darkSurface),
          ),
          const Divider(height: 16),
          for (final destination in destinations)
            NavigationDrawerDestination(
              icon: Icon(destination.icon),
              // Same glyph as unselected: `NavigationDrawerDestination`
              // already paints a selected background behind the tile, so a
              // second visual cue would only add noise.
              selectedIcon: Icon(destination.icon),
              label: Text(destination.label),
            ),
          const Divider(height: 24),
          // Not a `ListTile`: the compact selector brings its own icon and
          // label, and a tile around it would show two organizations icons.
          // The React navbar has the same asymmetry — the org control is a
          // `<select>` while Profile and Logout are nav items.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: OrganizationSelector(layoutSize: LayoutSize.mobile),
          ),
          _DrawerProfileTile(onOpenProfile: () => goTo(AppRoutes.profile)),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              onNavigate();
              _logout(ref);
            },
          ),
        ],
      ),
    );
  }
}

/// The Profile link.
///
/// Ungated, because `/profile` is the one authenticated route with no
/// permission requirement in the original router — the router would redirect the
/// user straight back out.
class _ProfileAction extends ConsumerWidget {
  const _ProfileAction({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(timeZoneControllerProvider).value;
    final mismatch = timeZoneMismatchFor(resolution);
    final dismissed = ref.watch(timeZoneMismatchDismissedProvider);
    final showBadge = mismatch != null && !dismissed;
    final icon = _profileIcon(showBadge ? mismatch : null);

    if (!extended) {
      return IconButton(
        onPressed: () => _go(context, AppRoutes.profile),
        icon: icon,
        tooltip: showBadge ? 'Profile (timezone issue)' : 'Profile',
        style: _trailingStyle(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _go(context, AppRoutes.profile),
          icon: icon,
          label: const Text('Profile'),
          style: _trailingStyle(context),
        ),
        if (mismatch != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
            child: _TimeZoneMismatchInlineAction(
              resolution: resolution,
              mismatch: mismatch,
              dense: true,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
      ],
    );
  }
}

Widget _profileIcon(TimeZoneMismatch? mismatch) {
  const icon = Icon(Icons.person);
  if (mismatch == null) return icon;
  return Badge(
    smallSize: 8,
    backgroundColor: mismatch.hasWarning
        ? Colors.amber
        : Colors.lightBlueAccent,
    child: icon,
  );
}

class _DrawerProfileTile extends ConsumerWidget {
  const _DrawerProfileTile({required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(timeZoneControllerProvider).value;
    final mismatch = timeZoneMismatchFor(resolution);
    final dismissed = ref.watch(timeZoneMismatchDismissedProvider);
    final showBadge = mismatch != null && !dismissed;
    return ListTile(
      leading: _profileIcon(showBadge ? mismatch : null),
      title: const Text('Profile'),
      subtitle: mismatch == null
          ? null
          : _TimeZoneMismatchInlineAction(
              resolution: resolution,
              mismatch: mismatch,
              dense: true,
            ),
      onTap: onOpenProfile,
    );
  }
}

class _TimeZoneMismatchInlineAction extends StatelessWidget {
  const _TimeZoneMismatchInlineAction({
    required this.resolution,
    required this.mismatch,
    this.dense = false,
    this.foregroundColor,
  });

  final TimeZoneResolution? resolution;
  final TimeZoneMismatch mismatch;
  final bool dense;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = foregroundColor ?? theme.colorScheme.onSurfaceVariant;
    final iconColor = mismatch.hasWarning
        ? Colors.amber
        : (foregroundColor ?? theme.colorScheme.primary);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showTimeZoneFixDialog(context, resolution: resolution),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Possible timezone issue',
                style:
                    (dense
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.bodySmall)
                        ?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Logout action.
///
/// There is no navigation here. Logging out clears the context, and the
/// router's redirect — which already sends any non-public path to `/login` once
/// the context is null — moves the user. Doing it explicitly would be a second
/// mechanism racing the first, and the Phase 2 log records what that race cost
/// when it was reached the other way round.
class _LogoutAction extends ConsumerWidget {
  const _LogoutAction({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return extended
        ? TextButton.icon(
            onPressed: () => _logout(ref),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: _trailingStyle(context),
          )
        : IconButton(
            onPressed: () => _logout(ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            style: _trailingStyle(context),
          );
  }
}

ButtonStyle _trailingStyle(BuildContext context) => TextButton.styleFrom(
  foregroundColor: Theme.of(context).colorScheme.onPrimary,
  alignment: Alignment.centerLeft,
  visualDensity: VisualDensity.compact,
);

/// Navigates to [path].
void _go(BuildContext context, String path) => context.go(path);

/// Signs out. See [_LogoutAction] for why there is no navigation here.
void _logout(WidgetRef ref) =>
    ref.read(authControllerProvider.notifier).logout();
