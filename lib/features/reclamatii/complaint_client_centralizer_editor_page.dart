import 'package:flutter/material.dart';

import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../registratura/registry_models.dart';
import 'complaint_client_centralizer_pdf_service.dart';
import 'complaint_document_models.dart';

class ComplaintClientCentralizerEditorPage extends StatefulWidget {
  const ComplaintClientCentralizerEditorPage({
    super.key,
    required this.repository,
    required this.initialRecord,
  });

  final AppDataRepository repository;
  final ComplaintClientCentralizerRecord initialRecord;

  @override
  State<ComplaintClientCentralizerEditorPage> createState() =>
      _ComplaintClientCentralizerEditorPageState();
}

class _ComplaintClientCentralizerEditorPageState
    extends State<ComplaintClientCentralizerEditorPage> {
  late final TextEditingController _numberController;
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _acceptancePersonController;
  late final TextEditingController _acceptanceRoleController;
  late final TextEditingController _acceptanceDateController;
  late final TextEditingController _acceptanceNotesController;
  late DateTime _periodStart;
  late DateTime _periodEnd;
  late List<ComplaintClientCentralizerLine> _lines;
  late String _recordId;
  late DateTime _createdAt;
  String _registryEntryId = '';
  String _generatedDocumentPath = '';
  String _generatedDocumentFileName = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialRecord;
    _recordId = seed.id;
    _createdAt = seed.createdAt;
    _registryEntryId = seed.registryEntryId;
    _generatedDocumentPath = seed.generatedDocumentPath;
    _generatedDocumentFileName = seed.generatedDocumentFileName;
    _periodStart = seed.periodStart;
    _periodEnd = seed.periodEnd;
    _lines = List<ComplaintClientCentralizerLine>.from(seed.lines);
    _numberController = TextEditingController(text: seed.documentNumber);
    _titleController = TextEditingController(text: seed.title);
    _summaryController = TextEditingController(text: seed.summaryDescription);
    _acceptancePersonController =
        TextEditingController(text: seed.acceptancePerson);
    _acceptanceRoleController =
        TextEditingController(text: seed.acceptanceRole);
    _acceptanceDateController =
        TextEditingController(text: seed.acceptanceDateText);
    _acceptanceNotesController =
        TextEditingController(text: seed.acceptanceNotes);
    if (_numberController.text.trim().isEmpty) {
      _assignAutomaticNumber();
    }
  }

  Future<void> _assignAutomaticNumber() async {
    final next = await widget.repository.nextComplaintClientCentralizerNumber();
    if (!mounted || _numberController.text.trim().isNotEmpty) {
      return;
    }
    setState(() {
      _numberController.text = next;
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _acceptancePersonController.dispose();
    _acceptanceRoleController.dispose();
    _acceptanceDateController.dispose();
    _acceptanceNotesController.dispose();
    super.dispose();
  }

  ComplaintClientCentralizerRecord _buildDraft() {
    return widget.initialRecord.copyWith(
      id: _recordId,
      documentNumber: _numberController.text.trim(),
      periodStart: _periodStart,
      periodEnd: _periodEnd,
      title: _titleController.text.trim(),
      summaryDescription: _summaryController.text.trim(),
      acceptancePerson: _acceptancePersonController.text.trim(),
      acceptanceRole: _acceptanceRoleController.text.trim(),
      acceptanceDateText: _acceptanceDateController.text.trim(),
      acceptanceNotes: _acceptanceNotesController.text.trim(),
      lines: List<ComplaintClientCentralizerLine>.from(_lines),
      registryEntryId: _registryEntryId,
      generatedDocumentPath: _generatedDocumentPath,
      generatedDocumentFileName: _generatedDocumentFileName,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<ComplaintClientCentralizerRecord> _persistDraft() async {
    var record = _buildDraft();
    if (record.documentNumber.trim().isEmpty) {
      final next =
          await widget.repository.nextComplaintClientCentralizerNumber();
      _numberController.text = next;
      record = record.copyWith(documentNumber: next);
    }
    await widget.repository.saveComplaintClientCentralizer(record);
    return record;
  }

  Future<void> _saveOnly() async {
    setState(() => _saving = true);
    try {
      final record = await _persistDraft();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(record);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _generatePdf({bool saveAs = false}) async {
    setState(() => _saving = true);
    try {
      var record = await _persistDraft();
      final company = await widget.repository.loadCompanyProfile();
      final filePath = await ComplaintClientCentralizerPdfService.export(
        repository: widget.repository,
        company: company,
        record: record,
        saveAs: saveAs,
      );
      record = record.copyWith(
        generatedDocumentPath: filePath,
        generatedDocumentFileName: _fileNameFromPath(filePath),
        updatedAt: DateTime.now(),
      );
      if (record.registryEntryId.trim().isEmpty) {
        final entry = await widget.repository.registerGeneratedDocument(
          registryType: RegistryType.iesire,
          documentCategory: 'Centralizator reclamatii',
          documentTitle: record.title.trim().isEmpty
              ? 'Centralizator ${record.clientName}'
              : record.title.trim(),
          documentNumber: record.documentNumber,
          documentDate: record.periodEnd,
          issuerName: company.companyName.trim(),
          recipientName: record.clientName.trim(),
          clientId: record.clientId.trim(),
          filePath: filePath,
          fileName: record.generatedDocumentFileName,
          notes: 'Generat din modulul Reclamatii.',
          status: 'emis',
        );
        record = record.copyWith(registryEntryId: entry.id);
      }
      await widget.repository.saveComplaintClientCentralizer(record);
      _registryEntryId = record.registryEntryId;
      _generatedDocumentPath = record.generatedDocumentPath;
      _generatedDocumentFileName = record.generatedDocumentFileName;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('PDF generat: ${record.generatedDocumentFileName}')),
      );
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: filePath,
        title: 'Centralizator reclamații generat',
        shareSubject: 'Centralizator ${record.clientName}',
        shareText: 'Centralizator reclamații generat din aplicație.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _periodStart = picked;
        if (_periodEnd.isBefore(_periodStart)) {
          _periodEnd = _periodStart;
        }
      } else {
        _periodEnd = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _lines
        .where((line) => line.includeInTotal)
        .fold<double>(0, (sum, line) => sum + line.offerValue);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centralizator client'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveOnly,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Salveaza',
          ),
          IconButton(
            onPressed: _saving ? null : _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Genereaza PDF',
          ),
          IconButton(
            onPressed: _saving ? null : () => _generatePdf(saveAs: true),
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Genereaza PDF ca',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _numberController,
            decoration: const InputDecoration(labelText: 'Număr document'),
          ),
          const SizedBox(height: 12),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titlu document'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.initialRecord.clientName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _saving ? null : () => _pickDate(start: true),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Start: ${_formatDate(_periodStart)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _saving ? null : () => _pickDate(start: false),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Sfarsit: ${_formatDate(_periodEnd)}'),
                      ),
                      Chip(
                          label: Text(
                              'Total: ${totalValue.toStringAsFixed(2)} lei')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _summaryController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descriere / sumar perioada',
            ),
          ),
          const SizedBox(height: 16),
          Text('Interventii incluse',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.complaintNumber.trim().isEmpty
                          ? 'Interventie fara numar'
                          : line.complaintNumber),
                      subtitle: Text(
                        '${_formatDate(line.interventionDate)} | ${line.offerNumber.trim().isEmpty ? 'Fara oferta' : line.offerNumber}',
                      ),
                      value: line.includeInTotal,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _lines[index] =
                                    line.copyWith(includeInTotal: value);
                              });
                            },
                    ),
                    TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      initialValue: line.beneficiaryName,
                      decoration:
                          const InputDecoration(labelText: 'Beneficiar'),
                      onChanged: (value) {
                        _lines[index] = line.copyWith(beneficiaryName: value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      initialValue: line.workSummary,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Descriere scurta'),
                      onChanged: (value) {
                        _lines[index] = line.copyWith(workSummary: value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: line.offerValue.toStringAsFixed(2),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Valoare oferta'),
                      onChanged: (value) {
                        _lines[index] = line.copyWith(
                          offerValue:
                              double.tryParse(value.replaceAll(',', '.')) ??
                                  line.offerValue,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text('Acceptare client',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _acceptancePersonController,
            decoration: const InputDecoration(labelText: 'Persoana acceptare'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _acceptanceRoleController,
            decoration: const InputDecoration(labelText: 'Functie'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _acceptanceDateController,
            decoration: const InputDecoration(labelText: 'Data acceptare'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _acceptanceNotesController,
            minLines: 3,
            maxLines: 5,
            decoration:
                const InputDecoration(labelText: 'Observatii acceptare'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }
}
