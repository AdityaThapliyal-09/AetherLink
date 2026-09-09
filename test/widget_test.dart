import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink/main.dart';
import 'package:aetherlink/features/settings/about_credits_screen.dart';

void main() {
  testWidgets('AetherLink launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const AetherLinkApp());
    // App should show something (loading state or home)
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AboutCreditsScreen renders branding, team, mentor, and institution', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: AboutCreditsScreen(),
    ));

    expect(find.text('About & Credits'), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
    expect(find.text('Ms. Nidhi Joshi'), findsOneWidget);
    expect(find.text('School of Computing'), findsOneWidget);
    expect(find.text('Graphic Era Hill University (GEHU)'), findsOneWidget);
    expect(find.text('Aditya Thapliyal'), findsOneWidget);
    expect(find.text('Ankit Singh Rawat'), findsOneWidget);
    expect(find.text('Suhail'), findsOneWidget);
    expect(find.textContaining('2421057'), findsOneWidget);
  });
}

