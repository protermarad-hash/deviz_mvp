import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/jobs/lucrare_detalii_models.dart';
import 'package:devizpro_ultra/features/jobs/lucrare_format_utils.dart';
import 'package:devizpro_ultra/features/jobs/services/lucrare_labor_calc.dart';
import 'package:devizpro_ultra/features/jobs/services/lucrare_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresie: în „Editează manoperă / ore” valorile modificate manual pentru
/// „Valoare diurnă/zi” și „Valoare cazare/noapte” reveneau la tariful
/// inițial după salvare (ex. real: Herman Sebastian, 04.08–06.08.2026,
/// 55→100 RON/zi, 125→75 RON/noapte).
///
/// Cauza: la salvare, tariful din câmp era citit doar dacă tariful
/// preîncărcat (`selectedPerDiemPerDay`, inițializat din rândul existent)
/// era 0 — `selected > 0 ? selected : câmp`. Cum rândul avea deja 55, câmpul
/// tastat era ignorat mereu.
///
/// Testele folosesc logica reală (`buildEditedLaborRow`, `normalizeLaborRow`,
/// `dedupeLaborRows`, `lucrareSaveRows`/`lucrareReadRows`, `JobRecord`) și
/// parcurg traseul complet: editare → salvare → recitire → redeschidere.
void main() {
  const herman = LucrareOption(
    id: 'e-herman',
    label: 'Herman Sebastian',
    hourlyRate: 40,
    dailyAllowance: 55,
    defaultLodgingCost: 125,
    requiresLodgingByDefault: true,
  );

  LucrareLaborCalculator buildCalc() => LucrareLaborCalculator(
        jobId: 'job-1',
        employeesProvider: () => const [herman],
        teamsProvider: () => const [],
      );

  final start = DateTime(2026, 8, 4);
  final end = DateTime(2026, 8, 6);

  Map<String, dynamic> hermanRow({
    String id = 'labor-herman-1',
    DateTime? from,
    DateTime? to,
  }) {
    final calc = buildCalc();
    final s = from ?? start;
    final e = to ?? end;
    final days = calc.laborPeriodDays(periodStart: s, periodEnd: e);
    return calc.normalizeLaborRow({
      'id': id,
      'jobId': 'job-1',
      'whoId': 'emp:e-herman',
      'type': 'person',
      'whoLabel': 'Herman Sebastian',
      'periodStartDate': lucrareEncodeLaborPeriodDate(s),
      'periodEndDate': lucrareEncodeLaborPeriodDate(e),
      'hoursPerDay': 8.0,
      'hourlyRate': 40.0,
      'includeDiurna': true,
      'includeCazare': true,
      'valoareDiurnaPeZi': 55.0,
      'valoareCazarePeNoapte': 125.0,
      'costDiurna': days * 55,
      'costCazare': days * 125,
    });
  }

  /// Simulează exact dialogul: controller-ele sunt precompletate din rând
  /// (`laborPerDiemPerDay`/`laborLodgingPerNight`), iar `selected*` din
  /// dialog pornește tot din rând; utilizatorul tastează în câmpuri.
  Map<String, dynamic> editInDialog(
    LucrareLaborCalculator calc,
    Map<String, dynamic> row, {
    String? diurnaText,
    String? cazareText,
    bool? includeDiurna,
    bool? includeCazare,
  }) {
    final periodStart = calc.laborPeriodStart(row)!;
    final periodEnd = calc.laborPeriodEnd(row)!;
    final tripDays =
        calc.laborPeriodDays(periodStart: periodStart, periodEnd: periodEnd);
    final incD = includeDiurna ?? calc.laborIncludePerDiem(row);
    final incC = includeCazare ?? calc.laborIncludeLodging(row);
    String fmt(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toString();
    return calc.buildEditedLaborRow(
      original: row,
      whoId: '${row['whoId']}',
      whoLabel: '${row['whoLabel']}',
      periodStart: periodStart,
      periodEnd: periodEnd,
      hoursText: fmt(tripDays * calc.laborHoursPerDay(row)),
      hoursPerDayText: fmt(calc.laborHoursPerDay(row)),
      tripDaysText: fmt(tripDays),
      zileDiurnaText: incD ? fmt(tripDays) : '0',
      noptiCazareText: incC ? fmt(tripDays) : '0',
      valoareDiurnaText:
          diurnaText ?? calc.laborPerDiemPerDay(row).toString(),
      valoareCazareText:
          cazareText ?? calc.laborLodgingPerNight(row).toString(),
      defaultPerDiemPerDay: calc.laborPerDiemPerDay(row),
      defaultLodgingPerNight: calc.laborLodgingPerNight(row),
      includeDiurna: incD,
      includeCazare: incC,
      hourlyRate: calc.laborRateForRow(row),
    );
  }

  /// Traseul real de salvare din `_saveLaborRows` + `_persistOperationalJobDetails`
  /// (prefs locale + JobRecord pentru Firestore/offline), urmat de recitirea
  /// făcută la încărcarea paginii (`_dedupeLaborRows(laborEntries)`).
  Future<List<Map<String, dynamic>>> saveAndReload(
    LucrareLaborCalculator calc,
    List<Map<String, dynamic>> rows,
  ) async {
    final normalized = rows.map(calc.normalizeLaborRow).toList();
    final deduped = calc.dedupeLaborRows(normalized);
    await lucrareSaveRows('labor-key', deduped);
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = lucrareReadRows(prefs.getString('labor-key'));
    // Traseul cloud: JobRecord.toMap() -> Firestore -> JobRecord.fromMap().
    final job = JobRecord.fromMap({
      'id': 'job-1',
      'labor_entries': fromPrefs,
    });
    final cloudRows = JobRecord.fromMap(job.toMap()).laborEntries;
    return calc.dedupeLaborRows(
      cloudRows.map((r) => Map<String, dynamic>.from(r)).toList(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Angajat propriu — valori personalizate diurnă/cazare', () {
    test('exemplul real: 100 RON/zi + 75 RON/noapte persistă după salvare',
        () async {
      final calc = buildCalc();
      final original = hermanRow();
      expect(calc.laborPerDiemPerDay(original), 55);
      expect(calc.laborLodgingPerNight(original), 125);

      final edited =
          editInDialog(calc, original, diurnaText: '100', cazareText: '75');
      expect(edited['valoareDiurnaPeZi'], 100);
      expect(edited['valoareCazarePeNoapte'], 75);

      final reloaded = await saveAndReload(calc, [edited]);
      expect(reloaded, hasLength(1));
      final row = reloaded.single;

      // Redeschiderea formularului precompletează din aceste funcții.
      expect(calc.laborPerDiemPerDay(row), 100);
      expect(calc.laborLodgingPerNight(row), 75);
      expect(calc.laborDaysPerDiem(row), 3);
      expect(calc.laborNightsLodging(row), 3);
      expect(_asNum(row['hours']), 24);

      // Calcule financiare: 3 × 100 = 300, 3 × 75 = 225, total 525.
      expect(calc.laborPerDiemCost(row), 300);
      expect(calc.laborLodgingCost(row), 225);
      expect(calc.laborPerDiemCost(row) + calc.laborLodgingCost(row), 525);
      // Linie: 24 h × 40 RON + 525 = 1485.
      expect(calc.laborTotalLineCost(row), 24 * 40 + 525);
    });

    test('redeschidere + salvare fără modificări păstrează 100/75', () async {
      final calc = buildCalc();
      final first = await saveAndReload(calc, [
        editInDialog(calc, hermanRow(), diurnaText: '100', cazareText: '75'),
      ]);
      // Al doilea ciclu: deschide din nou dialogul și apasă „Salvează”.
      final second =
          await saveAndReload(calc, [editInDialog(calc, first.single)]);
      final row = second.single;
      expect(calc.laborPerDiemPerDay(row), 100);
      expect(calc.laborLodgingPerNight(row), 75);
      expect(calc.laborPerDiemCost(row), 300);
      expect(calc.laborLodgingCost(row), 225);
    });

    test('salvări repetate nu dublează costurile', () async {
      final calc = buildCalc();
      var rows = [
        editInDialog(calc, hermanRow(), diurnaText: '100', cazareText: '75'),
      ];
      for (var i = 0; i < 4; i++) {
        rows = await saveAndReload(calc, rows);
      }
      expect(rows, hasLength(1));
      final total = rows.fold<double>(
          0, (sum, r) => sum + calc.laborPerDiemCost(r) + calc.laborLodgingCost(r));
      expect(total, 525);
      expect(calc.laborTotalLineCost(rows.single), 24 * 40 + 525);
    });

    test('modificarea unui singur câmp: doar diurna se schimbă', () async {
      final calc = buildCalc();
      final row = (await saveAndReload(
              calc, [editInDialog(calc, hermanRow(), diurnaText: '100')]))
          .single;
      expect(calc.laborPerDiemPerDay(row), 100);
      expect(calc.laborLodgingPerNight(row), 125);
      expect(calc.laborPerDiemCost(row), 300);
      expect(calc.laborLodgingCost(row), 375);
    });

    test('modificarea unui singur câmp: doar cazarea se schimbă', () async {
      final calc = buildCalc();
      final row = (await saveAndReload(
              calc, [editInDialog(calc, hermanRow(), cazareText: '75')]))
          .single;
      expect(calc.laborPerDiemPerDay(row), 55);
      expect(calc.laborLodgingPerNight(row), 75);
    });

    test('valoarea zero este respectată, nu devine tarif implicit', () async {
      final calc = buildCalc();
      final row = (await saveAndReload(calc, [
        editInDialog(calc, hermanRow(), diurnaText: '0', cazareText: '0'),
      ]))
          .single;
      expect(calc.laborPerDiemPerDay(row), 0);
      expect(calc.laborLodgingPerNight(row), 0);
      expect(calc.laborPerDiemCost(row), 0);
      expect(calc.laborLodgingCost(row), 0);
      expect(calc.laborTotalLineCost(row), 24 * 40);

      // Redeschidere + salvare: zero rămâne zero.
      final again =
          (await saveAndReload(calc, [editInDialog(calc, row)])).single;
      expect(calc.laborPerDiemPerDay(again), 0);
      expect(calc.laborLodgingPerNight(again), 0);
    });

    test('câmp gol / invalid -> se păstrează tariful existent al pontajului',
        () {
      final calc = buildCalc();
      final edited =
          editInDialog(calc, hermanRow(), diurnaText: '', cazareText: 'abc');
      expect(edited['valoareDiurnaPeZi'], 55);
      expect(edited['valoareCazarePeNoapte'], 125);
    });

    test('virgulă zecimală este acceptată', () {
      final calc = buildCalc();
      final edited = editInDialog(calc, hermanRow(),
          diurnaText: '100,50', cazareText: '75,25');
      expect(edited['valoareDiurnaPeZi'], 100.5);
      expect(edited['valoareCazarePeNoapte'], 75.25);
      expect(edited['costDiurna'], 301.5);
      expect(edited['costCazare'], 225.75);
    });

    test('tarif implicit vs personalizat: implicitul angajatului rămâne 55/125',
        () async {
      final calc = buildCalc();
      await saveAndReload(calc, [
        editInDialog(calc, hermanRow(), diurnaText: '100', cazareText: '75'),
      ]);
      expect(herman.dailyAllowance, 55);
      expect(herman.defaultLodgingCost, 125);
      expect(calc.employeeDailyAllowanceByRef('emp:e-herman'), 55);
      expect(calc.employeeLodgingByRef('emp:e-herman'), 125);
    });

    test('mai multe pontaje ale aceleiași persoane: doar cel editat se schimbă',
        () async {
      final calc = buildCalc();
      final a = hermanRow(id: 'a');
      final b = hermanRow(
          id: 'b', from: DateTime(2026, 8, 10), to: DateTime(2026, 8, 11));
      final c = hermanRow(
          id: 'c', from: DateTime(2026, 8, 12), to: DateTime(2026, 8, 12));
      final rows = await saveAndReload(calc, [
        a,
        editInDialog(calc, b, diurnaText: '100', cazareText: '75'),
        c,
      ]);
      Map<String, dynamic> byId(String id) =>
          rows.firstWhere((r) => r['id'] == id);
      expect(calc.laborPerDiemPerDay(byId('a')), 55);
      expect(calc.laborLodgingPerNight(byId('a')), 125);
      expect(calc.laborPerDiemPerDay(byId('b')), 100);
      expect(calc.laborLodgingPerNight(byId('b')), 75);
      expect(calc.laborPerDiemCost(byId('b')), 200);
      expect(calc.laborLodgingCost(byId('b')), 150);
      expect(calc.laborPerDiemPerDay(byId('c')), 55);
      // Total diurnă+cazare lucrare: a=3×180, b=2×175, c=1×180.
      final total = rows.fold<double>(
          0, (s, r) => s + calc.laborPerDiemCost(r) + calc.laborLodgingCost(r));
      expect(total, 540 + 350 + 180);
    });

    test('pontaj istoric (chei vechi perDiemPerDay/lodgingPerNight, fără flaguri)',
        () async {
      final calc = buildCalc();
      final legacy = <String, dynamic>{
        'id': 'legacy-1',
        'whoId': 'emp:e-herman',
        'type': 'person',
        'who': 'Herman Sebastian',
        'date': '04.08.2026',
        'periodStartDate': lucrareEncodeLaborPeriodDate(start),
        'periodEndDate': lucrareEncodeLaborPeriodDate(end),
        'hours': 24,
        'hourlyRate': 40,
        'zileDiurna': 3,
        'perDiemPerDay': 55,
        'noptiCazare': 3,
        'lodgingPerNight': 125,
      };
      // Recitirea simplă nu modifică valorile istorice.
      final untouched = (await saveAndReload(calc, [legacy])).single;
      expect(calc.laborPerDiemPerDay(untouched), 55);
      expect(calc.laborLodgingPerNight(untouched), 125);
      expect(calc.laborPerDiemCost(untouched), 165);
      expect(calc.laborLodgingCost(untouched), 375);

      // Editarea unui pontaj istoric aplică valorile noi.
      final edited = (await saveAndReload(calc, [
        editInDialog(calc, legacy, diurnaText: '100', cazareText: '75'),
      ]))
          .single;
      expect(calc.laborPerDiemPerDay(edited), 100);
      expect(calc.laborLodgingPerNight(edited), 75);
      expect(calc.laborPerDiemCost(edited), 300);
      expect(calc.laborLodgingCost(edited), 225);
    });

    test('dezactivare „Include cazare” -> cost cazare 0, tariful rămâne salvat',
        () async {
      final calc = buildCalc();
      final row = (await saveAndReload(calc, [
        editInDialog(calc, hermanRow(),
            diurnaText: '100', cazareText: '75', includeCazare: false),
      ]))
          .single;
      expect(calc.laborPerDiemCost(row), 300);
      expect(calc.laborLodgingCost(row), 0);
      expect(calc.laborLodgingPerNight(row), 75);
    });
  });

  group('Adăugare pontaj — tarif tastat vs implicit', () {
    test('resolveLaborUnitValue: text valid (inclusiv 0) are prioritate',
        () {
      expect(LucrareLaborCalculator.resolveLaborUnitValue('100', 55), 100);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('0', 55), 0);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('75,5', 125), 75.5);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('', 55), 55);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('  ', 55), 55);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('abc', 55), 55);
      expect(LucrareLaborCalculator.resolveLaborUnitValue('-5', 55), 55);
    });

    test('zile individuale cu tarif personalizat -> costuri pe tariful tastat',
        () {
      final calc = buildCalc();
      final entries = calc.buildMultiDayLaborEntries(
        selectedDays: {start, DateTime(2026, 8, 5), end},
        whoId: 'emp:e-herman',
        whoLabel: 'Herman Sebastian',
        type: 'person',
        hoursPerDayByDate: {
          start: 8,
          DateTime(2026, 8, 5): 8,
          end: 8,
        },
        hourlyRate: 40,
        includeDiurna: true,
        diurnaPerDay: LucrareLaborCalculator.resolveLaborUnitValue('100', 55),
        includeCazare: true,
        cazarePerNoapte:
            LucrareLaborCalculator.resolveLaborUnitValue('75', 125),
      );
      final normalized = calc.dedupeLaborRows(entries);
      final total = normalized.fold<double>(
          0, (s, r) => s + calc.laborPerDiemCost(r) + calc.laborLodgingCost(r));
      expect(total, 525);
    });
  });
}

double _asNum(dynamic v) => (v as num).toDouble();
