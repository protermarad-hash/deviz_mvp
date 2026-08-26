/// Grupare pe săptămână calendaristică (luni-duminică) a rândurilor de
/// pontaj PARTENER (`PontajFisaRow`, `esteProprie == false`), pentru
/// raportul agregat pe TOȚI muncitorii parteneri (nu doar unul, spre
/// deosebire de `buildPontajFisaCrossJob`).
///
/// Read-only, 100% în memorie — consumă `List<PontajFisaRow>` deja
/// construite (`buildPontajFisaPartnerRows` / `pontaj_fisa_all_partners_service.dart`).
/// NU interoghează Firestore, NU modifică `JobPartnerWorker`, NU atinge
/// `Appointment`/`assignedEmployeeIds`/`employee_financial_*`.
library;

import 'pontaj_fisa_aggregator.dart';

/// Începutul săptămânii (luni) pentru o dată — ora se ignoră.
///
/// Formulă IDENTICĂ cu cea deja folosită (triplicat) în:
/// - `lib/features/programari/programari_calendar_navigation.dart:58-60`
///   (`startOfWeekMonday`)
/// - `lib/features/programari/programari_page.dart:2207-2209`
///   (`_startOfWeekMonday`)
/// - `lib/features/programari/programari_consum_materiale_page.dart:351`
///   (`_mondayOf`)
///
/// Extrasă aici (nu importată din `features/programari`) ca să nu creeze o
/// dependență cross-modul jobs → programari pentru un singur calcul —
/// formula rămâne totuși aceeași, nereinventată.
DateTime startOfWeekMonday(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Un rând de pontaj-partener atribuit unei săptămâni calendaristice.
class PontajFisaWeeklyEntry {
  const PontajFisaWeeklyEntry({
    required this.row,
    required this.weekStart,
    required this.spansMultipleWeeks,
  });

  final PontajFisaRow row;

  /// Lunea săptămânii căreia îi e atribuit rândul — întotdeauna
  /// `startOfWeekMonday(row.dataStart)`.
  final DateTime weekStart;

  /// true dacă `row.dataEnd` cade într-o săptămână diferită de
  /// `row.dataStart` (rând provenit din modul "Interval" al dialogului
  /// personal partener, ce trece peste granița săptămânii).
  ///
  /// Rândul e atribuit ÎN ÎNTREGIME săptămânii de `dataStart` — flag-ul e
  /// STRICT un indicator vizual pentru UI, NU împarte orele/costul pe
  /// săptămâni (nu există bază de a presupune o distribuție uniformă a
  /// orelor pe zile în date existente).
  final bool spansMultipleWeeks;
}

/// Total agregat pentru UN muncitor, într-o săptămână.
class PontajFisaWorkerWeeklyTotal {
  PontajFisaWorkerWeeklyTotal({
    required this.personKey,
    required this.displayName,
  });

  /// Cheie de grupare: `persoanaNume.trim().toLowerCase()` — NU
  /// `masterWorkerId` (poate fi gol pe rânduri cu nume liber; pattern deja
  /// confirmat corect în `pontaj_fisa_cross_job_service.dart:68,82`).
  final String personKey;

  /// Numele afișabil — prima capitalizare întâlnită pentru această cheie.
  final String displayName;

  double totalOre = 0;
  double totalCost = 0;
  int numarRanduri = 0;
  bool areRandSpansMultipleWeeks = false;

  void adaugaRand(PontajFisaWeeklyEntry entry) {
    totalOre += entry.row.oreTotale;
    totalCost += entry.row.costTotal;
    numarRanduri += 1;
    if (entry.spansMultipleWeeks) areRandSpansMultipleWeeks = true;
  }
}

/// Total agregat pentru UN partener (firmă), într-o săptămână.
class PontajFisaPartnerWeeklyTotal {
  PontajFisaPartnerWeeklyTotal({
    required this.partnerId,
    required this.partnerNume,
  });

  final String partnerId;
  final String partnerNume;

  double totalCost = 0;

  final Map<String, PontajFisaWorkerWeeklyTotal> _muncitoriByKey = {};

  /// Muncitori, sortați descrescător după cost.
  List<PontajFisaWorkerWeeklyTotal> get muncitori {
    final list = _muncitoriByKey.values.toList(growable: false);
    list.sort((a, b) => b.totalCost.compareTo(a.totalCost));
    return list;
  }

  void adaugaRand(PontajFisaWeeklyEntry entry) {
    totalCost += entry.row.costTotal;
    final numeTrimmed = entry.row.persoanaNume.trim();
    final key = numeTrimmed.toLowerCase();
    final worker = _muncitoriByKey.putIfAbsent(
      key,
      () => PontajFisaWorkerWeeklyTotal(personKey: key, displayName: numeTrimmed),
    );
    worker.adaugaRand(entry);
  }
}

/// Grup complet pentru o săptămână calendaristică (luni-duminică).
class PontajFisaWeeklyGroup {
  PontajFisaWeeklyGroup({required this.weekStart});

  /// Lunea săptămânii.
  final DateTime weekStart;

  /// Duminica săptămânii (weekStart + 6 zile).
  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  final Map<String, PontajFisaPartnerWeeklyTotal> _partneriById = {};

  /// Parteneri, sortați descrescător după cost.
  List<PontajFisaPartnerWeeklyTotal> get parteneri {
    final list = _partneriById.values.toList(growable: false);
    list.sort((a, b) => b.totalCost.compareTo(a.totalCost));
    return list;
  }

  double get totalCost =>
      _partneriById.values.fold<double>(0, (s, p) => s + p.totalCost);

  void _adaugaRand(PontajFisaWeeklyEntry entry) {
    final partnerId = entry.row.partenerId;
    final partner = _partneriById.putIfAbsent(
      partnerId,
      () => PontajFisaPartnerWeeklyTotal(
        partnerId: partnerId,
        partnerNume: entry.row.partenerNume,
      ),
    );
    partner.adaugaRand(entry);
  }
}

/// Grupează rândurile de pontaj-partener (`esteProprie == false`) pe
/// săptămână calendaristică (luni-duminică), cu totaluri per muncitor și
/// per partener. Rândurile de manoperă PROPRIE (`esteProprie == true`) și
/// cele fără `dataStart` sunt IGNORATE explicit (nu pot fi atribuite unei
/// săptămâni).
///
/// Rezultat sortat descrescător după `weekStart` (cea mai recentă
/// săptămână primă).
List<PontajFisaWeeklyGroup> groupPontajFisaRowsByWeek(
  List<PontajFisaRow> rows,
) {
  final groupsByWeekStart = <DateTime, PontajFisaWeeklyGroup>{};

  for (final row in rows) {
    if (row.esteProprie) continue;
    final start = row.dataStart;
    if (start == null) continue;

    final weekStart = startOfWeekMonday(start);
    final end = row.dataEnd ?? start;
    final endWeekStart = startOfWeekMonday(end);
    final spansMultipleWeeks = endWeekStart != weekStart;

    final entry = PontajFisaWeeklyEntry(
      row: row,
      weekStart: weekStart,
      spansMultipleWeeks: spansMultipleWeeks,
    );

    final group = groupsByWeekStart.putIfAbsent(
      weekStart,
      () => PontajFisaWeeklyGroup(weekStart: weekStart),
    );
    group._adaugaRand(entry);
  }

  final result = groupsByWeekStart.values.toList()
    ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  return result;
}
