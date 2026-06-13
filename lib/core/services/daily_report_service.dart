import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/stoc/stoc_repository.dart';
import 'communication_service.dart';

class DailyReportData {
  const DailyReportData({
    required this.data,
    required this.programariAziTotal,
    required this.programariAziFinalizate,
    required this.programariAziNeFinalizate,
    required this.programariMaine,
    required this.programariMaineDetalii,
    required this.incasariAziRON,
    required this.stocCriticCount,
    required this.stocCriticNume,
  });

  const DailyReportData.empty()
      : data = null,
        programariAziTotal = 0,
        programariAziFinalizate = 0,
        programariAziNeFinalizate = 0,
        programariMaine = 0,
        programariMaineDetalii = const [],
        incasariAziRON = 0,
        stocCriticCount = 0,
        stocCriticNume = const [];

  final DateTime? data;
  final int programariAziTotal;
  final int programariAziFinalizate;
  final int programariAziNeFinalizate;
  final int programariMaine;
  final List<Map<String, dynamic>> programariMaineDetalii;
  final double incasariAziRON;
  final int stocCriticCount;
  final List<String> stocCriticNume;
}

class DailyReportService {
  DailyReportService._();
  static final DailyReportService instance = DailyReportService._();

  static const String _appointmentsKey = 'ultra_appointments_v1';
  static const String _lastReportKey = 'daily_report_last_sent_v1';

  Future<DailyReportData> generateReport({DateTime? forDate}) async {
    try {
      final date = forDate ?? DateTime.now();
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final tomorrowStart = dayEnd;
      final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));

      final appointments = await _loadAppointments();

      final azi = appointments.where((a) {
        final start = DateTime.tryParse(
                (a['start_time'] ?? a['startTime'] ?? '').toString()) ??
            DateTime.tryParse(
                (a['scheduled_date'] ?? '').toString());
        if (start == null) return false;
        return !start.isBefore(dayStart) && start.isBefore(dayEnd);
      }).toList();

      final maine = appointments.where((a) {
        final start = DateTime.tryParse(
                (a['start_time'] ?? a['startTime'] ?? '').toString()) ??
            DateTime.tryParse(
                (a['scheduled_date'] ?? '').toString());
        if (start == null) return false;
        return !start.isBefore(tomorrowStart) && start.isBefore(tomorrowEnd);
      }).toList();

      final finalizate =
          azi.where((a) => (a['status'] ?? '').toString() == 'finalizata').length;

      double incasari = 0;
      for (final a in azi) {
        incasari +=
            (a['admin_collected_amount'] as num? ?? 0).toDouble();
      }

      final stocCritic = await StocRepository.instance.listStocCritic();

      final maineDetalii = maine.map((a) => <String, dynamic>{
            'titlu': a['titlu'] ?? a['title'] ?? '',
            'beneficiar': a['beneficiar'] ??
                a['client_name'] ??
                '',
            'start_time': a['start_time'] ?? a['startTime'] ?? '',
          }).toList();

      return DailyReportData(
        data: date,
        programariAziTotal: azi.length,
        programariAziFinalizate: finalizate,
        programariAziNeFinalizate: azi.length - finalizate,
        programariMaine: maine.length,
        programariMaineDetalii: maineDetalii,
        incasariAziRON: incasari,
        stocCriticCount: stocCritic.length,
        stocCriticNume: stocCritic
            .take(5)
            .map((s) =>
                '${s.productName}: ${s.cantitate.toStringAsFixed(1)} ${s.unitate}')
            .toList(),
      );
    } catch (e) {
      debugPrint('[DailyReport] ❌ generateReport: $e');
      return const DailyReportData.empty();
    }
  }

  String formatAsText(DailyReportData r) {
    final d = r.data;
    final dateStr = d != null
        ? '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'
        : '';

    final buf = StringBuffer();
    buf.writeln('RAPORT ZILNIC PRO TERM SRL — $dateStr');
    buf.writeln();
    buf.writeln('PROGRAMARI AZI (${r.programariAziTotal}):');
    buf.writeln('  Finalizate: ${r.programariAziFinalizate}');
    buf.writeln('  Nefinalizate: ${r.programariAziNeFinalizate}');
    buf.writeln();
    buf.writeln('MAINE (${r.programariMaine} programari):');
    for (final p in r.programariMaineDetalii) {
      final start =
          DateTime.tryParse((p['start_time'] ?? '').toString());
      final oraStr = start != null
          ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
          : '';
      buf.writeln(
          '  • ${p['titlu']} — ${p['beneficiar']}${oraStr.isNotEmpty ? ' la $oraStr' : ''}');
    }
    buf.writeln();
    if (r.incasariAziRON > 0) {
      buf.writeln('INCASARI AZI: ${r.incasariAziRON.toStringAsFixed(2)} RON');
      buf.writeln();
    }
    if (r.stocCriticCount > 0) {
      buf.writeln('STOC CRITIC (${r.stocCriticCount} produse):');
      for (final s in r.stocCriticNume) {
        buf.writeln('  • $s');
      }
    } else {
      buf.writeln('Stoc: toate produsele OK');
    }
    buf.writeln();
    buf.writeln('SC PRO TERM SRL | ProVentaris');
    return buf.toString().trim();
  }

  Future<bool> sendToAdminWhatsApp({String adminPhone = '40749025610'}) async {
    try {
      final report = await generateReport();
      final text = formatAsText(report);
      final sent = await CommunicationService.instance
          .sendWhatsApp(phone: adminPhone, message: text);
      if (sent) await _markReportSentToday();
      return sent;
    } catch (e) {
      debugPrint('[DailyReport] ❌ sendToAdminWhatsApp: $e');
      return false;
    }
  }

  /// Returnează true dacă raportul nu a fost trimis azi și e după ora 17.
  Future<bool> shouldPromptDailyReport() async {
    if (DateTime.now().hour < 17) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastReportKey) ?? '';
    final today = _todayStr();
    return last != today;
  }

  Future<void> _markReportSentToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReportKey, _todayStr());
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> _loadAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
