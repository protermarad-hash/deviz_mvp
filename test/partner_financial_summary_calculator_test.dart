import 'package:devizpro_ultra/features/partner_financial/partner_financial_calculator.dart';
import 'package:devizpro_ultra/features/partner_financial/partner_financial_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _partnerId = 'partner-1';
const _partnerName = 'Partener Test';

PartnerTransaction _transaction({
  required String id,
  required PartnerTransactionType type,
  required PartnerTransactionDirection direction,
  required double amount,
  PartnerTransactionStatus status = PartnerTransactionStatus.neplatit,
}) {
  final date = DateTime(2026, 7, 13);
  return PartnerTransaction(
    id: id,
    partnerId: _partnerId,
    partnerName: _partnerName,
    type: type,
    direction: direction,
    amount: amount,
    date: date,
    description: type.label,
    status: status,
    createdAt: date,
    updatedAt: date,
  );
}

PartnerFinancialSummary _calculate(List<PartnerTransaction> transactions) {
  return calculatePartnerFinancialSummaryFromTransactions(
    partnerId: _partnerId,
    partnerName: _partnerName,
    transactions: transactions,
    calculatedAt: DateTime(2026, 7, 13),
  );
}

void main() {
  group('calculatePartnerFinancialSummaryFromTransactions', () {
    test('datorie 3800 și plată manuală 600 lasă rest 3200', () {
      final summary = _calculate([
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 3800,
        ),
        _transaction(
          id: 'payment',
          type: PartnerTransactionType.plataManuala,
          direction: PartnerTransactionDirection.iesire,
          amount: 600,
          status: PartnerTransactionStatus.platit,
        ),
      ]);

      expect(summary.totalDePlata, 3200);
      expect(summary.totalPlatit, 600);
      expect(summary.soldNet, -3200);
    });

    test('două plăți manuale, indiferent de status, lasă rest 2300', () {
      final summary = _calculate([
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 3800,
        ),
        _transaction(
          id: 'payment-600',
          type: PartnerTransactionType.plataManuala,
          direction: PartnerTransactionDirection.iesire,
          amount: 600,
          status: PartnerTransactionStatus.platit,
        ),
        _transaction(
          id: 'payment-900',
          type: PartnerTransactionType.plataManuala,
          direction: PartnerTransactionDirection.iesire,
          amount: 900,
        ),
      ]);

      expect(summary.totalDePlata, 2300);
      expect(summary.totalPlatit, 1500);
      expect(summary.soldNet, -2300);
    });

    test('datoria fără plăți rămâne integral de plată', () {
      final summary = _calculate([
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 3800,
        ),
      ]);

      expect(summary.totalDePlata, 3800);
      expect(summary.totalPlatit, 0);
      expect(summary.soldNet, -3800);
    });

    test('supraplata este plafonată la zero și păstrează totalul plătit', () {
      final summary = _calculate([
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 3800,
        ),
        _transaction(
          id: 'payment',
          type: PartnerTransactionType.plataManuala,
          direction: PartnerTransactionDirection.iesire,
          amount: 4500,
          status: PartnerTransactionStatus.platit,
        ),
      ]);

      expect(summary.totalDePlata, 0);
      expect(summary.totalPlatit, 4500);
      expect(summary.soldNet, 0);
    });

    test('încasarea manuală reduce doar creanța', () {
      final summary = _calculate([
        _transaction(
          id: 'credit',
          type: PartnerTransactionType.incasareProgramare,
          direction: PartnerTransactionDirection.intrare,
          amount: 3800,
        ),
        _transaction(
          id: 'collection',
          type: PartnerTransactionType.incasareManuala,
          direction: PartnerTransactionDirection.intrare,
          amount: 600,
          status: PartnerTransactionStatus.platit,
        ),
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 1000,
        ),
      ]);

      expect(summary.totalDeIncasat, 3200);
      expect(summary.totalIncasat, 600);
      expect(summary.totalDePlata, 1000);
      expect(summary.totalPlatit, 0);
    });

    test('plata manuală reduce doar datoria, nu creanța', () {
      final summary = _calculate([
        _transaction(
          id: 'credit',
          type: PartnerTransactionType.vanzareProdus,
          direction: PartnerTransactionDirection.intrare,
          amount: 1000,
        ),
        _transaction(
          id: 'debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 2000,
        ),
        _transaction(
          id: 'payment',
          type: PartnerTransactionType.plataManuala,
          direction: PartnerTransactionDirection.iesire,
          amount: 500,
          status: PartnerTransactionStatus.platit,
        ),
      ]);

      expect(summary.totalDeIncasat, 1000);
      expect(summary.totalIncasat, 0);
      expect(summary.totalDePlata, 1500);
      expect(summary.totalPlatit, 500);
      expect(summary.soldNet, -500);
    });

    test('programarea și achiziția rămân surse de datorie', () {
      final summary = _calculate([
        _transaction(
          id: 'appointment-debt',
          type: PartnerTransactionType.plataProgramare,
          direction: PartnerTransactionDirection.iesire,
          amount: 2000,
        ),
        _transaction(
          id: 'purchase-debt',
          type: PartnerTransactionType.achizitieProodus,
          direction: PartnerTransactionDirection.iesire,
          amount: 1800,
        ),
      ]);

      expect(summary.totalDePlata, 3800);
      expect(summary.totalPlatit, 0);
    });

    test('eliminarea plății din intrare crește din nou restul', () {
      final debt = _transaction(
        id: 'debt',
        type: PartnerTransactionType.plataProgramare,
        direction: PartnerTransactionDirection.iesire,
        amount: 3800,
      );
      final payment = _transaction(
        id: 'payment',
        type: PartnerTransactionType.plataManuala,
        direction: PartnerTransactionDirection.iesire,
        amount: 600,
        status: PartnerTransactionStatus.platit,
      );

      expect(_calculate([debt, payment]).totalDePlata, 3200);
      expect(_calculate([debt]).totalDePlata, 3800);
    });
  });
}
