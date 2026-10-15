import 'package:flutter/material.dart';

/// A record's name, linking to its detail page.
///
/// The React lists wrapped the name column in a react-router `<Link>` and put
/// the row's action buttons in an absolutely-positioned box over it
/// (`CustomerList.tsx:77-89`, and the same shape in `InventoryList` and
/// `OrganizationList`). That works in a table and not in a card, so
/// [ResponsiveListView] moved the actions to their own column and this became
/// the whole of what the name column still needs.
///
/// Three screens use it, which is why it is here rather than a private class in
/// each. None of the three destinations exists — see
/// `AppRoutes.customerDetails` — so the link is reproduced as it stands, and
/// naming the record is still what makes the row readable.
class RecordLinkButton extends StatelessWidget {
  const RecordLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // **Load-bearing, and it was not obvious.** `RenderTable` hands every
      // cell a *tight* width — the full column — so a cell widget decides for
      // itself where its content sits, and `TextButton` centres its label by
      // default. With the column sized to its content, that put "City Park" in
      // the middle of the name column while "Jones Corporation" sat at its left
      // edge, so the names looked raggedly indented. Every other column is a
      // `Text`, which is left-aligned, which is why only this one looked wrong.
      //
      // Found in a browser screenshot during task 4.4's verification pass;
      // `customer_list_screen_test.dart` did not and could not see it, because
      // the symptom is two names of different lengths side by side and the
      // fixtures were `"Acme"` and `""`.
      alignment: Alignment.centerLeft,
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
