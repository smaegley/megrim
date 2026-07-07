import 'package:flutter_test/flutter_test.dart';

import 'package:megrim/main.dart';

void main() {
  testWidgets('App boots to the home scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const MegrimApp());
    expect(find.text('Megrim'), findsWidgets);
  });
}
