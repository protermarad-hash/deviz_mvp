import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/company_profile.dart';
import '../../core/document_file_service.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../clients/client_models.dart';
import '../jobs/lucrare_detalii_page.dart' show LucrareDetaliiPage;
import '../jobs/job_models.dart';
import '../materials/materials_catalog_service.dart';
import '../registratura/registry_service.dart';
import '../reclamatii/complaint_models.dart';
import '../ai_assistant/ai_assistant_action_catalog.dart';
import '../ai_assistant/ai_assistant_models.dart';
import '../ai_assistant/ai_assistant_service.dart';
import '../ai_assistant/ai_assistant_sheet.dart';
import 'deviz_articol_template_models.dart';
import 'deviz_articol_template_repository.dart';
import 'offer_currency_converter.dart';
import 'offer_commercial_package_models.dart';
import 'offer_email_template.dart';
import 'offer_labor_calculator.dart';
import 'offer_labor_resources_catalog_service.dart';
import 'offer_line_resource_dialog.dart';
import 'offer_pdf_service.dart';
import 'offer_models.dart';
import 'offer_standard_catalog_models.dart';
import 'offer_standard_labor_line_dialog.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_models.dart';
import '../../core/widgets/client_info_card.dart';
import '../crm/crm_models.dart';
import '../crm/crm_repository.dart';
import 'oferte_dialogs/offer_commercial_package_picker_dialog.dart';
import 'oferta_detaliu/oferta_detaliu_formatting_mixin.dart';
import 'oferta_detaliu/oferta_detaliu_smartbill_mixin.dart';
import 'oferta_detaliu/oferta_detaliu_partner_mixin.dart';
import 'oferta_detaliu/oferta_detaliu_acceptance_mixin.dart';
import 'oferta_detaliu/oferta_detaliu_pdf_mixin.dart';

class OfertaDetaliuPage extends StatefulWidget {
  const OfertaDetaliuPage({
    super.key,
    required this.repository,
    required this.initialOffer,
    required this.clients,
    required this.jobs,
    required this.laborTemplates,
    required this.clauseTemplates,
    required this.packageTemplates,
    required this.onSaveOffer,
    this.currentUserEmail,
    this.onEditOffer,
    this.onDuplicateOffer,
    this.onConvertToJob,
  });

  final AppDataRepository repository;
  final OfferRecord initialOffer;
  final List<ClientRecord> clients;
  final List<JobRecord> jobs;
  final List<OfferLaborTemplate> laborTemplates;
  final List<OfferCommercialClauseTemplate> clauseTemplates;
  final List<OfferCommercialPackageTemplate> packageTemplates;
  final Future<void> Function(OfferRecord offer) onSaveOffer;
  final String? currentUserEmail;
  final Future<OfferRecord?> Function(OfferRecord offer)? onEditOffer;
  final Future<OfferRecord?> Function(OfferRecord offer)? onDuplicateOffer;
  final Future<OfferRecord?> Function(OfferRecord offer)? onConvertToJob;

  @override
  State<OfertaDetaliuPage> createState() => _OfertaDetaliuPageState();
}

class _OfertaDetaliuPageState extends State<OfertaDetaliuPage>
    with
        OffertaDetaliuFormattingMixin,
        OffertaDetaliuSmartbillMixin,
        OffertaDetaliuPartnerMixin,
        OffertaDetaliuAcceptanceMixin,
        OffertaDetaliuPdfMixin {
  static const int _maxInlineAttachmentBytes = 550 * 1024;

  late final RegistryService _registryService;
  late final AiAssistantService _aiAssistantService;
  @override
  late OfferRecord offer;
  @override
  bool saving = false;
  @override
  bool exportingPdf = false;
  @override
  bool converting = false;
  @override
  bool pdfTemplateLoaded = false;
  @override
  PdfVisualTemplate selectedPdfTemplate = PdfVisualTemplate.classic;
  PdfVisualTemplate? _lastGeneratedPdfTemplate;
  final MaterialsCatalogService _materialsCatalogService =
      MaterialsCatalogService();
  final OfferLaborResourcesCatalogService _laborResourcesService =
      OfferLaborResourcesCatalogService();
  OfferLaborResourcesCatalog _laborResourcesCatalog =
      const OfferLaborResourcesCatalog(
    personnel: <OfferLaborResourceOption>[],
    teams: <OfferLaborTeamOption>[],
    vehicles: <OfferLaborResourceOption>[],
    toolPackages: <OfferLaborResourceOption>[],
    dataSourceLabel: 'local',
  );

  @override
  void initState() {
    super.initState();
    _registryService = RegistryService(widget.repository);
    _aiAssistantService = AiAssistantService(repository: widget.repository);
    offer = widget.initialOffer;
    loadPdfTemplatePreference();
    _loadLaborResources();
    loadPartnerCatalog();
    loadSmartBillStock();
  }



  PdfVisualTemplate _resolvedPdfTemplate(CompanyProfile profile) {
    return pdfTemplateLoaded
        ? selectedPdfTemplate
        : profile.pdfExportSettings.visualTemplate;
  }


  Future<void> _loadLaborResources() async {
    final catalog = await _laborResourcesService.load();
    if (!mounted) return;
    setState(() => _laborResourcesCatalog = catalog);
  }


  String _laborResourceSummary(OfferLineItem line) {
    String section(
      String title,
      List<OfferLaborResourceUsage> rows, {
      bool hoursOnly = false,
      bool hoursAndKm = false,
    }) {
      if (rows.isEmpty) return '$title: -';
      final labels = rows.map(
        (row) {
          final total = hoursOnly
              ? (row.hours * row.hourlyRate)
              : (hoursAndKm
                  ? (row.hours * row.hourlyRate) + (row.days * row.dailyRate)
                  : row.total);
          final daysLabel = hoursOnly
              ? ''
              : (hoursAndKm
                  ? ', km ${row.days.toStringAsFixed(2)}'
                  : ', zile ${row.days.toStringAsFixed(2)}');
          return '${row.name} [ore ${row.hours.toStringAsFixed(2)}$daysLabel, total ${total.toStringAsFixed(2)}]';
        },
      ).join('; ');
      return '$title: $labels';
    }

    return '${section('Personal', line.laborPersonal)}\n'
        '${section('Autoturisme', line.laborVehicles, hoursAndKm: true)}\n'
        '${section('Scule', line.laborToolPackages, hoursOnly: true)}';
  }

  List<OfferLineItem> get _sortedLines {
    final lines = [...offer.lines];
    lines.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return lines;
  }

  List<OfferLineItem> get _commercialLines =>
      buildCommercialOfferLines(offer.lines);

  List<OfferLineItem> get _internalLaborLines =>
      buildInternalLaborDetailLines(offer.lines);

  double get _internalVehicleEstimatedCost {
    return _internalLaborLines.fold<double>(0, (sum, line) {
      final breakdown = OfferLaborCalculator.computeFromResources(
        personal: const <OfferLaborResourceUsage>[],
        autoturisme: line.laborVehicles,
        pacheteScule: const <OfferLaborResourceUsage>[],
        perDiemDays: 0,
        perDiemPerDay: 0,
        lodgingNights: 0,
        lodgingPerNight: 0,
      );
      return sum + breakdown.costAutoturisme;
    });
  }

  double get _estimatedCommercialVehicleValue =>
      _estimatedCommercialValueForDirectCost(_internalVehicleEstimatedCost);

  double get _estimatedVehicleMargin =>
      _estimatedCommercialVehicleValue - _internalVehicleEstimatedCost;

  double get _internalToolsEstimatedCost {
    return _internalLaborLines.fold<double>(0, (sum, line) {
      final breakdown = OfferLaborCalculator.computeFromResources(
        personal: const <OfferLaborResourceUsage>[],
        autoturisme: const <OfferLaborResourceUsage>[],
        pacheteScule: line.laborToolPackages,
        perDiemDays: 0,
        perDiemPerDay: 0,
        lodgingNights: 0,
        lodgingPerNight: 0,
      );
      return sum + breakdown.costScule;
    });
  }

  double get _estimatedCommercialToolsValue =>
      _estimatedCommercialValueForDirectCost(_internalToolsEstimatedCost);

  double get _estimatedToolsMargin =>
      _estimatedCommercialToolsValue - _internalToolsEstimatedCost;

  String _vehicleCostSourceSummary(OfferLineItem line) {
    final labels = <String>{};
    for (final row in line.laborVehicles) {
      for (final option in _laborResourcesCatalog.vehicles) {
        if (option.id != row.resourceId) continue;
        final label = option.metaLabel.trim();
        if (label.isNotEmpty) {
          labels.add(label);
        }
        break;
      }
    }
    if (labels.isEmpty) return '';
    return labels.join(', ');
  }

  String get _vehicleCostSourceSummaryAll {
    final labels = <String>{};
    for (final line in _internalLaborLines) {
      final label = _vehicleCostSourceSummary(line);
      if (label.isNotEmpty) {
        labels.add(label);
      }
    }
    if (labels.isEmpty) return '';
    return labels.join(', ');
  }

  String get _toolCostSourceSummaryAll {
    final labels = <String>{};
    for (final line in _internalLaborLines) {
      for (final row in line.laborToolPackages) {
        for (final option in _laborResourcesCatalog.toolPackages) {
          if (option.id != row.resourceId) continue;
          final label = option.metaLabel.trim();
          if (label.isNotEmpty) {
            labels.add(label);
          }
          break;
        }
      }
    }
    if (labels.isEmpty) return '';
    return labels.join(', ');
  }

  double get _internalLaborEstimatedCost {
    return _internalLaborLines.fold<double>(
      0,
      (sum, line) => sum + line.effectiveLineTotal,
    );
  }

  double get _standardLaborCommercialValue {
    return _sortedLines.fold<double>(0, (sum, line) {
      if (line.lineType != OfferLineType.manopera) return sum;
      if (line.laborSourceMode != OfferLaborSourceMode.standard) return sum;
      return sum + line.effectiveLineTotal;
    });
  }

  double _estimatedCommercialValueForDirectCost(double directCost) {
    if (directCost <= 0) return 0;
    if (offer.subtotalDirect <= 0) return directCost;
    final markupShare = (offer.regieValue + offer.profitValue) *
        (directCost / offer.subtotalDirect);
    return directCost + markupShare;
  }

  double get _estimatedCommercialLaborValue =>
      _estimatedCommercialValueForDirectCost(_internalLaborEstimatedCost);

  double get _estimatedLaborMargin =>
      _estimatedCommercialLaborValue - _internalLaborEstimatedCost;

  double get _estimatedInterventionCost => offer.subtotalDirect;

  double get _offeredPriceWithoutVat => offer.subtotalComercial;

  double get _estimatedCommercialMargin =>
      _offeredPriceWithoutVat - _estimatedInterventionCost;

  OfferLineItem _commercialLineForDisplay(OfferLineItem source) {
    final currency = OfferCurrencyConverter.normalizeCurrency(offer.currency);
    if (!OfferCurrencyConverter.requiresRate(currency)) return source;
    final convertedUnitPrice = OfferCurrencyConverter.convertRonToOfferCurrency(
      ronAmount: source.unitPrice,
      currency: currency,
      effectiveRate: offer.effectiveExchangeRate,
    );
    final convertedTotal = OfferCurrencyConverter.convertRonToOfferCurrency(
      ronAmount: source.effectiveLineTotal,
      currency: currency,
      effectiveRate: offer.effectiveExchangeRate,
    );
    if (source.lineType == OfferLineType.manopera) {
      return source.copyWith(
        quantity: 1,
        unitPrice: convertedUnitPrice,
        lineTotal: convertedTotal,
        laborHours: 1,
        laborHourlyRate: convertedTotal,
        laborPerDiemDays: 0,
        laborPerDiemPerDay: 0,
        laborLodgingNights: 0,
        laborLodgingPerNight: 0,
        laborPersonal: const <OfferLaborResourceUsage>[],
        laborVehicles: const <OfferLaborResourceUsage>[],
        laborToolPackages: const <OfferLaborResourceUsage>[],
      );
    }
    return source.copyWith(
      unitPrice: convertedUnitPrice,
      lineTotal: convertedTotal,
    );
  }

  OfferRecord _offerWithUpdatedLines(List<OfferLineItem> sourceLines) {
    final normalized = <OfferLineItem>[];
    final sorted = [...sourceLines]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (var i = 0; i < sorted.length; i++) {
      final line = sorted[i];
      normalized.add(
        line.copyWith(
          sortOrder: i + 1,
          lineTotal: line.effectiveLineTotal,
        ),
      );
    }
    final totals = OfferRecord.computeTotals(
      lines: normalized,
      vatPercent: offer.vatPercent,
      regiePercent: offer.regiePercent,
      profitPercent: offer.profitPercent,
    );
    return offer.copyWith(
      lines: normalized,
      materialSubtotal: totals.materialSubtotal,
      laborSubtotal: totals.laborSubtotal,
      subtotalDirect: totals.subtotalDirect,
      regiePercent: totals.regiePercent,
      regieValue: totals.regieValue,
      profitPercent: totals.profitPercent,
      profitValue: totals.profitValue,
      subtotalComercial: totals.subtotalComercial,
      subtotal: totals.subtotalComercial,
      vatPercent: totals.vatPercent,
      vatValue: totals.vatValue,
      totalValue: totals.totalValue,
    );
  }

  Color _statusChipColor(OfferRecord offer) {
    if (offer.isConverted) return Colors.purple.shade400;
    switch (offer.status) {
      case OfferStatus.draft:
        return Colors.grey.shade500;
      case OfferStatus.sent:
        return Colors.blue.shade500;
      case OfferStatus.awaiting:
        return Colors.orange.shade500;
      case OfferStatus.accepted:
        return Colors.green.shade600;
      case OfferStatus.rejected:
        return Colors.red.shade500;
      case OfferStatus.cancelled:
        return Colors.grey.shade700;
    }
  }

  String _resolveClientName() {
    if (offer.clientName.trim().isNotEmpty) {
      return offer.clientName.trim();
    }
    for (final item in widget.clients) {
      if (item.id == offer.clientId) return item.name;
    }
    return '-';
  }

  @override
  ClientRecord? clientRecordById(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) return null;
    for (final item in widget.clients) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _resolveRecipientEmail() {
    if (offer.contactPersonEmail.trim().isNotEmpty) {
      return offer.contactPersonEmail.trim();
    }

    final clientCandidates = <ClientRecord?>[
      clientRecordById(offer.commercialRecipientClientId),
      clientRecordById(offer.clientId),
      clientRecordById(offer.beneficiaryClientId),
    ];
    for (final client in clientCandidates.whereType<ClientRecord>()) {
      if (client.email.trim().isNotEmpty) {
        return client.email.trim();
      }
      for (final contact in client.contactPeople) {
        if (offer.contactPersonId.trim().isNotEmpty &&
            contact.id == offer.contactPersonId.trim() &&
            contact.email.trim().isNotEmpty) {
          return contact.email.trim();
        }
      }
      for (final contact in client.contactPeople) {
        if (contact.email.trim().isNotEmpty) {
          return contact.email.trim();
        }
      }
    }
    return '';
  }

  String _resolveSenderName(CompanyProfile company) {
    if (company.contactName.trim().isNotEmpty) {
      return company.contactName.trim();
    }
    final currentEmail = (widget.currentUserEmail ?? '').trim();
    if (currentEmail.isNotEmpty) {
      return currentEmail;
    }
    if (offer.createdByUserEmail.trim().isNotEmpty) {
      return offer.createdByUserEmail.trim();
    }
    return company.companyName.trim();
  }

  String _resolveSenderRole() => 'Departament comercial';

  String _resolveJobLabel() {
    if (offer.jobCode.trim().isNotEmpty || offer.jobTitle.trim().isNotEmpty) {
      final code = offer.jobCode.trim();
      final title = offer.jobTitle.trim();
      if (code.isNotEmpty && title.isNotEmpty) return '$code - $title';
      if (code.isNotEmpty) return code;
      if (title.isNotEmpty) return title;
    }
    for (final item in widget.jobs) {
      if (item.id != offer.jobId) continue;
      if (item.jobCode.trim().isNotEmpty && item.title.trim().isNotEmpty) {
        return '${item.jobCode} - ${item.title}';
      }
      return item.title.trim().isEmpty ? '-' : item.title;
    }
    return '-';
  }

  String _displayStatusLabel(OfferRecord offer) {
    if (offer.isConverted) return 'Convertita';
    return offer.status.label;
  }


  /// Automatically updates offer status to [OfferStatus.sent] if it is still
  /// in draft state, so the user doesn't have to change it manually.
  Future<void> _markOfferAsSentIfDraft() async {
    if (offer.status == OfferStatus.draft ||
        offer.status == OfferStatus.awaiting) {
      final next = offer.copyWith(
        status: OfferStatus.sent,
        updatedAt: DateTime.now(),
      );
      await widget.onSaveOffer(next);
      if (mounted) setState(() => offer = next);
    }
  }


  String _commercialLineSubtitle(OfferLineItem sourceLine, OfferLineItem line) {
    final buffer = StringBuffer()
      ..writeln('Tip: ${line.lineType.label}');
    // Descrierea dată de utilizator — dacă e goală, nu afișăm nimic
    if (sourceLine.description.trim().isNotEmpty) {
      buffer.writeln(sourceLine.description.trim());
    }
    buffer.write(
      'UM: ${line.unit} • Cantitate: ${line.quantity.toStringAsFixed(2)}'
      ' • Preț unitar: ${displayAmountWithLabels(sourceLine.unitPrice, withoutVatLabel: 'fără TVA', withVatLabel: 'cu TVA')}'
      ' • Total linie: ${displayAmountWithLabels(sourceLine.effectiveLineTotal, withoutVatLabel: 'fără TVA', withVatLabel: 'cu TVA')}',
    );
    if (sourceLine.lineType == OfferLineType.manopera &&
        sourceLine.laborSourceMode == OfferLaborSourceMode.standard) {
      buffer
        ..writeln()
        ..write('Cost intern: indisponibil în această variantă standard');
    }
    return buffer.toString();
  }

  @override
  bool get isFrozen => offer.isConverted;

  @override
  void showFrozenMessage() {
    final jobId = offer.convertedToJobId.trim();
    final suffix = jobId.isEmpty ? '' : ' Lucrarea generata este $jobId.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oferta a fost deja convertita in lucrare si nu mai poate fi modificata.$suffix',
        ),
      ),
    );
  }

  JobRecord? _findConvertedJob() {
    final jobId = offer.convertedToJobId.trim();
    if (jobId.isEmpty) return null;
    for (final item in widget.jobs) {
      if (item.id == jobId) return item;
    }
    return null;
  }

  Future<void> _openConvertedJob() async {
    final job = _findConvertedJob();
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lucrarea generata pentru oferta ${offer.offerNumber} nu a fost gasita in lista curenta.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LucrareDetaliiPage(
          repository: widget.repository,
          job: job,
          clientName: _resolveClientName(),
        ),
      ),
    );
  }

  // keepPdfPath: true doar când salvăm calea PDF după generare
  // În rest, ștergem pdfPath pentru a forța regenerarea la următoarea cerere
  @override
  Future<void> persistOffer(
    OfferRecord next, {
    bool keepPdfPath = false,
  }) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    if (saving) return;
    final toPersist = keepPdfPath ? next : next.copyWith(pdfPath: '');
    final updated = toPersist.copyWith(updatedAt: DateTime.now());
    // Update optimist: UI reflectă imediat modificarea, indiferent de rezultatul salvării
    setState(() {
      saving = true;
      offer = updated;
    });
    try {
      await widget.onSaveOffer(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  ClientRecord? _findOfferClient() {
    for (final item in widget.clients) {
      if (item.id == offer.clientId) return item;
    }
    return null;
  }

  JobRecord? _findOfferJob() {
    for (final item in widget.jobs) {
      if (item.id == offer.jobId) return item;
    }
    return null;
  }


  AiAssistantRuntimeContext _buildOfferAiContext() {
    final client = _findOfferClient();
    final job = _findOfferJob();
    return AiAssistantRuntimeContext(
      contextType: AiAssistantContextType.offers,
      module: 'oferte',
      entityId: offer.id,
      entityLabel: offer.offerNumber,
      userId: widget.currentUserEmail?.trim() ?? '',
      contextLabel: 'Oferta ${offer.offerNumber}',
      primaryData: <String, dynamic>{
        ...offer.toMap(),
        'type': 'offer',
      },
      relatedData: <String, dynamic>{
        'offer': offer.toMap(),
        'client': client?.toMap() ?? <String, dynamic>{},
        'job': job?.toMap() ?? <String, dynamic>{},
      },
      insertionTargets: const <AiAssistantInsertionTarget>[
        AiAssistantInsertionTarget(
          key: 'offer_notes',
          label: 'Note oferta',
          description: 'Insereaza draftul in notele ofertei.',
          insertMode: AiAssistantInsertMode.replace,
        ),
      ],
    );
  }

  Future<void> _openMaterialNecessar() async {
    // Collect only material lines
    final materialLines = offer.lines
        .where((l) => l.lineType == OfferLineType.material)
        .toList(growable: false);

    if (materialLines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oferta nu contine pozitii de tip material.'),
        ),
      );
      return;
    }

    // Build mutable state: name + quantity + unit per item
    final names =
        materialLines.map((l) => TextEditingController(text: l.name)).toList();
    final quantities = materialLines
        .map((l) => TextEditingController(
              text: l.quantity % 1 == 0
                  ? l.quantity.toInt().toString()
                  : l.quantity.toString(),
            ))
        .toList();
    final units =
        materialLines.map((l) => TextEditingController(text: l.unit)).toList();

    void disposeControllers() {
      for (final c in names) {
        c.dispose();
      }
      for (final c in quantities) {
        c.dispose();
      }
      for (final c in units) {
        c.dispose();
      }
    }

    String buildText() {
      final buf = StringBuffer();
      buf.writeln('NECESAR MATERIALE');
      buf.writeln('Oferta: ${offer.offerNumber}');
      buf.writeln(
          'Data: ${offer.createdAt.day.toString().padLeft(2, '0')}.${offer.createdAt.month.toString().padLeft(2, '0')}.${offer.createdAt.year}');
      buf.writeln();
      buf.writeln('Nr.  Denumire${' ' * 40}Cant.   UM');
      buf.writeln('-' * 70);
      for (int i = 0; i < names.length; i++) {
        final nr = (i + 1).toString().padLeft(3);
        final name = names[i].text.trim();
        final qty = quantities[i].text.trim();
        final um = units[i].text.trim();
        buf.writeln('$nr. $name  $qty  $um');
      }
      return buf.toString();
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Text('Necesar materiale furnizori'),
            content: SizedBox(
              width: 680,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editati lista de materiale inainte de a o trimite furnizorilor. Preturile nu sunt vizibile.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  // Header row
                  Row(
                    children: [
                      const SizedBox(
                          width: 40,
                          child: Text('#',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const Expanded(
                          flex: 5,
                          child: Text('Denumire',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      const SizedBox(
                          width: 80,
                          child: Text('Cantitate',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      const SizedBox(
                          width: 60,
                          child: Text('UM',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: names.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text('${i + 1}.',
                                    style: const TextStyle(color: Colors.grey)),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                textCapitalization: TextCapitalization.sentences,
                                controller: names[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: quantities[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                textCapitalization: TextCapitalization.sentences,
                                controller: units[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  disposeControllers();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Inchide'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiaza text'),
                onPressed: () async {
                  final text = buildText();
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Lista copiata in clipboard. Puteti lipi in email sau WhatsApp.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
    disposeControllers();
  }

  Future<void> _openAiAssistant() async {
    await AiAssistantSheet.show(
      context: context,
      title: 'Asistent AI oferta',
      service: _aiAssistantService,
      runtimeContext: _buildOfferAiContext(),
      actions: AiAssistantActionCatalog.actionsFor(
        AiAssistantContextType.offers,
      ),
      onInsertDraft: _applyAiOfferDraft,
    );
  }

  Future<bool> _applyAiOfferDraft(String targetKey, String content) async {
    if (isFrozen) {
      showFrozenMessage();
      return false;
    }
    if (targetKey != 'offer_notes') return false;
    final next = offer.copyWith(
      notes: content.trim(),
      updatedAt: DateTime.now(),
    );
    await persistOffer(next);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draftul AI a fost inserat in notele ofertei.'),
      ),
    );
    return true;
  }

  Future<void> _changeTipDocument() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    TipDocumentDeviz selected = offer.tipDocument;
    final result = await showDialog<TipDocumentDeviz>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tip document'),
          content: RadioGroup<TipDocumentDeviz>(
            groupValue: selected,
            onChanged: (v) {
              if (v != null) {
                setDialogState(() => selected = v);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: TipDocumentDeviz.values
                  .map((tip) => ListTile(
                        dense: true,
                        leading: Radio<TipDocumentDeviz>(value: tip),
                        title: Text(tip.label),
                        onTap: () => setDialogState(() => selected = tip),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Renunță'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Aplică'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result == offer.tipDocument) return;
    final next = offer.copyWith(
      tipDocument: result,
      updatedAt: DateTime.now(),
    );
    await persistOffer(next);
  }

  Future<void> _editOfferHeader() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final edit = widget.onEditOffer;
    if (edit == null) return;
    final updated = await edit(offer);
    if (!mounted || updated == null) return;
    setState(() => offer = updated);
  }

  Future<void> _duplicateOffer() async {
    final duplicate = widget.onDuplicateOffer;
    if (duplicate == null) return;
    final created = await duplicate(offer);
    if (!mounted || created == null) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfertaDetaliuPage(
          repository: widget.repository,
          initialOffer: created,
          clients: widget.clients,
          jobs: widget.jobs,
          laborTemplates: widget.laborTemplates,
          clauseTemplates: widget.clauseTemplates,
          packageTemplates: widget.packageTemplates,
          onSaveOffer: widget.onSaveOffer,
          currentUserEmail: widget.currentUserEmail,
          onEditOffer: widget.onEditOffer,
          onDuplicateOffer: widget.onDuplicateOffer,
          onConvertToJob: widget.onConvertToJob,
        ),
      ),
    );
  }

  Future<void> _changeOfferStatus(OfferStatus newStatus) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    if (offer.status == newStatus) return;

    final next = offer.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await persistOffer(next);

    // Fire-and-forget CRM sync la schimbarea statusului ofertei
    _syncCrmForOfferStatus(next, newStatus);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status oferta a fost schimbat in: ${newStatus.label}',
        ),
      ),
    );
  }

  void _syncCrmForOfferStatus(OfferRecord offer, OfferStatus newStatus) {
    if (newStatus == OfferStatus.sent) {
      _upsertCrmForOffer(offer, CrmStadiu.ofertaTrimisa);
    } else if (newStatus == OfferStatus.accepted) {
      _upsertCrmForOffer(offer, CrmStadiu.castigat,
          valoareFinala: offer.totalValue);
    } else if (newStatus == OfferStatus.rejected) {
      _upsertCrmForOffer(offer, CrmStadiu.pierdut);
    }
  }

  void _upsertCrmForOffer(OfferRecord offer, CrmStadiu stadiu,
      {double? valoareFinala}) {
    final repo = CrmRepository.instance;
    repo.listLocal().then((all) {
      final existing = all.cast<CrmRecord?>().firstWhere(
            (r) => r!.ofertaId == offer.id,
            orElse: () => null,
          );
      final now = DateTime.now();
      final CrmRecord updated;
      if (existing != null) {
        updated = existing.copyWith(
          stadiu: stadiu,
          valoareFinala: valoareFinala,
          updatedAt: now,
        );
      } else {
        updated = repo
            .createNew(
              titlu: offer.title.isNotEmpty
                  ? offer.title
                  : 'Oferta ${offer.id.substring(0, 8)}',
              clientName: offer.clientName,
              clientId: offer.clientId,
              stadiu: stadiu,
              valoareEstimata: offer.totalValue,
            )
            .copyWith(
              ofertaId: offer.id,
              valoareFinala: valoareFinala,
              updatedAt: now,
            );
      }
      repo.upsertCrmRecord(updated).catchError((e) {
        debugPrint('[CRM] ❌ _upsertCrmForOffer: $e');
      });
    }).catchError((e) {
      debugPrint('[CRM] ❌ listLocal for offer sync: $e');
    });
  }

  Future<void> _openEmailDialog() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }

    try {
      final company = await widget.repository.loadCompanyProfile();
      final attachmentPath = await _ensureOfferPdfAvailable(company: company);

      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        builder: (context) => OfferEmailSendDialog(
          offer: offer,
          company: company,
          currentUserEmail: widget.currentUserEmail ?? '',
          initialRecipientEmail: _resolveRecipientEmail(),
          currentUserName: _resolveSenderName(company),
          currentUserRole: _resolveSenderRole(),
          attachmentPath: attachmentPath,
          attachmentLabel: attachmentPath.split(RegExp(r'[\\/]')).last,
          onSendEmail: _sendEmailViaMailto,
          onQueueEmail: _queueSendEmail,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la incarcarea datelor companiei: $e'),
        ),
      );
    }
  }

  Future<bool> _sendEmailViaMailto(
    String recipientEmail,
    String subject,
    String bodyText,
    String bodyHtml,
    String attachmentPath,
  ) async {
    try {
      final company = await widget.repository.loadCompanyProfile();
      final pdfPath = await _ensureOfferPdfAvailable(company: company);
      final resolvedAttachmentPath =
          attachmentPath.trim().isEmpty ? pdfPath : attachmentPath.trim();

      if (Platform.isWindows) {
        final opened = await _openOutlookDraftOnWindows(
          recipientEmail: recipientEmail,
          subject: subject,
          bodyText: bodyText,
          bodyHtml: bodyHtml,
          attachmentPath: resolvedAttachmentPath,
        );
        if (opened) {
          await _markOfferAsSentIfDraft();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Outlook a fost deschis cu PDF-ul atasat.',
                ),
              ),
            );
          }
          return true;
        }
      }

      final encodedTo = Uri.encodeComponent(recipientEmail);
      final encodedSubject = Uri.encodeComponent(subject);
      final encodedBody = Uri.encodeComponent(bodyText);

      final uri = Uri.parse(
        'mailto:$encodedTo?subject=$encodedSubject&body=$encodedBody',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _markOfferAsSentIfDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Clientul de email a fost deschis. PDF-ul ofertei este pregatit la: $pdfPath',
              ),
            ),
          );
        }
        return true;
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nu am putut deschide clientul de email. Vă rugăm să trimiteți emailul manual.',
            ),
          ),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la deschiderea clientului de email: $e'),
        ),
      );
      return false;
    }
  }

  Future<bool> _openOutlookDraftOnWindows({
    required String recipientEmail,
    required String subject,
    required String bodyText,
    required String bodyHtml,
    required String attachmentPath,
  }) async {
    final normalizedAttachmentPath = attachmentPath.trim();
    if (!Platform.isWindows || normalizedAttachmentPath.isEmpty) {
      return false;
    }

    final attachmentFile = File(normalizedAttachmentPath);
    if (!attachmentFile.existsSync()) {
      return false;
    }

    String psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

    List<int> utf16LeBytes(String value) {
      final bytes = <int>[];
      for (final unit in value.codeUnits) {
        bytes
          ..add(unit & 0xff)
          ..add((unit >> 8) & 0xff);
      }
      return bytes;
    }

    final script = '''


\$ErrorActionPreference = 'Stop'
\$outlook = New-Object -ComObject Outlook.Application
\$mail = \$outlook.CreateItem(0)
\$mail.To = ${psLiteral(recipientEmail)}
\$mail.Subject = ${psLiteral(subject)}
\$attachment = ${psLiteral(normalizedAttachmentPath)}
if (${psLiteral(bodyHtml)} -ne '') {
  \$mail.HTMLBody = ${psLiteral(bodyHtml)}
} else {
  \$mail.Body = ${psLiteral(bodyText)}
}
if (Test-Path \$attachment) {
  [void]\$mail.Attachments.Add(\$attachment)
}
\$mail.Display()
''';

    try {
      final encodedCommand = base64Encode(utf16LeBytes(script));
      final result = await Process.run(
        'powershell',
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-EncodedCommand',
          encodedCommand,
        ],
      );
      if (result.exitCode == 0) {
        return true;
      }
    } catch (_) {
      // Fall through to the command-line fallback below.
    }

    return _openOutlookAttachmentFallbackOnWindows(
      attachmentPath: normalizedAttachmentPath,
      recipientEmail: recipientEmail,
      subject: subject,
      bodyText: bodyText,
    );
  }

  Future<bool> _openOutlookAttachmentFallbackOnWindows({
    required String attachmentPath,
    required String recipientEmail,
    required String subject,
    required String bodyText,
  }) async {
    if (!Platform.isWindows || attachmentPath.trim().isEmpty) {
      return false;
    }

    final attachmentFile = File(attachmentPath.trim());
    if (!attachmentFile.existsSync()) {
      return false;
    }

    try {
      final result = await Process.run(
        'cmd',
        <String>[
          '/c',
          'start',
          '',
          'outlook.exe',
          '/a',
          attachmentFile.path,
        ],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return true;
      }
    } catch (_) {
      // Fall through to the .eml draft fallback below.
    }

    return _openEmailDraftFileWithAttachment(
      recipientEmail: recipientEmail,
      subject: subject,
      bodyText: bodyText,
      attachmentPath: attachmentPath,
    );
  }

  Future<bool> _openEmailDraftFileWithAttachment({
    required String recipientEmail,
    required String subject,
    required String bodyText,
    required String attachmentPath,
  }) async {
    final normalizedAttachmentPath = attachmentPath.trim();
    if (normalizedAttachmentPath.isEmpty) {
      return false;
    }

    final attachmentFile = File(normalizedAttachmentPath);
    if (!attachmentFile.existsSync()) {
      return false;
    }

    String sanitizeHeader(String value) =>
        value.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();

    String wrapBase64(String value, {int width = 76}) {
      final buffer = StringBuffer();
      for (var index = 0; index < value.length; index += width) {
        final end =
            (index + width < value.length) ? index + width : value.length;
        buffer.writeln(value.substring(index, end));
      }
      return buffer.toString();
    }

    try {
      final boundary =
          '----=_NextPart_${DateTime.now().microsecondsSinceEpoch}';
      final attachmentBytes = await attachmentFile.readAsBytes();
      final attachmentBase64 = wrapBase64(base64Encode(attachmentBytes));
      final bodyBase64 = wrapBase64(base64Encode(utf8.encode(bodyText)));
      final fileName = attachmentFile.uri.pathSegments.isNotEmpty
          ? attachmentFile.uri.pathSegments.last
          : 'document.pdf';
      final emlContent = StringBuffer()
        ..writeln('To: ${sanitizeHeader(recipientEmail)}')
        ..writeln('Subject: ${sanitizeHeader(subject)}')
        ..writeln('MIME-Version: 1.0')
        ..writeln('Content-Type: multipart/mixed; boundary="$boundary"')
        ..writeln()
        ..writeln('--$boundary')
        ..writeln('Content-Type: text/plain; charset="utf-8"')
        ..writeln('Content-Transfer-Encoding: base64')
        ..writeln()
        ..write(bodyBase64)
        ..writeln('--$boundary')
        ..writeln('Content-Type: application/pdf; name="$fileName"')
        ..writeln('Content-Transfer-Encoding: base64')
        ..writeln('Content-Disposition: attachment; filename="$fileName"')
        ..writeln()
        ..write(attachmentBase64)
        ..writeln('--$boundary--');

      final draftFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}offer_email_${DateTime.now().microsecondsSinceEpoch}.eml',
      );
      await draftFile.writeAsString(emlContent.toString(), flush: true);
      final openResult = await DocumentFileService.openFile(draftFile.path);
      return openResult.opened;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _queueSendEmail(
    String recipientEmail,
    String subject,
    String bodyText,
    String bodyHtml,
  ) async {
    if (recipientEmail.trim().isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Va rugam introduceti email-ul destinatarului.')),
      );
      return false;
    }

    try {
      final company = await widget.repository.loadCompanyProfile();
      final pdfPath = await _ensureOfferPdfAvailable(company: company);

      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) {
        throw StateError('PDF-ul ofertei nu exista pe disc pentru atasare.');
      }
      final pdfBytes = await pdfFile.readAsBytes();

      final inlineAssets = <Map<String, dynamic>>[];
      if (company.logoBase64.trim().isNotEmpty) {
        inlineAssets.add({
          'cid': 'companylogo',
          'filename': 'logo.png',
          'base64': company.logoBase64.trim(),
          'contentType': 'image/png',
        });
      }

      final pdfFileName = OfferPdfService.exportFileName(offer);
      final attachments = <Map<String, dynamic>>[
        await _buildQueueAttachmentForOfferPdf(
          pdfBytes: pdfBytes,
          fileName: pdfFileName,
          sourceEntityId: offer.id,
        ),
      ];

      final templateData = OfferEmailTemplate.buildComplete(
        offer: offer,
        company: company,
        currentUserEmail: widget.currentUserEmail ?? '',
        currentUserName: _resolveSenderName(company),
        currentUserRole: _resolveSenderRole(),
        recipientEmail: recipientEmail.trim(),
      );

      final notif = NotificationCenterService();
      final queueItem = await notif.sendEmailNotification(
        recipientEmail: recipientEmail.trim(),
        recipientName: _resolveClientName(),
        subject: subject.trim().isEmpty
            ? OfferEmailTemplate.subject(offerNumber: offer.offerNumber)
            : subject.trim(),
        bodyText: bodyText,
        bodyHtml: bodyHtml.trim().isEmpty ? templateData.htmlBody : bodyHtml,
        attachments: attachments,
        inlineAssets: inlineAssets,
        sourceModule: 'oferte',
        sourceEntityId: offer.id,
        eventType: NotificationEventType.documentGenerated,
        metadata: {'offer_number': offer.offerNumber},
      );

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email pus in coada: ${queueItem.id}. Statusul final se vede in Notificari / Email log.',
          ),
        ),
      );
      return true;
    } catch (e) {
      final diagnosticMessage = _describeDirectEmailFailure(e);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(diagnosticMessage)),
      );
      return false;
    }
  }

  String _describeDirectEmailFailure(Object error) {
    final text = error.toString().trim();
    final normalized = text.toLowerCase();

    if (normalized.contains('firebase cloud nu este disponibil')) {
      return 'Trimiterea directa pe email nu este disponibila deoarece conexiunea cloud Firebase nu este activa.';
    }
    if (normalized.contains('notification_email_queue')) {
      return 'Trimiterea directa pe email a esuat la scrierea in coada cloud notification_email_queue.';
    }
    if (normalized.contains('resource-exhausted') ||
        normalized.contains('maximum size') ||
        normalized.contains('document too large')) {
      return 'Payload-ul emailului este prea mare pentru Firestore. PDF-ul trebuie incarcat in Storage pentru a fi trimis prin coada.';
    }
    if (normalized.contains('pdf-ul ofertei nu exista')) {
      return 'PDF-ul ofertei lipseste. Regenerati PDF-ul si incercati din nou.';
    }
    if (normalized.contains('config email lipsa') ||
        normalized.contains('notification_smtp_') ||
        normalized.contains('smtp_host') ||
        normalized.contains('email_from')) {
      return 'Trimiterea directa pe email nu este configurata complet pe server. Lipsesc setarile SMTP sau adresa expeditorului.';
    }
    return 'Trimiterea directa pe email a esuat: $text';
  }

  Future<Map<String, dynamic>> _buildQueueAttachmentForOfferPdf({
    required Uint8List pdfBytes,
    required String fileName,
    required String sourceEntityId,
  }) async {
    final normalizedFileName = _sanitizeAttachmentFileName(fileName);
    if (pdfBytes.length <= _maxInlineAttachmentBytes) {
      return <String, dynamic>{
        'filename': normalizedFileName,
        'base64': base64Encode(pdfBytes),
        'content_type': 'application/pdf',
        'size_bytes': pdfBytes.length,
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final safeEntity = sourceEntityId.trim().isEmpty
        ? 'unknown_offer'
        : sourceEntityId.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path =
        'notification_email_attachments/oferte/$safeEntity/${now}_$normalizedFileName';
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {/* intenționat ignorat: refresh token best-effort înainte de upload */}
    final ref = FirebaseStorage.instance.ref().child(path);
    try {
      await ref.putData(
        pdfBytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } catch (e) {
      debugPrint('[Oferta] ❌ Storage upload failed: $e');
      rethrow;
    }

    return <String, dynamic>{
      'filename': normalizedFileName,
      'storage_path': ref.fullPath,
      'storage_bucket': ref.bucket,
      'content_type': 'application/pdf',
      'size_bytes': pdfBytes.length,
      'encoding': 'firebase_storage',
    };
  }

  String _sanitizeAttachmentFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'oferta.pdf';
    }
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  Future<String> _ensureOfferPdfAvailable({
    CompanyProfile? company,
    PdfVisualTemplate? template,
    bool forceRegenerate = false,
  }) async {
    final currentPath = offer.pdfPath.trim();
    final profile = company ?? await widget.repository.loadCompanyProfile();
    final resolvedTemplate = template ?? _resolvedPdfTemplate(profile);
    final shouldRegenerate = forceRegenerate ||
        (_lastGeneratedPdfTemplate != null &&
            _lastGeneratedPdfTemplate != resolvedTemplate);
    if (!shouldRegenerate &&
        currentPath.isNotEmpty &&
        File(currentPath).existsSync()) {
      return currentPath;
    }

    final issuer = (offer.createdByUserEmail.trim().isNotEmpty
            ? offer.createdByUserEmail
            : (widget.currentUserEmail ?? ''))
        .trim();
    final branding = DocumentBrandingData.fromCompanyProfile(profile);
    final path = await OfferPdfService.export(
      repository: widget.repository,
      offer: offer,
      clientLabel: _resolveClientName(),
      jobLabel: _resolveJobLabel(),
      issuerLabel: issuer.isEmpty ? '-' : issuer,
      branding: branding,
      template: resolvedTemplate,
    );
    final next = offer.copyWith(
      pdfPath: path,
      updatedAt: DateTime.now(),
    );
    await persistOffer(next, keepPdfPath: true);
    _lastGeneratedPdfTemplate = resolvedTemplate;
    return path;
  }

  Future<void> _editVatPercent() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final ctrl =
        TextEditingController(text: offer.vatPercent.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica TVA (%)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'TVA %'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                ctrl.text.replaceAll(',', '.').trim(),
              );
              if (value == null || value < 0) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final next = offer.copyWith(
      vatPercent: result,
      lines: offer.lines,
    );
    await persistOffer(next);
  }

  Future<void> _generatePdf({bool share = false, bool saveAs = false}) async {
    if (exportingPdf) return;
    setState(() => exportingPdf = true);
    try {
      final companyProfile = await widget.repository.loadCompanyProfile();
      final selectedTemplate = _resolvedPdfTemplate(companyProfile);
      final issuer = (offer.createdByUserEmail.trim().isNotEmpty
              ? offer.createdByUserEmail
              : (widget.currentUserEmail ?? ''))
          .trim();
      final branding = DocumentBrandingData.fromCompanyProfile(
        companyProfile,
      );
      String path = '';
      var offerForActions = offer;
      if (share) {
        await OfferPdfService.share(
          offer: offer,
          clientLabel: _resolveClientName(),
          jobLabel: _resolveJobLabel(),
          issuerLabel: issuer.isEmpty ? '-' : issuer,
          branding: branding,
          template: selectedTemplate,
        );
        _lastGeneratedPdfTemplate = selectedTemplate;
      } else {
        path = await OfferPdfService.export(
          repository: widget.repository,
          offer: offer,
          clientLabel: _resolveClientName(),
          jobLabel: _resolveJobLabel(),
          issuerLabel: issuer.isEmpty ? '-' : issuer,
          branding: branding,
          template: selectedTemplate,
          saveAs: saveAs,
        );
        // Curăță TOATE fișierele PDF vechi ale acestei oferte din același director.
        // Previne acumularea de fișiere și caching-ul viewer-ului Android.
        cleanupOldOfferPdfs(newPath: path, offer: offer);
        offerForActions = offerForActions.copyWith(
          pdfPath: path,
          hasAcceptancePage: true,
          updatedAt: DateTime.now(),
        );
        _lastGeneratedPdfTemplate = selectedTemplate;
      }
      var successMessage = share
          ? 'Documentul a fost trimis catre share sheet.'
          : 'PDF oferta generat: $path';
      if (!share && offer.registryEntryId.trim().isEmpty) {
        try {
          final entry = await _registryService.registerOffer(
            offerId: offer.id,
            documentNumber: offer.offerNumber.trim().isEmpty
                ? offer.id
                : offer.offerNumber,
            title: offer.title.trim().isEmpty
                ? 'Oferta client ${offer.offerNumber}'
                : offer.title.trim(),
            clientId: offer.clientId,
            recipientName: _resolveClientName(),
            documentDate: offer.issueDate,
            filePath: path,
            fileName: path.split(RegExp(r'[\\/]')).last,
            notes: 'Oferta client inregistrata automat la primul export PDF.',
          );
          offerForActions = offerForActions.copyWith(
            registryEntryId: entry.id,
            registryNumber: entry.registryNumber,
            registeredAt: entry.registeredAt,
            updatedAt: DateTime.now(),
          );
          successMessage =
              'PDF oferta generat si inregistrat in Registratura (${entry.registryNumber}).';
        } catch (registryError) {
          successMessage =
              'PDF oferta generat, dar inregistrarea in Registratura a esuat: $registryError';
        }
      }
      if (!share || offerForActions != offer) {
        await widget.onSaveOffer(offerForActions);
        if (!mounted) return;
        setState(() => offer = offerForActions);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      if (!share && path.trim().isNotEmpty) {
        await _showGeneratedPdfActions(path);
      }
    } on PdfSaveCanceledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea documentului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la generare PDF oferta: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => exportingPdf = false);
      }
    }
  }


  Future<void> _showGeneratedPdfActions(String filePath) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PDF oferta generat',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  filePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final result =
                            await DocumentFileService.openFile(filePath);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                        if (result.shouldOfferShare && mounted) {
                          await _shareExistingPdf(filePath);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareExistingPdf(filePath);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    if (!DocumentFileService.isMobilePlatform)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final opened =
                              await DocumentFileService.openFolderForFile(
                            filePath,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? 'Folder deschis.'
                                    : 'Nu am putut deschide folderul.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareExistingPdf(String filePath) async {
    try {
      await DocumentFileService.shareFile(
        filePath,
        subject: 'Oferta ${offer.offerNumber.trim()}'.trim(),
        text: 'PDF oferta generat din aplicatie.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share deschis pentru PDF.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut trimite PDF-ul: $error')),
      );
    }
  }

  bool get _canConvertToJob =>
      offer.status == OfferStatus.accepted &&
      offer.convertedToJobId.trim().isEmpty &&
      widget.onConvertToJob != null;

  Future<void> _convertToJob() async {
    final action = widget.onConvertToJob;
    if (action == null || !_canConvertToJob || converting) return;
    setState(() => converting = true);
    try {
      final updated = await action(offer);
      if (!mounted) return;
      if (updated != null) {
        setState(() => offer = updated);
      }
    } finally {
      if (mounted) {
        setState(() => converting = false);
      }
    }
  }

  Future<void> _addLine() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_outlined),
              title: const Text('Adaugă din pachet comercial'),
              onTap: () => Navigator.of(context).pop('commercial_package'),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Material / manoperă din resurse'),
              onTap: () => Navigator.of(context).pop('resource'),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Manoperă simplă (cantitate × preț)'),
              subtitle: const Text(
                  'Titlu personalizat, nr. bucăți și preț fix — fără resurse'),
              onTap: () => Navigator.of(context).pop('simple_labor'),
            ),
            ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Manoperă standard'),
              onTap: () => Navigator.of(context).pop('standard_labor'),
            ),
          ],
        ),
      ),
    );
    if (mode == null) {
      return;
    }
    if (mode == 'commercial_package') {
      await _addCommercialPackage();
      return;
    }
    if (mode == 'simple_labor') {
      await _addSimpleLaborLine();
      return;
    }
    if (mode == 'standard_labor') {
      await _addStandardLaborLine();
      return;
    }
    if (!mounted) return;
    final saved = await showDialog<OfferLineItem>(
      context: context,
      builder: (context) => OfferLineResourceDialog(
        initialSortOrder: _sortedLines.length + 1,
        personnelOptions: _laborResourcesCatalog.personnel,
        teamOptions: _laborResourcesCatalog.teams,
        vehicleOptions: _laborResourcesCatalog.vehicles,
        toolPackageOptions: _laborResourcesCatalog.toolPackages,
      ),
    );
    if (saved == null) return;
    final syncedLine = await _syncMaterialLineIfNeeded(saved);
    final lines = [
      ..._sortedLines,
      syncedLine.copyWith(
        sortOrder: _sortedLines.length + 1,
        lineTotal: syncedLine.effectiveLineTotal,
      ),
    ];
    final next = _offerWithUpdatedLines(lines);
    await persistOffer(next);
    await _handleArticolTemplateSave(syncedLine);
  }

  Future<void> _addCommercialPackage() async {
    final selected = await showDialog<OfferCommercialPackageTemplate>(
      context: context,
      builder: (context) => OfferCommercialPackagePickerDialog(
        items: widget.packageTemplates,
      ),
    );
    if (selected == null) {
      return;
    }
    final normalizedMaterials = <OfferLineItem>[];
    var nextSortOrder = _sortedLines.length + 1;
    for (final material in selected.materials) {
      if (material.name.trim().isEmpty) {
        continue;
      }
      final line = OfferLineItem(
        id: 'line-${DateTime.now().microsecondsSinceEpoch}-$nextSortOrder',
        name: material.name.trim(),
        description: material.description.trim(),
        unit: material.unit.trim().isEmpty ? 'buc' : material.unit.trim(),
        quantity: material.quantity > 0 ? material.quantity : 1,
        unitPrice: material.unitPrice,
        lineTotal: (material.quantity > 0 ? material.quantity : 1) *
            material.unitPrice,
        sortOrder: nextSortOrder,
        lineType: OfferLineType.material,
        materialId: material.materialId.trim(),
      );
      normalizedMaterials.add(await _syncMaterialLineIfNeeded(line));
      nextSortOrder++;
    }

    final laborLines = <OfferLineItem>[];
    for (final labor in selected.standardLabor) {
      if (labor.name.trim().isEmpty) {
        continue;
      }
      laborLines.add(
        OfferLineItem(
          id: 'line-${DateTime.now().microsecondsSinceEpoch}-$nextSortOrder',
          name: labor.name.trim(),
          description: labor.description.trim(),
          unit: labor.unit.trim().isEmpty ? 'ore' : labor.unit.trim(),
          quantity: labor.quantity > 0 ? labor.quantity : 1,
          unitPrice: labor.unitPrice,
          lineTotal:
              (labor.quantity > 0 ? labor.quantity : 1) * labor.unitPrice,
          sortOrder: nextSortOrder,
          lineType: OfferLineType.manopera,
          laborSourceMode: OfferLaborSourceMode.standard,
          laborTemplateId: labor.laborTemplateId.trim(),
        ),
      );
      nextSortOrder++;
    }

    final appendedLines = [
      ..._sortedLines,
      ...normalizedMaterials,
      ...laborLines,
    ];

    final existingClauses = [...offer.commercialClauses];
    final clauseTitles = existingClauses
        .map((item) => item.title.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final addedClauses = <OfferCommercialClause>[];
    for (final clause in selected.commercialClauses) {
      final normalizedTitle = clause.title.trim().toLowerCase();
      if (normalizedTitle.isNotEmpty &&
          clauseTitles.contains(normalizedTitle)) {
        continue;
      }
      addedClauses.add(
        OfferCommercialClause(
          id: 'clause-${DateTime.now().microsecondsSinceEpoch}-${addedClauses.length}',
          title: clause.title.trim(),
          content: clause.content.trim(),
          templateId: clause.templateId.trim(),
          category: clause.category.trim(),
          sortOrder: existingClauses.length + addedClauses.length + 1,
        ),
      );
      if (normalizedTitle.isNotEmpty) {
        clauseTitles.add(normalizedTitle);
      }
    }

    final next = _offerWithUpdatedLines(appendedLines).copyWith(
      commercialClauses: [
        ...existingClauses,
        ...addedClauses,
      ],
    );
    await persistOffer(next);
  }

  Future<void> _addStandardLaborLine() async {
    final saved = await showDialog<OfferLineItem>(
      context: context,
      builder: (context) => OfferStandardLaborLineDialog(
        initialSortOrder: _sortedLines.length + 1,
        templates: widget.laborTemplates,
      ),
    );
    if (saved == null) {
      return;
    }
    final lines = [
      ..._sortedLines,
      saved.copyWith(
        sortOrder: _sortedLines.length + 1,
        lineTotal: saved.effectiveLineTotal,
      ),
    ];
    final next = _offerWithUpdatedLines(lines);
    await persistOffer(next);
    await _handleArticolTemplateSave(saved);
  }

  Future<void> _addSimpleLaborLine() async {
    final saved = await showDialog<OfferLineItem>(
      context: context,
      builder: (context) => OfferStandardLaborLineDialog(
        initialSortOrder: _sortedLines.length + 1,
        templates: widget.laborTemplates,
        simpleMode: true,
      ),
    );
    if (saved == null) {
      return;
    }
    final lines = [
      ..._sortedLines,
      saved.copyWith(
        sortOrder: _sortedLines.length + 1,
        lineTotal: saved.effectiveLineTotal,
      ),
    ];
    final next = _offerWithUpdatedLines(lines);
    await persistOffer(next);
    await _handleArticolTemplateSave(saved);
  }

  Future<void> _editLine(OfferLineItem line) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    if (line.lineType == OfferLineType.manopera &&
        line.laborSourceMode == OfferLaborSourceMode.standard) {
      final saved = await showDialog<OfferLineItem>(
        context: context,
        builder: (context) => OfferStandardLaborLineDialog(
          existing: line,
          initialSortOrder: line.sortOrder,
          templates: widget.laborTemplates,
        ),
      );
      if (saved == null) {
        return;
      }
      final lines = _sortedLines
          .map((item) => item.id == line.id ? saved : item)
          .toList(growable: false);
      final next = _offerWithUpdatedLines(lines);
      await persistOffer(next);
      await _handleArticolTemplateSave(saved);
      return;
    }
    final saved = await showDialog<OfferLineItem>(
      context: context,
      builder: (context) => OfferLineResourceDialog(
        existing: line,
        initialSortOrder: line.sortOrder,
        personnelOptions: _laborResourcesCatalog.personnel,
        teamOptions: _laborResourcesCatalog.teams,
        vehicleOptions: _laborResourcesCatalog.vehicles,
        toolPackageOptions: _laborResourcesCatalog.toolPackages,
      ),
    );
    if (saved == null) return;
    final syncedLine = await _syncMaterialLineIfNeeded(saved);
    final lines = _sortedLines
        .map((item) => item.id == line.id ? syncedLine : item)
        .toList(growable: false);
    final next = _offerWithUpdatedLines(lines);
    await persistOffer(next);
    await _handleArticolTemplateSave(syncedLine);
  }

  Future<OfferLineItem> _syncMaterialLineIfNeeded(OfferLineItem line) async {
    if (line.lineType != OfferLineType.material) {
      return line;
    }
    final synced = await _materialsCatalogService.upsertFromOfferMaterial(
      name: line.name,
      unit: line.unit,
      price: line.unitPrice,
      notes: line.description,
    );
    return line.copyWith(materialId: synced.id);
  }

  // Salvează automat prețul articolului în baza proprie de norme.
  Future<void> _handleArticolTemplateSave(OfferLineItem line) async {
    if (line.name.trim().isEmpty) return;
    if (line.lineType == OfferLineType.text) return;
    // Doar material și manoperă standard (resursele complexe nu au preț simplu)
    final isMaterial = line.lineType == OfferLineType.material;
    final isStandardLabor = line.lineType == OfferLineType.manopera &&
        line.laborSourceMode == OfferLaborSourceMode.standard;
    if (!isMaterial && !isStandardLabor) return;

    final newMat = isMaterial ? line.unitPrice : 0.0;
    final newMan = isStandardLabor ? line.unitPrice : 0.0;

    final repo = DevizArticolTemplateRepository();
    final templates = await repo.listLocal();
    final existing = repo.findByName(line.name, templates);

    if (existing == null) {
      final template = DevizArticolTemplate(
        id: 'dat-${DateTime.now().microsecondsSinceEpoch}',
        denumire: line.name.trim(),
        um: line.unit.trim(),
        pretUnitarMat: newMat,
        pretUnitarMan: newMan,
        lastUpdated: DateTime.now(),
        folositDeCateOri: 1,
        catalogProductId: line.materialId.trim(),
      );
      await repo.upsertLocal(template);
      await OfflineSyncRuntime.instance
          .queueDevizArticolTemplateUpsert(template.toMap());
      return;
    }

    // Actualizare statistici utilizare (fără dialog dacă prețul e același)
    if (!existing.hasPriceChange(newMat, newMan)) {
      final updated = existing.copyWith(
        lastUpdated: DateTime.now(),
        folositDeCateOri: existing.folositDeCateOri + 1,
        catalogProductId: line.materialId.trim().isNotEmpty
            ? line.materialId.trim()
            : existing.catalogProductId,
      );
      await repo.upsertLocal(updated);
      await OfflineSyncRuntime.instance
          .queueDevizArticolTemplateUpsert(updated.toMap());
      return;
    }

    // Prețul s-a schimbat — întreabă utilizatorul
    if (!mounted) return;
    final lines = <String>[];
    if (isMaterial &&
        (newMat - existing.pretUnitarMat).abs() > 0.005) {
      lines.add(
          'Mat: ${existing.pretUnitarMat.toStringAsFixed(2)} → ${newMat.toStringAsFixed(2)} RON');
    }
    if (isStandardLabor &&
        (newMan - existing.pretUnitarMan).abs() > 0.005) {
      lines.add(
          'Man: ${existing.pretUnitarMan.toStringAsFixed(2)} → ${newMan.toStringAsFixed(2)} RON');
    }
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Actualizezi prețul pentru\n"${line.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prețul s-a schimbat față de ultima utilizare:'),
            const SizedBox(height: 8),
            ...lines.map((l) => Text(l,
                style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nu, păstrează vechi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da, actualizează'),
          ),
        ],
      ),
    );

    final resolvedCatalogId = line.materialId.trim().isNotEmpty
        ? line.materialId.trim()
        : existing.catalogProductId;
    final toSave = shouldUpdate == true
        ? existing.copyWith(
            um: line.unit.trim().isNotEmpty
                ? line.unit.trim()
                : existing.um,
            pretUnitarMat:
                isMaterial ? newMat : existing.pretUnitarMat,
            pretUnitarMan:
                isStandardLabor ? newMan : existing.pretUnitarMan,
            lastUpdated: DateTime.now(),
            folositDeCateOri: existing.folositDeCateOri + 1,
            catalogProductId: resolvedCatalogId,
          )
        : existing.copyWith(
            lastUpdated: DateTime.now(),
            folositDeCateOri: existing.folositDeCateOri + 1,
            catalogProductId: resolvedCatalogId,
          );
    await repo.upsertLocal(toSave);
    await OfflineSyncRuntime.instance
        .queueDevizArticolTemplateUpsert(toSave.toMap());
  }

  Future<void> _deleteLine(OfferLineItem line) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge poziție'),
        content: Text('Sigur vrei să ștergi poziția "${line.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final remaining = _sortedLines
        .where((item) => item.id != line.id)
        .toList(growable: false);
    final next = _offerWithUpdatedLines(remaining);
    await persistOffer(next);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${offer.offerNumber} - Detaliu ofertă'),
        // Bara de progres la baza AppBar-ului când se salvează sau se exportă PDF
        bottom: (saving || exportingPdf)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: exportingPdf
                      ? Colors.orange.shade400
                      : Colors.blue.shade300,
                ),
              )
            : null,
        actions: [
          PopupMenuButton<PdfVisualTemplate>(
            tooltip: 'Șablon PDF',
            enabled: !(saving || exportingPdf || converting),
            initialValue: selectedPdfTemplate,
            onSelected: (value) {
              setState(() => selectedPdfTemplate = value);
            },
            itemBuilder: (context) => PdfVisualTemplate.values
                .map(
                  (template) => PopupMenuItem<PdfVisualTemplate>(
                    value: template,
                    child: SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(template.label),
                          const SizedBox(height: 2),
                          Text(
                            template.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.style_outlined),
                  const SizedBox(width: 6),
                  Text(selectedPdfTemplate.label),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: (saving || exportingPdf || converting)
                ? null
                : () => _generatePdf(),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: saving
                ? 'Salvare în curs...'
                : exportingPdf
                    ? 'Generare PDF în curs...'
                    : 'Generează PDF',
          ),
          IconButton(
            onPressed:
                (saving || converting || isFrozen) ? null : _openEmailDialog,
            icon: const Icon(Icons.email_outlined),
            tooltip: 'Trimite oferta',
          ),
          PopupMenuButton<String>(
            tooltip: 'Mai mult',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'ai':
                  _openAiAssistant();
                case 'necesar':
                  _openMaterialNecessar();
                case 'bon_consum':
                  emiteBonConsum();
                case 'save_as':
                  _generatePdf(saveAs: true);
                case 'share':
                  _generatePdf(share: true);
                case 'lucrare':
                  _openConvertedJob();
                case 'convert':
                  _convertToJob();
                case 'duplica':
                  _duplicateOffer();
                case 'edit':
                  _editOfferHeader();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'ai',
                child: ListTile(
                  leading: Icon(Icons.auto_awesome_outlined),
                  title: Text('Asistent AI'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'necesar',
                enabled: !(saving || converting),
                child: const ListTile(
                  leading: Icon(Icons.format_list_bulleted_outlined),
                  title: Text('Necesar materiale'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'bon_consum',
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Bon consum SmartBill'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'save_as',
                enabled: !(saving || exportingPdf || converting),
                child: const ListTile(
                  leading: Icon(Icons.save_as_outlined),
                  title: Text('Salvează ca...'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (offer.complaintId.trim().isNotEmpty)
                PopupMenuItem(
                  value: 'share',
                  enabled: !(saving || exportingPdf || converting),
                  child: const ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Distribuie'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (offer.isConverted)
                PopupMenuItem(
                  value: 'lucrare',
                  enabled: !(saving || exportingPdf || converting),
                  child: const ListTile(
                    leading: Icon(Icons.open_in_new_outlined),
                    title: Text('Deschide lucrarea'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (widget.onConvertToJob != null)
                PopupMenuItem(
                  value: 'convert',
                  enabled: !(saving ||
                      exportingPdf ||
                      converting ||
                      !_canConvertToJob),
                  child: const ListTile(
                    leading: Icon(Icons.transform_outlined),
                    title: Text('Transformă în lucrare'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (widget.onDuplicateOffer != null)
                PopupMenuItem(
                  value: 'duplica',
                  enabled: !(saving || exportingPdf || converting),
                  child: const ListTile(
                    leading: Icon(Icons.content_copy_outlined),
                    title: Text('Duplică'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              if (widget.onEditOffer != null)
                PopupMenuItem(
                  value: 'edit',
                  enabled: !(saving || converting || isFrozen),
                  child: const ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editează antet'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
            ],
          ),
          Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ajutor Ofertă',
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Detaliu ofertă'),
                content: const Text(
                  '• Vizualizare și gestionare ofertă comercială\n'
                  '• Buton + (FAB): adaugă poziție nouă\n'
                  '• Meniu ⋮: editare antet, export PDF, duplicare\n'
                  '• Status: Draft → Trimis → Acceptat/Respins\n'
                  '• Convertire la Lucrare la status Acceptat\n'
                  '• Semnătură electronică pentru acceptare',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (saving || converting || isFrozen) ? null : _addLine,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă poziție'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            offer.isConverted
                                ? 'Status: Convertită'
                                : 'Status: ${offer.status.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: _statusChipColor(offer),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            offer.registryNumber.trim().isEmpty
                                ? 'Neînregistrată'
                                : 'Registratură: ${offer.registryNumber.trim()}',
                            style: TextStyle(
                              color: offer.registryNumber.trim().isEmpty
                                  ? Colors.orange.shade900
                                  : Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: offer.registryNumber.trim().isEmpty
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (!offer.isConverted) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Status rapid',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: OfferStatus.values.map((status) {
                          final selected = offer.status == status;
                          final chipColor =
                              _statusChipColor(offer.copyWith(status: status));
                          return ChoiceChip(
                            label: Text(
                              status.label,
                              style: TextStyle(
                                color: selected ? Colors.white : chipColor,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: selected,
                            selectedColor: chipColor,
                            side: BorderSide(color: chipColor, width: 1.2),
                            onSelected: (saving || isFrozen || selected)
                                ? null
                                : (_) => _changeOfferStatus(status),
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: (saving || isFrozen)
                                ? null
                                : _openEmailDialog,
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Trimite oferta'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    buildPdfTemplateSelectorCard(),
                    const SizedBox(height: 12),
                    buildSmartBillSection(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _kv('Numar oferta', offer.offerNumber),
                        _kv('Titlu', offer.title),
                        _kv('Client', _resolveClientName()),
                        // Card detalii identificare client
                        if (_findOfferClient() != null)
                          SizedBox(
                            width: double.infinity,
                            child: ClientInfoCard(
                              client: _findOfferClient()!,
                              compact: true,
                              showTitle: false,
                            ),
                          ),
                        if (offer.commercialRecipientName.trim().isNotEmpty)
                          _kv(
                            'Destinatar comercial / platitor',
                            offer.commercialRecipientName.trim(),
                          ),
                        if (offer.beneficiaryName.trim().isNotEmpty)
                          _kv('Beneficiar real', offer.beneficiaryName.trim()),
                        _kv(
                          'Departament',
                          offer.departmentName.trim().isEmpty
                              ? '-'
                              : offer.departmentName.trim(),
                        ),
                        _kv(
                          'Persoana de contact',
                          offer.contactPersonName.trim().isEmpty
                              ? '-'
                              : offer.contactPersonName.trim(),
                        ),
                        _kv(
                          'Contact email',
                          offer.contactPersonEmail.trim().isEmpty
                              ? '-'
                              : offer.contactPersonEmail.trim(),
                        ),
                        _kv(
                          'Contact telefon',
                          offer.contactPersonPhone.trim().isEmpty
                              ? '-'
                              : offer.contactPersonPhone.trim(),
                        ),
                        _kv('Lucrare', _resolveJobLabel()),
                        if (offer.complaintNumber.trim().isNotEmpty)
                          _kv('Reclamatie sursa',
                              offer.complaintNumber.trim()),
                        if (offer.appointmentId.trim().isNotEmpty)
                          _kv('Programare sursa', offer.appointmentId.trim()),
                        _kv(
                          'Acord client',
                          offer.agreementAcceptedAt == null
                              ? 'Nesemnat'
                              : formatDate(offer.agreementAcceptedAt),
                        ),
                        _kv('Status', _displayStatusLabel(offer)),
                        _kv(
                          'Registratura',
                          offer.registryNumber.trim().isEmpty
                              ? 'neinregistrat'
                              : offer.registryNumber.trim(),
                        ),
                        _kv(
                          'Data inregistrare',
                          formatDate(offer.registeredAt),
                        ),
                        _kv(
                          'Conversie in lucrare',
                          offer.convertedToJobId.trim().isEmpty
                              ? 'Nu'
                              : 'Da (${offer.convertedToJobId})',
                        ),
                        _kv(
                          'Data conversie',
                          formatDate(offer.convertedAt),
                        ),
                        _kv('Data emitere', formatDate(offer.issueDate)),
                        _kv('Valabil pana la', formatDate(offer.validUntil)),
                        _kv(
                            'Moneda',
                            OfferCurrencyConverter.normalizeCurrency(
                                offer.currency)),
                        _kv('Curs oferta', rateLabel()),
                        _kv(
                          'Observatii',
                          offer.notes.trim().isEmpty
                              ? '-'
                              : offer.notes.trim(),
                        ),
                        _kv('Afisare preturi', priceDisplayModeLabel()),
                        Row(
                          children: [
                            Expanded(
                              child: _kv(
                                'Tip document',
                                offer.tipDocument.label,
                              ),
                            ),
                            if (!isFrozen)
                              TextButton.icon(
                                onPressed:
                                    saving ? null : _changeTipDocument,
                                icon: const Icon(Icons.edit_outlined,
                                    size: 14),
                                label: const Text('Schimbă'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                        if (offer.pdfPath.trim().isNotEmpty)
                          _kv('Ultimul PDF', offer.pdfPath.trim()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (offer.complaintId.trim().isNotEmpty)
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flux comercial complet pentru reclamatie',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Oferta pornita din reclamatie foloseste acelasi motor comercial din Oferte. Poti calcula normal materiale, manopera, autoturisme, scule, parteneri si totalurile comerciale.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          Chip(
                            label: Text('Materiale'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('Manopera'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('Autoturisme'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('Scule'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('Parteneri'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('Regie / Profit / TVA'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_hasEquipmentData)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _kv('Tip echipament', _equipmentTypeLabel),
                      _kv(
                          'Brand',
                          offer.equipmentBrand.trim().isEmpty
                              ? '-'
                              : offer.equipmentBrand.trim()),
                      _kv(
                          'Model',
                          offer.equipmentModel.trim().isEmpty
                              ? '-'
                              : offer.equipmentModel.trim()),
                      _kv(
                        'Serie unitate exterioara',
                        offer.outdoorUnitSerial.trim().isEmpty
                            ? '-'
                            : offer.outdoorUnitSerial.trim(),
                      ),
                      _kv(
                        'Serii unitati interioare',
                        offer.indoorUnitSerials.trim().isEmpty
                            ? '-'
                            : offer.indoorUnitSerials.trim(),
                      ),
                      _kv(
                        'Detalii tehnice',
                        offer.equipmentDetails.trim().isEmpty
                            ? '-'
                            : offer.equipmentDetails.trim(),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acord si semnaturi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer.complaintId.trim().isEmpty
                          ? 'Semnaturile pot fi folosite pentru confirmarea documentului comercial.'
                          : 'Documentul poate functiona si ca acord pentru interventia provenita din reclamatie.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            offer.beneficiaryName.trim().isEmpty
                                ? 'Beneficiar: -'
                                : 'Beneficiar: ${offer.beneficiaryName.trim()}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            offer.commercialRecipientName.trim().isEmpty
                                ? 'Platitor comercial: ${_resolveClientName()}'
                                : 'Platitor comercial: ${offer.commercialRecipientName.trim()}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            offer.agreementAcceptedAt == null
                                ? 'Acord client: in asteptare'
                                : 'Acord client: ${formatDate(offer.agreementAcceptedAt)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final vertical = constraints.maxWidth < 900;
                        final items = [
                          SizedBox(
                            width: vertical
                                ? double.infinity
                                : (constraints.maxWidth - 12) / 2,
                            child: signatureCard(
                              title: 'Semnatura client / beneficiar',
                              raw: offer.clientSignatureBase64,
                              isClient: true,
                              subtitle: offer.agreementAcceptedAt == null
                                  ? 'Confirmă acordul pentru execuție.'
                                  : 'Acord înregistrat la ${formatDate(offer.agreementAcceptedAt)}.',
                            ),
                          ),
                          SizedBox(
                            width: vertical
                                ? double.infinity
                                : (constraints.maxWidth - 12) / 2,
                            child: signatureCard(
                              title: 'Semnatura emitent / reprezentant firma',
                              raw: offer.issuerSignatureBase64,
                              isClient: false,
                              subtitle:
                                  'Semnatura emitentului pentru documentul comercial.',
                            ),
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: items,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            buildAcceptanceFormCard(),
            if (offer.isConverted) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title:
                      const Text('Oferta convertita este blocata operational'),
                  subtitle: Text(
                    'Oferta a fost deja convertita in lucrare si nu mai poate fi modificata. Lucrare generata: ${offer.convertedToJobId.trim().isEmpty ? "-" : offer.convertedToJobId.trim()}',
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: _openConvertedJob,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('Deschide lucrarea'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              color: offer.complaintId.trim().isNotEmpty
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.38)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.complaintId.trim().isNotEmpty
                          ? 'Rezumat economic pentru reclamație'
                          : 'Rezumat economic',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Cost estimat: ${displayAmount(_estimatedInterventionCost)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            priceDisplayMode == OfferPriceDisplayMode.both
                                ? displayAmountWithLabels(
                                    _offeredPriceWithoutVat,
                                    withoutVatLabel: 'Preț ofertat fără TVA',
                                    withVatLabel: 'Preț ofertat cu TVA',
                                  )
                                : 'Preț ofertat: ${displaySingleAmount(_offeredPriceWithoutVat)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (priceDisplayMode == OfferPriceDisplayMode.both)
                          Chip(
                            label: Text(
                              'TVA (${offer.vatPercent.toStringAsFixed(2)}%): ${moneyCommercial(offer.vatValue)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            priceDisplayMode == OfferPriceDisplayMode.both
                                ? displayAmountWithLabels(
                                    _offeredPriceWithoutVat,
                                    withoutVatLabel: 'Total fără TVA',
                                    withVatLabel: 'Preț final',
                                  )
                                : '${priceDisplayMode == OfferPriceDisplayMode.withoutVat ? 'Total fără TVA' : 'Preț final'}: ${displaySingleAmount(_offeredPriceWithoutVat)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (_estimatedInterventionCost > 0 ||
                            _offeredPriceWithoutVat > 0)
                          Chip(
                            label: Text(
                              'Marja estimata: ${moneyCommercial(_estimatedCommercialMargin)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${priceDisplayExplanation()} ${offer.complaintId.trim().isNotEmpty ? 'Cost estimat = subtotal direct calculat din resursele ofertei. Preț ofertat fără TVA = subtotal comercial. Preț final = totalul către plătitorul comercial.' : 'Cost estimat = subtotal direct. Preț ofertat fără TVA = subtotal comercial. Preț final = totalul cu TVA.'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Totaluri oferta',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed:
                              (saving || isFrozen) ? null : _editVatPercent,
                          icon: const Icon(Icons.percent),
                          label: const Text('Modifica TVA'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Subtotal materiale: ${displayAmount(offer.materialSubtotal)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Manopera generala: ${displayAmount(offer.laborSubtotal)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Cost estimat / subtotal direct: ${displayAmount(offer.subtotalDirect)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Regie (${offer.regiePercent.toStringAsFixed(2)}%): ${displayAmount(offer.regieValue)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Profit (${offer.profitPercent.toStringAsFixed(2)}%): ${displayAmount(offer.profitValue)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            priceDisplayMode == OfferPriceDisplayMode.both
                                ? displayAmountWithLabels(
                                    offer.subtotalComercial,
                                    withoutVatLabel: 'Preț ofertat fără TVA',
                                    withVatLabel: 'Preț ofertat cu TVA',
                                  )
                                : 'Preț ofertat: ${displaySingleAmount(offer.subtotalComercial)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (priceDisplayMode == OfferPriceDisplayMode.both)
                          Chip(
                            label: Text(
                              'TVA (${offer.vatPercent.toStringAsFixed(2)}%): ${moneyCommercial(offer.vatValue)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            priceDisplayMode == OfferPriceDisplayMode.both
                                ? displayAmountWithLabels(
                                    offer.subtotalComercial,
                                    withoutVatLabel: 'Total fără TVA',
                                    withVatLabel: 'Preț final',
                                  )
                                : '${priceDisplayMode == OfferPriceDisplayMode.withoutVat ? 'Total fără TVA' : 'Preț final'}: ${displaySingleAmount(offer.subtotalComercial)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      priceDisplayExplanation(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_internalLaborLines.isNotEmpty ||
                _standardLaborCommercialValue > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transparenta manopera',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (_internalLaborLines.isNotEmpty) ...[
                            Chip(
                              label: Text(
                                'Cost intern estimat: ${moneyCommercial(_internalLaborEstimatedCost)}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(
                                'Pret comercial estimat: ${moneyCommercial(_estimatedCommercialLaborValue)}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(
                                'Diferenta estimata: ${moneyCommercial(_estimatedLaborMargin)}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                          if (_standardLaborCommercialValue > 0)
                            Chip(
                              label: Text(
                                'Manopera standard comerciala: ${moneyCommercial(_standardLaborCommercialValue)}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _standardLaborCommercialValue > 0
                            ? 'Zona este doar informativa. Pentru manopera standard pastram doar pretul comercial daca nu exista un cost intern clar.'
                            : 'Zona este doar informativa si nu modifica totalurile actuale ale ofertei.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_internalVehicleEstimatedCost > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transparenta autoturisme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Cost intern estimat autoturisme: ${moneyCommercial(_internalVehicleEstimatedCost)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Pret comercial estimat: ${moneyCommercial(_estimatedCommercialVehicleValue)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Diferenta estimata: ${moneyCommercial(_estimatedVehicleMargin)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _vehicleCostSourceSummaryAll.isEmpty
                            ? 'Zona este doar informativa si nu modifica totalurile actuale ale ofertei.'
                            : 'Sursa cost autoturisme: $_vehicleCostSourceSummaryAll\nZona este doar informativa si nu modifica totalurile actuale ale ofertei.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_internalToolsEstimatedCost > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transparenta scule / pachete scule',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Cost intern estimat scule: ${moneyCommercial(_internalToolsEstimatedCost)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Pret comercial estimat: ${moneyCommercial(_estimatedCommercialToolsValue)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Diferenta estimata: ${moneyCommercial(_estimatedToolsMargin)}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _toolCostSourceSummaryAll.isEmpty
                            ? 'Zona este doar informativa si nu modifica totalurile actuale ale ofertei.'
                            : 'Sursa cost scule: $_toolCostSourceSummaryAll\nZona este doar informativa si nu modifica totalurile actuale ale ofertei.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (offer.partners.isNotEmpty ||
                offer.partnerWorkers.isNotEmpty ||
                offer.partnerVehicles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Totaluri parteneri',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Personal partener: ${partnerWorkersTotal.toStringAsFixed(2)} $partnerWorkersCurrency',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Autovehicule partener: ${partnerVehiclesTotal.toStringAsFixed(2)} $partnerVehiclesCurrency',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(
                              'Total general parteneri: ${partnersTotal.toStringAsFixed(2)} $partnersCurrency',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Zona este separata de resursele interne si are rol informativ pentru componenta partenerilor din oferta.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Resurse partener',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: (saving || isFrozen) ? null : addPartner,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Adauga partener'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            buildPartnerSection(),
            const SizedBox(height: 12),
            Text(
              'Pozitii comerciale oferta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              priceDisplayExplanation(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: (saving || isFrozen) ? null : _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Adaugă poziție'),
              ),
            ),
            const SizedBox(height: 8),
            if (_commercialLines.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nu exista pozitii in aceasta oferta.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _commercialLines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sourceLine = _commercialLines[index];
                  final line = _commercialLineForDisplay(sourceLine);
                  final isAggregatedLabor =
                      sourceLine.id == '__labor_aggregate__' &&
                          sourceLine.lineType == OfferLineType.manopera;
                  return Card(
                    child: ListTile(
                      title: Text('${line.sortOrder}. ${line.name}'),
                      subtitle: Text(_commercialLineSubtitle(sourceLine, line)),
                      isThreeLine: true,
                      trailing: isAggregatedLabor
                          ? null
                          : Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'Editeaza pozitie',
                                  onPressed: (saving || isFrozen)
                                      ? null
                                      : () => _editLine(sourceLine),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Șterge poziție',
                                  onPressed: (saving || isFrozen)
                                      ? null
                                      : () => _deleteLine(sourceLine),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            if (offer.commercialClauses.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Servicii incluse / Condiții comerciale',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offer.commercialClauses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final clause = offer.commercialClauses[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        clause.title.trim().isEmpty
                            ? 'Conditie comerciala'
                            : clause.title.trim(),
                      ),
                      subtitle: Text(
                        clause.content.trim().isEmpty
                            ? '-'
                            : clause.content.trim(),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (_internalLaborLines.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Compunere interna manopera',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _internalLaborLines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final line = _internalLaborLines[index];
                  return Card(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    child: ListTile(
                      title: Text('${line.sortOrder}. ${line.name}'),
                      subtitle: Text(
                        'Ore: ${line.laborHours.toStringAsFixed(2)} • Tarif orar: ${line.laborHourlyRate.toStringAsFixed(2)}\n'
                        'Diurna: ${line.laborPerDiemDays.toStringAsFixed(2)} zile x ${line.laborPerDiemPerDay.toStringAsFixed(2)}'
                        ' • Cazare: ${line.laborLodgingNights.toStringAsFixed(2)} nopti x ${line.laborLodgingPerNight.toStringAsFixed(2)}\n'
                        'Total intern: ${line.effectiveLineTotal.toStringAsFixed(2)}\n'
                        '${_laborResourceSummary(line)}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Editeaza manopera',
                            onPressed: (saving || isFrozen)
                                ? null
                                : () => _editLine(line),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Șterge manoperă',
                            onPressed: (saving || isFrozen)
                                ? null
                                : () => _deleteLine(line),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasEquipmentData =>
      offer.equipmentType.trim().isNotEmpty ||
      offer.equipmentBrand.trim().isNotEmpty ||
      offer.equipmentModel.trim().isNotEmpty ||
      offer.outdoorUnitSerial.trim().isNotEmpty ||
      offer.indoorUnitSerials.trim().isNotEmpty ||
      offer.equipmentDetails.trim().isNotEmpty;

  String get _equipmentTypeLabel {
    return ComplaintEquipmentType.fromValue(offer.equipmentType)?.label ??
        (offer.equipmentType.trim().isEmpty
            ? '-'
            : offer.equipmentType.trim());
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

