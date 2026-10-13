import 'package:flutter/material.dart';

/// The app's theme.
///
/// Task 3.10. Replaces the Phase 0 placeholder, which built a scheme with
/// `ColorScheme.fromSeed` and therefore *derived* every colour from one seed
/// rather than carrying the React app's values across. From-seed is the right
/// default for a new app; for a port whose job is to land visually close to
/// what already ships, it moves the palette somewhere arbitrary and leaves
/// every later screen tuned against a colour nobody chose.
///
/// Every value below is the one the React app actually painted, with its
/// provenance. The Bootstrap 5 defaults are quoted because they are what an
/// unstyled `btn-primary`, `alert-danger` or `navbar-dark bg-dark` resolves to.
abstract final class TevenTheme {
  const TevenTheme._();

  /// Bootstrap `$primary` as this app uses it: `#3174ad`.
  ///
  /// Worth being precise about, because the React app has no Bootstrap theme
  /// override file — `frontend/src/index.css` sets only the body background.
  /// So `btn-primary` really did render Bootstrap's stock `#0d6efd`, and
  /// `#3174ad` is the colour the app uses explicitly, for event pills in
  /// `EventCalendar.tsx:177`. The plan names it "the primary", the Phase 0
  /// theme file had already adopted it, and a single coherent accent beats a
  /// palette of two nearly identical blues. Recorded rather than quietly
  /// resolved, since it is a judgement call and not a fact.
  static const Color primary = Color(0xFF3174AD);

  /// Page background, from `body { background-color: #f8f9fa }` in
  /// `frontend/src/index.css`. Bootstrap's `$light`.
  static const Color surface = Color(0xFFF8F9FA);

  /// Nav and rail background. Bootstrap's `$dark`, from
  /// `navbar navbar-expand-lg navbar-dark bg-dark` (`MainLayout.tsx:14`) —
  /// which is also where Material's notion of an "on-surface" ink comes from.
  static const Color darkSurface = Color(0xFF212529);

  /// Secondary text, links and disabled controls. Bootstrap's `$secondary`.
  static const Color secondary = Color(0xFF6C757D);

  /// Muted body copy, the `.text-muted` class. Bootstrap's `$gray-500`.
  static const Color muted = Color(0xFFADB5BD);

  /// Errors. Bootstrap's `$danger`, used by `.text-danger` in
  /// `OrganizationSelector.tsx:44` and by `.alert-danger` on the invitation
  /// screen.
  static const Color danger = Color(0xFFDC3545);

  /// Today's date highlight in the calendar, from `EventCalendar.tsx:193`.
  static const Color todayHighlight = Color(0xFFE7F0F7);

  /// The unresolved "requested" RSVP pill (`EventCalendar.tsx:177`).
  ///
  /// The React value is the CSS keyword `orange` — `#FFA500`.
  static const Color requestedRsvp = Color(0xFFFFA500);

  /// The full scheme.
  ///
  /// Explicit rather than derived, so the role each colour plays is visible at
  /// the point of use.
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,

    primary: primary,
    onPrimary: Colors.white,

    secondary: secondary,
    onSecondary: Colors.white,

    error: danger,
    onError: Colors.white,

    surface: surface,
    onSurface: darkSurface,

    // Bootstrap's own alias for the light body colour. Flutter has no direct
    // equivalent, and this is the "background behind surfaces" role.
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,

    outline: muted,
    outlineVariant: Color(
      0xFFE9ECEF,
    ), // Bootstrap `$gray-200`, `.list-group` border
  );

  static ThemeData light() {
    final textTheme = Typography.material2021().black.apply(
      bodyColor: darkSurface,
      displayColor: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      // The React shell is one dark navbar over a light page. The Material
      // default would put a light app bar there instead, which is a different
      // app rather than the same one rendered differently.
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primary,
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(color: Colors.white),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        scrimColor: Color(0x80000000),
      ),
      listTileTheme: const ListTileThemeData(iconColor: secondary),
    );
  }
}
