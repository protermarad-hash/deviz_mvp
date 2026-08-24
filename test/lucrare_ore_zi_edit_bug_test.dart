import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/jobs/services/lucrare_labor_calc.dart';

/// Regresie pentru bug-ul critic din producție (JOB-0032, v1.9.1+106):
/// câmpul "Ore/zi" din dialogurile "Adaugă manoperă / ore" ȘI "Editează
/// manoperă / ore" (lucrare_detalii_page.dart, `_onAddLabor` linia ~4113
/// și `_onEditLabor` linia ~5429) revenea instant la 8, indiferent ce se
/// tasta.
///
/// Cauza (confirmată prin git blame — pre-existentă din commit inițial
/// `d3edf44`, 25 mai 2026, NU regresie din Faza 1 de azi, `97cf200`):
/// `onChanged` pe câmp apela `syncComputedValues()`, care făcea
/// `hoursPerDayController.text = _formatDecimal(sanitizeLaborHoursPerDay(
/// hoursPerDayController.text))` — un ECOU imediat al valorii SANITIZATE
/// înapoi în ACELAȘI câmp pe care utilizatorul îl edita. Cum
/// `sanitizeLaborHoursPerDay` întoarce fallback 8.0 pentru orice text
/// gol/zero (stare tranzitorie normală după Backspace, înainte de a
/// apuca să tastezi cifra nouă), câmpul se "auto-corecta" instant la 8
/// la fiecare ștergere, blocând orice editare reală.
///
/// `_onEditLabor`/`_onAddLabor` sunt metode private pe o pagină uriașă
/// (`LucrareDetaliiPage`) — testarea widget directă a lor rămâne
/// impracticabilă (limitare deja semnalată la Faza 1: ar necesita
/// pomparea întregii pagini, cu repository/date complete). Acest test
/// reproduce EXACT mecanismul cu logica reală (`LucrareLaborCalculator
/// .sanitizeLaborHoursPerDay`, nu o reimplementare), într-un harness
/// minimal ce oglindește STRUCTURAL cele două variante de `onChanged`
/// (înainte/după fix) din codul real.
void main() {
  final calc = LucrareLaborCalculator(
    jobId: 'job-1',
    employeesProvider: () => const [],
    teamsProvider: () => const [],
  );

  /// Harness cu patternul VECHI, buggy — `onChanged` rescrie câmpul cu
  /// valoarea sanitizată (identic cu codul dinainte de fix).
  Widget buggyHarness(TextEditingController controller) {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Ore/zi'),
            onChanged: (_) => setState(() {
              final hoursPerDay =
                  calc.sanitizeLaborHoursPerDay(controller.text);
              controller.text = hoursPerDay.toStringAsFixed(0);
            }),
          ),
        ),
      ),
    );
  }

  /// Harness cu patternul NOU, reparat — `onChanged` NU mai rescrie
  /// câmpul (identic cu codul după fix; `sanitizeLaborHoursPerDay` se
  /// aplică doar la calcule derivate, nu la câmpul editat).
  Widget fixedHarness(TextEditingController controller, ValueNotifier<double> derived) {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Ore/zi'),
            onChanged: (_) => setState(() {
              derived.value = calc.sanitizeLaborHoursPerDay(controller.text);
              // NU: controller.text = ... (asta era bug-ul)
            }),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'PATTERN VECHI (buggy): Backspace apoi tastare -> campul revine la 8, editarea e blocata',
      (tester) async {
    final controller = TextEditingController(text: '8');
    await tester.pumpWidget(buggyHarness(controller));
    await tester.pumpAndSettle();

    // Simulează exact fluxul raportat: utilizatorul șterge "8" (Backspace),
    // apoi încearcă să tasteze "4". `enterText` cu text intermediar gol
    // reproduce starea tranzitorie care declanșează fallback-ul.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    // Bug confirmat: chiar la starea tranzitorie goală, onChanged deja
    // a rescris campul la fallback 8 — utilizatorul nu a apucat sa tasteze.
    expect(controller.text, '8');

    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    // Cu patternul vechi, orice tastare care trece printr-o stare goală
    // e "corectata" instant la 8 — reproduce exact simptomul raportat.
    // (enterText seteaza textul direct la '4', dar onChanged-ul buggy
    // il rescrie imediat inapoi conform sanitize -> ramane 4 aici pentru
    // ca '4' > 0; testul urmator arata cazul real problematic: Backspace
    // repetat, camp gol persistent intre keystroke-uri individuale.)
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(controller.text, '8',
        reason:
            'Cu patternul vechi, campul golit temporar (ex. Backspace) '
            'revine instant la 8 - utilizatorul nu poate niciodata sa '
            'stearga complet cifra veche inainte de a tasta una noua.');
  });

  testWidgets(
      'PATTERN NOU (reparat): campul pastreaza exact ce s-a tastat, inclusiv starea goala tranzitorie',
      (tester) async {
    final controller = TextEditingController(text: '8');
    final derived = ValueNotifier<double>(8);
    await tester.pumpWidget(fixedHarness(controller, derived));
    await tester.pumpAndSettle();

    // Sterge campul (Backspace) - starea tranzitorie goala NU mai e
    // suprascrisa.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(controller.text, '',
        reason: 'Campul ramane gol - utilizatorul poate acum tasta cifra noua.');

    // Tasteaza valoarea noua.
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(controller.text, '4',
        reason: 'Valoarea tastata e pastrata exact, nu suprascrisa cu fallback.');

    // Valoarea derivata (folosita pt. "Ore totale"/calcule) reflecta
    // totusi corect noua valoare, prin sanitizeLaborHoursPerDay aplicat
    // DOAR la citire, nu la scriere in campul editat.
    expect(derived.value, 4);
  });

  test('sanitizeLaborHoursPerDay ramane fallback 8.0 pentru text gol/zero (comportament neschimbat)',
      () {
    expect(calc.sanitizeLaborHoursPerDay(''), 8.0);
    expect(calc.sanitizeLaborHoursPerDay('0'), 8.0);
    expect(calc.sanitizeLaborHoursPerDay('-3'), 8.0);
    expect(calc.sanitizeLaborHoursPerDay('4'), 4.0);
  });
}
