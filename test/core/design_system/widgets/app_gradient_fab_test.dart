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

  // Regresie reprodusă în producție: sub constrângeri loose-dar-mărginite
  // (exact ce oferă Scaffold slotului floatingActionButton), varianta
  // extended (cu label) devenea bară full-width din cauza Center-ului din
  // interior. IntrinsicWidth trebuie să forțeze dimensionarea după conținut.
  testWidgets(
      'AppGradientFab extins NU se întinde pe toată lățimea sub constrângeri loose (regresie fix)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Center(
          child: AppGradientFab(
            icon: Icons.add,
            label: 'Adaugă',
            onPressed: () {},
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(AppGradientFab));
    // Ecranul de test standard e 800×600 — un FAB extins real are ~150-180px.
    expect(size.width, lessThan(220));
  });

  testWidgets(
      'AppGradientFab icon-only păstrează lățimea fixă 56 sub aceleași constrângeri',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Center(
          child: AppGradientFab(icon: Icons.add, onPressed: () {}),
        ),
      ),
    );
    final size = tester.getSize(find.byType(AppGradientFab));
    expect(size.width, 56);
  });
}
