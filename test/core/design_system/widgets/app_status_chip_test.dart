import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_status_chip.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  for (final status in AppStatusKind.values) {
    testWidgets('AppStatusChip renders without crash for $status', (tester) async {
      await tester.pumpWidget(
        wrap(AppStatusChip(label: status.name, status: status)),
      );
      expect(find.text(status.name), findsOneWidget);
    });
  }

  testWidgets('AppStatusChip renders optional icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppStatusChip(
          label: 'Finalizată',
          status: AppStatusKind.finalizata,
          icon: Icons.check_circle,
        ),
      ),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Finalizată'), findsOneWidget);
  });
}
