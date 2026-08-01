import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_stat_pill.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AppStatPill renders value and label', (tester) async {
    await tester.pumpWidget(
      wrap(const AppStatPill(value: '12', label: 'Azi')),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Azi'), findsOneWidget);
  });

  testWidgets('AppStatPill renders optional icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppStatPill(
          value: '3',
          label: 'În curs',
          icon: Icons.timelapse,
        ),
      ),
    );
    expect(find.byIcon(Icons.timelapse), findsOneWidget);
  });

  testWidgets('AppStatPill fără icon nu randează o iconiță', (tester) async {
    await tester.pumpWidget(
      wrap(const AppStatPill(value: '7', label: 'Săptămâna')),
    );
    expect(find.byType(Icon), findsNothing);
  });
}
