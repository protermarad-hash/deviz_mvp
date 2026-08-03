import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/design_system/widgets/app_card.dart';

/// Regresie (build93): `AppCard(elevated: true)` nu mai umplea înălțimea
/// alocată de `Positioned(height:)` în planner-ul Calendar — se strângea
/// la înălțimea conținutului (ex. 58px în loc de 200px), din cauza
/// fix-ului anterior (`IntrinsicHeight` necondiționat, aug 2026) care
/// rezolvase corect invizibilitatea din `ListView`/`Column` nemărginit,
/// dar impunea greșit înălțimea intrinsecă a conținutului și în cazurile
/// cu înălțime MĂRGINITĂ (bounded) — atât tight (`Positioned(height:)`
/// direct) cât mai ales loose (copil ne-poziționat al unui `Stack`
/// intermediar — exact structura reală din `_calendarBlock`, unde
/// `AppCard` e copil al unui `Stack` folosit pentru badge-urile
/// "continuă").
///
/// Fix: `LayoutBuilder` condiționează aplicarea `IntrinsicHeight` STRICT
/// la cazul cu înălțime nemărginită (`!constraints.hasBoundedHeight`) —
/// singurul care crapă fără el. Pentru orice înălțime mărginită (tight
/// SAU loose), `Row(crossAxisAlignment: stretch)` e lăsat să funcționeze
/// nativ, fără nicio intervenție.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets(
      'REGRESIE CRITICĂ: Positioned(height:200) > Stack > AppCard (structura reală '
      'din _calendarBlock, planner Calendar) — umple exact 200px, NU se strânge la conținut',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200,
              child: Stack(
                children: [
                  AppCard(
                    elevated: true,
                    accentColor: Colors.green,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: const Text('mic'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(AppCard));
    expect(size.height, 200.0);
  });

  testWidgets(
      'Positioned(height:200) direct peste AppCard (fără Stack intermediar) — '
      'constrângere tight, umple 200px',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200,
              child: AppCard(
                elevated: true,
                accentColor: Colors.blue,
                child: const Text('mic'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(AppCard));
    expect(size.height, 200.0);
  });

  testWidgets(
      'SizedBox(height:200) peste AppCard — constrângere tight, umple 200px',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: AppCard(
              elevated: true,
              accentColor: Colors.purple,
              child: const Text('mic'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(AppCard));
    expect(size.height, 200.0);
  });

  testWidgets(
      'ConstrainedBox(maxHeight:200, minHeight:0) peste AppCard — constrângere '
      'BOUNDED dar LOOSE explicită (fără Stack), tot umple 200px',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 300,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, minHeight: 0),
              child: AppCard(
                elevated: true,
                accentColor: Colors.orange,
                child: const Text('mic'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(AppCard));
    expect(size.height, 200.0);
  });
}
