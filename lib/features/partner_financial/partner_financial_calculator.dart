import 'partner_financial_models.dart';

/// Calculează sumarul financiar exclusiv din tranzacțiile primite.
///
/// Plățile manuale către partener sunt tratate explicit ca plăți efective,
/// indiferent de status. Astfel nu sunt confundate cu datoriile originale
/// marcate drept achitate (`plataProgramare` / `achizitieProodus`).
PartnerFinancialSummary calculatePartnerFinancialSummaryFromTransactions({
  required String partnerId,
  required String partnerName,
  required Iterable<PartnerTransaction> transactions,
  DateTime? calculatedAt,
}) {
  double crediteNeincasate = 0;
  double platiPrimite = 0;
  double datoriiBrute = 0;
  double platiCatrePartener = 0;
  DateTime? lastDate;

  final seenIds = <String>{};
  var transactionCount = 0;

  for (final transaction in transactions) {
    if (transaction.partnerId != partnerId || !seenIds.add(transaction.id)) {
      continue;
    }

    transactionCount++;
    if (lastDate == null || transaction.date.isAfter(lastDate)) {
      lastDate = transaction.date;
    }

    final amount = transaction.amount.abs();

    // O plată manuală de ieșire reprezintă bani trimiși efectiv partenerului.
    // Este tratată separat pentru a nu scădea generic datoriile originale care
    // au financialDirection == plata_efectuata_achitata.
    if (transaction.type == PartnerTransactionType.plataManuala &&
        transaction.direction == PartnerTransactionDirection.iesire) {
      platiCatrePartener += amount;
      continue;
    }

    switch (transaction.financialDirection) {
      case 'credit_neincasat':
        crediteNeincasate += amount;
        break;
      case 'plata_primita':
        platiPrimite += amount;
        break;
      case 'plata_efectuata':
        datoriiBrute += amount;
        break;
      case 'credit_incasat':
      case 'plata_efectuata_achitata':
        break;
    }
  }

  final totalDeIncasat =
      (crediteNeincasate - platiPrimite).clamp(0.0, double.infinity);
  final totalDePlata =
      (datoriiBrute - platiCatrePartener).clamp(0.0, double.infinity);

  return PartnerFinancialSummary(
    partnerId: partnerId,
    partnerName: partnerName,
    totalDeIncasat: totalDeIncasat,
    totalDePlata: totalDePlata,
    totalIncasat: platiPrimite,
    totalPlatit: platiCatrePartener,
    lastTransactionDate: lastDate,
    transactionCount: transactionCount,
    updatedAt: calculatedAt ?? DateTime.now(),
  );
}
