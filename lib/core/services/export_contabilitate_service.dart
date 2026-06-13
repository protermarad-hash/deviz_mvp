import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'communication_service.dart';

class ExportContabilitateService {
  ExportContabilitateService._();
  static final ExportContabilitateService instance =
      ExportContabilitateService._();

  static const String _emailContabilaKey = 'email_contabila_v1';
  static const String _lastExportKey = 'last_export_contabilitate_v1';

  static const String _appointmentsKey = 'ultra_appointments_v1';
  static const String _payEntriesKey = 'employee_pay_entries_v1';
  static const String _hrPaymentsKey = 'hr_payroll_payments_v1';

  // ── Export Excel ─────────────────────────────────────────────────────────

  Future<Uint8List> genereazaRaportLunarExcel({
    required int an,
    required int luna,
  }) async {
    final excel = Excel.createExcel();

    await _buildSheetProgramari(excel, an: an, luna: luna);
    await _buildSheetCosturiAngajati(excel, an: an, luna: luna);
    await _buildSheetPlatiAngajati(excel, an: an, luna: luna);
    await _buildSheetPartnerFinanciar(excel, an: an, luna: luna);
    await _buildSheetRezumat(excel, an: an, luna: luna);

    // Excel creează implicit Sheet1 — o ștergem
    excel.delete('Sheet1');

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  Future<String> salveazaSiShare({
    required int an,
    required int luna,
  }) async {
    final bytes = await genereazaRaportLunarExcel(an: an, luna: luna);
    final numeLuna = _monthName(luna);
    final fileName = 'ProTerm_Contabilitate_${numeLuna}_$an.xlsx';
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Raport contabilitate $numeLuna $an — PRO TERM SRL',
    );
    await _markExportDone(an, luna);
    return file.path;
  }

  Future<void> trimiteRaportPeEmail({
    required int an,
    required int luna,
    String? emailContabil,
  }) async {
    final email = emailContabil ?? await getEmailContabila();
    if (email.isEmpty) return;
    final numeLuna = _monthName(luna);
    final bytes = await genereazaRaportLunarExcel(an: an, luna: luna);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ProTerm_Contabilitate_${numeLuna}_$an.xlsx');
    await file.writeAsBytes(bytes);
    await CommunicationService.instance.sendEmail(
      email: email,
      subject: 'ProVentaris — Raport contabilitate $numeLuna $an',
      body: 'Buna ziua,\n\nAlaturat gasiti raportul de contabilitate '
          'pentru luna $numeLuna $an generat automat din aplicatia ProVentaris.\n\n'
          'Continut fisier Excel:\n'
          '- Programari si incasari\n'
          '- Costuri angajati\n'
          '- Plati angajati\n'
          '- Financiar parteneri\n'
          '- Rezumat financiar lunar\n\n'
          'Cu respect,\nSC PRO TERM SRL',
    );
    await _markExportDone(an, luna);
  }

  // ── Setări email contabilă ────────────────────────────────────────────────

  Future<String> getEmailContabila() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailContabilaKey) ?? '';
  }

  Future<void> setEmailContabila(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailContabilaKey, email.trim());
  }

  /// Returnează true dacă raportul lunii trecute nu a fost exportat
  /// și suntem în primele 3 zile ale lunii curente.
  Future<bool> shouldPromptExportLunaTrecuta() async {
    final now = DateTime.now();
    if (now.day > 3) return false;
    final prefs = await SharedPreferences.getInstance();
    final luna = now.month == 1 ? 12 : now.month - 1;
    final an = now.month == 1 ? now.year - 1 : now.year;
    final key = '${an}_$luna';
    final done = prefs.getString(_lastExportKey) ?? '';
    return done != key;
  }

  Future<void> _markExportDone(int an, int luna) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastExportKey, '${an}_$luna');
  }

  // ── Sheet builders ────────────────────────────────────────────────────────

  Future<void> _buildSheetProgramari(Excel excel,
      {required int an, required int luna}) async {
    final sheet = excel['Programari'];
    _addHeaderRow(sheet, [
      'Data', 'Titlu', 'Client', 'Status', 'Incasare (RON)', 'Tehnician'
    ]);
    final appointments = await _loadMonthData(_appointmentsKey, an, luna,
        dateKey: 'start_time');
    for (final a in appointments) {
      _addRow(sheet, [
        _formatDate(
            DateTime.tryParse((a['start_time'] ?? '').toString())),
        (a['titlu'] ?? a['title'] ?? '').toString(),
        (a['beneficiar'] ?? a['client_name'] ?? '').toString(),
        (a['status'] ?? '').toString(),
        (a['admin_collected_amount'] ?? 0).toString(),
        (a['assigned_user_email'] ?? '').toString(),
      ]);
    }
  }

  Future<void> _buildSheetCosturiAngajati(Excel excel,
      {required int an, required int luna}) async {
    final sheet = excel['Costuri angajati'];
    _addHeaderRow(sheet, [
      'Data programare', 'Angajat', 'Titlu programare', 'Suma datorata (RON)'
    ]);
    final entries = await _loadMonthData(_payEntriesKey, an, luna,
        dateKey: 'appointment_date');
    for (final e in entries) {
      _addRow(sheet, [
        (e['appointment_date'] ?? '').toString(),
        (e['employee_name'] ?? '').toString(),
        (e['appointment_title'] ?? '').toString(),
        (e['amount_due'] ?? 0).toString(),
      ]);
    }
  }

  Future<void> _buildSheetPlatiAngajati(Excel excel,
      {required int an, required int luna}) async {
    final sheet = excel['Plati angajati'];
    _addHeaderRow(sheet, [
      'Data platii', 'Angajat', 'Tip plata', 'Suma (RON)', 'Metoda', 'Nota'
    ]);
    final payments = await _loadMonthData(_hrPaymentsKey, an, luna,
        dateKey: 'payment_date');
    for (final p in payments) {
      _addRow(sheet, [
        (p['payment_date'] ?? '').toString(),
        (p['employee_name'] ?? '').toString(),
        (p['payment_type'] ?? '').toString(),
        (p['amount'] ?? 0).toString(),
        (p['metoda_plata'] ?? '').toString(),
        (p['note'] ?? '').toString(),
      ]);
    }
  }

  Future<void> _buildSheetPartnerFinanciar(Excel excel,
      {required int an, required int luna}) async {
    final sheet = excel['Financiar parteneri'];
    _addHeaderRow(sheet, [
      'Data', 'Partener', 'Tip tranzactie', 'Suma (RON)', 'Status'
    ]);
    final transactions = await _loadMonthData(
        'partner_transactions_v1', an, luna,
        dateKey: 'date');
    for (final t in transactions) {
      _addRow(sheet, [
        (t['date'] ?? '').toString(),
        (t['partner_name'] ?? '').toString(),
        (t['type'] ?? '').toString(),
        (t['amount'] ?? 0).toString(),
        (t['status'] ?? '').toString(),
      ]);
    }
  }

  Future<void> _buildSheetRezumat(Excel excel,
      {required int an, required int luna}) async {
    final sheet = excel['Rezumat $luna.$an'];
    final appointments = await _loadMonthData(_appointmentsKey, an, luna,
        dateKey: 'start_time');
    final entries = await _loadMonthData(_payEntriesKey, an, luna,
        dateKey: 'appointment_date');
    final payments = await _loadMonthData(_hrPaymentsKey, an, luna,
        dateKey: 'payment_date');

    double incasari = 0;
    for (final a in appointments) {
      incasari += (a['admin_collected_amount'] as num? ?? 0).toDouble();
    }
    double costuriAngajati = 0;
    for (final e in entries) {
      costuriAngajati += (e['amount_due'] as num? ?? 0).toDouble();
    }
    double platiAngajati = 0;
    for (final p in payments) {
      platiAngajati += (p['amount'] as num? ?? 0).toDouble();
    }

    _addRow(sheet, ['Indicator', 'Valoare (RON)']);
    _addRow(sheet, ['Luna', '${_monthName(luna)} $an']);
    _addRow(sheet, ['Total programari', appointments.length.toString()]);
    _addRow(sheet,
        ['Incasari programari', incasari.toStringAsFixed(2)]);
    _addRow(sheet,
        ['Costuri angajati (datorat)', costuriAngajati.toStringAsFixed(2)]);
    _addRow(sheet,
        ['Plati angajati (efectuat)', platiAngajati.toStringAsFixed(2)]);
    _addRow(sheet, [
      'Profit brut estimat',
      (incasari - costuriAngajati).toStringAsFixed(2)
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _addHeaderRow(Sheet sheet, List<String> headers) {
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
  }

  void _addRow(Sheet sheet, List<String> values) {
    final rowIndex = sheet.maxRows;
    for (var i = 0; i < values.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
              columnIndex: i, rowIndex: rowIndex))
          .value = TextCellValue(values[i]);
    }
  }

  Future<List<Map<String, dynamic>>> _loadMonthData(
    String prefsKey,
    int an,
    int luna, {
    required String dateKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final monthStart = DateTime(an, luna);
      final monthEnd = DateTime(an, luna + 1);
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) {
        final dt =
            DateTime.tryParse((e[dateKey] ?? '').toString());
        if (dt == null) return false;
        return !dt.isBefore(monthStart) && dt.isBefore(monthEnd);
      }).toList();
    } catch (e) {
      debugPrint('[ExportContabilitate] ❌ _loadMonthData($prefsKey): $e');
      return [];
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _monthName(int luna) {
    const names = <String>[
      '', 'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
      'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
    ];
    return luna >= 1 && luna <= 12 ? names[luna] : '$luna';
  }
}
