import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/app_tokens.dart';
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

  testWidgets('AppCard elevated:false (default) does not use Container/BoxShadow variant', (tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('flat'))));
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('AppCard elevated:true renders accent bar + responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppCard(
          elevated: true,
          accentColor: Colors.teal,
          onTap: () => tapped = true,
          child: const Text('elevated'),
        ),
      ),
    );
    expect(find.text('elevated'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppCard elevated:true without accentColor falls back to colorScheme.primary', (tester) async {
    await tester.pumpWidget(
      wrap(const AppCard(elevated: true, child: Text('fara culoare custom'))),
    );
    expect(find.text('fara culoare custom'), findsOneWidget);
  });

  testWidgets('AppCard onLongPress este apelat fără onTap', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(
      wrap(
        AppCard(
          elevated: true,
          onLongPress: () => longPressed = true,
          child: const Text('long-press'),
        ),
      ),
    );
    await tester.longPress(find.byType(InkWell));
    await tester.pump();
    expect(longPressed, isTrue);
  });

  testWidgets(
    'AppCard elevated:true respectă rețeta AppElevatedCardStyle (radius, umbră, bară accent) — sursă unică folosită și de planner/Pe echipe',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppCard(
            elevated: true,
            accentColor: Colors.teal,
            child: Text('rețetă'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(ClipRRect),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, AppElevatedCardStyle.borderRadius);
      expect(
        decoration.boxShadow,
        AppElevatedCardStyle.shadow(Colors.teal),
      );

      final bar = tester.widget<Container>(
        find
            .descendant(of: find.byType(Row), matching: find.byType(Container))
            .first,
      );
      expect(bar.constraints?.maxWidth, AppElevatedCardStyle.accentBarWidth);
    },
  );
}
