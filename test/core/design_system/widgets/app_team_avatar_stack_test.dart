import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_team_avatar_stack.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('AppTeamAvatarStack gol nu randează nimic', (tester) async {
    await tester.pumpWidget(wrap(const AppTeamAvatarStack(avatars: [])));
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('+'), findsNothing);
  });

  testWidgets('AppTeamAvatarStack randează toate avatarele sub maxVisible', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppTeamAvatarStack(
          avatars: [
            AppAvatarData(label: 'AB', color: Colors.red),
            AppAvatarData(label: 'CD', color: Colors.blue),
          ],
          maxVisible: 3,
        ),
      ),
    );
    expect(find.text('AB'), findsOneWidget);
    expect(find.text('CD'), findsOneWidget);
  });

  testWidgets('AppTeamAvatarStack peste maxVisible arată indicator +N', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppTeamAvatarStack(
          avatars: [
            AppAvatarData(label: 'AB', color: Colors.red),
            AppAvatarData(label: 'CD', color: Colors.blue),
            AppAvatarData(label: 'EF', color: Colors.green),
            AppAvatarData(label: 'GH', color: Colors.orange),
          ],
          maxVisible: 2,
        ),
      ),
    );
    expect(find.text('AB'), findsOneWidget);
    expect(find.text('CD'), findsOneWidget);
    expect(find.text('EF'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });
}
