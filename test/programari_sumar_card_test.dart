import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/programari/widgets/programari_sumar_card.dart';

/// Teste pentru `ProgramariSumarCard` — sursa unică ce înlocuiește cele 3
/// copii aproape identice de `_SumarCard` din parteneri/profitabilitate/
/// consum-materiale (aug 2026, Lot 2 restilizare sateliți).
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('randează label, valoare și icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProgramariSumarCard(
          label: 'Total comisioane',
          value: '1234.50 RON',
          icon: Icons.handshake_outlined,
          accentColor: Colors.blue,
        ),
      ),
    );

    expect(find.text('Total comisioane'), findsOneWidget);
    expect(find.text('1234.50 RON'), findsOneWidget);
    expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
  });

  testWidgets('afișează subtextul doar când sub e furnizat', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProgramariSumarCard(
          label: 'Deja plătit',
          value: '500 RON',
          icon: Icons.check_circle_outline,
          accentColor: Colors.green,
        ),
      ),
    );

    // Fara sub -> Column-ul nu contine decat label + valoare, niciun
    // widget de subtext suplimentar cu text gol.
    expect(find.text(''), findsNothing);
  });

  testWidgets('afișează subtextul când sub e furnizat', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProgramariSumarCard(
          label: 'Total de încasat',
          value: '900 RON',
          icon: Icons.receipt_long_outlined,
          accentColor: Colors.orange,
          sub: '12 programări',
        ),
      ),
    );

    expect(find.text('12 programări'), findsOneWidget);
  });

  testWidgets('randează varianta elevated a AppCard (fără Card nativ)', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ProgramariSumarCard(
          label: 'Rest de plătit',
          value: '300 RON',
          icon: Icons.warning_amber_outlined,
          accentColor: Colors.red,
        ),
      ),
    );

    // AppCard(elevated:true) randează Container+InkWell, NU Card nativ —
    // confirmă că nu s-a strecurat varianta plată default (elevated:false).
    expect(find.byType(Card), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('icon și valoarea folosesc accentColor-ul primit', (tester) async {
    const accent = Colors.purple;
    await tester.pumpWidget(
      wrap(
        const ProgramariSumarCard(
          label: 'Profit net',
          value: '1500 RON',
          icon: Icons.trending_up_outlined,
          accentColor: accent,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.trending_up_outlined));
    expect(icon.color, accent);

    final valueText = tester.widget<Text>(find.text('1500 RON'));
    expect(valueText.style?.color, accent);
  });
}
