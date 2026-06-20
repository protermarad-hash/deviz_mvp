import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/app_role_policy.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/app_viewport_guard.dart';
import '../ai_assistant/ai_assistant_action_catalog.dart';
import '../ai_assistant/ai_assistant_models.dart';
import '../ai_assistant/ai_assistant_service.dart';
import '../ai_assistant/ai_assistant_sheet.dart';
import '../../core/pdf_actions_helper.dart';
import '../../core/signature_service.dart';
import '../../core/widgets/signature_pad_widget.dart';
import 'firebase_job_site_documents_repository.dart';
import 'job_models.dart';
import 'job_site_document_import_service.dart';
import 'job_site_document_models.dart';
import 'job_site_document_pdf_service.dart';
import 'job_site_document_services.dart';
import 'job_site_documents_cloud_repository.dart';

class JobSiteDocumentsPage extends StatefulWidget {
  const JobSiteDocumentsPage({
    super.key,
    required this.repository,
    required this.job,
    required this.clientName,
    this.roleKey,
  });

  final AppDataRepository repository;
  final JobRecord job;
  final String clientName;
  final String? roleKey;

  @override
  State<JobSiteDocumentsPage> createState() => _JobSiteDocumentsPageState();
}

class _JobSiteDocumentsPageState extends State<JobSiteDocumentsPage> {
  bool get _isTechnician => AppRolePolicy.isTechnician(widget.roleKey);

  final JobSiteDocumentTemplateService _templateService =
      const JobSiteDocumentTemplateService();
  static const List<String> _quickStatuses = <String>[
    'draft',
    'in_review',
    'final',
  ];

  JobSiteDocumentsCloudRepository? _cloudRepository;
  List<JobSiteDocumentRecord> _documents = const <JobSiteDocumentRecord>[];
  JobSiteDocumentType? _typeFilter;
  bool _isLoading = true;
  String _dataSourceLabel = 'cache';
  String? _cloudFallbackReason;

  String get _cacheKey => 'job_site_documents_v1_${widget.job.id}';

  @override
  void initState() {
    super.initState();
    _refreshCloudRepository();
    _loadData();
  }

  void _refreshCloudRepository() {
    if (FirebaseBootstrap.isInitialized) {
      _cloudRepository ??= FirebaseJobSiteDocumentsRepository();
    } else {
      _cloudFallbackReason = FirebaseBootstrap.lastErrorMessage;
    }
  }

  Future<void> _loadData() async {
    await OfflineSyncRuntime.instance.syncPending();
    _refreshCloudRepository();
    setState(() => _isLoading = true);
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        final rows = await cloud.listDocumentsForJob(widget.job.id);
        await _writeCache(rows);
        if (!mounted) return;
        setState(() {
          _documents = rows;
          _dataSourceLabel = 'cloud';
          _cloudFallbackReason = null;
          _isLoading = false;
        });
        return;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _cloudFallbackReason = error.toString().trim();
      }
    }
    final rows = await _readCache();
    if (!mounted) return;
    setState(() {
      _documents = rows;
      _dataSourceLabel = 'cache';
      _isLoading = false;
    });
  }

  Future<List<JobSiteDocumentRecord>> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <JobSiteDocumentRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <JobSiteDocumentRecord>[];
      return decoded
          .whereType<Map>()
          .map((row) =>
              JobSiteDocumentRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (_) {
      return const <JobSiteDocumentRecord>[];
    }
  }

  Future<void> _writeCache(List<JobSiteDocumentRecord> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(rows.map((row) => row.toMap()).toList(growable: false)),
    );
  }

  List<JobSiteDocumentRecord> get _filteredDocuments {
    if (_typeFilter == null) return _documents;
    return _documents
        .where((item) => item.documentType == _typeFilter)
        .toList(growable: false);
  }

  Future<void> _createDocument() async {
    final type = await showDialog<JobSiteDocumentType>(
      context: context,
      builder: (context) => _CreateDocumentDialog(
        initialType: JobSiteDocumentType.montajExecutie,
      ),
    );
    if (type == null) return;
    var draft = await _templateService.createDraft(
      job: widget.job,
      clientName: widget.clientName,
      documentType: type,
      documentNumber: _nextDocumentNumber(type),
    );
    draft = _applyInstallationAnnexCarryForward(draft);
    final created = await _openEditor(draft, isNew: true);
    if (created == null) return;
    await _saveDocument(created);
  }

  Future<void> _configureDraftTemplates() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => _JobSiteDocumentDraftTemplateDialog(
        templateService: _templateService,
      ),
    );
    if (!mounted || updated != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Șablonul de draft a fost salvat. Documentele noi vor fi precompletate automat.',
        ),
      ),
    );
  }

  Future<JobSiteDocumentRecord?> _openEditor(
    JobSiteDocumentRecord document, {
    required bool isNew,
  }) {
    return showDialog<JobSiteDocumentRecord>(
      context: context,
      builder: (context) => _JobSiteDocumentEditorDialog(
        repository: widget.repository,
        allDocuments: _documents,
        job: widget.job,
        clientName: widget.clientName,
        document: document,
        isNew: isNew,
        pdfFoundationService: _templateService.pdfFoundationService,
      ),
    );
  }

  Future<void> _editDocument(JobSiteDocumentRecord document) async {
    final updated = await _openEditor(document, isNew: false);
    if (updated == null) return;
    await _saveDocument(updated);
  }

  Future<void> _saveDocument(JobSiteDocumentRecord document) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    final next = <JobSiteDocumentRecord>[
      for (final item in _documents)
        if (item.id != updated.id) item,
      updated,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertDocument(updated);
        _dataSourceLabel = 'cloud';
        _cloudFallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _dataSourceLabel = 'cache';
        _cloudFallbackReason = error.toString().trim();
        queuedOffline = true;
      }
    } else {
      _dataSourceLabel = 'cache';
    }

    await _writeCache(next);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueDocument(updated);
    }
    if (!mounted) return;
    setState(() => _documents = next);
  }

  Future<void> _quickUpdateDocumentStatus(
    JobSiteDocumentRecord document,
    String nextStatus,
  ) async {
    if (document.status == nextStatus) {
      return;
    }
    await _saveDocument(document.copyWith(status: nextStatus));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status PV/PIF actualizat: $nextStatus')),
    );
  }

  PopupMenuButton<String> _buildQuickStatusMenu(
    JobSiteDocumentRecord document,
  ) {
    final currentStatus = document.status.trim().isEmpty
        ? _quickStatuses.first
        : document.status.trim();
    return PopupMenuButton<String>(
      tooltip: 'Status document: $currentStatus',
      onSelected: (value) => _quickUpdateDocumentStatus(document, value),
      itemBuilder: (_) => _quickStatuses
          .map(
            (status) => PopupMenuItem<String>(
              value: status,
              enabled: status != currentStatus,
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status)),
                ],
              ),
            ),
          )
          .toList(growable: false),
      icon: const Icon(Icons.flag_outlined),
    );
  }

  Future<void> _deleteDocument(JobSiteDocumentRecord document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere document'),
        content: Text(
          'Stergi documentul ${document.documentNumber.isEmpty ? document.documentType.label : document.documentNumber}?',
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
    if (confirm != true) return;

    final next = _documents
        .where((item) => item.id != document.id)
        .toList(growable: false);
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.deleteDocument(document.id);
        _dataSourceLabel = 'cloud';
        _cloudFallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _dataSourceLabel = 'cache';
        _cloudFallbackReason = error.toString().trim();
        queuedOffline = true;
      }
    }
    await _writeCache(next);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueDocumentDelete(document.id);
    }
    if (!mounted) return;
    setState(() => _documents = next);
  }

  String _nextDocumentNumber(JobSiteDocumentType type) {
    final sameTypeCount =
        _documents.where((item) => item.documentType == type).length;
    final seq = sameTypeCount + 1;
    return '${type.shortCode}-${seq.toString().padLeft(4, '0')}';
  }

  JobSiteDocumentRecord _applyInstallationAnnexCarryForward(
    JobSiteDocumentRecord draft,
  ) {
    if (draft.documentType == JobSiteDocumentType.montajExecutie) {
      return draft;
    }
    final source = _latestInstallationDocument();
    if (source == null) {
      return draft;
    }
    final carriedItems = _flattenAnnexItems(source.annexes);
    if (carriedItems.isEmpty) {
      return draft;
    }
    final nextAnnexes = draft.annexes.isEmpty
        ? <JobSiteDocumentAnnex>[
            JobSiteDocumentAnnex(
              key: 'imported_resources',
              title: 'Resurse preluate din ultimul PV de montaj',
              description: 'Preluare automată din ${source.documentNumber}.',
              summary:
                  'Au fost preluate ${carriedItems.length} poziții din ${source.documentNumber}.',
              items: carriedItems,
            ),
          ]
        : draft.annexes
            .map(
              (annex) => JobSiteDocumentAnnex(
                key: annex.key,
                title: annex.title,
                description: annex.description.trim().isEmpty
                    ? 'Preluare automată din ${source.documentNumber}.'
                    : annex.description,
                summary:
                    'Au fost preluate ${carriedItems.length} poziții din ${source.documentNumber}.',
                items: _filterItemsForAnnex(annex, carriedItems),
              ),
            )
            .toList(growable: false);
    return draft.copyWith(annexes: nextAnnexes);
  }

  JobSiteDocumentRecord? _latestInstallationDocument() {
    final candidates = _documents
        .where(
          (item) =>
              item.documentType == JobSiteDocumentType.montajExecutie &&
              item.annexes.any((annex) => annex.items.isNotEmpty),
        )
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  List<JobSiteDocumentAnnexItem> _flattenAnnexItems(
    List<JobSiteDocumentAnnex> annexes,
  ) {
    final seen = <String>{};
    final items = <JobSiteDocumentAnnexItem>[];
    for (final annex in annexes) {
      for (final item in annex.items) {
        final key =
            '${item.label.toLowerCase()}|${item.quantity}|${item.unit.toLowerCase()}|${item.details.toLowerCase()}';
        if (!seen.add(key)) {
          continue;
        }
        items.add(
          JobSiteDocumentAnnexItem(
            id: item.id,
            label: item.label,
            quantity: item.quantity,
            unit: item.unit,
            details: item.details,
            source: item.source,
          ),
        );
      }
    }
    return items;
  }

  List<JobSiteDocumentAnnexItem> _filterItemsForAnnex(
    JobSiteDocumentAnnex annex,
    List<JobSiteDocumentAnnexItem> items,
  ) {
    final lower = '${annex.key} ${annex.title}'.toLowerCase();
    if (lower.contains('echip')) {
      final equipmentItems =
          items.where(_looksLikeEquipment).toList(growable: false);
      if (equipmentItems.isNotEmpty) {
        return equipmentItems;
      }
    }
    if (lower.contains('material')) {
      final materialItems = items
          .where((item) => !_looksLikeEquipment(item))
          .toList(growable: false);
      if (materialItems.isNotEmpty) {
        return materialItems;
      }
    }
    return items;
  }

  bool _looksLikeEquipment(JobSiteDocumentAnnexItem item) {
    final lower = '${item.label} ${item.details}'.toLowerCase();
    const markers = <String>[
      'unitate',
      'echip',
      'recuperator',
      'ventilator',
      'vrf',
      'split',
      'chiller',
      'controller',
      'automatizare',
      'centrala',
      'pompa',
      'tablou',
    ];
    return markers.any(lower.contains);
  }

  // ── Semnătură electronică client + generare PDF ──────────────────────────

  Future<void> _signAndGeneratePdf(JobSiteDocumentRecord document) async {
    final signBytes = await showSignatureDialog(
      context,
      title: 'Semnătură client — ${document.documentType.label}',
      label: 'Clientul semnează mai jos',
    );
    if (signBytes == null || !mounted) return;

    final b64 = await SignatureService.instance.saveSignature(
      pngBytes: signBytes,
      localKey: 'pv_${document.id}',
      jobId: document.jobId,
      documentType: document.documentType.storageValue,
    );

    final signed = document.copyWith(
      clientSignatureBase64: b64,
      updatedAt: DateTime.now(),
    );

    await _saveDocument(signed);
    if (!mounted) return;
    await _generatePdf(signed);
  }

  Future<void> _generatePdf(JobSiteDocumentRecord document) async {
    if (!mounted) return;
    try {
      final path = await JobSiteDocumentPdfService.export(
        repository: widget.repository,
        document: document,
        liniiPlanificate: widget.job.liniiPlanificate.isNotEmpty
            ? widget.job.liniiPlanificate
            : null,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: document.documentTitle.isEmpty
            ? document.documentType.label
            : document.documentTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare generare PDF: $e')),
      );
    }
  }

  Future<void> _viewDocument(JobSiteDocumentRecord document) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.documentType.label),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _readOnlyLine('Număr document', document.documentNumber),
                _readOnlyLine('Titlu document', document.documentTitle),
                _readOnlyLine('Subtitlu document', document.documentSubtitle),
                _readOnlyLine(
                    'Data document', _formatDate(document.documentDate)),
                _readOnlyLine('Proiect', document.projectName),
                _readOnlyLine('Locatie', document.location),
                _readOnlyLine(
                  'Reprezentant beneficiar',
                  document.beneficiaryRepresentative,
                ),
                _readOnlyLine(
                  'Reprezentant executant',
                  document.executorRepresentative,
                ),
                _readOnlyLine('Status document', document.status),
                _readOnlyLine('Status functional', document.functionalStatus),
                _readOnlyLine(
                  'Tip Registratura',
                  document.documentTypeForRegistry,
                ),
                _readOnlyLine('Source module', document.sourceModule),
                _readOnlyLine('Concluzii', document.conclusions),
                _readOnlyLine('Observatii', document.observations),
                _readOnlyLine('Probe / masuratori', document.probesSummary),
                _readOnlyLine(
                  'Etapa urmatoare',
                  document.preparedForNextStep,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sectiuni tehnice fixe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...document.checkItems.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.label),
                    subtitle: Text(item.sectionKey),
                    trailing: Icon(
                      item.value
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Masuratori si probe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...document.measurements.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.label),
                    subtitle: Text(item.sectionKey),
                    trailing: Text(
                      item.value.trim().isEmpty
                          ? '- ${item.unit}'
                          : '${item.value} ${item.unit}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Anexe generate automat',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...document.annexes.map(
                  (annex) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            annex.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (annex.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(annex.summary),
                          ],
                          const SizedBox(height: 8),
                          Text('Pozitii: ${annex.items.length}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Închide'),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyLine(String label, String value) {
    final display = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(display),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredDocuments;
    return Scaffold(
      appBar: AppBar(
        title: Text('PV lucrari - ${widget.job.jobCode}'),
        actions: [
          IconButton(
            tooltip: 'Șabloane draft',
            onPressed: _configureDraftTemplates,
            icon: const Icon(Icons.text_snippet_outlined),
          ),
          IconButton(
            tooltip: 'Reincarca',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDocument,
        icon: const Icon(Icons.add),
        label: const Text('Document nou'),
      ),
      body: Padding(
        padding: AppViewportGuard.scrollablePadding(reserveForFab: true),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<JobSiteDocumentType?>(
                    initialValue: _typeFilter,
                    decoration:
                        const InputDecoration(labelText: 'Filtru tip document'),
                    items: [
                      const DropdownMenuItem<JobSiteDocumentType?>(
                        value: null,
                        child: Text('Toate documentele'),
                      ),
                      ...JobSiteDocumentType.values.map(
                        (type) => DropdownMenuItem<JobSiteDocumentType?>(
                          value: type,
                          child: Text(type.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _typeFilter = value),
                  ),
                ),
                Chip(label: Text('Sursa date: $_dataSourceLabel')),
                if ((_cloudFallbackReason ?? '').trim().isNotEmpty)
                  SizedBox(
                    width: 420,
                    child: Text(
                      'Fallback local: ${_cloudFallbackReason!}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? const Center(
                          child: Text(
                            'Nu exista documente PV / PIF pentru aceasta lucrare.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = rows[index];
                            final registryState =
                                item.registryEntryId.trim().isEmpty
                                    ? 'neinregistrat'
                                    : item.registryEntryId.trim();
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                title: Text(
                                  item.documentTitle.trim().isEmpty
                                      ? '${item.documentType.label} - ${item.documentNumber}'
                                      : item.documentTitle,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Data: ${_formatDate(item.documentDate)}'
                                    '\nSubtitlu: ${item.documentSubtitle.isEmpty ? '-' : item.documentSubtitle}'
                                    '\nProiect: ${item.projectName.isEmpty ? '-' : item.projectName}'
                                    '\nStatus: ${item.status} | Functional: ${item.functionalStatus.isEmpty ? '-' : item.functionalStatus}'
                                    '\nAnexe: ${item.annexes.length} | Registratura: $registryState',
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Buton rapid schimbare status
                                    _buildQuickStatusMenu(item),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Acțiuni',
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'open',
                                          child: ListTile(
                                            leading: Icon(Icons.open_in_new),
                                            title: Text('Deschide'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'sign_pdf',
                                          child: ListTile(
                                            leading: const Icon(Icons.draw_outlined),
                                            title: const Text('Semnează & Generează PDF'),
                                            subtitle: item.clientSignatureBase64.trim().isNotEmpty
                                                ? const Text('Semnătură client existentă', style: TextStyle(fontSize: 11, color: Colors.green))
                                                : null,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'pdf',
                                          child: ListTile(
                                            leading: Icon(Icons.picture_as_pdf_outlined),
                                            title: Text('Generează PDF'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        if (!_isTechnician) ...[
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                              leading:
                                                  Icon(Icons.edit_outlined),
                                              title: Text('Editează'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              leading:
                                                  Icon(Icons.delete_outline),
                                              title: Text('Șterge'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ],
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'open':
                                            _viewDocument(item);
                                          case 'sign_pdf':
                                            _signAndGeneratePdf(item);
                                          case 'pdf':
                                            _generatePdf(item);
                                          case 'edit':
                                            _editDocument(item);
                                          case 'delete':
                                            _deleteDocument(item);
                                        }
                                      },
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

class _JobSiteDocumentDraftTemplateDialog extends StatefulWidget {
  const _JobSiteDocumentDraftTemplateDialog({
    required this.templateService,
  });

  final JobSiteDocumentTemplateService templateService;

  @override
  State<_JobSiteDocumentDraftTemplateDialog> createState() =>
      _JobSiteDocumentDraftTemplateDialogState();
}

class _JobSiteDocumentDraftTemplateDialogState
    extends State<_JobSiteDocumentDraftTemplateDialog> {
  late JobSiteDocumentType _selectedType;
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _observationsController;
  late final TextEditingController _conclusionsController;
  late final TextEditingController _probesSummaryController;
  late final TextEditingController _functionalStatusController;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = JobSiteDocumentType.montajExecutie;
    _titleController = TextEditingController();
    _subtitleController = TextEditingController();
    _observationsController = TextEditingController();
    _conclusionsController = TextEditingController();
    _probesSummaryController = TextEditingController();
    _functionalStatusController = TextEditingController();
    _loadTemplate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _observationsController.dispose();
    _conclusionsController.dispose();
    _probesSummaryController.dispose();
    _functionalStatusController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() => _loading = true);
    final template =
        await widget.templateService.loadDraftTemplate(_selectedType);
    _titleController.text = template.documentTitle;
    _subtitleController.text = template.documentSubtitle;
    _observationsController.text = template.observations;
    _conclusionsController.text = template.conclusions;
    _probesSummaryController.text = template.probesSummary;
    _functionalStatusController.text = template.functionalStatus;
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _saveTemplate() async {
    setState(() => _saving = true);
    await widget.templateService.saveDraftTemplate(
      JobSiteDocumentDraftTemplate(
        documentType: _selectedType,
        documentTitle: _titleController.text.trim(),
        documentSubtitle: _subtitleController.text.trim(),
        observations: _observationsController.text.trim(),
        conclusions: _conclusionsController.text.trim(),
        probesSummary: _probesSummaryController.text.trim(),
        functionalStatus: _functionalStatusController.text.trim(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _resetTemplate() async {
    await widget.templateService.resetDraftTemplate(_selectedType);
    await _loadTemplate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Șablonul a fost resetat la valorile implicite.'),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? helperText,
  }) {
    return TextFormField(
      textCapitalization: TextCapitalization.sentences,
      controller: controller,
      minLines: maxLines > 1 ? maxLines : null,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Șabloane draft PV / PIF'),
      content: SizedBox(
        width: 680,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<JobSiteDocumentType>(
                      initialValue: _selectedType,
                      decoration:
                          const InputDecoration(labelText: 'Tip document'),
                      items: JobSiteDocumentType.values
                          .map(
                            (type) => DropdownMenuItem<JobSiteDocumentType>(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) async {
                        if (value == null || value == _selectedType) return;
                        setState(() => _selectedType = value);
                        await _loadTemplate();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Poți folosi placeholder-ele {project}, {jobCode}, {location}, {client}, {team}, {type}. Dacă lași un câmp gol, aplicația păstrează textul implicit actual.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Titlu document',
                      _titleController,
                      helperText: 'Ex.: Document PIF - {project}',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Subtitlu',
                      _subtitleController,
                      helperText: 'Ex.: {type} | {location}',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Observații',
                      _observationsController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Concluzii',
                      _conclusionsController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Rezumat probe',
                      _probesSummaryController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Status funcțional implicit',
                      _functionalStatusController,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Închide'),
        ),
        TextButton(
          onPressed: _saving ? null : _resetTemplate,
          child: const Text('Resetează'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveTemplate,
          child: Text(_saving ? 'Se salvează...' : 'Salvează'),
        ),
      ],
    );
  }
}

class _CreateDocumentDialog extends StatefulWidget {
  const _CreateDocumentDialog({
    required this.initialType,
  });

  final JobSiteDocumentType initialType;

  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  late JobSiteDocumentType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tip document PV'),
      content: SizedBox(
        width: 420,
        child: DropdownButtonFormField<JobSiteDocumentType>(
          initialValue: _selectedType,
          decoration: const InputDecoration(labelText: 'Tip document'),
          items: JobSiteDocumentType.values
              .map(
                (type) => DropdownMenuItem<JobSiteDocumentType>(
                  value: type,
                  child: Text(type.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedType = value);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedType),
          child: const Text('Continua'),
        ),
      ],
    );
  }
}

class _JobSiteDocumentEditorDialog extends StatefulWidget {
  const _JobSiteDocumentEditorDialog({
    required this.repository,
    required this.allDocuments,
    required this.job,
    required this.clientName,
    required this.document,
    required this.isNew,
    required this.pdfFoundationService,
  });

  final AppDataRepository repository;
  final List<JobSiteDocumentRecord> allDocuments;
  final JobRecord job;
  final String clientName;
  final JobSiteDocumentRecord document;
  final bool isNew;
  final JobSiteDocumentPdfFoundationService pdfFoundationService;

  @override
  State<_JobSiteDocumentEditorDialog> createState() =>
      _JobSiteDocumentEditorDialogState();
}

class _JobSiteDocumentEditorDialogState
    extends State<_JobSiteDocumentEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final AiAssistantService _aiAssistantService;
  late TextEditingController _documentNumberController;
  late TextEditingController _documentTitleController;
  late TextEditingController _documentSubtitleController;
  late TextEditingController _beneficiaryRepresentativeController;
  late TextEditingController _executorRepresentativeController;
  late TextEditingController _projectNameController;
  late TextEditingController _locationController;
  late TextEditingController _observationsController;
  late TextEditingController _conclusionsController;
  late TextEditingController _functionalStatusController;
  late TextEditingController _probesSummaryController;
  late TextEditingController _preparedForNextStepController;
  late TextEditingController _generatedPathController;
  late TextEditingController _generatedFileNameController;
  late TextEditingController _registryEntryController;

  late DateTime _documentDate;
  late DateTime? _remediationDeadline;
  late String _status;
  late bool _trainingProvided;
  late List<JobSiteDocumentAnnex> _annexes;
  bool _isImporting = false;
  bool _isRunningAi = false;

  @override
  void initState() {
    super.initState();
    _aiAssistantService = AiAssistantService(repository: widget.repository);
    final document = widget.document;
    _documentTitleController =
        TextEditingController(text: document.documentTitle);
    _documentSubtitleController =
        TextEditingController(text: document.documentSubtitle);
    _documentNumberController =
        TextEditingController(text: document.documentNumber);
    _beneficiaryRepresentativeController =
        TextEditingController(text: document.beneficiaryRepresentative);
    _executorRepresentativeController =
        TextEditingController(text: document.executorRepresentative);
    _projectNameController = TextEditingController(text: document.projectName);
    _locationController = TextEditingController(text: document.location);
    _observationsController =
        TextEditingController(text: document.observations);
    _conclusionsController = TextEditingController(text: document.conclusions);
    _functionalStatusController =
        TextEditingController(text: document.functionalStatus);
    _probesSummaryController =
        TextEditingController(text: document.probesSummary);
    _preparedForNextStepController =
        TextEditingController(text: document.preparedForNextStep);
    _generatedPathController =
        TextEditingController(text: document.generatedDocumentPath);
    _generatedFileNameController =
        TextEditingController(text: document.generatedDocumentFileName);
    _registryEntryController =
        TextEditingController(text: document.registryEntryId);
    _documentDate = document.documentDate;
    _remediationDeadline = document.remediationDeadline;
    _status = document.status;
    _trainingProvided = document.trainingProvided;
    _annexes = document.annexes.map(_cloneAnnex).toList(growable: true);
  }

  @override
  void dispose() {
    _documentTitleController.dispose();
    _documentSubtitleController.dispose();
    _documentNumberController.dispose();
    _beneficiaryRepresentativeController.dispose();
    _executorRepresentativeController.dispose();
    _projectNameController.dispose();
    _locationController.dispose();
    _observationsController.dispose();
    _conclusionsController.dispose();
    _functionalStatusController.dispose();
    _probesSummaryController.dispose();
    _preparedForNextStepController.dispose();
    _generatedPathController.dispose();
    _generatedFileNameController.dispose();
    _registryEntryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  Future<void> _pickOptionalDate() async {
    final initial = _remediationDeadline ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
    );
    if (picked == null) return;
    setState(() => _remediationDeadline = picked);
  }

  JobSiteDocumentAnnex _cloneAnnex(JobSiteDocumentAnnex annex) {
    return JobSiteDocumentAnnex(
      key: annex.key,
      title: annex.title,
      description: annex.description,
      summary: annex.summary,
      items: annex.items
          .map(
            (item) => JobSiteDocumentAnnexItem(
              id: item.id,
              label: item.label,
              quantity: item.quantity,
              unit: item.unit,
              details: item.details,
              source: item.source,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _importAnnexesFromFile() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'txt',
          'csv',
          'tsv',
          'json',
          'md',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'pdf',
        ],
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final picked = result.files.single;
      final fileName =
          picked.name.trim().isEmpty ? 'import' : picked.name.trim();
      var bytes = picked.bytes;
      if (bytes == null && (picked.path ?? '').trim().isNotEmpty) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) {
        throw Exception('Fișierul selectat nu a putut fi citit.');
      }
      final imported = await JobSiteDocumentImportService.importFile(
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (imported.items.isEmpty) {
        final warning = imported.warnings.isEmpty
            ? 'Nu am găsit poziții utile în fișier.'
            : imported.warnings.join(' ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning)),
        );
        return;
      }
      setState(() {
        _annexes = _applyImportedItemsToAnnexes(imported.items, fileName);
      });
      final warningText =
          imported.warnings.isEmpty ? '' : ' ${imported.warnings.join(' ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Au fost importate ${imported.items.length} poziții din $fileName.$warningText',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import eșuat: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _prefillAnnexesFromLatestInstallation() async {
    final source = _latestInstallationDocument();
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nu există încă un PV de montaj cu anexe pentru această lucrare.',
          ),
        ),
      );
      return;
    }
    final items = _flattenAnnexItems(source.annexes);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ultimul PV de montaj nu conține poziții reutilizabile.'),
        ),
      );
      return;
    }
    setState(() {
      _annexes = _applyImportedItemsToAnnexes(items, source.documentNumber);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Au fost preluate ${items.length} poziții din ${source.documentNumber}.',
        ),
      ),
    );
  }

  JobSiteDocumentRecord? _latestInstallationDocument() {
    final candidates = widget.allDocuments
        .where(
          (item) =>
              item.documentType == JobSiteDocumentType.montajExecutie &&
              item.annexes.any((annex) => annex.items.isNotEmpty),
        )
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  List<JobSiteDocumentAnnexItem> _flattenAnnexItems(
    List<JobSiteDocumentAnnex> annexes,
  ) {
    final seen = <String>{};
    final items = <JobSiteDocumentAnnexItem>[];
    for (final annex in annexes) {
      for (final item in annex.items) {
        final key =
            '${item.label.toLowerCase()}|${item.quantity}|${item.unit.toLowerCase()}|${item.details.toLowerCase()}';
        if (!seen.add(key)) {
          continue;
        }
        items.add(
          JobSiteDocumentAnnexItem(
            id: item.id,
            label: item.label,
            quantity: item.quantity,
            unit: item.unit,
            details: item.details,
            source: item.source,
          ),
        );
      }
    }
    return items;
  }

  List<JobSiteDocumentAnnex> _applyImportedItemsToAnnexes(
    List<JobSiteDocumentAnnexItem> items,
    String sourceLabel,
  ) {
    if (_annexes.isEmpty) {
      return <JobSiteDocumentAnnex>[
        JobSiteDocumentAnnex(
          key: 'imported_resources',
          title: 'Resurse importate',
          description: 'Import din $sourceLabel.',
          summary: 'Import automat: ${items.length} poziții.',
          items: items,
        ),
      ];
    }
    return _annexes
        .map(
          (annex) => JobSiteDocumentAnnex(
            key: annex.key,
            title: annex.title,
            description: annex.description.trim().isEmpty
                ? 'Import din $sourceLabel.'
                : annex.description,
            summary: 'Import automat: ${items.length} poziții.',
            items: _filterItemsForAnnex(annex, items, fallbackToAll: true),
          ),
        )
        .toList(growable: false);
  }

  List<JobSiteDocumentAnnexItem> _filterItemsForAnnex(
    JobSiteDocumentAnnex annex,
    List<JobSiteDocumentAnnexItem> items, {
    bool fallbackToAll = false,
  }) {
    final lower = '${annex.key} ${annex.title}'.toLowerCase();
    if (lower.contains('echip')) {
      final equipmentItems =
          items.where(_looksLikeEquipment).toList(growable: false);
      if (equipmentItems.isNotEmpty || !fallbackToAll) {
        return equipmentItems;
      }
    }
    if (lower.contains('material')) {
      final materialItems = items
          .where((item) => !_looksLikeEquipment(item))
          .toList(growable: false);
      if (materialItems.isNotEmpty || !fallbackToAll) {
        return materialItems;
      }
    }
    return items;
  }

  bool _looksLikeEquipment(JobSiteDocumentAnnexItem item) {
    final lower = '${item.label} ${item.details}'.toLowerCase();
    const markers = <String>[
      'unitate',
      'echip',
      'recuperator',
      'ventilator',
      'vrf',
      'split',
      'chiller',
      'controller',
      'automatizare',
      'centrala',
      'pompa',
      'tablou',
    ];
    return markers.any(lower.contains);
  }

  Future<void> _openAiAssistant() async {
    setState(() => _isRunningAi = true);
    try {
      final currentUser = await widget.repository.loadCurrentUser();
      if (!mounted) return;
      await AiAssistantSheet.show(
        context: context,
        title: 'Asistent AI PV / PIF',
        service: _aiAssistantService,
        runtimeContext: AiAssistantRuntimeContext(
          contextType: AiAssistantContextType.jobs,
          module: 'lucrari',
          entityId: widget.document.id,
          entityLabel: _documentNumberController.text.trim().isEmpty
              ? widget.document.documentType.label
              : _documentNumberController.text.trim(),
          userId: (currentUser?.email ?? '').trim().isNotEmpty
              ? currentUser!.email.trim()
              : (currentUser?.id ?? ''),
          contextLabel:
              '${widget.document.documentType.label} - ${widget.job.jobCode}',
          primaryData: <String, dynamic>{
            ...widget.document.toMap(),
            'document_number_live': _documentNumberController.text.trim(),
            'document_title_live': _documentTitleController.text.trim(),
            'document_subtitle_live': _documentSubtitleController.text.trim(),
            'observations_live': _observationsController.text.trim(),
            'conclusions_live': _conclusionsController.text.trim(),
            'probes_summary_live': _probesSummaryController.text.trim(),
            'prepared_for_next_step_live':
                _preparedForNextStepController.text.trim(),
            'functional_status_live': _functionalStatusController.text.trim(),
          },
          relatedData: <String, dynamic>{
            'job': widget.job.toMap(),
            'client': <String, dynamic>{'name': widget.clientName},
            'document': widget.document
                .copyWith(
                  documentNumber: _documentNumberController.text.trim(),
                  documentTitle: _documentTitleController.text.trim(),
                  documentSubtitle: _documentSubtitleController.text.trim(),
                  observations: _observationsController.text.trim(),
                  conclusions: _conclusionsController.text.trim(),
                  probesSummary: _probesSummaryController.text.trim(),
                  preparedForNextStep:
                      _preparedForNextStepController.text.trim(),
                  functionalStatus: _functionalStatusController.text.trim(),
                  annexes: _annexes,
                )
                .toMap(),
            'annexes':
                _annexes.map((annex) => annex.toMap()).toList(growable: false),
            'annex_items': _flattenAnnexItems(_annexes)
                .map((item) => item.toMap())
                .toList(growable: false),
          },
          insertionTargets: const <AiAssistantInsertionTarget>[
            AiAssistantInsertionTarget(
              key: 'job_site_full_body',
              label: 'Corp complet PV / PIF',
              description:
                  'Distribuie automat draftul în titlu, subtitlu, observații, concluzii, probe și etapa următoare.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_title',
              label: 'Titlu document',
              description: 'Înlocuiește titlul documentului.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_subtitle',
              label: 'Subtitlu document',
              description: 'Înlocuiește subtitlul documentului.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_observations',
              label: 'Observații tehnice',
              description: 'Înlocuiește observațiile tehnice.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_conclusions',
              label: 'Concluzii',
              description: 'Înlocuiește concluziile documentului.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_probes',
              label: 'Probe / măsurători',
              description: 'Înlocuiește sinteza probelor și măsurătorilor.',
              insertMode: AiAssistantInsertMode.replace,
            ),
            AiAssistantInsertionTarget(
              key: 'job_site_next_step',
              label: 'Etapa următoare',
              description: 'Înlocuiește etapa următoare recomandată.',
              insertMode: AiAssistantInsertMode.replace,
            ),
          ],
        ),
        actions: AiAssistantActionCatalog.actionsFor(
          AiAssistantContextType.jobs,
        ),
        onInsertDraft: _applyAiDraft,
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningAi = false);
      }
    }
  }

  Future<bool> _applyAiDraft(String targetKey, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    switch (targetKey) {
      case 'job_site_full_body':
        _applyFullBodyDraft(trimmed);
        break;
      case 'job_site_title':
        _documentTitleController.text = trimmed;
        break;
      case 'job_site_subtitle':
        _documentSubtitleController.text = trimmed;
        break;
      case 'job_site_observations':
        _observationsController.text = trimmed;
        break;
      case 'job_site_conclusions':
        _conclusionsController.text = trimmed;
        break;
      case 'job_site_probes':
        _probesSummaryController.text = trimmed;
        break;
      case 'job_site_next_step':
        _preparedForNextStepController.text = trimmed;
        break;
      default:
        return false;
    }
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft AI inserat în document.')),
    );
    return true;
  }

  void _applyFullBodyDraft(String content) {
    final sections = _parseAiSections(content);
    final title = sections['titlu'];
    final subtitle = sections['subtitlu'];
    final observations = sections['observații'] ?? sections['observatii'];
    final conclusions = sections['concluzii'];
    final probes = sections['probe'];
    final nextStep = sections['etapa următoare'] ?? sections['etapa urmatoare'];

    if ((title ?? '').trim().isNotEmpty) {
      _documentTitleController.text = title!.trim();
    }
    if ((subtitle ?? '').trim().isNotEmpty) {
      _documentSubtitleController.text = subtitle!.trim();
    }
    if ((observations ?? '').trim().isNotEmpty) {
      _observationsController.text = observations!.trim();
    }
    if ((conclusions ?? '').trim().isNotEmpty) {
      _conclusionsController.text = conclusions!.trim();
    }
    if ((probes ?? '').trim().isNotEmpty) {
      _probesSummaryController.text = probes!.trim();
    }
    if ((nextStep ?? '').trim().isNotEmpty) {
      _preparedForNextStepController.text = nextStep!.trim();
    }

    if (sections.isEmpty) {
      _conclusionsController.text = content.trim();
    }
  }

  Map<String, String> _parseAiSections(String content) {
    final matches = RegExp(
      r'^(Titlu|Subtitlu|Observații|Observatii|Concluzii|Probe|Etapa următoare|Etapa urmatoare)\s*:\s*',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(content).toList(growable: false);
    if (matches.isEmpty) {
      return const <String, String>{};
    }

    final sections = <String, String>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final rawKey = (match.group(1) ?? '').trim().toLowerCase();
      final start = match.end;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : content.length;
      final value = content.substring(start, end).trim();
      if (value.isNotEmpty) {
        sections[rawKey] = value;
      }
    }
    return sections;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.document.copyWith(
      documentTitle: _documentTitleController.text.trim(),
      documentSubtitle: _documentSubtitleController.text.trim(),
      documentNumber: _documentNumberController.text.trim(),
      documentDate: _documentDate,
      beneficiaryRepresentative:
          _beneficiaryRepresentativeController.text.trim(),
      executorRepresentative: _executorRepresentativeController.text.trim(),
      projectName: _projectNameController.text.trim(),
      location: _locationController.text.trim(),
      observations: _observationsController.text.trim(),
      conclusions: _conclusionsController.text.trim(),
      registryEntryId: _registryEntryController.text.trim(),
      generatedDocumentPath: _generatedPathController.text.trim(),
      generatedDocumentFileName: _generatedFileNameController.text.trim(),
      functionalStatus: _functionalStatusController.text.trim(),
      probesSummary: _probesSummaryController.text.trim(),
      remediationDeadline: _remediationDeadline,
      trainingProvided: _trainingProvided,
      preparedForNextStep: _preparedForNextStepController.text.trim(),
      annexes: _annexes,
      status: _status,
      updatedAt: DateTime.now(),
    );
    final normalized = base.copyWith(
      generatedDocumentFileName:
          _generatedFileNameController.text.trim().isEmpty
              ? widget.pdfFoundationService.buildSuggestedFileName(base)
              : _generatedFileNameController.text.trim(),
    );
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Document PV nou' : 'Editare document PV'),
      content: SizedBox(
        width: 860,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 732,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isImporting ? null : _importAnnexesFromFile,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: const Text('Importă listă din fișier'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.document.documentType ==
                                JobSiteDocumentType.montajExecutie
                            ? null
                            : _prefillAnnexesFromLatestInstallation,
                        icon: const Icon(
                            Icons.playlist_add_check_circle_outlined),
                        label: const Text('Preia lista din ultimul PV montaj'),
                      ),
                      FilledButton.icon(
                        onPressed: _isRunningAi ? null : _openAiAssistant,
                        icon: _isRunningAi
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Asistent AI'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    enabled: false,
                    initialValue: widget.document.documentType.label,
                    decoration:
                        const InputDecoration(labelText: 'Tip document'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _documentNumberController,
                    decoration:
                        const InputDecoration(labelText: 'Număr document'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Completeaza numarul documentului.'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _documentTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Titlu document',
                    ),
                  ),
                ),
                SizedBox(
                  width: 472,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _documentSubtitleController,
                    decoration: const InputDecoration(
                      labelText: 'Subtitlu document',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: InkWell(
                    onTap: () => _pickDate(
                      initial: _documentDate,
                      onPicked: (value) =>
                          setState(() => _documentDate = value),
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data document',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_documentDate)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('draft')),
                      DropdownMenuItem(
                        value: 'in_review',
                        child: Text('in_review'),
                      ),
                      DropdownMenuItem(value: 'final', child: Text('final')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _beneficiaryRepresentativeController,
                    decoration: const InputDecoration(
                      labelText: 'Reprezentant beneficiar',
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _executorRepresentativeController,
                    decoration: const InputDecoration(
                      labelText: 'Reprezentant executant',
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _projectNameController,
                    decoration: const InputDecoration(labelText: 'Proiect'),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Locatie'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _functionalStatusController,
                    decoration:
                        const InputDecoration(labelText: 'Status functional'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: InkWell(
                    onTap: _pickOptionalDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Termen remediere',
                        suffixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Text(
                        _remediationDeadline == null
                            ? '-'
                            : _formatDate(_remediationDeadline!),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    value: _trainingProvided,
                    onChanged: (value) =>
                        setState(() => _trainingProvided = value),
                    title: const Text('Instruire beneficiar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _observationsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration:
                        const InputDecoration(labelText: 'Observatii tehnice'),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _conclusionsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Concluzii'),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _probesSummaryController,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Probe / masuratori'),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _preparedForNextStepController,
                    decoration:
                        const InputDecoration(labelText: 'Etapa urmatoare'),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _registryEntryController,
                    decoration:
                        const InputDecoration(labelText: 'registryEntryId'),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    enabled: false,
                    initialValue: widget.document.documentTypeForRegistry,
                    decoration: const InputDecoration(
                      labelText: 'documentTypeForRegistry',
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _generatedPathController,
                    decoration: const InputDecoration(
                      labelText: 'generatedDocumentPath',
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _generatedFileNameController,
                    decoration: const InputDecoration(
                      labelText: 'generatedDocumentFileName',
                    ),
                  ),
                ),
                SizedBox(
                  width: 732,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Anexe generate automat / resurse preluate',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _annexes
                          .map(
                            (annex) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${annex.title} (${annex.items.length})${annex.items.isEmpty ? '' : '\nPrimele pozitii: ${annex.items.take(3).map((item) => item.label).join(', ')}'}${annex.summary.trim().isEmpty ? '' : '\n${annex.summary}'}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salveaza'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day.$month.$year';
}
