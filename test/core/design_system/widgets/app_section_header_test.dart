import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_section_header.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AppSectionHeader renders title only', (tester) async {
    await tester.pumpWidget(wrap(const AppSectionHeader(title: 'Titlu secțiune')));
    expect(find.text('Titlu secțiune'), findsOneWidget);
  });

  testWidgets('AppSectionHeader renders subtitle, icon and action', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppSectionHeader(
          title: 'Titlu',
          subtitle: 'Subtitlu descriptiv',
          icon: Icons.calendar_today,
          action: IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Titlu'), findsOneWidget);
    expect(find.text('Subtitlu descriptiv'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('AppSectionHeader with empty subtitle does not render subtitle text widget', (tester) async {
    await tester.pumpWidget(wrap(const AppSectionHeader(title: 'Titlu', subtitle: '')));
    expect(find.text('Titlu'), findsOneWidget);
  });
}
