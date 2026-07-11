import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:devizpro_ultra/features/partner_financial/partner_financial_models.dart';
import 'package:devizpro_ultra/features/partner_financial/partner_financial_repository.dart';
import 'package:devizpro_ultra/features/programari/appointment_status_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PartnerTransaction ptxn(
    String id,
    String partnerId,
    double amount,
    PartnerTransactionType type,
    PartnerTransactionDirection direction, {
    required String appointmentId,
  }) =>
      PartnerTransaction(
        id: id,
        partnerId: partnerId,
        partnerName: 'Partener $partnerId',
        type: type,
        direction: direction,
        amount: amount,
        date: DateTime(2026, 7, 10),
        description: 'test',
        referenceId: appointmentId,
        referenceType: 'programare',
        createdAt: DateTime(2026, 7, 10),
        updatedAt: DateTime(2026, 7, 10),
      );

  setUp(() {
    // Fără Firebase (FirebaseBootstrap.isInitialized == false) → repo lucrează
    // exclusiv pe SharedPreferences local.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('removeOrphanedTransactionsFor (helper comun Part C)', () {
    test('șterge ptxn_for/_exec/_materials pentru o programare', () async {
      final repo = PartnerFinancialRepository();
      await repo.upsertTransaction(ptxn(
        'ptxn_apt1_for',
        'p1',
        100,
        PartnerTransactionType.incasareProgramare,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt1',
      ));
      await repo.upsertTransaction(ptxn(
        'ptxn_apt1_exec',
        'p2',
        50,
        PartnerTransactionType.plataProgramare,
        PartnerTransactionDirection.iesire,
        appointmentId: 'apt1',
      ));
      await repo.upsertTransaction(ptxn(
        'ptxn_apt1_materials',
        'p1',
        30,
        PartnerTransactionType.consumMateriale,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt1',
      ));
      // Tranzacție de la altă programare — trebuie să rămână neatinsă.
      await repo.upsertTransaction(ptxn(
        'ptxn_apt2_for',
        'p1',
        999,
        PartnerTransactionType.incasareProgramare,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt2',
      ));

      final removed = await repo.removeOrphanedTransactionsFor('apt1');
      expect(removed, 3);

      final remaining = await repo.listLocalOnlyTransactions();
      expect(remaining.map((t) => t.id).toList(), ['ptxn_apt2_for']);
    });

    test('no-op când nu există nicio tranzacție (idempotent)', () async {
      final repo = PartnerFinancialRepository();
      final removed = await repo.removeOrphanedTransactionsFor('inexistent');
      expect(removed, 0);
      expect(await repo.listLocalOnlyTransactions(), isEmpty);
    });

    test('șterge doar tranzacțiile care există efectiv', () async {
      final repo = PartnerFinancialRepository();
      await repo.upsertTransaction(ptxn(
        'ptxn_apt3_for',
        'p1',
        100,
        PartnerTransactionType.incasareProgramare,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt3',
      ));
      // Doar _for există; _exec și _materials nu.
      final removed = await repo.removeOrphanedTransactionsFor('apt3');
      expect(removed, 1);
      expect(await repo.listLocalOnlyTransactions(), isEmpty);
    });
  });

  group('regresie upsert-by-id (Problema a rămâne corectă)', () {
    test('upsert cu același id actualizează în loc, fără dublare', () async {
      final repo = PartnerFinancialRepository();
      await repo.upsertTransaction(ptxn(
        'ptxn_apt4_for',
        'p1',
        100,
        PartnerTransactionType.incasareProgramare,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt4',
      ));
      // Re-upsert cu aceeași id, sumă schimbată (ex: re-sync după edit).
      await repo.upsertTransaction(ptxn(
        'ptxn_apt4_for',
        'p1',
        250,
        PartnerTransactionType.incasareProgramare,
        PartnerTransactionDirection.intrare,
        appointmentId: 'apt4',
      ));
      final all = await repo.listLocalOnlyTransactions();
      final matching = all.where((t) => t.id == 'ptxn_apt4_for').toList();
      expect(matching, hasLength(1));
      expect(matching.first.amount, 250);
    });
  });

  group('predicat guard status (Problema c)', () {
    test('doar finalizată declanșează generarea; retrogradarea o oprește', () {
      expect(isCompletedAppointmentStatus('finalizata'), isTrue);
      for (final status in [
        'planificata',
        'in_curs',
        'amanata',
        'anulata',
        '',
      ]) {
        expect(isCompletedAppointmentStatus(status), isFalse, reason: status);
      }
    });
  });
}
