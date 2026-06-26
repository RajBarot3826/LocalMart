import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:localmart/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LocalMartApp());
    // Settle any animations and the splash screen timer
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
