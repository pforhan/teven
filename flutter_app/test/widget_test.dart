import 'package:flutter_test/flutter_test.dart';
import 'package:teven_app/main.dart';

void main() {
  testWidgets('app builds and renders the scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TevenApp());

    expect(find.text('Teven'), findsOneWidget);
  });
}
