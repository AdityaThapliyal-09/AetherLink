import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink/main.dart';

void main() {
  testWidgets('AetherLink launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const AetherLinkApp());
    // App should show something (loading state or home)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
