import 'package:devizpro_ultra/features/jobs/services/lucrare_labor_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testează `buildMultiDayLaborEntries` — Varianta A (iul 2026) pentru
/// pontaj rapid manoperă proprie: generează câte o intrare `_labor` per zi
/// selectată, posibil neconsecutivă (ex: luni + miercuri + vineri), spre
/// deosebire de `laborPeriodDays`, care presupune un interval continuu.
void main() {
  LucrareLaborCalculator buildCalc() => LucrareLaborCalculator(
        jobId: 'job-1',
        employeesProvider: () => const [],
        teamsProvider: () => const [],
      );

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
        hoursPerDay: 8,
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

    test('fiecare zi are aceleași ore/tarif, cost calculat corect', () {
      final calc = buildCalc();
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {DateTime(2026, 7, 6), DateTime(2026, 7, 8)},
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDay: 6,
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
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {
          DateTime(2026, 7, 6),
          DateTime(2026, 7, 8),
          DateTime(2026, 7, 10),
        },
        whoId: 'emp:e1',
        whoLabel: 'Ion Popescu',
        type: 'person',
        hoursPerDay: 8,
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
        hoursPerDay: 8,
        hourlyRate: 40,
        includeDiurna: false,
        diurnaPerDay: 0,
        includeCazare: false,
        cazarePerNoapte: 0,
      );
      expect(entries, isEmpty);
    });

    test('ore diferite de 8 (ore/zi custom) se reflectă corect', () {
      final calc = buildCalc();
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {DateTime(2026, 7, 6)},
        whoId: 'team:t1',
        whoLabel: 'Echipa Nord',
        type: 'team',
        hoursPerDay: 4,
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
  });
}
