import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_card.dart';

/// Regresie pentru bug-ul din build91 (aug 2026): `AppCard(elevated: true)`
/// randa complet invizibil (fără eroare vizibilă în release) pe ecranele
/// "Rețete kituri" și "Parteneri — Plăți & Încasări", pentru că `Row`-ul
/// intern cu `crossAxisAlignment: CrossAxisAlignment.stretch`
/// (app_card.dart) primea înălțime NEMĂRGINITĂ ori de câte ori `AppCard`
/// era plasat ca item într-un `ListView`/`ListView.builder`/
/// `ListView.separated`, sau ca și copil ne-`Expanded` al unui `Column` —
/// ambele forme dau, normal în Flutter, înălțime nemărginită copiilor.
///
/// Fix: `Row`-ul e învelit acum într-un `IntrinsicHeight`, care îi
/// calculează o înălțime finită din conținut ÎNAINTE ca `stretch` să
/// intervină.
///
/// Fiecare test de mai jos reproduce STRUCTURAL o formă de utilizare reală
/// din cod (nu doar o presupunere) și verifică explicit
/// `tester.takeException()` == null — o eroare de layout nu se manifestă
/// mereu ca `TestFailure` pe un `find.text`, dar `takeException()` prinde
/// orice `FlutterError` aruncat în timpul layout-ului/randării.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets(
      'AppCard(elevated:true) ca item ListView.builder — fără eroare de constrângere infinită '
      '(forma din programare_kituri_page.dart si servicii_prestate_page.dart)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) => AppCard(
            elevated: true,
            accentColor: Colors.blue,
            margin: const EdgeInsets.only(bottom: 8),
            child: Text('Item $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) ca item ListView.separated — fără eroare de constrângere infinită '
      '(forma din tab-ul "Listă", programari_page.dart:7167)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ListView.separated(
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => AppCard(
            elevated: true,
            accentColor: Colors.teal,
            padding: const EdgeInsets.all(14),
            margin: EdgeInsets.zero,
            child: Text('Card $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Card 0'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) în Row(Expanded()) ca și copil al unui ListView — '
      'fără eroare (forma ProgramariSumarCard din parteneri/profitabilitate/consum-materiale)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    elevated: true,
                    accentColor: Colors.blue,
                    child: const Text('KPI 1'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    elevated: true,
                    accentColor: Colors.green,
                    child: const Text('KPI 2'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('KPI 1'), findsOneWidget);
    expect(find.text('KPI 2'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) ca item al unui ListView prin .map() — fără eroare '
      '(forma _SumarPartenerCard din programari_parteneri_page.dart)',
      (tester) async {
    final names = ['Partener A', 'Partener B'];
    await tester.pumpWidget(
      wrap(
        ListView(
          children: names
              .map(
                (n) => AppCard(
                  elevated: true,
                  accentColor: Colors.red,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Text(n),
                ),
              )
              .toList(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Partener A'), findsOneWidget);
    expect(find.text('Partener B'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) ca și copil ne-Expanded al unui Column într-un '
      'SingleChildScrollView — fără eroare (forma dialogului de componente kit, '
      'programare_kituri_page.dart:197, și a banner-ului de sursă date, linia 505)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: Column(
            children: [
              AppCard(
                elevated: true,
                accentColor: Colors.orange,
                margin: const EdgeInsets.only(bottom: 8),
                child: const Text('Componentă kit'),
              ),
              const Text('Alt conținut'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Componentă kit'), findsOneWidget);
  });

  testWidgets(
      'STRUCTURĂ REALĂ tab "Listă" (programari_page.dart) — Column > Expanded > '
      'ListView.separated > itemBuilder > AppCard(elevated:true) — fără eroare',
      (tester) async {
    // Replică fidelă a structurii reale din _ProgramariPageState.build():
    // mainContent este un Column, iar zona de listă e Expanded(child:
    // ListView.separated(...)) — Expanded mărginește ÎNĂLȚIMEA
    // ListView-ului însuși, dar NU mărginește înălțimea itemilor din
    // interior (fiecare item primește oricum înălțime nemărginită pe axa
    // de scroll — comportament Flutter normal pentru orice Sliver/
    // ListView). Testul confirmă că fix-ul rezolvă situația chiar și cu
    // acest wrapper Expanded intermediar, nu doar în teste izolate.
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            const Text('Header'),
            Expanded(
              child: ListView.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => AppCard(
                  elevated: true,
                  accentColor: Colors.teal,
                  padding: const EdgeInsets.all(14),
                  margin: EdgeInsets.zero,
                  child: Text('Programare $index'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Programare 0'), findsOneWidget);
    expect(find.text('Programare 1'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) în Positioned(height:) — formă deja sigură '
      '(planner Calendar, _calendarBlock) — rămâne fără eroare după fix',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
              child: AppCard(
                elevated: true,
                accentColor: Colors.purple,
                child: const Text('Bloc calendar'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bloc calendar'), findsOneWidget);
  });

  testWidgets(
      'AppCard(elevated:true) — bara de accent stretch-uiește corect pe înălțimea '
      'finită calculată de IntrinsicHeight (nu rămâne colapsată la 0)',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ListView(
          children: [
            AppCard(
              elevated: true,
              accentColor: Colors.indigo,
              child: const SizedBox(
                width: 200,
                height: 100,
                child: Text('Conținut înalt'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Bara de accent e primul Container din Row-ul intern, cu lățime fixă
    // AppElevatedCardStyle.accentBarWidth (4) — verificăm că înălțimea ei
    // randată e apropiată de înălțimea conținutului (100), nu 0.
    final accentBarFinder = find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxWidth == 4,
    );
    expect(accentBarFinder, findsOneWidget);
    final size = tester.getSize(accentBarFinder);
    expect(size.height, greaterThan(50));
  });
}
