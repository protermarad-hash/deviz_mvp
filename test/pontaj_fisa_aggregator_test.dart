import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/jobs/job_partner_models.dart';
import 'package:devizpro_ultra/features/jobs/services/pontaj_fisa_aggregator.dart';

/// Testează logica pură de filtrare pe perioadă folosită de fișa de pontaj
/// PDF (Faza 2 — per lucrare, Faza 3 — agregat cross-lucrare): un rând
/// intră în fișă doar dacă intervalul lui intersectează perioada cerută.
void main() {
  group('buildPontajFisaOwnRows — filtrare pe perioadă', () {
    final laborRows = [
      {
        'who': 'Ion Popescu',
        'periodStartDate': DateTime(2026, 6, 10).toIso8601String(),
        'periodEndDate': DateTime(2026, 6, 10).toIso8601String(),
        'hoursPerDay': 8,
        'hours': 8,
        'hourlyRate': 50,
        'costOre': 400,
        'costDiurna': 0,
        'costCazare': 0,
      },
      {
        'who': 'Vasile Ionescu',
        'periodStartDate': DateTime(2026, 6, 20).toIso8601String(),
        'periodEndDate': DateTime(2026, 6, 25).toIso8601String(),
        'hoursPerDay': 8,
        'hours': 48,
        'hourlyRate': 40,
        'costOre': 1920,
        'costDiurna': 100,
        'costCazare': 0,
      },
      {
        'who': 'Mihai Stan',
        'periodStartDate': DateTime(2026, 7, 5).toIso8601String(),
        'periodEndDate': DateTime(2026, 7, 5).toIso8601String(),
        'hoursPerDay': 8,
        'hours': 8,
        'hourlyRate': 45,
        'costOre': 360,
        'costDiurna': 0,
        'costCazare': 0,
      },
    ];

    test('fara perioada -> toate randurile', () {
      final rows = buildPontajFisaOwnRows(laborRows);
      expect(rows.length, 3);
    });

    test('perioada 1-30 iunie -> exclude randul din iulie', () {
      final rows = buildPontajFisaOwnRows(
        laborRows,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
      );
      expect(rows.length, 2);
      expect(rows.map((r) => r.persoanaNume),
          containsAll(['Ion Popescu', 'Vasile Ionescu']));
    });

    test('perioada partiala (18-22 iunie) include rand cu interval care se suprapune partial',
        () {
      final rows = buildPontajFisaOwnRows(
        laborRows,
        periodStart: DateTime(2026, 6, 18),
        periodEnd: DateTime(2026, 6, 22),
      );
      // Vasile: 20-25 iunie se suprapune cu 18-22 -> inclus.
      // Ion: 10 iunie NU se suprapune -> exclus.
      expect(rows.length, 1);
      expect(rows.single.persoanaNume, 'Vasile Ionescu');
    });

    test('perioada fara nicio suprapunere -> lista goala', () {
      final rows = buildPontajFisaOwnRows(
        laborRows,
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 1, 31),
      );
      expect(rows, isEmpty);
    });

    test('costOre + costDiurna + costCazare -> costTotal corect', () {
      final rows = buildPontajFisaOwnRows(laborRows);
      final vasile = rows.firstWhere((r) => r.persoanaNume == 'Vasile Ionescu');
      expect(vasile.costTotal, 1920 + 100 + 0);
    });
  });

  group('buildPontajFisaPartnerRows — filtrare pe perioadă + nume partener',
      () {
    final workers = [
      JobPartnerWorker(
        id: 'w1',
        jobId: 'job-1',
        partnerId: 'partner-1',
        fullName: 'Ana Dinu',
        workedHours: 8,
        hoursPerDay: 8,
        hourlyRate: 55,
        workPeriodStart: DateTime(2026, 6, 12),
        workPeriodEnd: DateTime(2026, 6, 12),
        workDays: 1,
        currency: 'RON',
      ),
      JobPartnerWorker(
        id: 'w2',
        jobId: 'job-1',
        partnerId: 'partner-1',
        fullName: 'Ana Dinu',
        workedHours: 8,
        hoursPerDay: 8,
        hourlyRate: 55,
        workPeriodStart: DateTime(2026, 8, 1),
        workPeriodEnd: DateTime(2026, 8, 1),
        workDays: 1,
        currency: 'RON',
      ),
      // Rand fara perioada setata (workPeriodStart == null, date vechi/legacy).
      JobPartnerWorker(
        id: 'w3',
        jobId: 'job-1',
        partnerId: 'partner-2',
        fullName: 'Radu Popa',
        workedHours: 20,
        hourlyRate: 30,
        currency: 'RON',
      ),
    ];
    final partnerNames = {'partner-1': 'ACME SRL', 'partner-2': 'BETA SRL'};

    test('rand fara data -> exclus la orice filtrare pe perioada', () {
      final rows = buildPontajFisaPartnerRows(
        workers,
        periodStart: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 12, 31),
        partnerNamesById: partnerNames,
      );
      expect(rows.any((r) => r.persoanaNume == 'Radu Popa'), isFalse);
    });

    test('fara perioada -> toate randurile, inclusiv cel fara data', () {
      final rows = buildPontajFisaPartnerRows(
        workers,
        partnerNamesById: partnerNames,
      );
      expect(rows.length, 3);
    });

    test('perioada iunie -> doar randul w1 al Anei, cu numele partenerului corect',
        () {
      final rows = buildPontajFisaPartnerRows(
        workers,
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
        partnerNamesById: partnerNames,
      );
      expect(rows.length, 1);
      expect(rows.single.persoanaNume, 'Ana Dinu');
      expect(rows.single.partenerNume, 'ACME SRL');
      expect(rows.single.esteProprie, isFalse);
    });

    test('laborCost/perDiemCost/lodgingCost din model -> costOre/costDiurna/costCazare corecte',
        () {
      final withPerDiem = JobPartnerWorker(
        id: 'w4',
        jobId: 'job-1',
        partnerId: 'partner-1',
        fullName: 'Test PerDiem',
        workedHours: 10,
        hourlyRate: 20,
        perDiemDays: 2,
        perDiemPerDay: 30,
        lodgingNights: 1,
        lodgingPerNight: 80,
        currency: 'RON',
      );
      final rows = buildPontajFisaPartnerRows([withPerDiem]);
      final row = rows.single;
      expect(row.costOre, 200); // 10 * 20
      expect(row.costDiurna, 60); // 2 * 30
      expect(row.costCazare, 80); // 1 * 80
      expect(row.costTotal, 340);
    });
  });
}
