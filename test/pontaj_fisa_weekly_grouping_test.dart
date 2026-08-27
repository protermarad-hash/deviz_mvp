import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_aggregator.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_weekly_grouping.dart';

/// Testează logica pură de grupare pe săptămână calendaristică
/// (luni-duminică) a rândurilor de pontaj-partener, folosită de raportul
/// nou "Pontaj parteneri — săptămânal".
void main() {
  PontajFisaRow partnerRow({
    required String persoanaNume,
    required String partenerId,
    String partenerNume = 'Partener SRL',
    required DateTime dataStart,
    DateTime? dataEnd,
    double oreTotale = 8,
    double costOre = 400,
    String jobCode = '',
    String jobTitle = '',
  }) {
    return PontajFisaRow(
      persoanaNume: persoanaNume,
      esteProprie: false,
      partenerId: partenerId,
      partenerNume: partenerNume,
      jobCode: jobCode,
      jobTitle: jobTitle,
      dataStart: dataStart,
      dataEnd: dataEnd ?? dataStart,
      orePeZi: 8,
      oreTotale: oreTotale,
      tarifOrar: 50,
      costOre: costOre,
      costDiurna: 0,
      costCazare: 0,
      moneda: 'RON',
    );
  }

  group('startOfWeekMonday', () {
    test('luni ramane pe loc', () {
      // 2026-06-08 este luni.
      final monday = DateTime(2026, 6, 8);
      expect(startOfWeekMonday(monday), DateTime(2026, 6, 8));
    });

    test('duminica se muta pe lunea din spate', () {
      // 2026-06-14 este duminica saptamanii care incepe luni 2026-06-08.
      final sunday = DateTime(2026, 6, 14);
      expect(startOfWeekMonday(sunday), DateTime(2026, 6, 8));
    });
  });

  group('groupPontajFisaRowsByWeek', () {
    test('(a) rand normal intr-o singura saptamana', () {
      // Marti 2026-06-09, in saptamana 08-14 iunie.
      final row = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
      );

      final groups = groupPontajFisaRowsByWeek([row]);

      expect(groups.length, 1);
      expect(groups.first.weekStart, DateTime(2026, 6, 8));
      final worker = groups.first.parteneri.single.muncitori.single;
      expect(worker.areRandSpansMultipleWeeks, isFalse);
      expect(worker.totalCost, 400);
    });

    test('(b) rand "interval" ce trece peste granita saptamanii', () {
      // Vineri 2026-06-12 -> luni 2026-06-15: trece din saptamana 08-14
      // in saptamana 15-21.
      final row = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 12),
        dataEnd: DateTime(2026, 6, 15),
        oreTotale: 32,
        costOre: 1600,
      );

      final groups = groupPontajFisaRowsByWeek([row]);

      // Randul e atribuit INTEGRAL saptamanii de dataStart (08-14 iunie).
      expect(groups.length, 1);
      expect(groups.first.weekStart, DateTime(2026, 6, 8));
      final worker = groups.first.parteneri.single.muncitori.single;
      expect(worker.areRandSpansMultipleWeeks, isTrue);
      expect(worker.totalCost, 1600);
    });

    test(
        '(c) doi muncitori cu nume diferite, fara masterWorkerId, '
        'nu se amesteca', () {
      final row1 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
      );
      final row2 = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 10),
        costOre: 350,
      );

      final groups = groupPontajFisaRowsByWeek([row1, row2]);

      expect(groups.length, 1);
      final partner = groups.first.parteneri.single;
      expect(partner.muncitori.length, 2);
      expect(partner.totalCost, 750);
      final names = partner.muncitori.map((w) => w.displayName).toSet();
      expect(names, {'Ion Popescu', 'Vasile Ionescu'});
    });

    test('(d) acelasi nume, capitalizare diferita -> se agrega corect', () {
      final row1 = partnerRow(
        persoanaNume: 'ion popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
      );
      final row2 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 10),
        costOre: 350,
      );
      final row3 = partnerRow(
        persoanaNume: 'ION POPESCU',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 11),
        costOre: 300,
      );

      final groups = groupPontajFisaRowsByWeek([row1, row2, row3]);

      final partner = groups.first.parteneri.single;
      expect(partner.muncitori.length, 1);
      final worker = partner.muncitori.single;
      expect(worker.totalCost, 1050);
      expect(worker.numarRanduri, 3);
    });

    test('grupare per partener foloseste partenerId, nu numele', () {
      final row1 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        partenerNume: 'Alfa SRL',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
      );
      final row2 = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p2',
        partenerNume: 'Beta SRL',
        dataStart: DateTime(2026, 6, 9),
        costOre: 500,
      );

      final groups = groupPontajFisaRowsByWeek([row1, row2]);

      expect(groups.length, 1);
      expect(groups.first.parteneri.length, 2);
      final ids = groups.first.parteneri.map((p) => p.partnerId).toSet();
      expect(ids, {'p1', 'p2'});
    });

    test('randuri fara data sau proprii sunt ignorate', () {
      final rowFaraData = PontajFisaRow(
        persoanaNume: 'Fara Data',
        esteProprie: false,
        partenerId: 'p1',
        orePeZi: 8,
        oreTotale: 8,
        tarifOrar: 50,
        costOre: 400,
        costDiurna: 0,
        costCazare: 0,
        moneda: 'RON',
      );
      final rowProprie = PontajFisaRow(
        persoanaNume: 'Angajat Propriu',
        esteProprie: true,
        dataStart: DateTime(2026, 6, 9),
        dataEnd: DateTime(2026, 6, 9),
        orePeZi: 8,
        oreTotale: 8,
        tarifOrar: 50,
        costOre: 400,
        costDiurna: 0,
        costCazare: 0,
        moneda: 'RON',
      );

      final groups =
          groupPontajFisaRowsByWeek([rowFaraData, rowProprie]);

      expect(groups, isEmpty);
    });

    test('saptamanile sunt sortate descrescator (cea mai recenta prima)', () {
      final rowVechi = partnerRow(
        persoanaNume: 'A',
        partenerId: 'p1',
        dataStart: DateTime(2026, 5, 4),
      );
      final rowNou = partnerRow(
        persoanaNume: 'B',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
      );

      final groups = groupPontajFisaRowsByWeek([rowVechi, rowNou]);

      expect(groups.length, 2);
      expect(groups.first.weekStart.isAfter(groups.last.weekStart), isTrue);
    });
  });

  group('PontajFisaWorkerWeeklyTotal.intrari (Faza 1 — detaliu individual)', () {
    test('o singura intrare -> lista "intrari" contine exact acel rand', () {
      final row = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Montaj centrala',
      );

      final groups = groupPontajFisaRowsByWeek([row]);
      final worker = groups.first.parteneri.single.muncitori.single;

      expect(worker.intrari.length, 1);
      expect(worker.intrari.single.row.jobCode, 'DVZ-2026-0001');
      expect(worker.intrari.single.row.jobTitle, 'Montaj centrala');
      expect(worker.intrari.single.row.dataStart, DateTime(2026, 6, 9));
      expect(worker.intrari.single.row.costTotal, 400);
      // Sumele agregate raman neschimbate (Faza 1 e strict aditiva).
      expect(worker.totalCost, 400);
      expect(worker.numarRanduri, 1);
    });

    test(
        'muncitor cu intrari pe DOUA lucrari diferite in aceeasi saptamana '
        '-> "intrari" pastreaza ambele, distincte, sortate cronologic', () {
      final rowA = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 11), // joi
        costOre: 300,
        jobCode: 'DVZ-2026-0002',
        jobTitle: 'Lucrare a doua',
      );
      final rowB = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9), // marti — mai devreme
        costOre: 400,
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Lucrare intai',
      );

      // Ordine intentionat inversa la intrare, ca sa verificam sortarea.
      final groups = groupPontajFisaRowsByWeek([rowA, rowB]);
      final worker = groups.first.parteneri.single.muncitori.single;

      expect(worker.numarRanduri, 2);
      expect(worker.totalCost, 700);
      expect(worker.intrari.length, 2);
      // Sortate cronologic: marti (rowB) inaintea lui joi (rowA).
      expect(worker.intrari[0].row.jobCode, 'DVZ-2026-0001');
      expect(worker.intrari[0].row.dataStart, DateTime(2026, 6, 9));
      expect(worker.intrari[1].row.jobCode, 'DVZ-2026-0002');
      expect(worker.intrari[1].row.dataStart, DateTime(2026, 6, 11));
      // Fiecare intrare isi pastreaza costul propriu, distinct.
      expect(worker.intrari[0].row.costTotal, 400);
      expect(worker.intrari[1].row.costTotal, 300);
    });

    test('intrare "interval" (dataStart != dataEnd) pastreaza ambele date', () {
      final row = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 12),
        dataEnd: DateTime(2026, 6, 13),
        costOre: 800,
        jobCode: 'DVZ-2026-0003',
      );

      final groups = groupPontajFisaRowsByWeek([row]);
      final worker = groups.first.parteneri.single.muncitori.single;

      expect(worker.intrari.single.row.dataStart, DateTime(2026, 6, 12));
      expect(worker.intrari.single.row.dataEnd, DateTime(2026, 6, 13));
      expect(worker.intrari.single.spansMultipleWeeks, isFalse);
    });
  });
}
