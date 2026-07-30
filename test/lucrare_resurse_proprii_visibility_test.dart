import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Harness care reproduce exact structura de randare din tab-ul Execuție
/// al `lucrare_detalii_page.dart` (`_buildExecutieTab`, liniile ~11941-12030
/// după fix-ul din 2026-07-30): un `if/else if/else` care alege ÎNTRE
/// tracking per-linie / card repopulare / "Materiale asociate", urmat de
/// secțiunea "Resurse proprii" randată NECONDIȚIONAT, exact ca "Resurse
/// partener".
///
/// Regresia reparată: înainte de fix, "Resurse proprii" era în interiorul
/// ramurii `else` (alături de "Materiale asociate"), deci dispărea complet
/// pentru orice lucrare cu `liniiPlanificate.isNotEmpty` sau cu
/// `sourceOfferId`/`sourceOfferNumber` setate (adică orice lucrare
/// convertită dintr-o ofertă) — cazul JOB-0032.
class _ExecutieTabHarness extends StatelessWidget {
  const _ExecutieTabHarness({
    required this.liniiPlanificateNotEmpty,
    required this.sourceOfferSetat,
  });

  final bool liniiPlanificateNotEmpty;
  final bool sourceOfferSetat;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            if (liniiPlanificateNotEmpty)
              const Text('Tracking execuție')
            else if (sourceOfferSetat)
              const Text('Linii planificate neimportate')
            else
              const Text('Materiale asociate'),
            const Text('Resurse proprii'),
            const Text('Resurse partener'),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Tab Execuție — vizibilitate "Resurse proprii"', () {
    testWidgets(
        'lucrare cu liniiPlanificate.isNotEmpty=true TOT arată "Resurse proprii"',
        (tester) async {
      await tester.pumpWidget(const _ExecutieTabHarness(
        liniiPlanificateNotEmpty: true,
        sourceOfferSetat: false,
      ));

      expect(find.text('Tracking execuție'), findsOneWidget);
      expect(find.text('Resurse proprii'), findsOneWidget);
      expect(find.text('Resurse partener'), findsOneWidget);
      // "Materiale asociate" nu trebuie dublată lângă tracking-ul per-linie.
      expect(find.text('Materiale asociate'), findsNothing);
    });

    testWidgets(
        'lucrare convertită din ofertă fără linii importate TOT arată "Resurse proprii"',
        (tester) async {
      await tester.pumpWidget(const _ExecutieTabHarness(
        liniiPlanificateNotEmpty: false,
        sourceOfferSetat: true,
      ));

      expect(find.text('Linii planificate neimportate'), findsOneWidget);
      expect(find.text('Resurse proprii'), findsOneWidget);
      expect(find.text('Resurse partener'), findsOneWidget);
    });

    testWidgets(
        'lucrare manuală (fără ofertă sursă) arată "Materiale asociate" și "Resurse proprii"',
        (tester) async {
      await tester.pumpWidget(const _ExecutieTabHarness(
        liniiPlanificateNotEmpty: false,
        sourceOfferSetat: false,
      ));

      expect(find.text('Materiale asociate'), findsOneWidget);
      expect(find.text('Resurse proprii'), findsOneWidget);
      expect(find.text('Resurse partener'), findsOneWidget);
    });
  });
}
