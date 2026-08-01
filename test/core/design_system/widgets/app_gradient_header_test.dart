import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/app_theme_preset.dart';
import 'package:devizpro_ultra/core/design_system/widgets/app_gradient_header.dart';
import 'package:devizpro_ultra/core/design_system/widgets/app_stat_pill.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildAppTheme(AppThemePreset.proTermSignature),
        home: Scaffold(body: child),
      );

  testWidgets('AppGradientHeader renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppGradientHeader(
          title: 'Programări',
          subtitle: 'Astăzi',
        ),
      ),
    );
    expect(find.text('Programări'), findsOneWidget);
    expect(find.text('Astăzi'), findsOneWidget);
  });

  testWidgets('AppGradientHeader renders icon, action and stat pills', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppGradientHeader(
          title: 'Programări',
          icon: Icons.event_outlined,
          action: const Icon(Icons.settings),
          stats: const [
            AppStatPill(value: '5', label: 'Azi'),
            AppStatPill(value: '2', label: 'În curs'),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.event_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byType(AppStatPill), findsNWidgets(2));
  });

  testWidgets('AppGradientHeader fără brand theme nu crapă (fallback pe primary)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: AppGradientHeader(title: 'Fără brand')),
      ),
    );
    expect(find.text('Fără brand'), findsOneWidget);
  });
}
