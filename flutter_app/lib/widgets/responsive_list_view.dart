import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/layout/breakpoints.dart';
import '../core/services/list_query.dart';
import '../core/theme/teven_theme.dart';

/// One column of a [ResponsiveListView].
///
/// `TableView.tsx:5-10`, minus the `'actions'` magic key — actions are a
/// separate widget here because they are not a column of data and putting them
/// in the list is what let them drift per call site.
class ListColumn<T> {
  const ListColumn({
    required this.key,
    required this.label,
    this.text,
    this.render,
    this.sortable = false,
  }) : assert(
         text == null || render == null,
         'A column takes either a plain text extractor or a custom renderer, '
         'not both — text is the default for render.',
       );

  /// Stable identifier for the column, used for the sort key and as the
  /// React original's `keyof T` accessor.
  final String key;

  /// Header text, shown in both layouts.
  final String label;

  /// Plain-value accessor, for the columns that are just a field.
  final String Function(T item)? text;

  /// Custom cell. Takes precedence over [text] when both are given.
  final Widget Function(BuildContext context, T item)? render;

  /// Whether the header is a sort control.
  ///
  /// `sortBy` on the screen is compared against [key]; the widget only reports
  /// the click. `CustomerList.tsx:50-56` owns the toggle.
  final bool sortable;

  /// The cell for [item].
  Widget build(BuildContext context, T item) {
    final render = this.render;
    if (render != null) return render(context, item);

    final text = this.text;
    if (text == null) return const SizedBox.shrink();

    return Text(text(item));
  }
}

/// An icon-only action on a row, or on a card at mobile.
class ListRowAction {
  const ListRowAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;

  /// The tooltip **and** the accessible name.
  ///
  /// Task 4.3: `Tooltip` supplies both — it is not decoration here. It shows on
  /// hover, and it is what a screen reader announces for an icon-only button,
  /// which would otherwise be unlabelled since the React `OverlayTrigger` only
  /// ever showed a pointer tooltip.
  final String label;

  final VoidCallback onPressed;

  /// Paints the button in the error colour. `CustomerList.tsx:82-86` used
  /// `btn-light` for both; the delete is styled separately here because a
  /// destructive control that looks identical to the edit beside it is the
  /// kind of thing a phone user mis-taps.
  final bool isDestructive;
}

/// A list of records: a table where there is room for one, cards where there
/// is not.
///
/// Replaces `TableView.tsx` (90 lines) with the redesign Phase 4 calls for.
///
/// | Width | Layout |
/// |---|---|
/// | `< 1100` | one card per record, actions always visible |
/// | `>= 1100` | a table, actions revealed on hover |
///
/// **Tablet gets cards, not a narrow table.** The plan says "table at desktop,
/// card at mobile" and leaves the middle unsaid; at 700px the rail already
/// takes 72px and the four customer columns plus an actions column do not
/// survive the remainder. Cards are the honest answer for a squeezed table
/// rather than a horizontally scrolling one.
///
/// The width is the list's **own** available width, not the window's, because
/// that is what `LayoutBuilder` reports. Inside the app shell that means the
/// desktop layout starts at a window of roughly 1360px — the 256px extended
/// rail comes off the top first.
class ResponsiveListView<T> extends StatefulWidget {
  const ResponsiveListView({
    super.key,
    required this.data,
    required this.columns,
    required this.idOf,
    this.actions,
    this.sortBy,
    this.sortOrder,
    this.onSort,
    this.emptyMessage = 'Nothing to show.',
    this.revealActionsOnHover,
  });

  final List<T> data;

  final List<ListColumn<T>> columns;

  /// The record's identity — `keyField` in the React original, and what the
  /// hover state compares.
  final Object Function(T item) idOf;

  /// Per-row actions, or null when the user may not take any.
  ///
  /// Null rather than an empty list, so that a screen gated on a permission
  /// does not have to reserve an empty column for actions nobody can see.
  final List<ListRowAction> Function(BuildContext context, T item)? actions;

  /// The column currently sorted by, if any.
  final String? sortBy;

  final SortOrder? sortOrder;

  /// Called with a column [key] when a sortable header is tapped. The screen
  /// decides what that means, exactly as `CustomerList.tsx:50` does.
  final ValueChanged<String>? onSort;

  final String emptyMessage;

  /// Whether row actions appear only on hover.
  ///
  /// Defaults to [kIsWeb] above the card breakpoint: hover-revealed actions are
  /// a pointer affordance, and a native touch device has no hover to reveal
  /// them. Overridable because widget tests run on the VM, where [kIsWeb] is
  /// false and the hover path would otherwise be unreachable from a test.
  final bool? revealActionsOnHover;

  @override
  State<ResponsiveListView<T>> createState() => _ResponsiveListViewState<T>();
}

class _ResponsiveListViewState<T> extends State<ResponsiveListView<T>> {
  /// Which row the pointer is over, or null.
  ///
  /// A [ValueNotifier] rather than widget state so that hovering one row
  /// rebuilds two buttons rather than every cell of every row.
  final ValueNotifier<Object?> _hovered = ValueNotifier<Object?>(null);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The `card` + `card-body` of the React original. A plain bordered
    // container rather than a `Card`, because at mobile the layout nests a
    // `Card` per record inside it.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = AppBreakpoints.of(constraints.maxWidth);
          // Two independent decisions that happen to share a breakpoint. The
          // layout follows the space available; the hover affordance follows
          // the input device, and only exists in the table at all.
          final isTable = size == LayoutSize.desktop;
          final revealOnHover =
              widget.revealActionsOnHover ?? (isTable && kIsWeb);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isTable && widget.onSort != null)
                _SortControl<T>(
                  columns: widget.columns,
                  sortBy: widget.sortBy,
                  sortOrder: widget.sortOrder,
                  onSort: widget.onSort!,
                ),
              if (widget.data.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              else if (isTable)
                _TableLayout<T>(state: this, revealOnHover: revealOnHover)
              else
                _CardLayout<T>(state: this),
            ],
          );
        },
      ),
    );
  }

  /// The row's action buttons, or nothing when the user may take none.
  ///
  /// Shared by both layouts so a screen wires its buttons once — which is the
  /// point of the redesign: `TableView.tsx` had six call sites, each of which
  /// built its own `OverlayTrigger` pair.
  List<Widget> actionButtons(BuildContext context, T item) {
    final actions = widget.actions;
    if (actions == null) return const [];

    return [
      for (final action in actions(context, item))
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Icon(action.icon),
            // Task 4.3 — hover tooltip and accessible name in one widget.
            tooltip: action.label,
            color: action.isDestructive
                ? Theme.of(context).colorScheme.error
                : null,
            onPressed: action.onPressed,
          ),
        ),
    ];
  }
}

class _TableLayout<T> extends StatelessWidget {
  const _TableLayout({required this.state, required this.revealOnHover});

  final _ResponsiveListViewState<T> state;
  final bool revealOnHover;

  @override
  Widget build(BuildContext context) {
    final widget = state.widget;

    // **The table fills the width it is given and its text wraps.** This was
    // `IntrinsicColumnWidth` inside a horizontal `SingleChildScrollView`, and
    // both were wrong. Intrinsic sized each column to its content, so a
    // customer with a long address pushed the notes column 3915px to the right,
    // off screen entirely. The scroll view is gone because it handed the table
    // an *unbounded* width, which flex columns cannot divide — a fixed-size
    // table and a flexible one are opposites, and the second is what a data
    // table in a bounded pane wants.
    //
    // What Bootstrap's `table-responsive` does, minus the scrolling: the table
    // shares out the available width and cells wrap. The scroll was only ever
    // reachable *because* the widths were intrinsic, so losing it loses
    // nothing.
    //
    // The first column gets a double share because it holds the record's name,
    // which is the one column worth reading first. A guess, and the thing to
    // revisit if a screen's columns want something else.
    return Table(
      columnWidths: {
        for (final (index, _) in widget.columns.indexed)
          index: FlexColumnWidth(index == 0 ? 2 : 1),
        if (widget.actions != null)
          widget.columns.length: const FixedColumnWidth(_actionsWidth),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: TevenTheme.darkSurface),
          children: [
            for (final column in widget.columns) _headerCell(context, column),
            if (widget.actions != null) const SizedBox(height: _rowHeight),
          ],
        ),
        for (final (index, item) in widget.data.indexed)
          _row(context, item, striped: index.isOdd),
      ],
    );
  }

  /// The sort control in a header cell.
  ///
  /// `TableView.tsx:54-64`: label, then an arrow for the active column and a
  /// faint one for the rest. The arrow here is Material's rather than
  /// `FaSortUp`/`FaSortDown` — task 3.11, no attempt at glyph parity.
  Widget _headerCell(BuildContext context, ListColumn<T> column) {
    final widget = state.widget;
    final active = widget.sortBy == column.key;
    final label = Text(
      column.label,
      style: const TextStyle(color: Colors.white),
    );

    if (!column.sortable || widget.onSort == null) {
      return _headerContent(label, null);
    }

    final icon = Icon(
      active
          ? (widget.sortOrder == SortOrder.asc
                ? Icons.arrow_upward
                : Icons.arrow_downward)
          : Icons.swap_vert,
      size: 16,
      color: Colors.white.withValues(alpha: active ? 1 : 0.3),
    );

    return _headerContent(
      InkWell(
        onTap: () => widget.onSort!(column.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [label, const SizedBox(width: 8), icon],
          ),
        ),
      ),
      column.sortable,
    );
  }

  Widget _headerContent(Widget child, bool? interactive) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.centerLeft,
    child: MouseRegion(
      cursor: interactive == true
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: child,
    ),
  );

  TableRow _row(BuildContext context, T item, {required bool striped}) {
    final widget = state.widget;
    final id = widget.idOf(item);

    return TableRow(
      // `table-striped` — every other row shaded, as Bootstrap did.
      decoration: striped
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
            )
          : null,
      children: [
        for (final column in widget.columns)
          _hoverRegion(
            id,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: column.build(context, item),
            ),
          ),
        if (widget.actions != null)
          _hoverRegion(
            id,
            ValueListenableBuilder<Object?>(
              valueListenable: state._hovered,
              builder: (context, hovered, _) => SizedBox(
                // Fixed in **both** states. The hidden state was a
                // `SizedBox(height: 48)` and the shown state a bare `Row` of
                // `IconButton`s, whose height comes from the theme — so the row
                // could change height as the pointer crossed it. Fixed here
                // rather than derived, because "the button happens to be 48
                // today" is not a constraint worth relying on.
                height: _rowHeight,
                child: revealOnHover && hovered != id
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: state.actionButtons(context, item),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  /// A cell that reports the pointer entering and leaving the row.
  Widget _hoverRegion(Object id, Widget child) => MouseRegion(
    onEnter: (_) => state._hovered.value = id,
    onExit: (_) => state._hovered.value = null,
    child: child,
  );
}

class _CardLayout<T> extends StatelessWidget {
  const _CardLayout({required this.state});

  final _ResponsiveListViewState<T> state;

  @override
  Widget build(BuildContext context) {
    final widget = state.widget;

    return Column(
      children: [
        for (final item in widget.data)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final column in widget.columns)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              column.label,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            column.build(context, item),
                          ],
                        ),
                      ),
                    if (widget.actions != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: state.actionButtons(context, item),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Width of the actions column, and the height every row is pinned to.
///
/// Wide enough for two `IconButton`s (48 each) and their padding (4 each), and
/// the Material tap-target minimum. Both are load-bearing: the width stops the
/// column growing when the actions appear, and the height stops the row
/// resizing — which is what made the table jump as the pointer moved down it.
const double _actionsWidth = 104;
const double _rowHeight = 48;

/// The mobile sort control.
///
/// A table header cell is unreachable once the layout is cards, so the same
/// sort state has to be reachable some other way — otherwise sorting is a
/// desktop-only feature in a responsive app.
class _SortControl<T> extends StatelessWidget {
  const _SortControl({
    required this.columns,
    required this.sortBy,
    required this.sortOrder,
    required this.onSort,
  });

  final List<ListColumn<T>> columns;
  final String? sortBy;
  final SortOrder? sortOrder;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final sortable = columns.where((column) => column.sortable).toList();
    if (sortable.isEmpty) return const SizedBox.shrink();

    final active = sortBy == null
        ? null
        : sortable.firstWhere(
            (column) => column.key == sortBy,
            orElse: () => sortable.first,
          );

    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        tooltip: 'Sort',
        icon: const Icon(Icons.swap_vert),
        initialValue: active?.key,
        onSelected: onSort,
        itemBuilder: (context) => [
          for (final column in sortable)
            PopupMenuItem(value: column.key, child: Text(column.label)),
        ],
      ),
    );
  }
}
