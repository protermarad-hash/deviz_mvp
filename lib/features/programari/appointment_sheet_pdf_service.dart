import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/company_profile.dart';
import '../../core/pdf/pdf_font_helper.dart';
import '../../core/pdf/pro_term_pdf_template.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../hr/employee_financial_models.dart';
import 'appointment_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Opțiuni export — checkbox-urile administrative (toate opt-in, debifate implicit)
// Setul „teren" se exportă ÎNTOTDEAUNA, indiferent de aceste flag-uri.
// ─────────────────────────────────────────────────────────────────────────────

class AppointmentSheetExportOptions {
  const AppointmentSheetExportOptions({
    this.financiarIntern = false,
    this.costuriMateriale = false,
    this.societateContractanta = false,
    this.partenerBeneficiar = false,
    this.partenerExecutant = false,
    this.platiAngajati = false,
  });

  /// adminCollectedAmount, adminFinancialStatus, adminDueDate, adminFinancialNotes
  final bool financiarIntern;

  /// materialUsage.lines (unitCost/totalCost), estimatedMaterialsCost,
  /// estimatedProfit, materialUsage.facturabilPartener
  final bool costuriMateriale;

  /// contractingClientName / contractingClientId
  final bool societateContractanta;

  /// forPartner* (nume, sumă de încasat, status, dată, observații)
  final bool partenerBeneficiar;

  /// executingPartner* (nume, comision, status plată, dată, observații)
  final bool partenerExecutant;

  /// EmployeePayEntry — necesită fetch suplimentar din employee_financial
  final bool platiAngajati;

  bool get anyAdminSelected =>
      financiarIntern ||
      costuriMateriale ||
      societateContractanta ||
      partenerBeneficiar ||
      partenerExecutant ||
      platiAngajati;

  /// Set fără niciun câmp administrativ (folosit forțat pentru non-admin).
  static const AppointmentSheetExportOptions terenOnly =
      AppointmentSheetExportOptions();
}

// ─────────────────────────────────────────────────────────────────────────────
// Etichete rezolvate — valorile care necesită lookup (client, echipă, angajați,
// vehicul, job) sunt rezolvate în pagină și transmise deja formatate aici, ca
// serviciul să rămână decuplat de state-ul paginii.
// ─────────────────────────────────────────────────────────────────────────────

class AppointmentSheetLabels {
  const AppointmentSheetLabels({
    required this.clientName,
    required this.addressLabel,
    required this.clientAddressFromRecord,
    required this.contractingClientName,
    required this.teamLabel,
    required this.employeeLabel,
    required this.vehicleLabel,
    required this.jobLabel,
    required this.statusLabel,
    required this.priorityLabel,
    required this.contactPerson,
    required this.phones,
    required this.email,
  });

  final String clientName;
  final String addressLabel;
  final String clientAddressFromRecord;
  final String contractingClientName;
  final String teamLabel;
  final String employeeLabel;
  final String vehicleLabel;
  final String jobLabel;
  final String statusLabel;
  final String priorityLabel;
  final String contactPerson;
  final List<String> phones;
  final String email;
}

// ─────────────────────────────────────────────────────────────────────────────
// Model conținut — structură pură (fără PDF), testabilă direct.
// ─────────────────────────────────────────────────────────────────────────────

class SheetRow {
  const SheetRow(this.label, this.value);
  final String label;
  final String value;
}

class SheetTable {
  const SheetTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

class SheetSection {
  const SheetSection({
    required this.title,
    this.rows = const <SheetRow>[],
    this.table,
  });

  final String title;
  final List<SheetRow> rows;
  final SheetTable? table;

  bool get isEmpty => rows.isEmpty && (table == null || table!.rows.isEmpty);
}

class AppointmentSheetContent {
  const AppointmentSheetContent({
    required this.terenSections,
    required this.adminSections,
  });

  final List<SheetSection> terenSections;
  final List<SheetSection> adminSections;

  /// Toate etichetele câmpurilor incluse (pentru verificare în teste).
  List<String> get allTerenLabels => [
        for (final s in terenSections) ...s.rows.map((r) => r.label),
      ];
  List<String> get allAdminLabels => [
        for (final s in adminSections) ...s.rows.map((r) => r.label),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviciu principal
// ─────────────────────────────────────────────────────────────────────────────

class AppointmentSheetPdfService {
  const AppointmentSheetPdfService._();

  static final DateFormat _dtFmt = DateFormat('dd.MM.yyyy HH:mm');
  static final DateFormat _dFmt = DateFormat('dd.MM.yyyy');
  static final DateFormat _fileFmt = DateFormat('yyyyMMdd_HHmmss');

  static String _money(double value, String currency) {
    final cur = currency.trim().isEmpty ? 'RON' : currency.trim();
    return '${value.toStringAsFixed(2)} $cur';
  }

  static String _durationLabel(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0 && minutes <= 0) return '-';
    if (hours <= 0) return '$minutes min';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Content builder PUR — aici trăiește gating-ul de securitate pe rol.
  // Dacă isAdmin == false, TOATE opțiunile administrative sunt ignorate forțat
  // și adminSections este garantat gol (defense in depth față de dialog).
  // ───────────────────────────────────────────────────────────────────────────

  static AppointmentSheetContent buildContent({
    required Appointment appointment,
    required AppointmentSheetLabels labels,
    required AppointmentSheetExportOptions options,
    required bool isAdmin,
    List<EmployeePayEntry> payEntries = const <EmployeePayEntry>[],
  }) {
    final opt = isAdmin ? options : AppointmentSheetExportOptions.terenOnly;

    final teren = <SheetSection>[];
    final admin = <SheetSection>[];

    // Helper: adaugă rând doar dacă valoarea e non-goală.
    List<SheetRow> rowsOf(List<SheetRow?> raw) =>
        raw.whereType<SheetRow>().toList(growable: false);
    SheetRow? rowIf(String label, String value) {
      final v = value.trim();
      return v.isEmpty ? null : SheetRow(label, v);
    }

    // ── TEREN ────────────────────────────────────────────────────────────────

    // Programare
    teren.add(SheetSection(
      title: 'Programare',
      rows: rowsOf([
        rowIf('Titlu', appointment.title),
        SheetRow('Status', labels.statusLabel),
        rowIf('Prioritate', labels.priorityLabel),
        rowIf('Tip', appointment.type),
        SheetRow(
          'Interval',
          '${_dtFmt.format(appointment.effectiveStartDateTime)} - '
              '${_dtFmt.format(appointment.effectiveEndDateTime)}',
        ),
        SheetRow('Durată', _durationLabel(appointment.effectiveDuration)),
        if (appointment.complaintVisitType != null)
          SheetRow('Tip vizită', appointment.complaintVisitType!.label),
        if (appointment.complaintVisitOutcome != null)
          SheetRow('Rezultat vizită', appointment.complaintVisitOutcome!.label),
      ]),
    ));

    // Contact și locație
    teren.add(SheetSection(
      title: 'Contact și locație',
      rows: rowsOf([
        rowIf('Beneficiar', labels.clientName),
        rowIf('Adresă / locație', labels.addressLabel),
        rowIf('Adresă din fișa client', labels.clientAddressFromRecord),
        rowIf('Persoană de contact', labels.contactPerson),
        if (labels.phones.isNotEmpty)
          SheetRow(
            labels.phones.length == 1 ? 'Telefon' : 'Telefoane',
            labels.phones.join(', '),
          ),
        rowIf('Email', labels.email),
      ]),
    ));

    // Alocare
    teren.add(SheetSection(
      title: 'Alocare',
      rows: rowsOf([
        rowIf('Echipă', labels.teamLabel),
        rowIf('Angajați', labels.employeeLabel),
        rowIf('Responsabil (email)', appointment.assignedUserEmail),
        rowIf('Vehicul', labels.vehicleLabel),
      ]),
    ));

    // Lucrare / reclamație
    final rescheduled = appointment.rescheduledFromStartDateTime != null
        ? _dtFmt.format(appointment.rescheduledFromStartDateTime!) +
            (appointment.rescheduledFromEndDateTime != null
                ? ' - ${_dtFmt.format(appointment.rescheduledFromEndDateTime!)}'
                : '')
        : '';
    teren.add(SheetSection(
      title: 'Lucrare / reclamație',
      rows: rowsOf([
        rowIf('Echipament', appointment.equipmentDescription),
        rowIf('Lucrare asociată', labels.jobLabel),
        rowIf(
          'Nr. reclamație',
          appointment.complaintNumber.trim().isNotEmpty
              ? appointment.complaintNumber
              : appointment.complaintId,
        ),
        rowIf('Motiv amânare', appointment.postponementReason),
        rowIf('Reprogramat din', rescheduled),
      ]),
    ));

    // Documente atașate (doar etichete)
    final docLabels = appointment.linkedDocuments
        .map((d) => d.label.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    if (docLabels.isNotEmpty) {
      teren.add(SheetSection(
        title: 'Documente atașate',
        rows: [SheetRow('Documente', docLabels.join(', '))],
      ));
    }

    // Materiale (teren: doar denumire + cantitate + UM)
    final matRows = rowsOf([
      rowIf('Kit materiale', appointment.materialUsage.kitTemplateName),
      if (appointment.materialUsage.linearMetersUsed > 0)
        SheetRow(
          'Cantitate liniară',
          '${appointment.materialUsage.linearMetersUsed.toStringAsFixed(2)} ml',
        ),
      rowIf('Observații materiale', appointment.materialUsage.notes),
    ]);
    SheetTable? matTable;
    if (appointment.materialUsage.lines.isNotEmpty) {
      matTable = SheetTable(
        headers: const ['Denumire', 'Cantitate', 'UM'],
        rows: appointment.materialUsage.lines
            .map((l) => [
                  l.name,
                  _fmtQty(l.quantity),
                  l.unit,
                ])
            .toList(growable: false),
      );
    }
    if (matRows.isNotEmpty || matTable != null) {
      teren.add(SheetSection(
          title: 'Materiale', rows: matRows, table: matTable));
    }

    // Preț intervenție (TEREN — vizibil angajaților pentru încasare pe teren)
    teren.add(SheetSection(
      title: 'Preț intervenție',
      rows: [
        SheetRow(
          'Preț intervenție',
          _money(appointment.interventionPrice,
              appointment.interventionPriceCurrency),
        ),
      ],
    ));

    // Notițe
    final notesSection = SheetSection(
      title: 'Notițe',
      rows: rowsOf([rowIf('Notițe', appointment.notes)]),
    );
    if (!notesSection.isEmpty) teren.add(notesSection);

    // ── ADMIN (opt-in, doar dacă isAdmin) ──────────────────────────────────────

    if (opt.financiarIntern) {
      final section = SheetSection(
        title: 'Financiar intern',
        rows: rowsOf([
          if (appointment.adminCollectedAmount > 0)
            SheetRow(
              'Încasare / valoare internă',
              _money(appointment.adminCollectedAmount,
                  appointment.adminCollectedCurrency),
            ),
          SheetRow('Status financiar', appointment.adminFinancialStatus.label),
          if (appointment.adminDueDate != null)
            SheetRow(
                'Scadență / dată încasare', _dFmt.format(appointment.adminDueDate!)),
          rowIf('Observații financiare', appointment.adminFinancialNotes),
        ]),
      );
      if (!section.isEmpty) admin.add(section);
    }

    if (opt.costuriMateriale) {
      SheetTable? costTable;
      if (appointment.materialUsage.lines.isNotEmpty) {
        costTable = SheetTable(
          headers: const ['Denumire', 'Cant.', 'UM', 'Cost unitar', 'Cost total'],
          rows: appointment.materialUsage.lines
              .map((l) => [
                    l.name,
                    _fmtQty(l.quantity),
                    l.unit,
                    l.unitCost.toStringAsFixed(2),
                    l.totalCost.toStringAsFixed(2),
                  ])
              .toList(growable: false),
        );
      }
      final section = SheetSection(
        title: 'Costuri materiale și profit',
        rows: rowsOf([
          if (appointment.estimatedMaterialsCost > 0)
            SheetRow('Cost materiale estimat',
                _money(appointment.estimatedMaterialsCost, 'RON')),
          if (appointment.adminCollectedAmount > 0)
            SheetRow(
              'Profit estimat',
              _money(appointment.estimatedProfit,
                  appointment.adminCollectedCurrency),
            ),
          SheetRow('Facturabil partener',
              appointment.materialUsage.facturabilPartener ? 'Da' : 'Nu'),
        ]),
        table: costTable,
      );
      if (!section.isEmpty) admin.add(section);
    }

    if (opt.societateContractanta) {
      final section = SheetSection(
        title: 'Societate contractantă',
        rows: rowsOf([
          rowIf('Societate contractantă', labels.contractingClientName),
        ]),
      );
      if (!section.isEmpty) admin.add(section);
    }

    if (opt.partenerBeneficiar) {
      final section = SheetSection(
        title: 'Partener beneficiar (subcontractare)',
        rows: rowsOf([
          rowIf('Partener beneficiar', appointment.forPartnerName),
          if (appointment.forPartnerInvoiceAmount > 0)
            SheetRow(
              'Sumă de încasat',
              _money(appointment.forPartnerInvoiceAmount,
                  appointment.forPartnerInvoiceCurrency),
            ),
          SheetRow(
              'Status încasare', appointment.forPartnerReceiveStatus.label),
          if (appointment.forPartnerReceiveDate != null)
            SheetRow('Dată încasare',
                _dFmt.format(appointment.forPartnerReceiveDate!)),
          rowIf('Observații încasare', appointment.forPartnerReceiveNotes),
        ]),
      );
      // Afișează secțiunea doar dacă are conținut relevant (nume sau sumă).
      if (appointment.forPartnerName.trim().isNotEmpty ||
          appointment.forPartnerInvoiceAmount > 0) {
        admin.add(section);
      }
    }

    if (opt.partenerExecutant) {
      final section = SheetSection(
        title: 'Partener executant (comision)',
        rows: rowsOf([
          rowIf('Partener executant', appointment.executingPartnerName),
          if (appointment.executingPartnerCommission > 0)
            SheetRow(
              'Comision',
              _money(appointment.executingPartnerCommission,
                  appointment.executingPartnerCommissionCurrency),
            ),
          SheetRow(
              'Status plată', appointment.executingPartnerPaymentStatus.label),
          if (appointment.executingPartnerPaymentDate != null)
            SheetRow('Dată plată',
                _dFmt.format(appointment.executingPartnerPaymentDate!)),
          rowIf('Observații plată', appointment.executingPartnerPaymentNotes),
        ]),
      );
      if (appointment.executingPartnerName.trim().isNotEmpty ||
          appointment.executingPartnerCommission > 0) {
        admin.add(section);
      }
    }

    if (opt.platiAngajati && payEntries.isNotEmpty) {
      final total = payEntries.fold<double>(0, (s, e) => s + e.amountDue);
      final currency =
          payEntries.first.currency.trim().isEmpty ? 'RON' : payEntries.first.currency;
      admin.add(SheetSection(
        title: 'Plăți angajați',
        rows: [SheetRow('Total datorat', _money(total, currency))],
        table: SheetTable(
          headers: const ['Angajat', 'Sumă datorată', 'Notă'],
          rows: payEntries
              .map((e) => [
                    e.employeeName,
                    _money(e.amountDue, e.currency),
                    e.notes,
                  ])
              .toList(growable: false),
        ),
      ));
    }

    return AppointmentSheetContent(
      terenSections: teren.where((s) => !s.isEmpty).toList(growable: false),
      adminSections: admin,
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  // ───────────────────────────────────────────────────────────────────────────
  // Generare + salvare PDF
  // ───────────────────────────────────────────────────────────────────────────

  static Future<String> export({
    required AppDataRepository repository,
    required Appointment appointment,
    required AppointmentSheetLabels labels,
    required AppointmentSheetExportOptions options,
    required bool isAdmin,
    List<EmployeePayEntry> payEntries = const <EmployeePayEntry>[],
    bool forceSaveAs = false,
    String outputDirectory = '',
  }) async {
    await PdfFontHelper.initialize();

    CompanyProfile profile;
    try {
      profile = await repository.loadCompanyProfile();
    } catch (_) {
      profile = const CompanyProfile();
    }
    final branding = DocumentBrandingData.fromCompanyProfile(profile);

    final content = buildContent(
      appointment: appointment,
      labels: labels,
      options: options,
      isAdmin: isAdmin,
      payEntries: payEntries,
    );

    final bytes = await _buildPdf(
      branding: branding,
      appointment: appointment,
      content: content,
    );

    final numarSafe = (appointment.complaintNumber.trim().isNotEmpty
            ? appointment.complaintNumber
            : appointment.title)
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');
    final safe = numarSafe.isEmpty ? 'programare' : numarSafe;
    final fileName = 'Fisa_${safe}_${_fileFmt.format(DateTime.now())}.pdf';

    return PdfSaveService.savePdf(
      repository: repository,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      category: PdfDocumentCategory.other,
      outputDirectory: outputDirectory,
      forceSaveAs: forceSaveAs,
    );
  }

  static Future<List<int>> _buildPdf({
    required DocumentBrandingData branding,
    required Appointment appointment,
    required AppointmentSheetContent content,
  }) async {
    final doc = pw.Document(theme: PdfFontHelper.theme);
    final dateStr = _dFmt.format(DateTime.now());
    final docNumber = appointment.complaintNumber.trim().isNotEmpty
        ? appointment.complaintNumber.trim()
        : '';

    pw.Widget renderSection(SheetSection section, {bool admin = false}) {
      final children = <pw.Widget>[];
      for (final row in section.rows) {
        children.add(ProTermPdfTemplate.buildInfoRow(row.label, row.value));
      }
      if (section.table != null && section.table!.rows.isNotEmpty) {
        if (children.isNotEmpty) children.add(pw.SizedBox(height: 4));
        children.add(ProTermPdfTemplate.buildTable(
          headers: section.table!.headers,
          rows: section.table!.rows,
        ));
      }
      final title = admin ? '${section.title}  (administrativ)' : section.title;
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: ProTermPdfTemplate.buildSection(title, children),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: ProTermPdfLayout.a4PortraitCompact,
        header: (_) => pw.Column(children: [
          ProTermPdfTemplate.buildHeader(
            branding: branding,
            documentTitle: 'Fișă programare',
            documentNumber: docNumber,
            documentDate: dateStr,
            documentSubtitle: appointment.title.trim().isEmpty
                ? null
                : appointment.title.trim(),
          ),
          pw.SizedBox(height: 8),
        ]),
        footer: (ctx) => ProTermPdfTemplate.buildPageFooter(
          documentTitle: 'Fișă programare',
          pageNumber: ctx.pageNumber,
          totalPages: ctx.pagesCount,
          date: dateStr,
        ),
        build: (_) => [
          for (final s in content.terenSections) renderSection(s),
          if (content.adminSections.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: const pw.BoxDecoration(
                  color: ProTermPdfTemplate.lightRed),
              child: pw.Text(
                'INFORMAȚII ADMINISTRATIVE',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: ProTermPdfTemplate.primaryRed,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            for (final s in content.adminSections)
              renderSection(s, admin: true),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
