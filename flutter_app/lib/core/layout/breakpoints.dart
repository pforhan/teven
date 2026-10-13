import 'package:flutter/widgets.dart';

/// The three layout sizes the chrome is built for.
///
/// Task 3.2. Not a device check: the app is web-first and the same browser is
/// resized rather than swapped, so the branch has to follow available width.
/// [AppBreakpoints.of] takes a width for exactly that reason — it is a pure
/// function of a number, which is what makes it testable without a browser.
enum LayoutSize {
  /// Phones, and anything narrower than [AppBreakpoints.tablet].
  mobile,

  /// Narrow windows and tablets.
  tablet,

  /// Wide windows and desktop.
  desktop,
}

/// Width thresholds, in logical pixels.
///
/// Chosen for this app rather than inherited from Material 3, whose defaults
/// (600 / 840) do not line up with where this chrome actually needs to change
/// shape. The React shell was `navbar-expand-lg`, i.e. a single hard switch at
/// Bootstrap's 992px breakpoint, and it collapsed rather than reflowed. Three
/// sizes are strictly more capable than one, but the numbers are ours.
///
/// [desktop] in particular is set so the extended navigation rail plus a
/// content column stays readable — a 1200px window has room for a 256px rail
/// and a comfortable table, a 1000px one does not.
abstract final class AppBreakpoints {
  const AppBreakpoints._();

  /// Below this width the chrome is a drawer behind a hamburger.
  static const double tablet = 700;

  /// At or above this width the navigation rail is extended.
  ///
  /// Exclusive of [tablet]: `700 <= width < 1100` is tablet, and `>= 1100` is
  /// desktop.
  static const double desktop = 1100;

  /// The layout size for a given [width].
  static LayoutSize of(double width) {
    if (width >= desktop) return LayoutSize.desktop;
    if (width >= tablet) return LayoutSize.tablet;
    return LayoutSize.mobile;
  }
}

/// Layout size lookups.
extension LayoutSizeContext on BuildContext {
  /// The layout size of the nearest [MediaQuery].
  ///
  /// Reads `MediaQuery.sizeOf` rather than the `Breakpoints` enum Flutter
  /// provides, because that enum has its own thresholds and would be a second
  /// source of truth for the same decision.
  LayoutSize get layoutSize => AppBreakpoints.of(MediaQuery.sizeOf(this).width);
}
