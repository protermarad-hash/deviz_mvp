import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/document_file_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../product_catalog/product_catalog_service.dart';
import '../programari/appointment_models.dart';
import '../reclamatii/repair_report_models.dart';
import '../reclamatii/warranty_intervention_report_models.dart';
import '../agfr/agfr_models.dart';
import '../clients/client_models.dart';
import '../product_catalog/product_sales_models.dart';
import '../registratura/registry_models.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

class DocumentePage extends StatefulWidget {
  const DocumentePage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<DocumentePage> createState() => _DocumentePageState();
}

enum _DocumentSortMode {
  dataDesc,
  clientAsc,
  tipAsc,
}

class _DocumentePageState extends State<DocumentePage> {
  final ProductCatalogService _productCatalogService = ProductCatalogService();

  bool _loading = true;
  List<_DocumentHubItem> _allItems = const <_DocumentHubItem>[];
  final TextEditingController _searchController = TextEditingController();
  String _selectedClientId = '';
  String _selectedSourceModule = '';
  String _selectedDocumentType = '';
  _DocumentSortMode _sortMode = _DocumentSortMode.dataDesc;

  @override
  void initState() {
    super.initState();
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
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.listRegistryEntries(),
        widget.repository.listAppointments(),
        widget.repository.listRepairReports(),
        widget.repository.listWarrantyInterventionReports(),
        widget.repository.listAgfrReports(),
        widget.repository.listClients(),
        _productCatalogService.listWarrantyCertificates(),
      ]);

      final registryEntries = results[0] as List<RegistryEntry>;
      final appointments = results[1] as List<Appointment>;
      final repairReports = results[2] as List<RepairReportRecord>;
      final warrantyReports =
          results[3] as List<WarrantyInterventionReportRecord>;
      final agfrReports = results[4] as List<AgfrReportRecord>;
      final clients = results[5] as List<ClientRecord>;
      final warrantyCertificates = results[6] as List<WarrantyCertificateRecord>;

      final clientNameById = <String, String>{
        for (final client in clients)
          if (client.id.trim().isNotEmpty)
            client.id.trim(): client.name.trim(),
      };

      final items = <_DocumentHubItem>[
        ..._fromRegistryEntries(registryEntries, clientNameById),
        ..._fromAppointments(appointments, clientNameById),
        ..._fromRepairReports(repairReports),
        ..._fromWarrantyReports(warrantyReports, clientNameById),
        ..._fromAgfrReports(agfrReports, clientNameById),
        ..._fromWarrantyCertificates(warrantyCertificates, clientNameById),
      ];

      final deduped = <String, _DocumentHubItem>{};
      for (final item in items) {
        final key = item.filePath.trim().isNotEmpty
            ? item.filePath.trim().toLowerCase()
            : '${item.sourceModule}|${item.sourceId}|${item.title}'.toLowerCase();
        deduped[key] = item;
      }

      if (!mounted) return;
      setState(() {
        _allItems = deduped.values.toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_DocumentHubItem> _fromRegistryEntries(
    List<RegistryEntry> entries,
    Map<String, String> clientNameById,
  ) {
    return entries
        .where((entry) => entry.filePath.trim().isNotEmpty)
        .map((entry) {
          final clientId = entry.clientId.trim();
          final clientName = clientNameById[clientId] ??
              (entry.recipientName.trim().isNotEmpty
                  ? entry.recipientName.trim()
                  : clientId);
          return _DocumentHubItem(
            id: 'registry-${entry.id}',
            sourceId: entry.id,
            sourceModule: 'registratura',
            sourceLabel: 'Registratura',
            documentType: entry.documentCategory.trim().isEmpty
                ? 'document'
                : entry.documentCategory.trim(),
            documentNumber: entry.documentNumber.trim(),
            title: entry.documentTitle.trim().isEmpty
                ? entry.documentCategory.trim()
                : entry.documentTitle.trim(),
            clientId: clientId,
            clientName: clientName,
            contractingClientName: entry.recipientName.trim(),
            relatedJobId: entry.jobId.trim(),
            relatedAppointmentId: '',
            issuedAt: entry.documentDate ?? entry.registeredAt,
            filePath: entry.filePath.trim(),
            fileName: entry.fileName.trim(),
            notes: entry.notes.trim(),
          );
        })
        .toList(growable: false);
  }

  List<_DocumentHubItem> _fromAppointments(
    List<Appointment> appointments,
    Map<String, String> clientNameById,
  ) {
    final items = <_DocumentHubItem>[];
    for (final appointment in appointments) {
      for (final document in appointment.linkedDocuments) {
        final path = document.filePath.trim();
        if (path.isEmpty) continue;
        final clientId = appointment.clientId.trim();
        final clientName = clientNameById[clientId] ??
            appointment.clientName.trim();
        items.add(
          _DocumentHubItem(
            id: 'appointment-${appointment.id}-${path.hashCode}',
            sourceId: appointment.id,
            sourceModule: 'programari',
            sourceLabel: 'Programari',
            documentType: 'Document atasat programare',
            documentNumber: '',
            title: document.label.trim().isEmpty
                ? 'Document programare'
                : document.label.trim(),
            clientId: clientId,
            clientName: clientName,
            contractingClientName: appointment.contractingClientName.trim(),
            relatedJobId: appointment.jobId.trim(),
            relatedAppointmentId: appointment.id,
            issuedAt: appointment.effectiveStartDateTime,
            filePath: path,
            fileName: document.fileName.trim(),
            notes: appointment.notes.trim(),
          ),
        );
      }
    }
    return items;
  }

  List<_DocumentHubItem> _fromRepairReports(List<RepairReportRecord> reports) {
    return reports
        .where((report) => report.pdfPath.trim().isNotEmpty)
        .map(
          (report) => _DocumentHubItem(
            id: 'repair-${report.id}',
            sourceId: report.id,
            sourceModule: 'reclamatii',
            sourceLabel: 'Reclamatii',
            documentType: 'PV reparatie',
            documentNumber: report.reportNumber.trim(),
            title: report.reportNumber.trim().isEmpty
                ? 'Proces verbal reparatie'
                : 'PV reparatie ${report.reportNumber.trim()}',
            clientId: '',
            clientName: report.beneficiaryName.trim(),
            contractingClientName: report.contractorName.trim(),
            relatedJobId: report.jobId.trim(),
            relatedAppointmentId: report.appointmentId.trim(),
            issuedAt: report.interventionDate,
            filePath: report.pdfPath.trim(),
            fileName: '',
            notes: report.findings.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<_DocumentHubItem> _fromWarrantyReports(
    List<WarrantyInterventionReportRecord> reports,
    Map<String, String> clientNameById,
  ) {
    return reports
        .where((report) => report.generatedDocumentPath.trim().isNotEmpty)
        .map(
          (report) => _DocumentHubItem(
            id: 'warranty-${report.id}',
            sourceId: report.id,
            sourceModule: report.sourceModule.trim().isEmpty
                ? 'reclamatii'
                : report.sourceModule.trim(),
            sourceLabel: 'Garantie',
            documentType: report.documentType.trim().isEmpty
                ? 'PV PIF / garantie'
                : report.documentType.trim(),
            documentNumber: report.documentNumber.trim(),
            title: report.documentNumber.trim().isEmpty
                ? 'Document garantie'
                : report.documentNumber.trim(),
            clientId: report.clientId.trim(),
            clientName: report.clientName.trim().isNotEmpty
                ? report.clientName.trim()
                : (clientNameById[report.clientId.trim()] ?? ''),
            contractingClientName: report.jobTitle.trim(),
            relatedJobId: report.jobId.trim(),
            relatedAppointmentId: '',
            issuedAt: report.documentDate ?? report.createdAt,
            filePath: report.generatedDocumentPath.trim(),
            fileName: report.generatedDocumentFileName.trim(),
            notes: report.findings.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<_DocumentHubItem> _fromAgfrReports(
    List<AgfrReportRecord> reports,
    Map<String, String> clientNameById,
  ) {
    return reports
        .where((report) => report.generatedDocumentPath.trim().isNotEmpty)
        .map(
          (report) => _DocumentHubItem(
            id: 'agfr-${report.id}',
            sourceId: report.id,
            sourceModule:
                report.sourceModule.trim().isEmpty ? 'agfr' : report.sourceModule,
            sourceLabel: 'AGFR',
            documentType: report.documentType.trim().isEmpty
                ? 'PV AGFR'
                : report.documentType.trim(),
            documentNumber: report.reportNumber.trim(),
            title: report.reportNumber.trim().isEmpty
                ? 'Proces verbal AGFR'
                : report.reportNumber.trim(),
            clientId: report.clientId.trim(),
            clientName: clientNameById[report.clientId.trim()] ?? '',
            contractingClientName: '',
            relatedJobId: report.jobId.trim(),
            relatedAppointmentId: '',
            issuedAt: report.operationDate,
            filePath: report.generatedDocumentPath.trim(),
            fileName: report.generatedDocumentFileName.trim(),
            notes: report.conclusions.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<_DocumentHubItem> _fromWarrantyCertificates(
    List<WarrantyCertificateRecord> certificates,
    Map<String, String> clientNameById,
  ) {
    return certificates
        .where((item) => item.generatedDocumentPath.trim().isNotEmpty)
        .map(
          (item) => _DocumentHubItem(
            id: 'certificate-${item.id}',
            sourceId: item.id,
            sourceModule: item.sourceModule.trim().isEmpty
                ? 'garantii'
                : item.sourceModule.trim(),
            sourceLabel: 'Garantii',
            documentType: item.documentType.trim().isEmpty
                ? 'Certificat garantie'
                : item.documentType.trim(),
            documentNumber: item.fullCertificateNumber,
            title: item.fullCertificateNumber.trim().isEmpty
                ? 'Certificat garantie'
                : item.fullCertificateNumber.trim(),
            clientId: item.buyerClientId.trim(),
            clientName: item.buyerName.trim().isNotEmpty
                ? item.buyerName.trim()
                : (clientNameById[item.buyerClientId.trim()] ?? ''),
            contractingClientName: item.jobTitle.trim(),
            relatedJobId: item.jobId.trim(),
            relatedAppointmentId: '',
            issuedAt: item.documentDate ?? item.createdAt,
            filePath: item.generatedDocumentPath.trim(),
            fileName: item.generatedDocumentFileName.trim(),
            notes: item.sourceEquipmentLabel.trim(),
          ),
        )
        .toList(growable: false);
  }

  List<_DocumentHubItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    final items = _allItems.where((item) {
      if (_selectedClientId.isNotEmpty && item.clientId != _selectedClientId) {
        return false;
      }
      if (_selectedSourceModule.isNotEmpty &&
          item.sourceModule != _selectedSourceModule) {
        return false;
      }
      if (_selectedDocumentType.isNotEmpty &&
          item.documentType != _selectedDocumentType) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        item.title,
        item.documentType,
        item.documentNumber,
        item.clientName,
        item.contractingClientName,
        item.notes,
        item.fileName,
        item.filePath,
      ].join(' | ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    items.sort((a, b) {
      switch (_sortMode) {
        case _DocumentSortMode.dataDesc:
          return b.issuedAt.compareTo(a.issuedAt);
        case _DocumentSortMode.clientAsc:
          return a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
        case _DocumentSortMode.tipAsc:
          return a.documentType.toLowerCase().compareTo(b.documentType.toLowerCase());
      }
    });
    return items;
  }

  Set<MapEntry<String, String>> get _clientOptions {
    return _allItems
        .where((item) => item.clientId.trim().isNotEmpty)
        .map((item) => MapEntry<String, String>(item.clientId, item.clientLabel))
        .toSet();
  }

  Set<String> get _sourceOptions => _allItems
      .map((item) => item.sourceModule)
      .where((value) => value.trim().isNotEmpty)
      .toSet();

  Set<String> get _typeOptions => _allItems
      .map((item) => item.documentType)
      .where((value) => value.trim().isNotEmpty)
      .toSet();

  Future<void> _openFile(_DocumentHubItem item) async {
    final result = await DocumentFileService.openFile(
      item.filePath,
      fallbackFileName: item.preferredFileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _openFolder(_DocumentHubItem item) async {
    final ok = await DocumentFileService.openFolderForFile(
      item.filePath,
      fallbackFileName: item.preferredFileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Am deschis folderul documentului.'
              : 'Nu am putut deschide folderul documentului.',
        ),
      ),
    );
  }

  Future<void> _copyPath(_DocumentHubItem item) async {
    await Clipboard.setData(ClipboardData(text: item.filePath));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calea fisierului a fost copiata.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final clientOptions = _clientOptions.toList(growable: false)
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final sourceOptions = _sourceOptions.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final typeOptions = _typeOptions.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documente'),
        actions: [
          IconButton(
            tooltip: 'Reincarca',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          HelpButton(content: AppHelp.documente),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Cauta document',
                              hintText:
                                  'Client, societate, PV, PIF, AGFR, contract, numar document...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 260,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedClientId.isEmpty
                                      ? null
                                      : _selectedClientId,
                                  decoration:
                                      const InputDecoration(labelText: 'Client'),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Toti clientii'),
                                    ),
                                    ...clientOptions.map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item.key,
                                        child: Text(item.value),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _selectedClientId = value ?? '',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedSourceModule.isEmpty
                                      ? null
                                      : _selectedSourceModule,
                                  decoration: const InputDecoration(
                                    labelText: 'Modul sursa',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Toate modulele'),
                                    ),
                                    ...sourceOptions.map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _selectedSourceModule = value ?? '',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedDocumentType.isEmpty
                                      ? null
                                      : _selectedDocumentType,
                                  decoration: const InputDecoration(
                                    labelText: 'Tip document',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Toate tipurile'),
                                    ),
                                    ...typeOptions.map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _selectedDocumentType = value ?? '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Data descrescator'),
                                selected: _sortMode == _DocumentSortMode.dataDesc,
                                onSelected: (_) => setState(
                                  () => _sortMode = _DocumentSortMode.dataDesc,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Client A-Z'),
                                selected: _sortMode == _DocumentSortMode.clientAsc,
                                onSelected: (_) => setState(
                                  () => _sortMode = _DocumentSortMode.clientAsc,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Tip document A-Z'),
                                selected: _sortMode == _DocumentSortMode.tipAsc,
                                onSelected: (_) => setState(
                                  () => _sortMode = _DocumentSortMode.tipAsc,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Documente gasite: ${items.length}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nu exista documente pentru filtrele curente.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(label: Text(item.documentType)),
                                        Chip(label: Text(item.sourceLabel)),
                                        Chip(
                                          label: Text(
                                            _formatDateTime(item.issuedAt),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    if (item.documentNumber.trim().isNotEmpty)
                                      Text('Numar: ${item.documentNumber.trim()}'),
                                    Text('Client: ${item.clientLabel}'),
                                    if (item.contractingClientName.trim().isNotEmpty)
                                      Text(
                                        'Societate / context: ${item.contractingClientName.trim()}',
                                      ),
                                    if (item.relatedJobId.trim().isNotEmpty)
                                      Text('Lucrare: ${item.relatedJobId.trim()}'),
                                    if (item.relatedAppointmentId.trim().isNotEmpty)
                                      Text(
                                        'Programare: ${item.relatedAppointmentId.trim()}',
                                      ),
                                    if (item.fileName.trim().isNotEmpty)
                                      Text('Fisier: ${item.fileName.trim()}'),
                                    if (item.notes.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.notes.trim(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed: () => _openFile(item),
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text('Deschide'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _openFolder(item),
                                          icon:
                                              const Icon(Icons.folder_open_outlined),
                                          label: const Text('Folder'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _copyPath(item),
                                          icon:
                                              const Icon(Icons.content_copy_outlined),
                                          label: const Text('Copiaza calea'),
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
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

class _DocumentHubItem {
  const _DocumentHubItem({
    required this.id,
    required this.sourceId,
    required this.sourceModule,
    required this.sourceLabel,
    required this.documentType,
    required this.documentNumber,
    required this.title,
    required this.clientId,
    required this.clientName,
    required this.contractingClientName,
    required this.relatedJobId,
    required this.relatedAppointmentId,
    required this.issuedAt,
    required this.filePath,
    required this.fileName,
    required this.notes,
  });

  final String id;
  final String sourceId;
  final String sourceModule;
  final String sourceLabel;
  final String documentType;
  final String documentNumber;
  final String title;
  final String clientId;
  final String clientName;
  final String contractingClientName;
  final String relatedJobId;
  final String relatedAppointmentId;
  final DateTime issuedAt;
  final String filePath;
  final String fileName;
  final String notes;

  String get clientLabel =>
      clientName.trim().isEmpty ? 'Nealocat clientului' : clientName.trim();

  String get preferredFileName {
    final explicitName = fileName.trim();
    if (explicitName.isNotEmpty) {
      return explicitName;
    }
    final normalized = filePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last.trim();
  }
}
