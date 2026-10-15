import 'package:flutter/material.dart';

/// A screen's heading and its single primary action.
///
/// `d-flex justify-content-between align-items-center mb-3` in the React
/// originals — heading on the left, `btn-primary` on the right.
///
/// A `Row` is the obvious translation and it overflows. At 500px the
/// organization screen's header overflowed **by 178 pixels**, because
/// "Create Organization" is a long label and a `Row` has nowhere to put it. The
/// mistake survived on the customer screen because "Create Customer" happens to
/// fit, and on the inventory screen because "Create Item" fits better still —
/// so the defect was in three places and visible in one, which is the argument
/// for the widget rather than the pattern. Found by a widget test at 500px,
/// not by a screenshot.
///
/// [Wrap] gives the same layout on one line and two lines below it, so the
/// action is never clipped at any width. `WrapAlignment.spaceBetween` keeps the
/// gap the `Row` had.
class ListScreenHeader extends StatelessWidget {
  const ListScreenHeader({super.key, required this.title, this.action});

  final String title;

  /// The primary action, or null when the user may not take it.
  ///
  /// Null rather than a disabled button: the React screens render the button
  /// only when the permission is held, and a greyed-out "Create" that cannot
  /// be pressed is a worse answer than no button.
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ?action,
    ],
  );
}
