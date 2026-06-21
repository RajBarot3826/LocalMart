import 'package:flutter_test/flutter_test.dart';

import 'package:localmart/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LocalMartApp());
    // Verify that the app launches without errors
    expect(find.text('LocalMart'), findsAny);
  });
}
