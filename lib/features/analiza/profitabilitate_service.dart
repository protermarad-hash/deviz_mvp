import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfitabilitateTipLucrare {
  const ProfitabilitateTipLucrare({
    required this.tip,
    required this.nrProgramari,
    required this.incasariTotal,
    required this.costuriTotal,
    required this.profitTotal,
  });

  final String tip;
  final int nrProgramari;
  final double incasariTotal;
  final double costuriTotal;
  final double profitTotal;

  double get marjaProfit =>
      incasariTotal > 0 ? profitTotal / incasariTotal * 100 : 0;
  double get incasareMedie =>
      nrProgramari > 0 ? incasariTotal / nrProgramari : 0;
  double get profitMediu =>
      nrProgramari > 0 ? profitTotal / nrProgramari : 0;
}

class ProfitabilitateAngajat {
  const ProfitabilitateAngajat({
    required this.angajatId,
    required this.angajatNume,
    required this.nrProgramari,
    required this.valoareGenerata,
    required this.costAngajat,
  });

  final String angajatId;
  final String angajatNume;
  final int nrProgramari;
  final double valoareGenerata;
  final double costAngajat;

  double get profit => valoareGenerata - costAngajat;
  double get roi => costAngajat > 0 ? profit / costAngajat * 100 : 0;
}

class ProfitabilitateService {
  ProfitabilitateService._();
  static final ProfitabilitateService instance = ProfitabilitateService._();

  static const String _appointmentsKey = 'ultra_appointments_v1';
  static const String _payEntriesKey = 'employee_pay_entries_v1';

  Future<List<ProfitabilitateTipLucrare>> analizeazaPerTip({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final appointments = await _loadAppointments(from, to);
      final builders = <String, _TipBuilder>{};

      for (final a in appointments) {
        final tip = (a['tip_lucrare'] ??
                a['equipment_type'] ??
                a['type'] ??
                'Nespecificat')
            .toString()
            .trim();
        final tipKey = tip.isEmpty ? 'Nespecificat' : tip;
        builders.putIfAbsent(tipKey, () => _TipBuilder(tipKey));
        final b = builders[tipKey]!;
        b.nrProgramari++;
        b.incasari +=
            (a['admin_collected_amount'] as num? ?? 0).toDouble();
        b.costuri +=
            (a['material_cost'] as num? ?? 0).toDouble();
      }

      return builders.values
          .map((b) => ProfitabilitateTipLucrare(
                tip: b.tip,
                nrProgramari: b.nrProgramari,
                incasariTotal: b.incasari,
                costuriTotal: b.costuri,
                profitTotal: b.incasari - b.costuri,
              ))
          .toList()
        ..sort((a, b) => b.profitTotal.compareTo(a.profitTotal));
    } catch (e) {
      debugPrint('[Profitabilitate] ❌ analizeazaPerTip: $e');
      return [];
    }
  }

  Future<List<ProfitabilitateAngajat>> analizeazaPerAngajat({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final appointments = await _loadAppointments(from, to);
      final payEntries = await _loadPayEntries(from, to);

      // Construieste map angajat → valoare generata
      final valori = <String, double>{};
      final nume = <String, String>{};
      final count = <String, int>{};

      for (final a in appointments) {
        final assignedIds = (a['employee_ids'] as List? ?? []);
        final assignedId =
            (a['assigned_user_id'] ?? '').toString();
        final allIds = <String>{
          ...assignedIds.map((e) => e.toString()),
          if (assignedId.isNotEmpty) assignedId,
        };
        final incasare =
            (a['admin_collected_amount'] as num? ?? 0).toDouble();
        final sharePerAngajat =
            allIds.isEmpty ? 0.0 : incasare / allIds.length;
        for (final id in allIds) {
          valori[id] = (valori[id] ?? 0) + sharePerAngajat;
          count[id] = (count[id] ?? 0) + 1;
        }
      }

      // Construieste map angajat → cost
      final costuri = <String, double>{};
      for (final e in payEntries) {
        final empId = (e['employee_id'] ?? '').toString();
        final amount = (e['amount_due'] as num? ?? 0).toDouble();
        costuri[empId] = (costuri[empId] ?? 0) + amount;
        if (!nume.containsKey(empId)) {
          nume[empId] = (e['employee_name'] ?? empId).toString();
        }
      }

      final allIds = {...valori.keys, ...costuri.keys};
      return allIds
          .map((id) => ProfitabilitateAngajat(
                angajatId: id,
                angajatNume: nume[id] ?? id,
                nrProgramari: count[id] ?? 0,
                valoareGenerata: valori[id] ?? 0,
                costAngajat: costuri[id] ?? 0,
              ))
          .toList()
        ..sort((a, b) => b.valoareGenerata.compareTo(a.valoareGenerata));
    } catch (e) {
      debugPrint('[Profitabilitate] ❌ analizeazaPerAngajat: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadAppointments(
      DateTime from, DateTime to) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appointmentsKey) ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((a) {
      final dt = DateTime.tryParse(
          (a['start_time'] ?? a['startTime'] ?? '').toString());
      if (dt == null) return false;
      return !dt.isBefore(from) && dt.isBefore(to);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadPayEntries(
      DateTime from, DateTime to) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_payEntriesKey) ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) {
      final dt = DateTime.tryParse(
          (e['appointment_date'] ?? '').toString());
      if (dt == null) return false;
      return !dt.isBefore(from) && dt.isBefore(to);
    }).toList();
  }
}

class _TipBuilder {
  _TipBuilder(this.tip);
  final String tip;
  int nrProgramari = 0;
  double incasari = 0;
  double costuri = 0;
}
