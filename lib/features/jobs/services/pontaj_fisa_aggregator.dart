import '../job_partner_models.dart';
import '../lucrare_format_utils.dart';

/// Un rând pentru fișa de pontaj PDF (Faza 2 — per lucrare, Faza 3 —
/// agregat cross-lucrare). Sursă unică de adevăr pentru forma unui rând,
/// indiferent dacă provine din manoperă proprie (`laborEntries`) sau din
/// personal partener (`jobPartnerWorkers`).
class PontajFisaRow {
  const PontajFisaRow({
    required this.persoanaNume,
    required this.esteProprie,
    this.partenerNume = '',
    this.rol = '',
    this.jobCode = '',
    this.jobTitle = '',
    this.dataStart,
    this.dataEnd,
    required this.orePeZi,
    required this.oreTotale,
    required this.tarifOrar,
    required this.costOre,
    required this.costDiurna,
    required this.costCazare,
    required this.moneda,
  });

  final String persoanaNume;
  final bool esteProprie;

  /// Numele companiei partenere — doar dacă `esteProprie == false`.
  final String partenerNume;
  final String rol;

  /// Cod/titlu lucrare — folosit la detalierea per-lucrare din fișa
  /// agregată cross-lucrare (Faza 3); gol pentru fișa per-lucrare (Faza 2,
  /// unde toate rândurile aparțin oricum aceleiași lucrări).
  final String jobCode;
  final String jobTitle;

  final DateTime? dataStart;
  final DateTime? dataEnd;
  final double orePeZi;
  final double oreTotale;
  final double tarifOrar;
  final double costOre;
  final double costDiurna;
  final double costCazare;
  final String moneda;

  double get costTotal => costOre + costDiurna + costCazare;

  /// Interval [dataStart, dataEnd] intersectează [periodStart, periodEnd]?
  /// Rândurile fără dată (dataStart == null) NU sunt incluse niciodată
  /// într-o filtrare pe perioadă — nu există pe ce dată să le raportăm.
  bool intersecteazaPerioada(DateTime periodStart, DateTime periodEnd) {
    final start = dataStart;
    if (start == null) return false;
    final end = dataEnd ?? start;
    return !start.isAfter(periodEnd) && !end.isBefore(periodStart);
  }
}

/// Construiește rândurile de manoperă PROPRIE dintr-o listă brută
/// `laborEntries` (Map necesar — vezi `JobRecord.laborEntries`), opțional
/// filtrate pe o perioadă [periodStart, periodEnd].
List<PontajFisaRow> buildPontajFisaOwnRows(
  List<Map<String, dynamic>> laborRows, {
  DateTime? periodStart,
  DateTime? periodEnd,
  String jobCode = '',
  String jobTitle = '',
}) {
  double asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
  }

  final rows = laborRows.map((row) {
    final start = lucrareTryParseLaborDate(
      row['periodStartDate'] ?? row['date'],
    );
    final end =
        lucrareTryParseLaborDate(row['periodEndDate'] ?? row['date']) ?? start;
    return PontajFisaRow(
      persoanaNume: '${row['who'] ?? row['whoLabel'] ?? '-'}'.trim(),
      esteProprie: true,
      dataStart: start,
      dataEnd: end,
      orePeZi: asDouble(row['hoursPerDay']),
      oreTotale: asDouble(row['hours']),
      tarifOrar: asDouble(row['hourlyRate']),
      costOre: asDouble(row['costOre']),
      costDiurna: asDouble(row['costDiurna']),
      costCazare: asDouble(row['costCazare']),
      moneda: 'RON',
      jobCode: jobCode,
      jobTitle: jobTitle,
    );
  }).toList(growable: false);

  if (periodStart == null || periodEnd == null) return rows;
  return rows
      .where((r) => r.intersecteazaPerioada(periodStart, periodEnd))
      .toList(growable: false);
}

/// Construiește rândurile de personal PARTENER dintr-o listă
/// `JobPartnerWorker`, opțional filtrate pe o perioadă.
List<PontajFisaRow> buildPontajFisaPartnerRows(
  List<JobPartnerWorker> workers, {
  DateTime? periodStart,
  DateTime? periodEnd,
  String jobCode = '',
  String jobTitle = '',
  Map<String, String> partnerNamesById = const {},
}) {
  final rows = workers.map((w) {
    return PontajFisaRow(
      persoanaNume: w.fullName,
      esteProprie: false,
      partenerNume: partnerNamesById[w.partnerId] ?? '',
      rol: w.role,
      dataStart: w.workPeriodStart,
      dataEnd: w.workPeriodEnd ?? w.workPeriodStart,
      orePeZi: w.hoursPerDay,
      oreTotale: w.workedHours,
      tarifOrar: w.hourlyRate,
      costOre: w.laborCost,
      costDiurna: w.perDiemCost,
      costCazare: w.lodgingCost,
      moneda: w.currency,
      jobCode: jobCode,
      jobTitle: jobTitle,
    );
  }).toList(growable: false);

  if (periodStart == null || periodEnd == null) return rows;
  return rows
      .where((r) => r.intersecteazaPerioada(periodStart, periodEnd))
      .toList(growable: false);
}
