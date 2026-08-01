import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/app_theme_preset.dart';
import 'package:devizpro_ultra/core/design_system/widgets/app_gradient_fab.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildAppTheme(AppThemePreset.proTermSignature),
        home: Scaffold(body: child),
      );

  testWidgets('AppGradientFab (icon-only) răspunde la tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppGradientFab(
          icon: Icons.add,
          onPressed: () => tapped = true,
        ),
      ),
    );
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppGradientFab extins randează label', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppGradientFab(
          icon: Icons.add,
          label: 'Adaugă',
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('Adaugă'), findsOneWidget);
  });

  testWidgets('AppGradientFab cu onPressed null nu crapă la tap', (tester) async {
    await tester.pumpWidget(
      wrap(const AppGradientFab(icon: Icons.add, onPressed: null)),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
