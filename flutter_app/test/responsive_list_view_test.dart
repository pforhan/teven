import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/core/services/list_query.dart';
import 'package:teven_app/core/theme/teven_theme.dart';
import 'package:teven_app/widgets/responsive_list_view.dart';

/// The shared list widget — tasks 4.1, 4.2, 4.3.
///
/// Widths are pinned rather than exercised in a browser, as with the chrome
/// tests: what is being established is that the layout branch follows the
/// available width and that each branch renders the right controls.
///
/// The widget is pumped inside a real `MaterialApp` rather than the app's, so
/// these tests are about the list and not about the shell around it.
void main() {
  const mobileWidth = 500.0;
  const desktopWidth = 1300.0;

  const customers = [
    _Record(id: 1, name: 'Globex', phone: '555-0100', notes: 'vip'),
    _Record(id: 2, name: 'Initech', phone: '555-0111', notes: ''),
  ];

  Future<void> pumpList(
    WidgetTester tester, {
    required double width,
    bool? revealActionsOnHover,
    List<_Record> data = customers,
    bool withActions = true,
    ValueChanged<String>? onSort,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: TevenTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ResponsiveListView<_Record>(
              data: data,
              revealActionsOnHover: revealActionsOnHover,
              emptyMessage: 'No customers found.',
              sortBy: 'name',
              sortOrder: SortOrder.asc,
              onSort: onSort,
              idOf: (record) => record.id,
              columns: [
                ListColumn<_Record>(
                  key: 'name',
                  label: 'Name',
                  sortable: true,
                  text: (record) => record.name,
                ),
                ListColumn<_Record>(
                  key: 'notes',
                  label: 'Notes',
                  text: (record) => record.notes,
                ),
              ],
              actions: withActions
                  ? (context, record) => [
                      ListRowAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        onPressed: () {},
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('layout', () {
    // Task 4.1.
    testWidgets('desktop is a table', (tester) async {
      await pumpList(tester, width: desktopWidth);

      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Globex'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('mobile is a card per record, labelled by column', (
      tester,
    ) async {
      await pumpList(tester, width: mobileWidth);

      expect(find.byType(Table), findsNothing);
      expect(find.byType(Card), findsNWidgets(2));
      // The label is repeated per card, which is the point — a card with no
      // heading is a wall of values.
      expect(find.text('Notes'), findsNWidgets(2));
    });

    testWidgets('tablet gets cards too — the rail leaves no room for a table', (
      tester,
    ) async {
      await pumpList(tester, width: 900);

      expect(find.byType(Table), findsNothing);
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('an empty list says so instead of rendering a bare header', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(desktopWidth, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: TevenTheme.light(),
          home: Scaffold(
            body: ResponsiveListView<_Record>(
              data: const [],
              idOf: (record) => record.id,
              emptyMessage: 'No customers found.',
              columns: const [
                ListColumn<_Record>(key: 'name', label: 'Name', text: _nameOf),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No customers found.'), findsOneWidget);
      expect(find.byType(Table), findsNothing);
    });
  });

  group('row actions', () {
    // Task 4.2. Hover is a pointer affordance; the reveal flag is passed
    // explicitly because `kIsWeb` is false on the VM these tests run on.
    testWidgets('hidden until the row is hovered', (tester) async {
      await pumpList(tester, width: desktopWidth, revealActionsOnHover: true);

      expect(find.byIcon(Icons.edit), findsNothing);

      final row = find.text('Globex');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(row));
      await gesture.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('leaving the row hides them again', (tester) async {
      await pumpList(tester, width: desktopWidth, revealActionsOnHover: true);

      final row = find.text('Globex');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(row));
      await gesture.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('always visible in a card, since there is no hover', (
      tester,
    ) async {
      await pumpList(tester, width: mobileWidth);

      expect(find.byIcon(Icons.edit), findsNWidgets(2));
    });

    testWidgets('revealing the actions does not resize the row', (
      tester,
    ) async {
      // Found in a browser, not by a test: hovering a row made the table jump,
      // so the rows below shifted as the pointer travelled down. The measured
      // cause was 8px of growth in the actions column, which can tip the
      // container over the point where a horizontal scrollbar appears — and a
      // scrollbar appearing changes the content *height*, which is what reads
      // as rows changing size.
      //
      // Every presence assertion in this group passed with the bug in place.
      // This is task 3.12's lesson, where a positional check caught what "the
      // widget exists" could not.
      await pumpList(tester, width: desktopWidth, revealActionsOnHover: true);

      final before = tester.getRect(find.byType(Table));
      final textBefore = tester.getRect(find.text('Globex'));
      final belowBefore = tester.getRect(find.text('Initech'));
      final headerToFirst =
          textBefore.top - tester.getRect(find.text('Name')).top;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Globex')));
      await gesture.moveTo(tester.getCenter(find.text('Globex')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(
        tester.getRect(find.byType(Table)),
        before,
        reason: 'the table must not grow when the actions appear',
      );
      expect(tester.getRect(find.text('Globex')), textBefore);
      expect(tester.getRect(find.text('Initech')), belowBefore);

      // **The row pitch**, which is the invariant the screenshots actually
      // showed breaking. Comparing text positions alone missed it: when the
      // hovered row's *band* changed height, its text and the row below moved
      // together, so both rects stayed consistent while the gap above the text
      // grew and the gap below it shrank.
      double pitch() =>
          tester.getRect(find.text('Initech')).top -
          tester.getRect(find.text('Globex')).top;

      expect(
        pitch(),
        belowBefore.top - textBefore.top,
        reason: 'the distance between two rows must not depend on hover',
      );
      expect(
        tester.getRect(find.text('Globex')).top -
            tester.getRect(find.text('Name')).top,
        headerToFirst,
        reason: 'the space above the first row must not depend on hover',
      );

      // And back again — a row that shrinks on un-hover is the same bug.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(Table)), before);
      expect(pitch(), belowBefore.top - textBefore.top);
    });

    testWidgets('long content wraps rather than pushing columns off screen', (
      tester,
    ) async {
      // The same bug, visible without hovering: `IntrinsicColumnWidth` sized
      // each column to its content, so a real address and a real note built a
      // table 3915px wide with the notes column entirely off screen. The
      // customer list is the screen that has long text in it, which is why
      // this only showed up in a browser.
      await pumpList(
        tester,
        width: desktopWidth,
        revealActionsOnHover: true,
        data: const [
          _Record(
            id: 1,
            name: 'Globex Corporation International',
            phone: '555-0101',
            notes:
                'A note long enough that it would have taken the notes column '
                'three thousand pixels to the right before the fix',
          ),
          _Record(id: 2, name: 'Initech', phone: '555-0111', notes: ''),
        ],
      );

      expect(find.text('Globex Corporation International'), findsOneWidget);
      expect(
        tester.getRect(find.byType(Table)).width,
        lessThan(1400),
        reason: 'the table must fit the space it was given, not its content',
      );
    });

    testWidgets('no actions column when the screen offers none', (
      tester,
    ) async {
      await pumpList(tester, width: desktopWidth, withActions: false);

      expect(find.byIcon(Icons.edit), findsNothing);
      // The table still renders — the column is absent, not the data.
      expect(find.text('Globex'), findsOneWidget);
    });
  });

  group('sorting', () {
    // Task 4.11's client half: the widget reports the column, the screen
    // decides. `TableView.tsx:49` did exactly this.
    testWidgets('a sortable header reports its key', (tester) async {
      final keys = <String>[];
      await pumpList(tester, width: desktopWidth, onSort: keys.add);

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(keys, ['name']);
    });

    testWidgets('a non-sortable header is not a control', (tester) async {
      final keys = <String>[];
      await pumpList(tester, width: desktopWidth, onSort: keys.add);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(keys, isEmpty);
    });

    testWidgets('the active column shows a direction', (tester) async {
      await pumpList(tester, width: desktopWidth, onSort: (_) {});

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('cards get a sort control, since there is no header', (
      tester,
    ) async {
      await pumpList(tester, width: mobileWidth, onSort: (_) {});

      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}

String _nameOf(_Record record) => record.name;

class _Record {
  const _Record({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
  });

  final int id;
  final String name;
  final String phone;
  final String notes;
}
