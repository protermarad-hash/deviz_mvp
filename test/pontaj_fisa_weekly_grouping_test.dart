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

  group('regroupByPartnerAcrossWeeks (Faza 4 — vedere Partener→Săptămână)', () {
    test('acelasi partener, doua saptamani diferite -> UN card partener cu '
        '2 intrari de saptamana, nu doua carduri separate', () {
      final rowS1 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        partenerNume: 'Alfa SRL',
        dataStart: DateTime(2026, 6, 9), // saptamana 08-14 iunie
        costOre: 400,
      );
      final rowS2 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        partenerNume: 'Alfa SRL',
        dataStart: DateTime(2026, 6, 16), // saptamana 15-21 iunie
        costOre: 600,
      );

      final weeklyGroups = groupPontajFisaRowsByWeek([rowS1, rowS2]);
      expect(weeklyGroups.length, 2,
          reason: 'precondiție: sursa are 2 grupuri săptămânale distincte');

      final byPartner = regroupByPartnerAcrossWeeks(weeklyGroups);

      expect(byPartner.length, 1,
          reason: 'un singur partener, indiferent de cate saptamani');
      final partner = byPartner.single;
      expect(partner.partnerId, 'p1');
      expect(partner.totalCost, 1000);
      expect(partner.saptamani.length, 2);
      // Sortate descrescator: 15-21 iunie inaintea lui 08-14 iunie.
      expect(partner.saptamani[0].weekStart, DateTime(2026, 6, 15));
      expect(partner.saptamani[0].total.totalCost, 600);
      expect(partner.saptamani[1].weekStart, DateTime(2026, 6, 8));
      expect(partner.saptamani[1].total.totalCost, 400);
    });

    test('doi parteneri diferiti in aceeasi saptamana -> 2 carduri partener, '
        'fiecare cu totalul lui propriu', () {
      final rowA = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        partenerNume: 'Alfa SRL',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
      );
      final rowB = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p2',
        partenerNume: 'Beta SRL',
        dataStart: DateTime(2026, 6, 9),
        costOre: 900,
      );

      final weeklyGroups = groupPontajFisaRowsByWeek([rowA, rowB]);
      final byPartner = regroupByPartnerAcrossWeeks(weeklyGroups);

      expect(byPartner.length, 2);
      // Sortat descrescator dupa totalCost -> Beta (900) inaintea lui Alfa (400).
      expect(byPartner[0].partnerId, 'p2');
      expect(byPartner[0].totalCost, 900);
      expect(byPartner[1].partnerId, 'p1');
      expect(byPartner[1].totalCost, 400);
    });

    test('muncitorii ramân accesibili nemodificati prin vederea noua '
        '(aceleasi obiecte PontajFisaPartnerWeeklyTotal, nu copii)', () {
      final row = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        costOre: 400,
        jobCode: 'DVZ-2026-0001',
      );

      final weeklyGroups = groupPontajFisaRowsByWeek([row]);
      final byPartner = regroupByPartnerAcrossWeeks(weeklyGroups);

      final total = byPartner.single.saptamani.single.total;
      expect(total.muncitori.single.displayName, 'Ion Popescu');
      expect(total.muncitori.single.intrari.single.row.jobCode, 'DVZ-2026-0001');
    });

    test('lista de intrare goala -> lista de parteneri goala', () {
      expect(regroupByPartnerAcrossWeeks(const []), isEmpty);
    });
  });

  group('partnerJobLabels (FIX 3 — rezumat lucrari pe card partener)', () {
    test('un singur muncitor, o singura lucrare -> o singura eticheta', () {
      final row = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Reparatie centrala termica',
      );
      final partner = groupPontajFisaRowsByWeek([row]).first.parteneri.single;

      expect(partnerJobLabels(partner),
          ['DVZ-2026-0001 · Reparatie centrala termica']);
    });

    test('doi muncitori, aceeasi lucrare -> o singura eticheta (dedup)', () {
      final row1 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Montaj VRF',
      );
      final row2 = partnerRow(
        persoanaNume: 'Vasile Ionescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 10),
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Montaj VRF',
      );
      final partner =
          groupPontajFisaRowsByWeek([row1, row2]).first.parteneri.single;

      expect(partnerJobLabels(partner), ['DVZ-2026-0001 · Montaj VRF']);
    });

    test('un muncitor cu 2 intrari pe lucrari diferite -> 2 etichete, '
        'ordinea primei aparitii, fara duplicate', () {
      final rowA = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Lucrare A',
      );
      final rowB = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 10),
        jobCode: 'DVZ-2026-0002',
        jobTitle: 'Lucrare B',
      );
      // A doua intrare pe DVZ-2026-0001 (aceeasi lucrare ca prima) -> NU
      // trebuie sa produca un al treilea label duplicat.
      final rowA2 = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 11),
        jobCode: 'DVZ-2026-0001',
        jobTitle: 'Lucrare A',
      );
      final partner = groupPontajFisaRowsByWeek([rowA, rowB, rowA2])
          .first
          .parteneri
          .single;

      expect(partnerJobLabels(partner),
          ['DVZ-2026-0001 · Lucrare A', 'DVZ-2026-0002 · Lucrare B']);
    });

    test('jobCode gol, doar titlu -> foloseste titlul; ambele goale -> ignorat',
        () {
      final rowTitluDoar = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        jobCode: '',
        jobTitle: 'Lucrare fara cod',
      );
      final partner =
          groupPontajFisaRowsByWeek([rowTitluDoar]).first.parteneri.single;

      expect(partnerJobLabels(partner), ['Lucrare fara cod']);
    });

    test('nicio lucrare identificata (cod si titlu goale) -> lista goala', () {
      final row = partnerRow(
        persoanaNume: 'Ion Popescu',
        partenerId: 'p1',
        dataStart: DateTime(2026, 6, 9),
        jobCode: '',
        jobTitle: '',
      );
      final partner = groupPontajFisaRowsByWeek([row]).first.parteneri.single;

      expect(partnerJobLabels(partner), isEmpty);
    });
  });
}
