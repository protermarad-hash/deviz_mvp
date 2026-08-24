import 'package:devizpro_ultra/features/jobs/services/lucrare_labor_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testează `buildMultiDayLaborEntries` — Varianta A (iul 2026) pentru
/// pontaj rapid manoperă proprie: generează câte o intrare `_labor` per zi
/// selectată, posibil neconsecutivă (ex: luni + miercuri + vineri), spre
/// deosebire de `laborPeriodDays`, care presupune un interval continuu.
///
/// Migrat la semnătura cu ore PER ZI (`hoursPerDayByDate`, nu un singur
/// `hoursPerDay` uniform) — testele "aceleași ore pe toate zilele" verifică
/// EXACT aceleași așteptări ca înainte de migrare (compatibilitate), plus
/// teste noi pentru ore diferite per zi (capacitatea nouă).
void main() {
  LucrareLaborCalculator buildCalc() => LucrareLaborCalculator(
        jobId: 'job-1',
        employeesProvider: () => const [],
        teamsProvider: () => const [],
      );

  Map<DateTime, double> uniformMap(Set<DateTime> days, double hours) => {
        for (final d in days) DateTime(d.year, d.month, d.day): hours,
      };

  group('LucrareLaborCalculator.buildMultiDayLaborEntries', () {
    test('generează o intrare per zi selectată, id-uri unice', () {
      final calc = buildCalc();
      final zile = {
        DateTime(2026, 7, 6), // luni
        DateTime(2026, 7, 8), // miercuri
        DateTime(2026, 7, 10), // vineri
      };
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: zile,
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: uniformMap(zile, 8),
        hourlyRate: 40,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );

      expect(entries.length, 3);
      final ids = entries.map((e) => e['id']).toSet();
      expect(ids.length, 3); // toate id-urile sunt unice

      // Sortate cronologic, indiferent de ordinea din Set.
      expect(entries[0]['date'], '06.07.2026');
      expect(entries[1]['date'], '08.07.2026');
      expect(entries[2]['date'], '10.07.2026');
    });

    test('ore uniforme pe toate zilele (compatibilitate cu comportamentul vechi)',
        () {
      final calc = buildCalc();
      final zile = {DateTime(2026, 7, 6), DateTime(2026, 7, 8)};
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: zile,
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: uniformMap(zile, 6),
        hourlyRate: 50,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );

      for (final e in entries) {
        expect(e['hoursPerDay'], 6);
        expect(e['hours'], 6);
        expect(e['hourlyRate'], 50);
        expect(e['tripDays'], 1.0);
        expect(e['costOre'], 300); // 6 * 50
        expect(e['costTotalLinie'], 300);
        // periodStartDate == periodEndDate — fiecare intrare e o zi unică.
        expect(e['periodStartDate'], e['periodEndDate']);
      }
    });

    test('diurnă/cazare incluse se aplică per zi (nu pe tot intervalul)', () {
      final calc = buildCalc();
      final zile = {
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 8),
        DateTime(2026, 7, 10),
      };
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: zile,
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: uniformMap(zile, 8),
        hourlyRate: 40,
        includeDiurna: true,
        diurnaPerDay: 50,
        includeCazare: true,
        cazarePerNoapte: 100,
      );

      for (final e in entries) {
        expect(e['zileDiurna'], 1.0);
        expect(e['noptiCazare'], 1.0);
        expect(e['costDiurna'], 50);
        expect(e['costCazare'], 100);
        expect(e['costTotalLinie'], (8 * 40) + 50 + 100);
      }
      // Diurna/cazare NU se înmulțesc cu numărul de zile per intrare —
      // fiecare zi are propria diurnă de 50, nu 150 (3 zile × 50).
      expect(entries.every((e) => e['costDiurna'] == 50), isTrue);
    });

    test('selectedDays gol → listă goală, fără crash', () {
      final calc = buildCalc();
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {},
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: const {},
        hourlyRate: 40,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );
      expect(entries, isEmpty);
    });

    test('ore diferite de 8 (ore/zi custom, uniform) se reflectă corect', () {
      final calc = buildCalc();
      final zile = {DateTime(2026, 7, 6)};
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: zile,
        whoId: 'team:t1',
        whoLabel: 'Echipa Nord',
        type: 'team',
        hoursPerDayByDate: uniformMap(zile, 4),
        hourlyRate: 60,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );
      expect(entries.single['hours'], 4);
      expect(entries.single['costOre'], 240); // 4 * 60
      expect(entries.single['type'], 'team');
      expect(entries.single['whoId'], 'team:t1');
    });

    // ── Teste noi — ore DIFERITE per zi (capacitatea nouă) ──────────────

    test('ore diferite per zi — fiecare rând primește ora EXACTĂ a zilei lui',
        () {
      final calc = buildCalc();
      final luni = DateTime(2026, 7, 6);
      final miercuri = DateTime(2026, 7, 8);
      final vineri = DateTime(2026, 7, 10);
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {luni, miercuri, vineri},
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: {
          luni: 2,
          miercuri: 4,
          vineri: 6,
        },
        hourlyRate: 50,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );

      expect(entries.length, 3);
      final byDate = {for (final e in entries) e['date']: e};
      expect(byDate['06.07.2026']!['hours'], 2);
      expect(byDate['06.07.2026']!['costOre'], 100); // 2 * 50
      expect(byDate['08.07.2026']!['hours'], 4);
      expect(byDate['08.07.2026']!['costOre'], 200); // 4 * 50
      expect(byDate['10.07.2026']!['hours'], 6);
      expect(byDate['10.07.2026']!['costOre'], 300); // 6 * 50

      // "Ore totale" (suma) NU e uniformă — exact cerința: 2+4+6=12,
      // NU 3 zile × o valoare unică.
      final totalHours =
          entries.fold<double>(0, (s, e) => s + (e['hours'] as double));
      expect(totalHours, 12);
    });

    test('zi lipsă din hoursPerDayByDate → fallback 8.0 (aceeași valoare de siguranță ca înainte)',
        () {
      final calc = buildCalc();
      final ziCuOra = DateTime(2026, 7, 6);
      final ziFaraOra = DateTime(2026, 7, 8);
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {ziCuOra, ziFaraOra},
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: {ziCuOra: 3}, // ziFaraOra lipsește intenționat
        hourlyRate: 50,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );

      final byDate = {for (final e in entries) e['date']: e};
      expect(byDate['06.07.2026']!['hours'], 3);
      expect(byDate['08.07.2026']!['hours'], 8); // fallback
    });

    test('ore 0 sau negative per zi → fallback 8.0 (sanitizeLaborHoursPerDay)',
        () {
      final calc = buildCalc();
      final zi1 = DateTime(2026, 7, 6);
      final zi2 = DateTime(2026, 7, 7);
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {zi1, zi2},
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDayByDate: {zi1: 0, zi2: -5},
        hourlyRate: 50,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );
      for (final e in entries) {
        expect(e['hours'], 8);
      }
    });
  });
}
