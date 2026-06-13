import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../programari/appointment_models.dart';
import '../jobs/job_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modele de date
// ─────────────────────────────────────────────────────────────────────────────

class PartnerBalanceSummary {
  const PartnerBalanceSummary({
    required this.partnerId,
    required this.partnerName,
    required this.balance,
  });
  final String partnerId;
  final String partnerName;
  final double balance; // pozitiv = ei îți datorează
}

class EmployeeBalanceSummary {
  const EmployeeBalanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.balance,
  });
  final String employeeId;
  final String employeeName;
  final double balance; // pozitiv = tu le datorezi
}

class MonthlyRevenue {
  const MonthlyRevenue({
    required this.luna,
    required this.incasari,
    required this.costuri,
    required this.profit,
  });
  final String luna; // "Ian", "Feb", etc.
  final double incasari;
  final double costuri;
  final double profit;
}

class FinancialDashboardData {
  const FinancialDashboardData({
    // Încasări
    required this.incasariLunaAceasta,
    required this.incasariLunaTrecuta,
    required this.incasariAnAcesta,
    // De încasat (creanțe)
    required this.deIncasatParteneri,
    required this.deIncasatClienti,
    required this.numarFacturiRestante,
    // Costuri
    required this.costuriAngajatiLuna,
    required this.costuriParteneriLuna,
    required this.costuriMaterialeLuna,
    required this.totalCosturiLuna,
    // Datorii (ce datorezi tu)
    required this.datoriiAngajati,
    required this.datoriiParteneri,
    // Profit
    required this.profitBrutLuna,
    required this.marjaProfit,
    // Activitate
    required this.programariAzi,
    required this.programariAceastaSaptamana,
    required this.lucrariInCurs,
    required this.lucrariFinalizateLuna,
    // Top
    required this.topParteneriDeIncasat,
    required this.topAngajatiDePlata,
    required this.graficUltimele6Luni,
  });

  final double incasariLunaAceasta;
  final double incasariLunaTrecuta;
  final double incasariAnAcesta;
  final double deIncasatParteneri;
  final double deIncasatClienti;
  final int numarFacturiRestante;
  final double costuriAngajatiLuna;
  final double costuriParteneriLuna;
  final double costuriMaterialeLuna;
  final double totalCosturiLuna;
  final double datoriiAngajati;
  final double datoriiParteneri;
  final double profitBrutLuna;
  final double marjaProfit;
  final int programariAzi;
  final int programariAceastaSaptamana;
  final int lucrariInCurs;
  final int lucrariFinalizateLuna;
  final List<PartnerBalanceSummary> topParteneriDeIncasat;
  final List<EmployeeBalanceSummary> topAngajatiDePlata;
  final List<MonthlyRevenue> graficUltimele6Luni;

  static FinancialDashboardData empty() => const FinancialDashboardData(
        incasariLunaAceasta: 0,
        incasariLunaTrecuta: 0,
        incasariAnAcesta: 0,
        deIncasatParteneri: 0,
        deIncasatClienti: 0,
        numarFacturiRestante: 0,
        costuriAngajatiLuna: 0,
        costuriParteneriLuna: 0,
        costuriMaterialeLuna: 0,
        totalCosturiLuna: 0,
        datoriiAngajati: 0,
        datoriiParteneri: 0,
        profitBrutLuna: 0,
        marjaProfit: 0,
        programariAzi: 0,
        programariAceastaSaptamana: 0,
        lucrariInCurs: 0,
        lucrariFinalizateLuna: 0,
        topParteneriDeIncasat: [],
        topAngajatiDePlata: [],
        graficUltimele6Luni: [],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service — citește exclusiv din cache local (funcționează offline)
// ─────────────────────────────────────────────────────────────────────────────

class FinancialDashboardService {
  FinancialDashboardService._();
  static final FinancialDashboardService instance = FinancialDashboardService._();

  // Chei SharedPreferences — trebuie să coincidă cu cheile din fiecare repository
  static const String _appointmentsKey = 'ultra_appointments_v1';
  static const String _jobsKey = 'ultra_jobs_v1';
  static const String _payEntriesKey = 'employee_pay_entries_v1';
  static const String _empSummariesKey = 'employee_financial_summaries_v1';
  static const String _partnerSummariesKey = 'partner_financial_summaries_v1';

  static const List<String> _monthNames = [
    'Ian', 'Feb', 'Mar', 'Apr', 'Mai', 'Iun',
    'Iul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Agregă datele din toate modulele — citire exclusiv din SharedPreferences.
  /// Nu face nicio cerere Firestore — funcționează offline.
  Future<FinancialDashboardData> loadDashboard() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final appointments = _readAppointments(prefs);
    final jobs = _readJobs(prefs);
    final payEntries = _readPayEntries(prefs);
    final empSummaries = _readMaps(prefs, _empSummariesKey);
    final partnerSummaries = _readMaps(prefs, _partnerSummariesKey);

    // ── Perioade ──────────────────────────────────────────────────────────────
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    final yearStart = DateTime(now.year, 1, 1);
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    // ── Agregate din programări ────────────────────────────────────────────────
    double incasariLuna = 0;
    double incasariLunaTrecuta = 0;
    double incasariAn = 0;
    double deIncasatParteneri = 0;
    double deIncasatClienti = 0;
    int numarFacturiRestante = 0;
    double costuriParteneriLuna = 0;
    double costuriMaterialeLuna = 0;
    int programariAzi = 0;
    int programariSaptamana = 0;

    for (final a in appointments) {
      final dt = a.effectiveStartDateTime;
      final dayOnly = DateTime(dt.year, dt.month, dt.day);

      if (dayOnly == today) programariAzi++;
      if (!dayOnly.isBefore(weekStart) && !dayOnly.isAfter(weekEnd)) {
        programariSaptamana++;
      }

      if (!dt.isBefore(monthStart) && !dt.isAfter(monthEnd)) {
        incasariLuna += a.adminCollectedAmount;
        costuriParteneriLuna += a.executingPartnerCommission;
        costuriMaterialeLuna += a.materialUsage.totalCost;
      }

      if (!dt.isBefore(prevMonthStart) && !dt.isAfter(prevMonthEnd)) {
        incasariLunaTrecuta += a.adminCollectedAmount;
      }

      if (!dt.isBefore(yearStart)) {
        incasariAn += a.adminCollectedAmount;
      }

      // De încasat de la parteneri
      if (a.forPartnerInvoiceAmount > 0 &&
          a.forPartnerReceiveStatus != PartnerPaymentStatus.platit) {
        deIncasatParteneri += a.forPartnerInvoiceAmount;
      }

      // De încasat de la clienți (facturi restante)
      if (a.adminFinancialStatus == AppointmentFinancialStatus.neincasata &&
          a.interventionPrice > 0) {
        final restant = a.interventionPrice - a.adminCollectedAmount;
        if (restant > 0.01) {
          deIncasatClienti += restant;
          numarFacturiRestante++;
        }
      }
    }

    // ── Costuri angajați luna curentă ─────────────────────────────────────────
    double costuriAngajatiLuna = 0;
    for (final e in payEntries) {
      final dateStr = e['appointment_date'] as String? ?? '';
      final dt = DateTime.tryParse(dateStr);
      if (dt != null && !dt.isBefore(monthStart) && !dt.isAfter(monthEnd)) {
        costuriAngajatiLuna += _parseAmount(e['amount_due']);
      }
    }

    final totalCosturiLuna =
        costuriAngajatiLuna + costuriParteneriLuna + costuriMaterialeLuna;
    final profitBrut = incasariLuna - totalCosturiLuna;
    final marjaProfit =
        incasariLuna > 0 ? (profitBrut / incasariLuna * 100) : 0.0;

    // ── Datorii angajați ──────────────────────────────────────────────────────
    double datoriiAngajati = 0;
    final topAngajati = <EmployeeBalanceSummary>[];
    for (final s in empSummaries) {
      final balance = _parseAmount(s['total_due']) - _parseAmount(s['total_paid']);
      if (balance > 0.01) {
        datoriiAngajati += balance;
        topAngajati.add(EmployeeBalanceSummary(
          employeeId: s['employee_id']?.toString() ?? '',
          employeeName: s['employee_name']?.toString() ?? '',
          balance: balance,
        ));
      }
    }
    topAngajati.sort((a, b) => b.balance.compareTo(a.balance));

    // ── Sold parteneri ────────────────────────────────────────────────────────
    double datoriiParteneri = 0;
    final topParteneri = <PartnerBalanceSummary>[];
    for (final s in partnerSummaries) {
      final soldNet = s.containsKey('sold_net')
          ? _parseAmount(s['sold_net'])
          : _parseAmount(s['total_de_incasat']) - _parseAmount(s['total_de_plata']);
      if (soldNet > 0.01) {
        topParteneri.add(PartnerBalanceSummary(
          partnerId: s['partner_id']?.toString() ?? '',
          partnerName: s['partner_name']?.toString() ?? '',
          balance: soldNet,
        ));
      } else if (soldNet < -0.01) {
        datoriiParteneri += soldNet.abs();
      }
    }
    topParteneri.sort((a, b) => b.balance.compareTo(a.balance));

    // ── Lucrări ───────────────────────────────────────────────────────────────
    int lucrariInCurs = 0;
    int lucrariFinalizateLuna = 0;
    for (final j in jobs) {
      if (j.status == JobStatus.inExecutie) lucrariInCurs++;
      if (j.status == JobStatus.finalizata) {
        final closed = j.closedDate;
        if (closed != null &&
            !closed.isBefore(monthStart) &&
            !closed.isAfter(monthEnd)) {
          lucrariFinalizateLuna++;
        }
      }
    }

    // ── Grafic ultimele 6 luni ────────────────────────────────────────────────
    final grafic = <MonthlyRevenue>[];
    for (var i = 5; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final mStart = DateTime(target.year, target.month, 1);
      final mEnd = DateTime(target.year, target.month + 1, 0, 23, 59, 59);

      double mIncasari = 0;
      double mCosturiParteneri = 0;
      double mCosturiMateriale = 0;
      for (final a in appointments) {
        final dt = a.effectiveStartDateTime;
        if (!dt.isBefore(mStart) && !dt.isAfter(mEnd)) {
          mIncasari += a.adminCollectedAmount;
          mCosturiParteneri += a.executingPartnerCommission;
          mCosturiMateriale += a.materialUsage.totalCost;
        }
      }
      double mCosturiAngajati = 0;
      for (final e in payEntries) {
        final dt = DateTime.tryParse(e['appointment_date'] as String? ?? '');
        if (dt != null && !dt.isBefore(mStart) && !dt.isAfter(mEnd)) {
          mCosturiAngajati += _parseAmount(e['amount_due']);
        }
      }
      final mCosturi = mCosturiAngajati + mCosturiParteneri + mCosturiMateriale;
      grafic.add(MonthlyRevenue(
        luna: _monthNames[(target.month - 1) % 12],
        incasari: mIncasari,
        costuri: mCosturi,
        profit: mIncasari - mCosturi,
      ));
    }

    return FinancialDashboardData(
      incasariLunaAceasta: incasariLuna,
      incasariLunaTrecuta: incasariLunaTrecuta,
      incasariAnAcesta: incasariAn,
      deIncasatParteneri: deIncasatParteneri,
      deIncasatClienti: deIncasatClienti,
      numarFacturiRestante: numarFacturiRestante,
      costuriAngajatiLuna: costuriAngajatiLuna,
      costuriParteneriLuna: costuriParteneriLuna,
      costuriMaterialeLuna: costuriMaterialeLuna,
      totalCosturiLuna: totalCosturiLuna,
      datoriiAngajati: datoriiAngajati,
      datoriiParteneri: datoriiParteneri,
      profitBrutLuna: profitBrut,
      marjaProfit: marjaProfit,
      programariAzi: programariAzi,
      programariAceastaSaptamana: programariSaptamana,
      lucrariInCurs: lucrariInCurs,
      lucrariFinalizateLuna: lucrariFinalizateLuna,
      topParteneriDeIncasat: topParteneri.take(3).toList(),
      topAngajatiDePlata: topAngajati.take(3).toList(),
      graficUltimele6Luni: grafic,
    );
  }

  // ── Helpers de citire din SharedPreferences ──────────────────────────────

  List<Appointment> _readAppointments(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_appointmentsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Appointment.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<JobRecord> _readJobs(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_jobsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => JobRecord.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _readPayEntries(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_payEntriesKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _readMaps(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Parsează o sumă dintr-un câmp care poate fi String sau double.
  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }
}
