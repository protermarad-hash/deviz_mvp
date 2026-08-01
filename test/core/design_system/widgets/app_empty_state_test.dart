import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AppEmptyState renders icon and title', (tester) async {
    await tester.pumpWidget(
      wrap(const AppEmptyState(icon: Icons.inbox_outlined, title: 'Nimic aici')),
    );
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Nimic aici'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('AppEmptyState renders message and action button, action fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nimic aici',
          message: 'Adaugă primul element.',
          actionLabel: 'Adaugă',
          onAction: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Adaugă primul element.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Adaugă'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Adaugă'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppEmptyState with actionLabel but no onAction does not render button', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nimic',
          actionLabel: 'Fără callback',
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });
}
