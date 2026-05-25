import 'package:flutter/material.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/app_viewport_guard.dart';
import '../clients/client_models.dart';
import '../jobs/job_models.dart';
import '../registratura/registry_models.dart';
import 'product_catalog_service.dart';
import 'product_sales_models.dart';
import 'warranty_certificate_editor_dialog.dart';
import 'warranty_certificate_pdf_service.dart';

class WarrantyCertificatesPage extends StatefulWidget {
  const WarrantyCertificatesPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<WarrantyCertificatesPage> createState() =>
      _WarrantyCertificatesPageState();
}

class _WarrantyCertificatesPageState extends State<WarrantyCertificatesPage> {
  final ProductCatalogService _service = ProductCatalogService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<WarrantyCertificateRecord> _certificates =
      const <WarrantyCertificateRecord>[];
  List<ClientRecord> _clients = const <ClientRecord>[];
  List<JobRecord> _jobs = const <JobRecord>[];
  CompanyProfile _company = const CompanyProfile();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.listWarrantyCertificates(),
        widget.repository.listClients(),
        widget.repository.listJobs(),
        widget.repository.loadCompanyProfile(),
      ]);
      final certificates = (results[0] as List<WarrantyCertificateRecord>)
          .toList(growable: false);
      final clients = (results[1] as List<ClientRecord>).toList(growable: true)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final jobs = (results[2] as List<JobRecord>).toList(growable: true)
        ..sort((a, b) {
          final aDate = a.updatedAt;
          final bDate = b.updatedAt;
          return bDate.compareTo(aDate);
        });
      final company = results[3] as CompanyProfile;
      if (!mounted) return;
      setState(() {
        _certificates = certificates;
        _clients = clients;
        _jobs = jobs;
        _company = company;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut incarca taloanele: $error')),
      );
    }
  }

  List<WarrantyCertificateRecord> get _filteredCertificates {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _certificates;
    }
    return _certificates.where((item) {
      final client = _clientById(item.buyerClientId);
      final job = _jobById(item.jobId);
      return item.fullCertificateNumber.toLowerCase().contains(query) ||
          item.buyerName.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query) ||
          item.serialNumberOutdoor.toLowerCase().contains(query) ||
          item.serialNumberIndoor.toLowerCase().contains(query) ||
          item.sourceType.label.toLowerCase().contains(query) ||
          (client?.name.toLowerCase().contains(query) ?? false) ||
          (job?.title.toLowerCase().contains(query) ?? false) ||
          (job?.jobCode.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  ClientRecord? _clientById(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) return null;
    for (final item in _clients) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  JobRecord? _jobById(String jobId) {
    final id = jobId.trim();
    if (id.isEmpty) return null;
    for (final item in _jobs) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? path : segments.last;
  }

  WarrantyCertificateRecord _buildManualCertificate({
    WarrantyCertificateRecord? existing,
  }) {
    final now = DateTime.now();
    final selectedJob = _jobById(existing?.jobId ?? '');
    final selectedClient = _clientById(
      existing?.buyerClientId ?? selectedJob?.clientId ?? '',
    );
    final sellerName = _company.companyName.trim().isNotEmpty
        ? _company.companyName.trim()
        : _company.contactName.trim();
    final identity = existing == null ||
            (existing.certificateSeries.trim().isEmpty &&
                existing.certificateNumber.trim().isEmpty)
        ? _service.nextCertificateIdentity(
            _certificates,
            now: existing?.documentDate ?? now,
          )
        : (
            series: existing.certificateSeries,
            number: existing.certificateNumber,
          );
    final buyerAddressParts = <String>[
      selectedClient?.address.trim() ?? existing?.buyerAddress.trim() ?? '',
      selectedClient?.city.trim() ?? selectedJob?.city.trim() ?? '',
      selectedClient?.county.trim() ?? selectedJob?.county.trim() ?? '',
    ].where((item) => item.isNotEmpty).toList(growable: false);

    return WarrantyCertificateRecord(
      id: existing?.id ?? 'warranty-certificate-${now.microsecondsSinceEpoch}',
      saleId: existing?.saleId ?? '',
      sourceType: existing?.sourceType ?? WarrantyCertificateSourceType.manual,
      jobId: existing?.jobId ?? '',
      jobTitle: existing?.jobTitle ??
          (selectedJob == null
              ? ''
              : '${selectedJob.jobCode} | ${selectedJob.title}'),
      sourceEquipmentId: existing?.sourceEquipmentId ?? '',
      sourceEquipmentLabel: existing?.sourceEquipmentLabel ?? '',
      certificateSeries: identity.series.trim(),
      certificateNumber: identity.number.trim(),
      documentDate: existing?.documentDate ?? now,
      equipmentType: existing?.equipmentType ?? '',
      brand: existing?.brand ?? '',
      model: existing?.model ?? '',
      serialNumberIndoor: existing?.serialNumberIndoor ?? '',
      serialNumberOutdoor: existing?.serialNumberOutdoor ?? '',
      invoiceNumber: existing?.invoiceNumber ?? '',
      saleDate: existing?.saleDate ?? now,
      warrantyMonths: existing?.warrantyMonths ?? 24,
      warrantyStartDate: existing?.warrantyStartDate ?? now,
      warrantyEndDate: existing?.warrantyEndDate ??
          DateTime(
              now.year, now.month + (existing?.warrantyMonths ?? 24), now.day),
      sellerName: existing?.sellerName ?? sellerName,
      sellerAddress: existing?.sellerAddress ?? _company.address.trim(),
      sellerEmail: existing?.sellerEmail ?? _company.email.trim(),
      sellerPhone: existing?.sellerPhone ?? _company.phone.trim(),
      sellerTaxId: existing?.sellerTaxId ?? _company.cui.trim(),
      buyerClientId: existing?.buyerClientId ??
          selectedClient?.id ??
          selectedJob?.clientId ??
          '',
      buyerName: existing?.buyerName ?? selectedClient?.name.trim() ?? '',
      buyerAddress: existing?.buyerAddress ?? buyerAddressParts.join(', '),
      buyerPhone: existing?.buyerPhone ??
          selectedClient?.phone.trim() ??
          selectedJob?.contactPhone.trim() ??
          '',
      buyerTaxOrCnp:
          existing?.buyerTaxOrCnp ?? selectedClient?.cui.trim() ?? '',
      installerName: existing?.installerName ?? sellerName,
      installerAddress: existing?.installerAddress ?? _company.address.trim(),
      installerEmail: existing?.installerEmail ?? _company.email.trim(),
      installerPhone: existing?.installerPhone ?? _company.phone.trim(),
      installerTaxId: existing?.installerTaxId ?? _company.cui.trim(),
      installerPersons:
          existing?.installerPersons ?? _company.contactName.trim(),
      installationDate: existing?.installationDate ?? now,
      termsText:
          existing?.termsText ?? ProductCatalogService.defaultWarrantyTerms,
      registryEntryId: existing?.registryEntryId ?? '',
      documentType: existing?.documentType ?? 'warranty_certificate',
      sourceModule: existing?.sourceModule ?? 'warranty_certificates',
      generatedDocumentPath: existing?.generatedDocumentPath ?? '',
      generatedDocumentFileName: existing?.generatedDocumentFileName ?? '',
      warrantyServiceHistoryIds:
          existing?.warrantyServiceHistoryIds ?? const <String>[],
      complaintIds: existing?.complaintIds ?? const <String>[],
      warrantyServiceTickets: existing?.warrantyServiceTickets ??
          const <WarrantyServiceTicketRecord>[],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _openEditor({WarrantyCertificateRecord? existing}) async {
    final initial = _buildManualCertificate(existing: existing);
    final saved = await showDialog<WarrantyCertificateRecord>(
      context: context,
      builder: (context) => WarrantyCertificateEditorDialog(
        initial: initial,
        clients: _clients,
        jobs: _jobs,
        allowSourceTypeChange: true,
      ),
    );
    if (saved == null) return;
    await _service.saveWarrantyCertificate(
      saved.copyWith(
        createdAt: existing?.createdAt ?? saved.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    await _load();
  }

  Future<void> _quickUpdateCertificateStatus(
    WarrantyCertificateRecord certificate,
    String nextStatus,
  ) async {
    final normalized = normalizeWarrantyCertificateStatus(nextStatus);
    if (normalizeWarrantyCertificateStatus(certificate.status) == normalized) {
      return;
    }
    await _service.saveWarrantyCertificate(
      certificate.copyWith(
        status: normalized,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status certificat actualizat: ${warrantyCertificateStatusLabel(normalized)}',
        ),
      ),
    );
  }

  PopupMenuButton<String> _buildQuickStatusMenu(
    WarrantyCertificateRecord certificate,
  ) {
    final currentStatus =
        normalizeWarrantyCertificateStatus(certificate.status);
    return PopupMenuButton<String>(
      tooltip:
          'Status certificat: ${warrantyCertificateStatusLabel(currentStatus)}',
      onSelected: (value) => _quickUpdateCertificateStatus(certificate, value),
      itemBuilder: (_) => warrantyCertificateStatusOptions
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              enabled: item != currentStatus,
              child: Text(warrantyCertificateStatusLabel(item)),
            ),
          )
          .toList(growable: false),
      icon: const Icon(Icons.flag_outlined),
    );
  }

  Future<void> _generatePdf(
    WarrantyCertificateRecord certificate, {
    required bool saveAs,
  }) async {
    try {
      final filePath = await WarrantyCertificatePdfService.export(
        repository: widget.repository,
        certificate: certificate,
        saveAs: saveAs,
      );
      var persisted = certificate.copyWith(
        generatedDocumentPath: filePath,
        generatedDocumentFileName: _fileNameFromPath(filePath),
        updatedAt: DateTime.now(),
      );
      if (persisted.registryEntryId.trim().isEmpty) {
        final entry = await widget.repository.registerGeneratedDocument(
          registryType: RegistryType.iesire,
          documentCategory: 'Certificat garantie',
          documentTitle:
              'Certificat de garantie ${persisted.fullCertificateNumber.trim().isEmpty ? persisted.id : persisted.fullCertificateNumber}',
          documentNumber: persisted.fullCertificateNumber.trim().isEmpty
              ? persisted.id
              : persisted.fullCertificateNumber,
          documentDate: persisted.documentDate,
          issuerName: persisted.sellerName,
          recipientName: persisted.buyerName,
          clientId: persisted.buyerClientId,
          jobId: persisted.jobId,
          filePath: filePath,
          fileName: persisted.generatedDocumentFileName,
          notes: 'Generat din modulul Taloane garantie.',
          status: 'emis',
        );
        persisted = persisted.copyWith(registryEntryId: entry.id);
      }
      await _service.saveWarrantyCertificate(persisted);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saveAs
                ? 'Certificatul a fost salvat cu Save As.'
                : 'Certificatul PDF a fost generat.',
          ),
        ),
      );
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: filePath,
        title: 'Certificat de garanție generat',
        shareSubject:
            'Certificat garanție ${certificate.fullCertificateNumber.trim().isEmpty ? certificate.id : certificate.fullCertificateNumber}',
        shareText: 'Certificat de garanție generat din aplicație.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut genera PDF-ul: $error')),
      );
    }
  }

  Future<void> _deleteCertificate(WarrantyCertificateRecord certificate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stergi talonul?'),
        content: Text(
          'Confirmi ștergerea talonului ${certificate.fullCertificateNumber.trim().isEmpty ? certificate.id : certificate.fullCertificateNumber}?',
        ),
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
    if (confirmed != true) return;
    await _service.deleteWarrantyCertificate(certificate.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredCertificates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taloane garantie'),
        actions: [
          IconButton(
            tooltip: 'Reincarca',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Talon nou'),
      ),
      body: Padding(
        padding: AppViewportGuard.scrollablePadding(reserveForFab: true),
        child: Column(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 340,
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText:
                              'Cauta dupa numar, client, lucrare, echipament',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        _service.dataSourceLabel == 'cloud'
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _service.dataSourceLabel == 'cloud'
                            ? 'Cloud activ'
                            : 'Fallback local',
                      ),
                    ),
                    if ((_service.fallbackReason ?? '').trim().isNotEmpty)
                      Text(
                        'Motiv fallback: ${_service.fallbackReason}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      '${filtered.length} taloane',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Nu exista inca taloane de garantie. Creeaza unul nou pentru instalari istorice sau alocari manuale.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final certificate = filtered[index];
                        final client = _clientById(certificate.buyerClientId);
                        final job = _jobById(certificate.jobId);
                        final coverage =
                            _service.coverageStatusForCertificate(certificate);
                        final warrantyStart =
                            _service.effectiveWarrantyStartDate(certificate);
                        final warrantyEnd =
                            _service.effectiveWarrantyEndDate(certificate);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      certificate.fullCertificateNumber
                                              .trim()
                                              .isEmpty
                                          ? certificate.id
                                          : certificate.fullCertificateNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Chip(
                                      label: Text(certificate.sourceType.label),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Chip(
                                      label: Text(
                                        warrantyCertificateStatusLabel(
                                          certificate.status,
                                        ),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Chip(
                                      label: Text(coverage.label),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (certificate.registryEntryId
                                        .trim()
                                        .isNotEmpty)
                                      const Chip(
                                        label: Text('Inregistrat'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Client: ${client?.name.trim().isNotEmpty == true ? client!.name.trim() : (certificate.buyerName.trim().isEmpty ? '-' : certificate.buyerName.trim())}',
                                ),
                                Text(
                                  'Lucrare: ${job == null ? (certificate.jobTitle.trim().isEmpty ? '-' : certificate.jobTitle.trim()) : '${job.jobCode} | ${job.title}'}',
                                ),
                                Text(
                                  'Echipament: ${[
                                    certificate.equipmentType.trim(),
                                    certificate.brand.trim(),
                                    certificate.model.trim(),
                                  ].where((item) => item.isNotEmpty).join(' | ').isEmpty ? '-' : [
                                      certificate.equipmentType.trim(),
                                      certificate.brand.trim(),
                                      certificate.model.trim(),
                                    ].where((item) => item.isNotEmpty).join(' | ')}',
                                ),
                                Text(
                                  'Serie UE: ${certificate.serialNumberOutdoor.trim().isEmpty ? '-' : certificate.serialNumberOutdoor.trim()} | Serie UI: ${certificate.serialNumberIndoor.trim().isEmpty ? '-' : certificate.serialNumberIndoor.trim()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Document: ${_formatDate(certificate.documentDate)} | Garantie: ${_formatDate(warrantyStart)} - ${_formatDate(warrantyEnd)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (certificate.generatedDocumentPath
                                    .trim()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'PDF: ${certificate.generatedDocumentFileName.trim().isEmpty ? _fileNameFromPath(certificate.generatedDocumentPath) : certificate.generatedDocumentFileName.trim()}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                if (certificate
                                    .warrantyServiceTickets.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Taloane service completate: ${certificate.warrantyServiceTickets.length}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildQuickStatusMenu(certificate),
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _openEditor(existing: certificate),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Editeaza'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _generatePdf(
                                        certificate,
                                        saveAs: false,
                                      ),
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      label: const Text('Genereaza PDF'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _generatePdf(
                                        certificate,
                                        saveAs: true,
                                      ),
                                      icon: const Icon(Icons.save_alt_outlined),
                                      label: const Text('Save As'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _deleteCertificate(certificate),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Șterge'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
