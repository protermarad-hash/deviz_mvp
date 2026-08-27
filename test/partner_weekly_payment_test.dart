// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/jobs/services/partner_weekly_payment_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Model ──────────────────────────────────────────────────────────────────

  group('PartnerWeeklyPayment — model', () {
    test('ID determinist are formatul pwp_{partnerId}_{YYYYMMDD}', () {
      final id = PartnerWeeklyPaymentRepository.paymentId(
          'abc123', DateTime(2025, 3, 10));
      expect(id, 'pwp_abc123_20250310');
    });

    test('ID cu luna și zi cu zero-padding corect', () {
      final id = PartnerWeeklyPaymentRepository.paymentId(
          'x', DateTime(2025, 1, 5));
      expect(id, 'pwp_x_20250105');
    });

    test('roundtrip toMap/fromMap păstrează toate câmpurile', () {
      final orig = PartnerWeeklyPayment(
        id: 'pwp_abc_20250310',
        partnerId: 'abc',
        weekStart: DateTime(2025, 3, 10),
        amountPaid: 1500.50,
        calculatedAmountAtMarking: 1600.0,
        paidAt: DateTime(2025, 3, 15, 10, 30),
        notes: 'Test notițe',
      );
      final back = PartnerWeeklyPayment.fromMap(orig.toMap());
      expect(back.id, orig.id);
      expect(back.partnerId, orig.partnerId);
      expect(back.amountPaid, orig.amountPaid);
      expect(back.calculatedAmountAtMarking, orig.calculatedAmountAtMarking);
      expect(back.notes, orig.notes);
    });

    test('fromMap cu câmpuri lipsă returnează valori implicite sigure', () {
      final p = PartnerWeeklyPayment.fromMap({});
      expect(p.id, '');
      expect(p.amountPaid, 0.0);
      expect(p.calculatedAmountAtMarking, 0.0);
      expect(p.notes, isNull);
    });
  });

  // ── Repository local ───────────────────────────────────────────────────────

  group('PartnerWeeklyPaymentRepository — local storage', () {
    test('(a) marcare inițială — creează document nou corect', () async {
      final repo = PartnerWeeklyPaymentRepository();
      final weekStart = DateTime(2025, 3, 10);
      const partnerId = 'partner_test';
      final payment = PartnerWeeklyPayment(
        id: PartnerWeeklyPaymentRepository.paymentId(partnerId, weekStart),
        partnerId: partnerId,
        weekStart: weekStart,
        amountPaid: 1500.0,
        calculatedAmountAtMarking: 1500.0,
        paidAt: DateTime(2025, 3, 15),
      );

      // upsertPayment scrie local (queue și Firebase sunt no-op fără inițializare)
      await repo.upsertPayment(payment);

      final loaded = await repo.getPaymentLocal(partnerId, weekStart);
      expect(loaded, isNotNull);
      expect(loaded!.id, payment.id);
      expect(loaded.amountPaid, 1500.0);
      expect(loaded.partnerId, partnerId);
    });

    test('(b) editare marcare existentă — suprascrie, nu duplică', () async {
      final repo = PartnerWeeklyPaymentRepository();
      final weekStart = DateTime(2025, 3, 10);
      const partnerId = 'partner_test';
      final id =
          PartnerWeeklyPaymentRepository.paymentId(partnerId, weekStart);

      final v1 = PartnerWeeklyPayment(
        id: id,
        partnerId: partnerId,
        weekStart: weekStart,
        amountPaid: 1000.0,
        calculatedAmountAtMarking: 1000.0,
        paidAt: DateTime(2025, 3, 10),
      );
      await repo.upsertPayment(v1);

      final v2 = PartnerWeeklyPayment(
        id: id,
        partnerId: partnerId,
        weekStart: weekStart,
        amountPaid: 1200.0,
        calculatedAmountAtMarking: 1000.0,
        paidAt: DateTime(2025, 3, 11),
        notes: 'Avans parțial',
      );
      await repo.upsertPayment(v2);

      final loaded = await repo.getPaymentLocal(partnerId, weekStart);
      expect(loaded!.amountPaid, 1200.0);
      expect(loaded.notes, 'Avans parțial');

      final all = await repo.listLocalPayments();
      expect(all.where((p) => p.id == id).length, 1,
          reason: 'Trebuie exact un document, fără duplicate');
    });
  });

  // ── Detecție discrepanță pontaj ────────────────────────────────────────────

  group('Discrepanță pontaj — logică pură', () {
    test(
        '(c) pontaj modificat după marcare → calculatedAmountAtMarking '
        'diferă de totalCostNow → discrepanță detectată', () {
      const calculatedAtMarking = 1500.0;
      const totalCostNow = 1600.0; // pontajul s-a schimbat
      const epsilon = 0.005;

      final hasDiscrepancy =
          (calculatedAtMarking - totalCostNow).abs() > epsilon;
      expect(hasDiscrepancy, isTrue);
    });

    test(
        '(d) pontaj nemodificat — fără discrepanță chiar dacă '
        'amountPaid diferă de totalCost (plată intenționat diferită)', () {
      const calculatedAtMarking = 1500.0;
      const totalCostNow = 1500.0; // pontajul NESCHIMBAT
      const amountPaid = 1200.0; // plată parțială intenționată
      const epsilon = 0.005;

      // Compară STRICT calculatedAmountAtMarking cu totalCostNow
      final hasDiscrepancy =
          (calculatedAtMarking - totalCostNow).abs() > epsilon;
      expect(hasDiscrepancy, isFalse);

      // Confirmare că diferența amountPaid vs. totalCost nu declanșează avertisment
      final wrongComparison = (amountPaid - totalCostNow).abs() > epsilon;
      expect(wrongComparison, isTrue,
          reason: 'Diferența sumei plătite față de total există...');
      expect(hasDiscrepancy, isFalse,
          reason: '...dar NU produce avertisment de discrepanță pontaj');
    });
  });
}
