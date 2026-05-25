import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/pdf_actions_helper.dart';
import '../../core/repositories/app_data_repository.dart';
import '../registratura/registry_models.dart';
import 'complaint_document_models.dart';
import 'complaint_work_order_pdf_service.dart';

class ComplaintWorkOrderEditorPage extends StatefulWidget {
  const ComplaintWorkOrderEditorPage({
    super.key,
    required this.repository,
    required this.initialRecord,
  });

  final AppDataRepository repository;
  final ComplaintWorkOrderRecord initialRecord;

  @override
  State<ComplaintWorkOrderEditorPage> createState() =>
      _ComplaintWorkOrderEditorPageState();
}

class _ComplaintWorkOrderEditorPageState
    extends State<ComplaintWorkOrderEditorPage> {
  final Uuid _uuid = const Uuid();
  late final TextEditingController _numberController;
  late final TextEditingController _requestedByController;
  late final TextEditingController _requestedPhoneController;
  late final TextEditingController _requestedEmailController;
  late final TextEditingController _locationController;
  late final TextEditingController _subjectController;
  late final TextEditingController _scopeController;
  late final TextEditingController _executionNotesController;
  late final TextEditingController _acceptancePersonController;
  late final TextEditingController _acceptanceRoleController;
  late final TextEditingController _acceptanceDateController;
  late final TextEditingController _acceptanceNotesController;
  late String _recordId;
  late DateTime _createdAt;
  late DateTime _issueDate;
  late List<ComplaintWorkOrderLine> _lines;
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
    _issueDate = seed.issueDate;
    _lines = List<ComplaintWorkOrderLine>.from(seed.lines);
    _registryEntryId = seed.registryEntryId;
    _generatedDocumentPath = seed.generatedDocumentPath;
    _generatedDocumentFileName = seed.generatedDocumentFileName;
    _numberController = TextEditingController(text: seed.documentNumber);
    _requestedByController = TextEditingController(text: seed.requestedBy);
    _requestedPhoneController =
        TextEditingController(text: seed.requestedPhone);
    _requestedEmailController =
        TextEditingController(text: seed.requestedEmail);
    _locationController = TextEditingController(text: seed.location);
    _subjectController = TextEditingController(text: seed.subject);
    _scopeController = TextEditingController(text: seed.scopeOfWork);
    _executionNotesController =
        TextEditingController(text: seed.executionNotes);
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
    final next = await widget.repository.nextComplaintWorkOrderNumber();
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
    _requestedByController.dispose();
    _requestedPhoneController.dispose();
    _requestedEmailController.dispose();
    _locationController.dispose();
    _subjectController.dispose();
    _scopeController.dispose();
    _executionNotesController.dispose();
    _acceptancePersonController.dispose();
    _acceptanceRoleController.dispose();
    _acceptanceDateController.dispose();
    _acceptanceNotesController.dispose();
    super.dispose();
  }

  ComplaintWorkOrderRecord _buildDraft() {
    return widget.initialRecord.copyWith(
      id: _recordId,
      documentNumber: _numberController.text.trim(),
      issueDate: _issueDate,
      requestedBy: _requestedByController.text.trim(),
      requestedPhone: _requestedPhoneController.text.trim(),
      requestedEmail: _requestedEmailController.text.trim(),
      location: _locationController.text.trim(),
      subject: _subjectController.text.trim(),
      scopeOfWork: _scopeController.text.trim(),
      executionNotes: _executionNotesController.text.trim(),
      acceptancePerson: _acceptancePersonController.text.trim(),
      acceptanceRole: _acceptanceRoleController.text.trim(),
      acceptanceDateText: _acceptanceDateController.text.trim(),
      acceptanceNotes: _acceptanceNotesController.text.trim(),
      lines: List<ComplaintWorkOrderLine>.from(_lines),
      registryEntryId: _registryEntryId,
      generatedDocumentPath: _generatedDocumentPath,
      generatedDocumentFileName: _generatedDocumentFileName,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<ComplaintWorkOrderRecord> _persistDraft() async {
    var record = _buildDraft();
    if (record.documentNumber.trim().isEmpty) {
      final next = await widget.repository.nextComplaintWorkOrderNumber();
      _numberController.text = next;
      record = record.copyWith(documentNumber: next);
    }
    await widget.repository.saveComplaintWorkOrder(record);
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
      final filePath = await ComplaintWorkOrderPdfService.export(
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
          documentCategory: 'Comanda lucrari',
          documentTitle: record.subject.trim().isEmpty
              ? 'Comanda lucrari ${record.clientName}'
              : record.subject.trim(),
          documentNumber: record.documentNumber,
          documentDate: record.issueDate,
          issuerName: company.companyName.trim(),
          recipientName: record.clientName.trim(),
          clientId: record.clientId.trim(),
          ticketId: record.complaintId.trim(),
          filePath: filePath,
          fileName: record.generatedDocumentFileName,
          notes: 'Generat din modulul Reclamatii.',
          status: 'emis',
        );
        record = record.copyWith(registryEntryId: entry.id);
      }
      await widget.repository.saveComplaintWorkOrder(record);
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
        title: 'Comandă lucrări generată',
        shareSubject: 'Comandă lucrări ${record.documentNumber}',
        shareText: 'Comandă lucrări generată din aplicație.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _issueDate = picked;
    });
  }

  void _addLine() {
    setState(() {
      _lines = <ComplaintWorkOrderLine>[
        ..._lines,
        ComplaintWorkOrderLine(id: 'line-${_uuid.v4()}'),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalValue =
        _lines.fold<double>(0, (sum, line) => sum + line.totalValue);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comanda de lucrari'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addLine,
        icon: const Icon(Icons.add),
        label: const Text('Adauga linie'),
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
                      Chip(
                          label: Text(
                              'Beneficiar: ${widget.initialRecord.beneficiaryName.isEmpty ? '-' : widget.initialRecord.beneficiaryName}')),
                      Chip(
                          label: Text(
                              'Total: ${totalValue.toStringAsFixed(2)} lei')),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickIssueDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Data: ${_formatDate(_issueDate)}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _requestedByController,
            decoration: const InputDecoration(labelText: 'Solicitat de'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _requestedPhoneController,
            decoration: const InputDecoration(labelText: 'Telefon'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _requestedEmailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Locatie'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _subjectController,
            decoration:
                const InputDecoration(labelText: 'Subiect / denumire comanda'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _scopeController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Lucrari comandate'),
          ),
          const SizedBox(height: 8),
          TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _executionNotesController,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Note executie / facturare'),
          ),
          const SizedBox(height: 16),
          Text('Articole', style: Theme.of(context).textTheme.titleMedium),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.description.trim().isEmpty
                                ? 'Linie noua'
                                : line.description,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _lines = List<ComplaintWorkOrderLine>.from(
                                        _lines)
                                      ..removeAt(index);
                                  });
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      initialValue: line.description,
                      decoration: const InputDecoration(labelText: 'Descriere'),
                      onChanged: (value) {
                        _lines[index] = line.copyWith(description: value);
                      },
                    ),
                    const SizedBox(height: 8),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: line.quantity.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Cantitate'),
                            onChanged: (value) {
                              _lines[index] = line.copyWith(
                                quantity: double.tryParse(
                                        value.replaceAll(',', '.')) ??
                                    line.quantity,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            textCapitalization: TextCapitalization.sentences,
                            initialValue: line.unit,
                            decoration: const InputDecoration(labelText: 'UM'),
                            onChanged: (value) {
                              _lines[index] = line.copyWith(unit: value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: line.unitPrice.toStringAsFixed(2),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Pret unitar'),
                      onChanged: (value) {
                        _lines[index] = line.copyWith(
                          unitPrice:
                              double.tryParse(value.replaceAll(',', '.')) ??
                                  line.unitPrice,
                        );
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Total linie: ${line.totalValue.toStringAsFixed(2)} lei'),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
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
