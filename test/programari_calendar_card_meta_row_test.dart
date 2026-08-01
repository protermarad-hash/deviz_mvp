import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_team_avatar_stack.dart';
import 'package:devizpro_ultra/features/programari/widgets/calendar_card_meta_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CalendarCardMetaRow — rândul secundar al cardului din planner', () {
    testWidgets('fără recurență și fără avatare -> nu randează nimic vizibil',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const CalendarCardMetaRow(
            isRecurring: false,
            avatars: [],
            accentColor: Colors.blue,
          ),
        ),
      );
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.byType(AppTeamAvatarStack), findsNothing);
    });

    testWidgets('doar recurență -> randează iconița repeat, fără avatar stack',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const CalendarCardMetaRow(
            isRecurring: true,
            avatars: [],
            accentColor: Colors.blue,
          ),
        ),
      );
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byType(AppTeamAvatarStack), findsNothing);
    });

    testWidgets('doar avatare -> randează stack-ul, fără iconița repeat',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const CalendarCardMetaRow(
            isRecurring: false,
            avatars: [AppAvatarData(label: 'AB', color: Colors.red)],
            accentColor: Colors.blue,
          ),
        ),
      );
      expect(find.byIcon(Icons.repeat), findsNothing);
      expect(find.byType(AppTeamAvatarStack), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('recurență + avatare -> ambele randate, în această ordine',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const CalendarCardMetaRow(
            isRecurring: true,
            avatars: [AppAvatarData(label: 'CD', color: Colors.green)],
            accentColor: Colors.orange,
          ),
        ),
      );
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byType(AppTeamAvatarStack), findsOneWidget);

      // Iconița de recurență trebuie să fie ÎNAINTEA avatarelor (stânga->dreapta).
      final iconLeft = tester.getTopLeft(find.byIcon(Icons.repeat)).dx;
      final avatarLeft =
          tester.getTopLeft(find.byType(AppTeamAvatarStack)).dx;
      expect(iconLeft, lessThan(avatarLeft));
    });

    testWidgets('nu este plasat pe același rând cu un titlu alăturat (grupare izolată)',
        (tester) async {
      // Reproduce structura reală din card: titlul e SINGUR pe rândul lui
      // (Expanded), iar CalendarCardMetaRow e pe rândul URMĂTOR (Column),
      // NU alături de titlu într-un Row comun — exact fix-ul regresiei.
      await tester.pumpWidget(
        wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(child: Text('Titlu foarte lung de programare')),
                ],
              ),
              const CalendarCardMetaRow(
                isRecurring: true,
                avatars: [AppAvatarData(label: 'EF', color: Colors.purple)],
                accentColor: Colors.blue,
              ),
            ],
          ),
        ),
      );
      final titleTop = tester.getTopLeft(find.text('Titlu foarte lung de programare')).dy;
      final metaRowTop = tester.getTopLeft(find.byType(CalendarCardMetaRow)).dy;
      expect(metaRowTop, greaterThan(titleTop));
    });
  });
}
