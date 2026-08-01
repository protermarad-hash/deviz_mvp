import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AppCard renders child with default padding', (tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('conținut'))));
    expect(find.text('conținut'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('AppCard renders with custom padding/margin/color', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppCard(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.all(8),
          color: Colors.red,
          child: const Text('custom'),
        ),
      ),
    );
    expect(find.text('custom'), findsOneWidget);
  });

  testWidgets('AppCard with onTap wraps content in InkWell and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppCard(
          onTap: () => tapped = true,
          child: const Text('tappable'),
        ),
      ),
    );
    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppCard without onTap does not add InkWell', (tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('static'))));
    expect(find.byType(InkWell), findsNothing);
  });
}
