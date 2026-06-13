import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../core/help/help_module_button.dart';

import '../notifications/send_document_dialog.dart';
import '../notifications/document_email_templates.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/document_file_service.dart';
import '../../core/pdf_save_service.dart';
import '../../core/company_profile.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../clients/client_models.dart';
import '../clients/add_client_quick_dialog.dart';
import '../../core/widgets/client_autocomplete_field.dart';
import '../field_photos/field_photos_page.dart';
import '../jobs/job_models.dart';
import '../programari/appointment_models.dart';
import '../reclamatii/signature_capture_page.dart';
import '../registratura/registry_models.dart';
import 'agfr_models.dart';
import 'agfr_refrigerant_data.dart';
import 'agfr_report_pdf_service.dart';
import 'agfr_weighing_import_service.dart';

class AgfrPage extends StatefulWidget {
  const AgfrPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  State<AgfrPage> createState() => _AgfrPageState();
}

class _AgfrPageState extends State<AgfrPage> {
  static const int _maxInlineAttachmentBytes = 550 * 1024;
  static const String _prefKeySearch = 'agfr_filter_search_v1';
  static const Duration _preferencesDebounceDuration =
      Duration(milliseconds: 300);
  bool _loading = true;
  Timer? _clientsReloadDebounce;
  Timer? _preferencesDebounce;
  bool _clientsReloading = false;
  CompanyProfile _companyProfile = const CompanyProfile();
  final TextEditingController _searchController = TextEditingController();

  String get _agfrTechnicianNameDefault =>
      _companyProfile.agfrTechnicianName.trim();

  String get _agfrCertNumberDefault =>
      _companyProfile.agfrTechnicianCertificateNumber.trim();

  String get _agfrAuthNumberDefault =>
      _companyProfile.agfrCompanyAuthorizationNumber.trim();
  List<AgfrEquipmentRecord> _equipments = const <AgfrEquipmentRecord>[];
  List<AgfrInterventionRecord> _interventions =
      const <AgfrInterventionRecord>[];
  List<AgfrReportRecord> _reports = const <AgfrReportRecord>[];
  List<AgfrWeighingReportRecord> _weighingReports =
      const <AgfrWeighingReportRecord>[];
  List<ClientRecord> _clients = const <ClientRecord>[];
  List<JobRecord> _jobs = const <JobRecord>[];
  List<Appointment> _appointments = const <Appointment>[];
  // Cache filtrare — evită recalcul la fiecare rebuild
  List<AgfrEquipmentRecord> _cachedFilteredEquipments =
      const <AgfrEquipmentRecord>[];
  List<AgfrInterventionRecord> _cachedFilteredInterventions =
      const <AgfrInterventionRecord>[];
  List<AgfrReportRecord> _cachedFilteredReports = const <AgfrReportRecord>[];
  List<AgfrWeighingReportRecord> _cachedFilteredWeighingReports =
      const <AgfrWeighingReportRecord>[];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadSearchPreference();
    Future.microtask(_load);
    LocalAppDataRepository.clientsChangeCount.addListener(_handleClientsChanged);
  }

  Future<void> _loadSearchPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final search = prefs.getString(_prefKeySearch) ?? '';
    if (search.isNotEmpty) {
      _searchController.text = search;
    }
  }

  @override
  void dispose() {
    LocalAppDataRepository.clientsChangeCount.removeListener(_handleClientsChanged);
    _clientsReloadDebounce?.cancel();
    _preferencesDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleClientsChanged() {
    if (_loading) {
      return;
    }
    _clientsReloadDebounce?.cancel();
    _clientsReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _reloadClientsOnly();
    });
  }

  Future<void> _reloadClientsOnly() async {
    if (_loading || _clientsReloading) {
      return;
    }
    _clientsReloading = true;
    try {
      final clients = await widget.repository.listClients();
      if (!mounted) return;
      setState(() => _clients = clients);
    } finally {
      _clientsReloading = false;
    }
  }

  void _updateAgfrFilterCache() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _cachedFilteredEquipments = List.of(_equipments);
      _cachedFilteredInterventions = List.of(_interventions);
      _cachedFilteredReports = List.of(_reports);
      _cachedFilteredWeighingReports = List.of(_weighingReports);
      return;
    }
    _cachedFilteredEquipments = _equipments.where((item) {
      return item.clientName.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.equipmentType.toLowerCase().contains(query) ||
          item.brand.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query) ||
          item.serialNumber.toLowerCase().contains(query) ||
          item.refrigerantType.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query);
    }).toList(growable: false);
    _cachedFilteredInterventions = _interventions.where((item) {
      return item.clientName.toLowerCase().contains(query) ||
          item.refrigerantType.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query) ||
          item.technicianName.toLowerCase().contains(query) ||
          item.operationType.label.toLowerCase().contains(query) ||
          _equipmentSummary(item.equipmentId).toLowerCase().contains(query);
    }).toList(growable: false);
    _cachedFilteredReports = _reports.where((item) {
      return item.reportNumber.toLowerCase().contains(query) ||
          _clientNameById(item.clientId).toLowerCase().contains(query) ||
          item.beneficiaryRepresentative.toLowerCase().contains(query) ||
          item.technicianName.toLowerCase().contains(query) ||
          item.observations.toLowerCase().contains(query) ||
          item.conclusions.toLowerCase().contains(query) ||
          _equipmentSummary(item.equipmentId).toLowerCase().contains(query);
    }).toList(growable: false);
    _cachedFilteredWeighingReports = _weighingReports.where((item) {
      return _clientNameById(item.clientId).toLowerCase().contains(query) ||
          item.sourceType.label.toLowerCase().contains(query) ||
          item.sourceFileName.toLowerCase().contains(query) ||
          item.sourceDeviceInfo.toLowerCase().contains(query) ||
          item.scaleIdentifier.toLowerCase().contains(query) ||
          item.cylinderIdentifier.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _updateAgfrFilterCache();
    });
    _schedulePersistSearchPreference();
  }

  void _schedulePersistSearchPreference() {
    _preferencesDebounce?.cancel();
    _preferencesDebounce = Timer(
      _preferencesDebounceDuration,
      () {
        unawaited(_persistSearchPreference());
      },
    );
  }

  Future<void> _persistSearchPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySearch, _searchController.text.trim());
    } catch (error) {
      debugPrint('[AGFR] persist search preference failed: $error');
    }
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      widget.repository.listAgfrEquipments(),
      widget.repository.listAgfrInterventions(),
      widget.repository.listAgfrReports(),
      widget.repository.listAgfrWeighingReports(),
      widget.repository.listClients(),
      widget.repository.listJobs(),
      widget.repository.listAppointments(),
      widget.repository.loadCompanyProfile(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _equipments = results[0] as List<AgfrEquipmentRecord>;
      _interventions = results[1] as List<AgfrInterventionRecord>;
      _reports = results[2] as List<AgfrReportRecord>;
      _weighingReports = results[3] as List<AgfrWeighingReportRecord>;
      _clients = results[4] as List<ClientRecord>;
      _jobs = results[5] as List<JobRecord>;
      _appointments = results[6] as List<Appointment>;
      _companyProfile = results[7] as CompanyProfile;
      _loading = false;
      _updateAgfrFilterCache();
    });
  }

  List<AgfrEquipmentRecord> get _filteredEquipments =>
      _cachedFilteredEquipments;
  List<AgfrInterventionRecord> get _filteredInterventions =>
      _cachedFilteredInterventions;
  List<AgfrReportRecord> get _filteredReports => _cachedFilteredReports;
  List<AgfrWeighingReportRecord> get _filteredWeighingReports =>
      _cachedFilteredWeighingReports;

  String _formatDate(DateTime value) =>
      DateFormat('dd.MM.yyyy', 'ro_RO').format(value);

  String _formatDateTime(DateTime value) =>
      DateFormat('dd.MM.yyyy HH:mm', 'ro_RO').format(value);

  String _clientNameById(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) {
      return '';
    }
    for (final client in _clients) {
      if (client.id == id) {
        return client.name.trim();
      }
    }
    return '';
  }

  ClientRecord? _clientById(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final client in _clients) {
      if (client.id == id) {
        return client;
      }
    }
    return null;
  }

  String _entityTypeLabel(ClientType type) => type.label;

  String _jobLabel(String jobId) {
    final id = jobId.trim();
    if (id.isEmpty) {
      return '-';
    }
    for (final job in _jobs) {
      if (job.id == id) {
        final code = job.jobCode.trim();
        final title = job.title.trim();
        if (code.isNotEmpty && title.isNotEmpty) {
          return '$code - $title';
        }
        return code.isNotEmpty ? code : (title.isNotEmpty ? title : id);
      }
    }
    return id;
  }

  JobRecord? _jobById(String jobId) {
    final id = jobId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final job in _jobs) {
      if (job.id == id) {
        return job;
      }
    }
    return null;
  }

  String _appointmentLabel(String appointmentId) {
    final id = appointmentId.trim();
    if (id.isEmpty) {
      return '-';
    }
    for (final appointment in _appointments) {
      if (appointment.id == id) {
        final title = appointment.title.trim().isEmpty
            ? appointment.clientName.trim()
            : appointment.title.trim();
        return '$title | ${_formatDateTime(appointment.effectiveStartDateTime)}';
      }
    }
    return id;
  }

  AgfrEquipmentRecord? _equipmentById(String equipmentId) {
    final id = equipmentId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final item in _equipments) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  AgfrInterventionRecord? _interventionById(String interventionId) {
    final id = interventionId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final item in _interventions) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  AgfrInterventionRecord? _latestIntervention({String equipmentId = ''}) {
    final normalizedEquipmentId = equipmentId.trim();
    final candidates = _interventions
        .where(
          (item) =>
              normalizedEquipmentId.isEmpty ||
              item.equipmentId == normalizedEquipmentId,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    final sorted = [...candidates]..sort((a, b) {
        final byOperationDate = b.operationDate.compareTo(a.operationDate);
        if (byOperationDate != 0) {
          return byOperationDate;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted.first;
  }

  AgfrWeighingReportRecord? _weighingReportById(String reportId) {
    final id = reportId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final item in _weighingReports) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String _reportLabelById(String reportId) {
    final id = reportId.trim();
    if (id.isEmpty) {
      return 'neasociat';
    }
    for (final item in _reports) {
      if (item.id == id) {
        final number = item.reportNumber.trim();
        return number.isEmpty ? item.id : number;
      }
    }
    return id;
  }

  String _equipmentSummary(String equipmentId) {
    final equipment = _equipmentById(equipmentId);
    if (equipment == null) {
      return equipmentId.trim().isEmpty ? '-' : equipmentId.trim();
    }
    final parts = <String>[
      equipment.equipmentType.trim(),
      equipment.brand.trim(),
      equipment.model.trim(),
      if (equipment.serialNumber.trim().isNotEmpty)
        'SN ${equipment.serialNumber.trim()}',
    ].where((item) => item.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? equipment.id : parts.join(' | ');
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Uint8List? _decodeSignature(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Widget _signatureCard({
    required String title,
    required String signatureBase64,
    required VoidCallback onSign,
    required VoidCallback onClear,
  }) {
    final bytes = _decodeSignature(signatureBase64);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Container(
              height: 110,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: bytes == null
                  ? const Text('Fara semnatura')
                  : Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onSign,
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Semneaza'),
                ),
                OutlinedButton.icon(
                  onPressed: bytes == null ? null : onClear,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('Reseteaza'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _captureSignature(String title) async {
    final bytes =
        await Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => SignatureCapturePage(title: title),
      ),
    );
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
    return base64Encode(bytes);
  }

  Future<String> _pickAttachmentPath() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>[
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif'
      ],
    );
    if (result == null || result.files.isEmpty) {
      return '';
    }
    return result.files.single.path?.trim() ?? '';
  }

  Future<String> _defaultReportNumber(DateTime operationDate) {
    return widget.repository.nextAgfrReportNumber(issueDate: operationDate);
  }

  double _co2EquivalentTons({
    required double totalChargeKg,
    required double gwp,
  }) {
    return totalChargeKg * gwp / 1000;
  }

  Future<void> _openEquipmentForm({AgfrEquipmentRecord? current}) async {
    final now = DateTime.now();
    String selectedClientId = current?.clientId ?? '';
    String selectedJobId = current?.jobId ?? '';
    ClientType selectedEntityType = current?.entityType ??
        _clientById(selectedClientId)?.type ??
        ClientType.persoanaJuridica;
    AgfrEquipmentCategory selectedCategory =
        current?.equipmentCategory ?? AgfrEquipmentCategory.aerConditionatSplit;
    AgfrRefrigerantType? selectedRefrigerantEnum =
        AgfrRefrigerantType.fromValue(current?.refrigerantType);
    final locationController =
        TextEditingController(text: current?.location ?? '');
    final equipmentTypeController =
        TextEditingController(text: current?.equipmentType ?? '');
    final brandController = TextEditingController(text: current?.brand ?? '');
    final modelController = TextEditingController(text: current?.model ?? '');
    final serialController =
        TextEditingController(text: current?.serialNumber ?? '');
    final refrigerantCustomController = TextEditingController(
      text: selectedRefrigerantEnum == null
          ? (current?.refrigerantType ?? '')
          : '',
    );
    final gwpController = TextEditingController(
      text: current == null ? '' : current.gwp.toStringAsFixed(0),
    );
    final factoryChargeController = TextEditingController(
      text: current == null ? '' : current.factoryChargeKg.toStringAsFixed(2),
    );
    final additionalChargeController = TextEditingController(
      text:
          current == null ? '' : current.additionalChargeKg.toStringAsFixed(2),
    );
    final notesController = TextEditingController(text: current?.notes ?? '');
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalCharge = _parseDouble(factoryChargeController.text) +
                _parseDouble(additionalChargeController.text);
            final co2 = _co2EquivalentTons(
              totalChargeKg: totalCharge,
              gwp: _parseDouble(gwpController.text),
            );
            return AlertDialog(
              title: Text(
                current == null
                    ? 'Echipament AGFR nou'
                    : 'Editeaza echipament AGFR',
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClientAutocompleteField(
                              key: ValueKey(
                                  'agfr-client-${selectedClientId.isEmpty ? 'none' : selectedClientId}'),
                              clients: _clients,
                              initialClient: _clientById(selectedClientId),
                              labelText: 'Client',
                              onClientSelected: (c) => setDialogState(() {
                                selectedClientId = c?.id ?? '';
                                selectedEntityType =
                                    _clientById(selectedClientId)?.type ??
                                        selectedEntityType;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.tonalIcon(
                              onPressed: () async {
                                final newClient =
                                    await AddClientQuickDialog.show(
                                  context: context,
                                  repository: widget.repository,
                                  defaultType: selectedEntityType,
                                );
                                if (newClient != null && mounted) {
                                  await _load();
                                  if (mounted) {
                                    setDialogState(() {
                                      selectedClientId = newClient.id;
                                      selectedEntityType = newClient.type;
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_outlined),
                              label: const Text('Adaugă'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: const Icon(Icons.badge_outlined, size: 16),
                          label: Text(
                            'Tip entitate: ${_entityTypeLabel(selectedEntityType)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _jobs.any((j) => j.id == selectedJobId)
                            ? selectedJobId
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Lucrare asociata (optional)',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Neselectata'),
                          ),
                          ..._jobs.map(
                            (job) => DropdownMenuItem<String>(
                              value: job.id,
                              child: Text(_jobLabel(job.id)),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() {
                          selectedJobId = (value ?? '').trim();
                          if (selectedClientId.isEmpty &&
                              selectedJobId.isNotEmpty) {
                            final matches =
                                _jobs.where((job) => job.id == selectedJobId);
                            if (matches.isNotEmpty) {
                              selectedClientId = matches.first.clientId.trim();
                              selectedEntityType =
                                  _clientById(selectedClientId)?.type ??
                                      selectedEntityType;
                            }
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Locatie'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AgfrEquipmentCategory>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categorie echipament',
                        ),
                        items: AgfrEquipmentCategory.values
                            .map(
                              (item) => DropdownMenuItem<AgfrEquipmentCategory>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setDialogState(() {
                          selectedCategory = value ?? selectedCategory;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: equipmentTypeController,
                              decoration: const InputDecoration(
                                labelText: 'Tip echipament',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: brandController,
                              decoration:
                                  const InputDecoration(labelText: 'Brand'),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: modelController,
                              decoration:
                                  const InputDecoration(labelText: 'Model'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: serialController,
                              decoration: const InputDecoration(
                                labelText: 'Serie / serial number',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AgfrRefrigerantType>(
                        initialValue: selectedRefrigerantEnum,
                        decoration: const InputDecoration(
                          labelText: 'Tip refrigerant',
                        ),
                        items: AgfrRefrigerantType.values
                            .map(
                              (item) => DropdownMenuItem<AgfrRefrigerantType>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setDialogState(() {
                          selectedRefrigerantEnum = value;
                          if (value != null && value != AgfrRefrigerantType.altul) {
                            refrigerantCustomController.clear();
                            // Auto-fill GWP din datele statice
                            final gwp = AgfrRefrigerantData.gwpFor(value.value);
                            if (gwp > 0) gwpController.text = gwp.toString();
                          }
                        }),
                      ),
                      // ── Banner avertizare refrigerant periculos ───────
                      Builder(builder: (_) {
                        final spec = selectedRefrigerantEnum != null
                            ? AgfrRefrigerantData.specs[selectedRefrigerantEnum!.value]
                            : null;
                        if (spec?.note == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              '⚠️ ${spec!.note}',
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                            )),
                          ]),
                        );
                      }),
                      if (selectedRefrigerantEnum ==
                              AgfrRefrigerantType.altul ||
                          selectedRefrigerantEnum == null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: refrigerantCustomController,
                          decoration: const InputDecoration(
                            labelText: 'Refrigerant personalizat',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: gwpController,
                              readOnly: selectedRefrigerantEnum != null &&
                                  selectedRefrigerantEnum != AgfrRefrigerantType.altul &&
                                  AgfrRefrigerantData.gwpFor(selectedRefrigerantEnum!.value) > 0,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'GWP',
                                suffixIcon: (selectedRefrigerantEnum != null &&
                                    selectedRefrigerantEnum != AgfrRefrigerantType.altul &&
                                    AgfrRefrigerantData.gwpFor(selectedRefrigerantEnum!.value) > 0)
                                    ? const Icon(Icons.lock_outline, size: 14, color: Colors.grey)
                                    : null,
                                helperText: 'Reg. UE 517/2014',
                                helperStyle: const TextStyle(fontSize: 9),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: factoryChargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Incarcare fabrica kg',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: TextField(
                              controller: additionalChargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Completare kg',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ── Calcul automat CO₂ echivalent ─────────────────
                      if (totalCharge > 0 || co2 > 0)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Calcul automat CO₂ echivalent',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue.shade800)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(label: Text('Total agent: ${totalCharge.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 12))),
                                  Chip(label: Text('CO₂e: ${co2.toStringAsFixed(3)} t', style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                              if (co2 > 0) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.schedule_outlined, size: 13, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    AgfrRefrigerantData.intervalVerificareScurgeri(co2),
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: notesController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Observatii'),
                      ),
                      if ((formError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Renunță'),
                ),
                FilledButton(
                  onPressed: () async {
                    final resolvedClientName =
                        _clientNameById(selectedClientId);
                    final resolvedRefrigerant = selectedRefrigerantEnum == null
                        ? refrigerantCustomController.text.trim()
                        : selectedRefrigerantEnum == AgfrRefrigerantType.altul
                            ? refrigerantCustomController.text.trim()
                            : selectedRefrigerantEnum!.value;
                    if (selectedClientId.isEmpty ||
                        resolvedClientName.isEmpty) {
                      setDialogState(() {
                        formError = 'Selecteaza clientul.';
                      });
                      return;
                    }
                    if (equipmentTypeController.text.trim().isEmpty) {
                      setDialogState(() {
                        formError = 'Completeaza tipul echipamentului.';
                      });
                      return;
                    }
                    if (resolvedRefrigerant.isEmpty) {
                      setDialogState(() {
                        formError = 'Completeaza tipul refrigerantului.';
                      });
                      return;
                    }
                    final totalCharge =
                        _parseDouble(factoryChargeController.text) +
                            _parseDouble(additionalChargeController.text);
                    final item = AgfrEquipmentRecord(
                      id: current?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      clientId: selectedClientId,
                      clientName: resolvedClientName,
                      entityType: _clientById(selectedClientId)?.type ??
                          selectedEntityType,
                      jobId: selectedJobId,
                      location: locationController.text.trim(),
                      equipmentCategory: selectedCategory,
                      equipmentType: equipmentTypeController.text.trim(),
                      brand: brandController.text.trim(),
                      model: modelController.text.trim(),
                      serialNumber: serialController.text.trim(),
                      refrigerantType: resolvedRefrigerant,
                      gwp: _parseDouble(gwpController.text),
                      factoryChargeKg:
                          _parseDouble(factoryChargeController.text),
                      additionalChargeKg:
                          _parseDouble(additionalChargeController.text),
                      totalChargeKg: totalCharge,
                      co2EquivalentTons: _co2EquivalentTons(
                        totalChargeKg: totalCharge,
                        gwp: _parseDouble(gwpController.text),
                      ),
                      notes: notesController.text.trim(),
                      createdAt: current?.createdAt ?? now,
                      updatedAt: DateTime.now(),
                    );
                    await widget.repository.saveAgfrEquipment(item);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Salveaza'),
                ),
              ],
            );
          },
        );
      },
    );

    locationController.dispose();
    equipmentTypeController.dispose();
    brandController.dispose();
    modelController.dispose();
    serialController.dispose();
    refrigerantCustomController.dispose();
    gwpController.dispose();
    factoryChargeController.dispose();
    additionalChargeController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _openInterventionForm({
    AgfrInterventionRecord? current,
    String seedEquipmentId = '',
  }) async {
    final now = DateTime.now();
    String selectedEquipmentId = current?.equipmentId ?? seedEquipmentId.trim();
    String selectedClientId = current?.clientId ?? '';
    String selectedJobId = current?.jobId ?? '';
    String selectedAppointmentId = current?.appointmentId ?? '';
    AgfrInterventionType selectedType =
        current?.operationType ?? AgfrInterventionType.service;
    AgfrRefrigerantType? selectedRefrigerantEnum =
        AgfrRefrigerantType.fromValue(current?.refrigerantType);
    AgfrLeakCheckMethod? selectedLeakMethod = current?.leakCheckMethod;
    AgfrLeakCheckResult? selectedLeakResult = current?.leakCheckResult;
    DateTime selectedOperationDate = current?.operationDate ?? now;
    final refrigerantCustomController = TextEditingController(
      text: selectedRefrigerantEnum == null
          ? (current?.refrigerantType ?? '')
          : '',
    );
    final chargedController = TextEditingController(
      text: current == null ? '' : current.chargedKg.toStringAsFixed(2),
    );
    final recoveredController = TextEditingController(
      text: current == null ? '' : current.recoveredKg.toStringAsFixed(2),
    );
    final totalInSystemController = TextEditingController(
      text: current == null ? '' : current.totalInSystemKg.toStringAsFixed(2),
    );
    final pressureBarController = TextEditingController(
      text: current == null ? '' : current.pressureTestBar.toStringAsFixed(2),
    );
    final pressureHoursController = TextEditingController(
      text: current == null
          ? ''
          : current.pressureTestDurationHours.toStringAsFixed(2),
    );
    final vacuumMicronsController = TextEditingController(
      text: current == null ? '' : current.vacuumMicrons.toStringAsFixed(0),
    );
    final vacuumHoursController = TextEditingController(
      text:
          current == null ? '' : current.vacuumDurationHours.toStringAsFixed(2),
    );
    final notesController = TextEditingController(text: current?.notes ?? '');
    // Task 5 — Auto-completare tehnician din Firebase user curent
    String techDefaultName = current?.technicianName ?? '';
    if (techDefaultName.isEmpty) {
      final fbUser = FirebaseAuth.instance.currentUser;
      techDefaultName = fbUser?.displayName ?? fbUser?.email ?? '';
    }
    final technicianNameController =
        TextEditingController(text: techDefaultName);
    final technicianCertificateController = TextEditingController(
      text: current?.technicianCertificateNumber ?? '',
    );
    final companyAuthorizationController = TextEditingController(
      text: current?.companyFgasAuthorizationNumber ?? '',
    );
    String? formError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedEquipment = _equipmentById(selectedEquipmentId);
            if (selectedEquipment != null) {
              selectedClientId = selectedEquipment.clientId;
              if (selectedJobId.isEmpty) {
                selectedJobId = selectedEquipment.jobId;
              }
              if (selectedRefrigerantEnum == null &&
                  refrigerantCustomController.text.trim().isEmpty &&
                  selectedEquipment.refrigerantType.trim().isNotEmpty) {
                final mapped = AgfrRefrigerantType.fromValue(
                  selectedEquipment.refrigerantType,
                );
                if (mapped != null) {
                  selectedRefrigerantEnum = mapped;
                } else {
                  refrigerantCustomController.text =
                      selectedEquipment.refrigerantType;
                }
              }
              if (current == null &&
                  totalInSystemController.text.trim().isEmpty) {
                totalInSystemController.text =
                    selectedEquipment.totalChargeKg.toStringAsFixed(2);
              }
            }
            return AlertDialog(
              title: Text(
                current == null
                    ? 'Interventie AGFR noua'
                    : 'Editeaza interventie AGFR',
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _equipments.any(
                          (item) => item.id == selectedEquipmentId,
                        )
                            ? selectedEquipmentId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Echipament'),
                        items: _equipments
                            .map(
                              (equipment) => DropdownMenuItem<String>(
                                value: equipment.id,
                                child: Text(_equipmentSummary(equipment.id)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setDialogState(() {
                          selectedEquipmentId = (value ?? '').trim();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 250,
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Client'),
                              child: Text(
                                _clientNameById(selectedClientId).trim().isEmpty
                                    ? '-'
                                    : _clientNameById(selectedClientId),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _jobs.any((j) => j.id == selectedJobId)
                                      ? selectedJobId
                                      : '',
                              decoration: const InputDecoration(
                                labelText: 'Lucrare (optional)',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Neselectata'),
                                ),
                                ..._jobs.map(
                                  (job) => DropdownMenuItem<String>(
                                    value: job.id,
                                    child: Text(_jobLabel(job.id)),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedJobId = (value ?? '').trim();
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: DropdownButtonFormField<String>(
                              initialValue: _appointments.any(
                                (item) => item.id == selectedAppointmentId,
                              )
                                  ? selectedAppointmentId
                                  : '',
                              decoration: const InputDecoration(
                                labelText: 'Programare (optional)',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Neselectata'),
                                ),
                                ..._appointments.map(
                                  (appointment) => DropdownMenuItem<String>(
                                    value: appointment.id,
                                    child:
                                        Text(_appointmentLabel(appointment.id)),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedAppointmentId = (value ?? '').trim();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child:
                                DropdownButtonFormField<AgfrInterventionType>(
                              initialValue: selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Tip interventie',
                              ),
                              items: AgfrInterventionType.values
                                  .map(
                                    (item) =>
                                        DropdownMenuItem<AgfrInterventionType>(
                                      value: item,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) => setDialogState(() {
                                selectedType = value ?? selectedType;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedOperationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedOperationDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                'Data: ${_formatDate(selectedOperationDate)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AgfrRefrigerantType>(
                        initialValue: selectedRefrigerantEnum,
                        decoration:
                            const InputDecoration(labelText: 'Tip refrigerant'),
                        items: AgfrRefrigerantType.values
                            .map(
                              (item) => DropdownMenuItem<AgfrRefrigerantType>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setDialogState(() {
                          selectedRefrigerantEnum = value;
                          if (value != null && value != AgfrRefrigerantType.altul) {
                            refrigerantCustomController.clear();
                          }
                        }),
                      ),
                      // ── Banner avertizare refrigerant periculos ───────
                      Builder(builder: (_) {
                        final spec = selectedRefrigerantEnum != null
                            ? AgfrRefrigerantData.specs[selectedRefrigerantEnum!.value]
                            : null;
                        if (spec?.note == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              '⚠️ ${spec!.note}',
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                            )),
                          ]),
                        );
                      }),
                      if (selectedRefrigerantEnum == null ||
                          selectedRefrigerantEnum ==
                              AgfrRefrigerantType.altul) ...[
                        const SizedBox(height: 12),
                        TextField(
                          textCapitalization: TextCapitalization.sentences,
                          controller: refrigerantCustomController,
                          decoration: const InputDecoration(
                            labelText: 'Refrigerant personalizat',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _numberField(
                            controller: chargedController,
                            label: 'Incarcat kg',
                            width: 140,
                          ),
                          _numberField(
                            controller: recoveredController,
                            label: 'Recuperat kg',
                            width: 140,
                          ),
                          _numberField(
                            controller: totalInSystemController,
                            label: 'Total in sistem kg',
                            width: 160,
                          ),
                          _numberField(
                            controller: pressureBarController,
                            label: 'Proba presiune bar',
                            width: 170,
                          ),
                          _numberField(
                            controller: pressureHoursController,
                            label: 'Durata proba ore',
                            width: 170,
                          ),
                          _numberField(
                            controller: vacuumMicronsController,
                            label: 'Vacuum microni',
                            width: 150,
                          ),
                          _numberField(
                            controller: vacuumHoursController,
                            label: 'Durata vacuum ore',
                            width: 170,
                          ),
                        ],
                      ),
                      // ── CO₂ echivalent calculat din cantitate încărcată ──
                      Builder(builder: (_) {
                        final gwpStr = selectedRefrigerantEnum != null &&
                            selectedRefrigerantEnum != AgfrRefrigerantType.altul
                            ? AgfrRefrigerantData.gwpFor(selectedRefrigerantEnum!.value)
                            : 0;
                        final charged = _parseDouble(chargedController.text);
                        final recovered = _parseDouble(recoveredController.text);
                        if (gwpStr <= 0 && charged == 0 && recovered == 0) {
                          return const SizedBox.shrink();
                        }
                        final co2Incarcat = (charged * gwpStr) / 1000.0;
                        final co2Recuperat = (recovered * gwpStr) / 1000.0;
                        final interval = co2Incarcat > 0
                            ? AgfrRefrigerantData.intervalVerificareScurgeri(co2Incarcat)
                            : null;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CO₂ echivalent',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue.shade800)),
                              const SizedBox(height: 4),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                if (charged > 0) Chip(label: Text('Înc: ${co2Incarcat.toStringAsFixed(3)} t CO₂e', style: const TextStyle(fontSize: 11))),
                                if (recovered > 0) Chip(label: Text('Rec: ${co2Recuperat.toStringAsFixed(3)} t CO₂e', style: const TextStyle(fontSize: 11))),
                              ]),
                              if (interval != null) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.schedule_outlined, size: 13, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text(interval, style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
                                ]),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child:
                                DropdownButtonFormField<AgfrLeakCheckMethod?>(
                              initialValue: selectedLeakMethod,
                              decoration: const InputDecoration(
                                labelText: 'Metoda verificare scurgeri',
                              ),
                              items: <DropdownMenuItem<AgfrLeakCheckMethod?>>[
                                const DropdownMenuItem<AgfrLeakCheckMethod?>(
                                  value: null,
                                  child: Text('Neselectata'),
                                ),
                                ...AgfrLeakCheckMethod.values.map(
                                  (item) =>
                                      DropdownMenuItem<AgfrLeakCheckMethod?>(
                                    value: item,
                                    child: Text(item.label),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedLeakMethod = value;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child:
                                DropdownButtonFormField<AgfrLeakCheckResult?>(
                              initialValue: selectedLeakResult,
                              decoration: const InputDecoration(
                                labelText: 'Rezultat verificare',
                              ),
                              items: <DropdownMenuItem<AgfrLeakCheckResult?>>[
                                const DropdownMenuItem<AgfrLeakCheckResult?>(
                                  value: null,
                                  child: Text('Neselectat'),
                                ),
                                ...AgfrLeakCheckResult.values.map(
                                  (item) =>
                                      DropdownMenuItem<AgfrLeakCheckResult?>(
                                    value: item,
                                    child: Text(item.label),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedLeakResult = value;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: technicianNameController,
                              decoration:
                                  const InputDecoration(labelText: 'Tehnician'),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: technicianCertificateController,
                              decoration: const InputDecoration(
                                labelText: 'Certificat F-GAS tehnician',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: companyAuthorizationController,
                              decoration: const InputDecoration(
                                labelText: 'Autorizatie F-GAS firma',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: notesController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Observatii'),
                      ),
                      if ((formError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Renunță'),
                ),
                FilledButton(
                  onPressed: () async {
                    final selectedEquipment =
                        _equipmentById(selectedEquipmentId);
                    final resolvedRefrigerant = selectedRefrigerantEnum == null
                        ? refrigerantCustomController.text.trim()
                        : selectedRefrigerantEnum == AgfrRefrigerantType.altul
                            ? refrigerantCustomController.text.trim()
                            : selectedRefrigerantEnum!.value;
                    if (selectedEquipment == null) {
                      setDialogState(() {
                        formError = 'Selecteaza echipamentul.';
                      });
                      return;
                    }
                    if (resolvedRefrigerant.isEmpty) {
                      setDialogState(() {
                        formError = 'Completeaza tipul refrigerantului.';
                      });
                      return;
                    }
                    if (technicianNameController.text.trim().isEmpty) {
                      setDialogState(() {
                        formError = 'Completeaza tehnicianul.';
                      });
                      return;
                    }
                    final item = AgfrInterventionRecord(
                      id: current?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      equipmentId: selectedEquipment.id,
                      clientId: selectedEquipment.clientId,
                      clientName: selectedEquipment.clientName,
                      jobId: selectedJobId,
                      appointmentId: selectedAppointmentId,
                      operationDate: selectedOperationDate,
                      operationType: selectedType,
                      refrigerantType: resolvedRefrigerant,
                      chargedKg: _parseDouble(chargedController.text),
                      recoveredKg: _parseDouble(recoveredController.text),
                      totalInSystemKg:
                          _parseDouble(totalInSystemController.text),
                      pressureTestBar: _parseDouble(pressureBarController.text),
                      pressureTestDurationHours:
                          _parseDouble(pressureHoursController.text),
                      vacuumMicrons: _parseDouble(vacuumMicronsController.text),
                      vacuumDurationHours:
                          _parseDouble(vacuumHoursController.text),
                      leakCheckMethod: selectedLeakMethod,
                      leakCheckResult: selectedLeakResult,
                      notes: notesController.text.trim(),
                      technicianName: technicianNameController.text.trim(),
                      technicianCertificateNumber:
                          technicianCertificateController.text.trim(),
                      companyFgasAuthorizationNumber:
                          companyAuthorizationController.text.trim(),
                      createdAt: current?.createdAt ?? now,
                      updatedAt: DateTime.now(),
                    );
                    await widget.repository.saveAgfrIntervention(item);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Salveaza'),
                ),
              ],
            );
          },
        );
      },
    );

    refrigerantCustomController.dispose();
    chargedController.dispose();
    recoveredController.dispose();
    totalInSystemController.dispose();
    pressureBarController.dispose();
    pressureHoursController.dispose();
    vacuumMicronsController.dispose();
    vacuumHoursController.dispose();
    notesController.dispose();
    technicianNameController.dispose();
    technicianCertificateController.dispose();
    companyAuthorizationController.dispose();

    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _openReportForm({
    AgfrReportRecord? current,
    String seedInterventionId = '',
    String seedEquipmentId = '',
  }) async {
    final now = DateTime.now();
    String selectedInterventionId =
        current?.interventionId ?? seedInterventionId;
    String selectedEquipmentId = current?.equipmentId ?? seedEquipmentId.trim();
    String selectedClientId = current?.clientId ?? '';
    String selectedJobId = current?.jobId ?? '';
    String selectedWeighingReportId = current?.weighingReportId ?? '';
    DateTime selectedOperationDate = current?.operationDate ?? now;
    if (current == null && selectedInterventionId.trim().isEmpty) {
      final fallbackIntervention = _latestIntervention(
        equipmentId: selectedEquipmentId,
      );
      if (fallbackIntervention != null) {
        selectedInterventionId = fallbackIntervention.id;
      }
    }

    final seededIntervention = _interventionById(selectedInterventionId);
    if (seededIntervention != null) {
      selectedEquipmentId = seededIntervention.equipmentId;
      selectedClientId = seededIntervention.clientId;
      if (selectedJobId.trim().isEmpty) {
        selectedJobId = seededIntervention.jobId;
      }
      if (current == null) {
        selectedOperationDate = seededIntervention.operationDate;
      }
    }
    final seededEquipment = _equipmentById(selectedEquipmentId);
    if (seededEquipment != null) {
      if (selectedClientId.trim().isEmpty) {
        selectedClientId = seededEquipment.clientId;
      }
      if (selectedJobId.trim().isEmpty) {
        selectedJobId = seededEquipment.jobId;
      }
    }

    const defaultCertificatePath = '';
    final reportNumberController = TextEditingController(
      text: current?.reportNumber ?? '',
    );
    final beneficiaryRepresentativeController = TextEditingController(
      text: current?.beneficiaryRepresentative ?? '',
    );
    final technicianNameController = TextEditingController(
      text: (current?.technicianName ?? '').trim().isNotEmpty
          ? current!.technicianName
          : (seededIntervention?.technicianName ?? '').trim().isNotEmpty
              ? seededIntervention!.technicianName
              : _agfrTechnicianNameDefault,
    );
    final technicianCertificateController = TextEditingController(
      text: (current?.technicianCertificateNumber ?? '').trim().isNotEmpty
          ? current!.technicianCertificateNumber
          : (seededIntervention?.technicianCertificateNumber ?? '')
                  .trim()
                  .isNotEmpty
              ? seededIntervention!.technicianCertificateNumber
              : _agfrCertNumberDefault,
    );
    final companyAuthorizationController = TextEditingController(
      text: (current?.companyFgasAuthorizationNumber ?? '').trim().isNotEmpty
          ? current!.companyFgasAuthorizationNumber
          : (seededIntervention?.companyFgasAuthorizationNumber ?? '')
                  .trim()
                  .isNotEmpty
              ? seededIntervention!.companyFgasAuthorizationNumber
              : _agfrAuthNumberDefault,
    );
    final observationsController = TextEditingController(
      text: current?.observations ?? '',
    );
    final conclusionsController = TextEditingController(
      text: current?.conclusions ?? '',
    );
    final companyCertificatePathController = TextEditingController(
      text: (current?.companyCertificateAttachmentPath ?? '').trim().isNotEmpty
          ? current!.companyCertificateAttachmentPath
          : defaultCertificatePath,
    );
    final technicianCertificatePathController = TextEditingController(
      text:
          (current?.technicianCertificateAttachmentPath ?? '').trim().isNotEmpty
              ? current!.technicianCertificateAttachmentPath
              : defaultCertificatePath,
    );
    String clientSignatureBase64 = current?.clientSignatureBase64 ?? '';
    String technicianSignatureBase64 = current?.technicianSignatureBase64 ?? '';
    String? formError;

    if (current == null && reportNumberController.text.trim().isEmpty) {
      reportNumberController.text =
          await _defaultReportNumber(selectedOperationDate);
    }

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedIntervention =
                _interventionById(selectedInterventionId);
            final selectedEquipment = selectedIntervention == null
                ? _equipmentById(selectedEquipmentId)
                : _equipmentById(selectedIntervention.equipmentId);
            if (selectedIntervention != null) {
              selectedEquipmentId = selectedIntervention.equipmentId;
              selectedClientId = selectedIntervention.clientId;
              if (selectedJobId.trim().isEmpty) {
                selectedJobId = selectedIntervention.jobId;
              }
              if (selectedWeighingReportId.trim().isEmpty) {
                for (final item in _weighingReports) {
                  if (item.interventionId == selectedIntervention.id) {
                    selectedWeighingReportId = item.id;
                    break;
                  }
                }
              }
              if (current == null) {
                selectedOperationDate = selectedIntervention.operationDate;
                if (technicianNameController.text.trim().isEmpty) {
                  technicianNameController.text =
                      selectedIntervention.technicianName.trim().isNotEmpty
                          ? selectedIntervention.technicianName
                          : _agfrTechnicianNameDefault;
                }
                if (technicianCertificateController.text.trim().isEmpty) {
                  technicianCertificateController.text = selectedIntervention
                          .technicianCertificateNumber
                          .trim()
                          .isNotEmpty
                      ? selectedIntervention.technicianCertificateNumber
                      : _agfrCertNumberDefault;
                }
                if (companyAuthorizationController.text.trim().isEmpty) {
                  companyAuthorizationController.text = selectedIntervention
                          .companyFgasAuthorizationNumber
                          .trim()
                          .isNotEmpty
                      ? selectedIntervention.companyFgasAuthorizationNumber
                      : _agfrAuthNumberDefault;
                }
              }
            }
            return AlertDialog(
              title: Text(
                current == null
                    ? 'Proces-verbal AGFR nou'
                    : 'Editeaza proces-verbal AGFR',
              ),
              content: SizedBox(
                width: 840,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 360,
                            child: DropdownButtonFormField<String>(
                              initialValue: _equipments.any(
                                (item) => item.id == selectedEquipmentId,
                              )
                                  ? selectedEquipmentId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Echipament AGFR',
                              ),
                              items: _equipments
                                  .map(
                                    (equipment) => DropdownMenuItem<String>(
                                      value: equipment.id,
                                      child:
                                          Text(_equipmentSummary(equipment.id)),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) => setDialogState(() {
                                selectedEquipmentId = (value ?? '').trim();
                                final selectedEquipment =
                                    _equipmentById(selectedEquipmentId);
                                selectedClientId =
                                    selectedEquipment?.clientId ?? '';
                                if (selectedJobId.trim().isEmpty) {
                                  selectedJobId =
                                      selectedEquipment?.jobId ?? '';
                                }
                                final latest = _latestIntervention(
                                  equipmentId: selectedEquipmentId,
                                );
                                selectedInterventionId = latest?.id ?? '';
                                if (latest != null) {
                                  selectedClientId = latest.clientId;
                                  selectedJobId = latest.jobId;
                                  selectedOperationDate = latest.operationDate;
                                  if (technicianNameController.text
                                      .trim()
                                      .isEmpty) {
                                    technicianNameController.text =
                                        latest.technicianName.trim().isNotEmpty
                                            ? latest.technicianName
                                            : _agfrTechnicianNameDefault;
                                  }
                                  if (technicianCertificateController.text
                                      .trim()
                                      .isEmpty) {
                                    technicianCertificateController.text =
                                        latest.technicianCertificateNumber
                                                .trim()
                                                .isNotEmpty
                                            ? latest.technicianCertificateNumber
                                            : _agfrCertNumberDefault;
                                  }
                                  if (companyAuthorizationController.text
                                      .trim()
                                      .isEmpty) {
                                    companyAuthorizationController.text = latest
                                            .companyFgasAuthorizationNumber
                                            .trim()
                                            .isNotEmpty
                                        ? latest.companyFgasAuthorizationNumber
                                        : _agfrAuthNumberDefault;
                                  }
                                }
                                selectedWeighingReportId = '';
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 420,
                            child: DropdownButtonFormField<String>(
                              initialValue: _interventions.any(
                                (item) => item.id == selectedInterventionId,
                              )
                                  ? selectedInterventionId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Interventie AGFR',
                              ),
                              items: _interventions
                                  .where(
                                    (item) =>
                                        selectedEquipmentId.trim().isEmpty ||
                                        item.equipmentId == selectedEquipmentId,
                                  )
                                  .map(
                                    (intervention) => DropdownMenuItem<String>(
                                      value: intervention.id,
                                      child: Text(
                                        '${intervention.operationType.label} | ${intervention.clientName} | ${_formatDate(intervention.operationDate)}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) => setDialogState(() {
                                selectedInterventionId = (value ?? '').trim();
                                final intervention =
                                    _interventionById(selectedInterventionId);
                                if (intervention != null) {
                                  selectedEquipmentId =
                                      intervention.equipmentId;
                                  selectedClientId = intervention.clientId;
                                  selectedJobId = intervention.jobId;
                                  selectedOperationDate =
                                      intervention.operationDate;
                                }
                                selectedWeighingReportId = '';
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (selectedIntervention == null &&
                          selectedEquipmentId.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Nu exista inca o interventie AGFR pentru echipamentul selectat. Adauga mai intai interventia, apoi creeaza PV-ul.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: reportNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Număr document',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedOperationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedOperationDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                'Data: ${_formatDate(selectedOperationDate)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 280,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Client / beneficiar',
                              ),
                              child: Text(
                                _clientNameById(selectedClientId).trim().isEmpty
                                    ? '-'
                                    : _clientNameById(selectedClientId),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Echipament',
                              ),
                              child: Text(
                                selectedEquipment == null
                                    ? '-'
                                    : _equipmentSummary(selectedEquipment.id),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Lucrare',
                              ),
                              child: Text(_jobLabel(selectedJobId)),
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: DropdownButtonFormField<String>(
                              initialValue: _weighingReports.any(
                                (item) => item.id == selectedWeighingReportId,
                              )
                                  ? selectedWeighingReportId
                                  : '',
                              decoration: const InputDecoration(
                                labelText: 'Raport cantarire AGFR',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Neasociat'),
                                ),
                                ..._weighingReports
                                    .where(
                                      (item) =>
                                          selectedIntervention == null ||
                                          item.interventionId ==
                                              selectedIntervention.id,
                                    )
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item.id,
                                        child: Text(
                                          '${item.sourceType.label} | ${item.sourceFileName.trim().isEmpty ? _formatDate(item.operationDate) : item.sourceFileName.trim()}',
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedWeighingReportId = (value ?? '').trim();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: beneficiaryRepresentativeController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Reprezentant beneficiar',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: technicianNameController,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Tehnician F-GAS',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: technicianCertificateController,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Nr. certificat F-GAS tehnician',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: companyAuthorizationController,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Nr. autorizatie F-GAS societate',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: observationsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Constatari generale / observatii',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: conclusionsController,
                        maxLines: 3,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Concluzii',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: companyCertificatePathController,
                              decoration: const InputDecoration(
                                labelText: 'Certificat F-GAS firma',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final path = await _pickAttachmentPath();
                              if (path.isEmpty) {
                                return;
                              }
                              setDialogState(() {
                                companyCertificatePathController.text = path;
                              });
                            },
                            icon: const Icon(Icons.attach_file_outlined),
                            label: const Text('Alege fisier'),
                          ),
                        ],
                      ),
                      if (companyCertificatePathController.text
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildCertificatePreview(
                              companyCertificatePathController.text),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: technicianCertificatePathController,
                              decoration: const InputDecoration(
                                labelText: 'Certificat F-GAS tehnician',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final path = await _pickAttachmentPath();
                              if (path.isEmpty) {
                                return;
                              }
                              setDialogState(() {
                                technicianCertificatePathController.text = path;
                              });
                            },
                            icon: const Icon(Icons.attach_file_outlined),
                            label: const Text('Alege fisier'),
                          ),
                        ],
                      ),
                      if (technicianCertificatePathController.text
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildCertificatePreview(
                              technicianCertificatePathController.text),
                        ),
                      const SizedBox(height: 16),
                      _buildPvCompliancePanel(
                        selectedInterventionId: selectedInterventionId,
                        selectedEquipmentId: selectedEquipmentId,
                        technicianName: technicianNameController.text,
                        technicianCertificateNumber:
                            technicianCertificateController.text,
                        companyAuthorizationNumber:
                            companyAuthorizationController.text,
                        beneficiaryRepresentative:
                            beneficiaryRepresentativeController.text,
                        selectedWeighingReportId: selectedWeighingReportId,
                        companyCertificatePath:
                            companyCertificatePathController.text,
                        technicianCertificatePath:
                            technicianCertificatePathController.text,
                        conclusions: conclusionsController.text,
                        clientSignatureBase64: clientSignatureBase64,
                        technicianSignatureBase64: technicianSignatureBase64,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 320,
                            child: _signatureCard(
                              title: 'Semnatura beneficiar',
                              signatureBase64: clientSignatureBase64,
                              onSign: () async {
                                final encoded = await _captureSignature(
                                  'Semnatura beneficiar AGFR',
                                );
                                if (encoded.isEmpty) {
                                  return;
                                }
                                setDialogState(() {
                                  clientSignatureBase64 = encoded;
                                });
                              },
                              onClear: () => setDialogState(() {
                                clientSignatureBase64 = '';
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: _signatureCard(
                              title: 'Semnatura tehnician',
                              signatureBase64: technicianSignatureBase64,
                              onSign: () async {
                                final encoded = await _captureSignature(
                                  'Semnatura tehnician AGFR',
                                );
                                if (encoded.isEmpty) {
                                  return;
                                }
                                setDialogState(() {
                                  technicianSignatureBase64 = encoded;
                                });
                              },
                              onClear: () => setDialogState(() {
                                technicianSignatureBase64 = '';
                              }),
                            ),
                          ),
                        ],
                      ),
                      if ((formError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Renunță'),
                ),
                FilledButton(
                  onPressed: () async {
                    final selectedIntervention =
                        _interventionById(selectedInterventionId);
                    final selectedEquipment = selectedIntervention == null
                        ? _equipmentById(selectedEquipmentId)
                        : _equipmentById(selectedIntervention.equipmentId);
                    if (selectedIntervention == null ||
                        selectedEquipment == null) {
                      setDialogState(() {
                        formError = 'Selecteaza interventia AGFR.';
                      });
                      return;
                    }
                    if (technicianNameController.text.trim().isEmpty) {
                      setDialogState(() {
                        formError = 'Completeaza tehnicianul F-GAS.';
                      });
                      return;
                    }
                    if (technicianCertificateController.text.trim().isEmpty) {
                      setDialogState(() {
                        formError =
                            'Completeaza numarul certificatului F-GAS al tehnicianului.';
                      });
                      return;
                    }
                    if (companyAuthorizationController.text.trim().isEmpty) {
                      setDialogState(() {
                        formError =
                            'Completeaza numarul autorizatiei F-GAS al societatii.';
                      });
                      return;
                    }
                    final reportNumber =
                        reportNumberController.text.trim().isEmpty
                            ? await _defaultReportNumber(selectedOperationDate)
                            : reportNumberController.text.trim();
                    final item = AgfrReportRecord(
                      id: current?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      equipmentId: selectedEquipment.id,
                      interventionId: selectedIntervention.id,
                      clientId: selectedIntervention.clientId,
                      jobId: selectedJobId.trim().isEmpty
                          ? selectedIntervention.jobId
                          : selectedJobId.trim(),
                      reportNumber: reportNumber,
                      operationDate: selectedOperationDate,
                      beneficiaryRepresentative:
                          beneficiaryRepresentativeController.text.trim(),
                      technicianName: technicianNameController.text.trim(),
                      technicianCertificateNumber:
                          technicianCertificateController.text.trim(),
                      companyFgasAuthorizationNumber:
                          companyAuthorizationController.text.trim(),
                      observations: observationsController.text.trim(),
                      conclusions: conclusionsController.text.trim(),
                      clientSignatureBase64: clientSignatureBase64,
                      technicianSignatureBase64: technicianSignatureBase64,
                      companyCertificateAttachmentPath:
                          companyCertificatePathController.text.trim(),
                      technicianCertificateAttachmentPath:
                          technicianCertificatePathController.text.trim(),
                      documentType: current?.documentType ?? 'pv_agfr',
                      sourceModule: current?.sourceModule ?? 'agfr',
                      weighingReportId: selectedWeighingReportId,
                      generatedDocumentPath:
                          current?.generatedDocumentPath ?? '',
                      generatedDocumentFileName:
                          current?.generatedDocumentFileName ?? '',
                      registryEntryId: current?.registryEntryId ?? '',
                      createdAt: current?.createdAt ?? now,
                      updatedAt: DateTime.now(),
                    );
                    await widget.repository.saveAgfrReport(item);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Salveaza'),
                ),
              ],
            );
          },
        );
      },
    );

    reportNumberController.dispose();
    beneficiaryRepresentativeController.dispose();
    technicianNameController.dispose();
    technicianCertificateController.dispose();
    companyAuthorizationController.dispose();
    observationsController.dispose();
    conclusionsController.dispose();
    companyCertificatePathController.dispose();
    technicianCertificatePathController.dispose();

    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _openWeighingReportForm({
    AgfrWeighingReportRecord? current,
    String seedInterventionId = '',
    String seedReportId = '',
  }) async {
    final now = DateTime.now();
    String selectedInterventionId =
        current?.interventionId ?? seedInterventionId;
    String selectedEquipmentId = current?.equipmentId ?? '';
    String selectedClientId = current?.clientId ?? '';
    String selectedJobId = current?.jobId ?? '';
    String selectedReportId = current?.reportId ?? seedReportId;
    DateTime selectedOperationDate = current?.operationDate ?? now;
    AgfrWeighingSourceType selectedSourceType =
        current?.sourceType ?? AgfrWeighingSourceType.manual;
    final sourceFilePathController = TextEditingController(
      text: current?.sourceFilePath ?? '',
    );
    final sourceFileNameController = TextEditingController(
      text: current?.sourceFileName ?? '',
    );
    final sourceDeviceInfoController = TextEditingController(
      text: current?.sourceDeviceInfo ?? '',
    );
    final originalPdfPathController = TextEditingController(
      text: current?.originalPdfAttachmentPath ?? '',
    );
    final originalPdfNameController = TextEditingController(
      text: current?.originalPdfAttachmentFileName ?? '',
    );
    final initialWeightController = TextEditingController(
      text: current == null ? '' : current.initialWeightKg.toStringAsFixed(2),
    );
    final finalWeightController = TextEditingController(
      text: current == null ? '' : current.finalWeightKg.toStringAsFixed(2),
    );
    final chargedController = TextEditingController(
      text: current == null ? '' : current.chargedKg.toStringAsFixed(2),
    );
    final recoveredController = TextEditingController(
      text: current == null ? '' : current.recoveredKg.toStringAsFixed(2),
    );
    final netQuantityController = TextEditingController(
      text: current == null ? '' : current.netQuantityKg.toStringAsFixed(2),
    );
    final scaleIdentifierController = TextEditingController(
      text: current?.scaleIdentifier ?? '',
    );
    final cylinderIdentifierController = TextEditingController(
      text: current?.cylinderIdentifier ?? '',
    );
    final sourceRawPayloadController = TextEditingController(
      text: current?.sourceRawPayload ?? '',
    );
    final notesController = TextEditingController(text: current?.notes ?? '');
    DateTime? measurementTimestamp = current?.measurementTimestamp;
    DateTime? sourceImportedAt = current?.sourceImportedAt;
    List<String> importWarnings = const <String>[];
    String? formError;

    Future<void> importCsv(StateSetter setDialogState) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const <String>['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setDialogState(() {
          formError = 'Nu am putut citi CSV-ul selectat.';
        });
        return;
      }
      final csvText = utf8.decode(bytes, allowMalformed: true);
      final imported = AgfrWeighingImportService.importTestoCsv(
        csvText: csvText,
        filePath: file.path?.trim() ?? '',
        fileName: file.name.trim(),
        seed: AgfrWeighingReportRecord(
          id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          reportId: selectedReportId,
          equipmentId: selectedEquipmentId,
          interventionId: selectedInterventionId,
          clientId: selectedClientId,
          jobId: selectedJobId,
          operationDate: selectedOperationDate,
          sourceType: selectedSourceType,
          sourceFilePath: sourceFilePathController.text.trim(),
          sourceFileName: sourceFileNameController.text.trim(),
          sourceImportedAt: sourceImportedAt,
          sourceDeviceInfo: sourceDeviceInfoController.text.trim(),
          sourceRawPayload: sourceRawPayloadController.text,
          originalPdfAttachmentPath: originalPdfPathController.text.trim(),
          originalPdfAttachmentFileName: originalPdfNameController.text.trim(),
          measurementTimestamp: measurementTimestamp,
          initialWeightKg: _parseDouble(initialWeightController.text),
          finalWeightKg: _parseDouble(finalWeightController.text),
          chargedKg: _parseDouble(chargedController.text),
          recoveredKg: _parseDouble(recoveredController.text),
          netQuantityKg: _parseDouble(netQuantityController.text),
          scaleIdentifier: scaleIdentifierController.text.trim(),
          cylinderIdentifier: cylinderIdentifierController.text.trim(),
          notes: notesController.text.trim(),
          createdAt: current?.createdAt ?? now,
          updatedAt: DateTime.now(),
        ),
      );
      setDialogState(() {
        selectedSourceType = imported.record.sourceType;
        sourceFilePathController.text = imported.record.sourceFilePath;
        sourceFileNameController.text = imported.record.sourceFileName;
        sourceDeviceInfoController.text = imported.record.sourceDeviceInfo;
        sourceRawPayloadController.text = imported.record.sourceRawPayload;
        initialWeightController.text = imported.record.initialWeightKg == 0
            ? ''
            : imported.record.initialWeightKg.toStringAsFixed(2);
        finalWeightController.text = imported.record.finalWeightKg == 0
            ? ''
            : imported.record.finalWeightKg.toStringAsFixed(2);
        chargedController.text = imported.record.chargedKg == 0
            ? ''
            : imported.record.chargedKg.toStringAsFixed(2);
        recoveredController.text = imported.record.recoveredKg == 0
            ? ''
            : imported.record.recoveredKg.toStringAsFixed(2);
        netQuantityController.text = imported.record.netQuantityKg == 0
            ? ''
            : imported.record.netQuantityKg.toStringAsFixed(2);
        scaleIdentifierController.text = imported.record.scaleIdentifier;
        cylinderIdentifierController.text = imported.record.cylinderIdentifier;
        measurementTimestamp = imported.record.measurementTimestamp;
        sourceImportedAt = imported.record.sourceImportedAt;
        importWarnings = imported.warnings;
        formError = null;
      });
    }

    Future<void> attachPdf(StateSetter setDialogState) async {
      final path = await _pickAttachmentPath();
      if (path.isEmpty) {
        return;
      }
      setDialogState(() {
        final fileName = _fileNameFromPath(path);
        originalPdfPathController.text = path;
        originalPdfNameController.text = fileName;
        if (sourceFilePathController.text.trim().isEmpty) {
          sourceFilePathController.text = path;
        }
        if (sourceFileNameController.text.trim().isEmpty) {
          sourceFileNameController.text = fileName;
        }
        sourceImportedAt ??= DateTime.now();
        if (selectedSourceType != AgfrWeighingSourceType.testoCsv) {
          selectedSourceType = AgfrWeighingSourceType.testoPdf;
        }
      });
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedIntervention =
                _interventionById(selectedInterventionId);
            if (selectedIntervention != null) {
              selectedEquipmentId = selectedIntervention.equipmentId;
              selectedClientId = selectedIntervention.clientId;
              if (selectedJobId.trim().isEmpty) {
                selectedJobId = selectedIntervention.jobId;
              }
              if (selectedReportId.trim().isEmpty) {
                for (final report in _reports) {
                  if (report.interventionId == selectedIntervention.id) {
                    selectedReportId = report.id;
                    break;
                  }
                }
              }
              if (current == null) {
                selectedOperationDate = selectedIntervention.operationDate;
              }
            }
            return AlertDialog(
              title: Text(
                current == null
                    ? 'Raport cantarire AGFR nou'
                    : 'Editeaza raport cantarire AGFR',
              ),
              content: SizedBox(
                width: 900,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 320,
                            child: DropdownButtonFormField<String>(
                              initialValue: _interventions.any(
                                (item) => item.id == selectedInterventionId,
                              )
                                  ? selectedInterventionId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Interventie AGFR',
                              ),
                              items: _interventions
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item.id,
                                      child: Text(
                                        '${item.operationType.label} | ${item.clientName} | ${_formatDate(item.operationDate)}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) => setDialogState(() {
                                selectedInterventionId = (value ?? '').trim();
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: DropdownButtonFormField<String>(
                              initialValue: _reports.any(
                                (item) => item.id == selectedReportId,
                              )
                                  ? selectedReportId
                                  : '',
                              decoration: const InputDecoration(
                                labelText: 'Proces-verbal AGFR (optional)',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Neasociat'),
                                ),
                                ..._reports.map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item.id,
                                    child: Text(
                                      item.reportNumber.trim().isEmpty
                                          ? item.id
                                          : item.reportNumber.trim(),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(() {
                                selectedReportId = (value ?? '').trim();
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedOperationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setDialogState(() {
                                  selectedOperationDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                'Data: ${_formatDate(selectedOperationDate)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => importCsv(setDialogState),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Importa CSV Testo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => attachPdf(setDialogState),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Ataseaza PDF Testo'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.source_outlined, size: 16),
                            label: Text('Sursa: ${selectedSourceType.label}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (importWarnings.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(importWarnings.join('\n')),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: sourceFileNameController,
                              decoration: const InputDecoration(
                                labelText: 'Fisier sursa',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 280,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: sourceDeviceInfoController,
                              decoration: const InputDecoration(
                                labelText: 'Device / cantar',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: measurementTimestamp ??
                                      selectedOperationDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked == null) {
                                  return;
                                }
                                setDialogState(() {
                                  measurementTimestamp = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              },
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(
                                measurementTimestamp == null
                                    ? 'Moment masurare'
                                    : _formatDate(measurementTimestamp!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _numberField(
                            controller: initialWeightController,
                            label: 'Greutate initiala kg',
                            width: 180,
                          ),
                          _numberField(
                            controller: finalWeightController,
                            label: 'Greutate finala kg',
                            width: 180,
                          ),
                          _numberField(
                            controller: chargedController,
                            label: 'Cantitate incarcata kg',
                            width: 180,
                          ),
                          _numberField(
                            controller: recoveredController,
                            label: 'Cantitate recuperata kg',
                            width: 180,
                          ),
                          _numberField(
                            controller: netQuantityController,
                            label: 'Cantitate neta kg',
                            width: 160,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: scaleIdentifierController,
                              decoration: const InputDecoration(
                                labelText: 'Identificare cantar',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: cylinderIdentifierController,
                              decoration: const InputDecoration(
                                labelText: 'Identificare butelie / recipient',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: originalPdfPathController,
                              decoration: const InputDecoration(
                                labelText: 'PDF original Testo',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => attachPdf(setDialogState),
                            icon: const Icon(Icons.attach_file_outlined),
                            label: const Text('Alege PDF'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observatii / corectii manuale',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: sourceRawPayloadController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Payload CSV brut',
                        ),
                      ),
                      if ((formError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Renunță'),
                ),
                FilledButton(
                  onPressed: () async {
                    final selectedIntervention =
                        _interventionById(selectedInterventionId);
                    if (selectedIntervention == null) {
                      setDialogState(() {
                        formError = 'Selecteaza interventia AGFR.';
                      });
                      return;
                    }
                    final filePath = sourceFilePathController.text.trim();
                    final fileName = sourceFileNameController.text.trim();
                    final originalPdfPath =
                        originalPdfPathController.text.trim();
                    final item = AgfrWeighingReportRecord(
                      id: current?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      reportId: selectedReportId,
                      equipmentId: selectedIntervention.equipmentId,
                      interventionId: selectedIntervention.id,
                      clientId: selectedIntervention.clientId,
                      jobId: selectedJobId.trim().isEmpty
                          ? selectedIntervention.jobId
                          : selectedJobId.trim(),
                      operationDate: selectedOperationDate,
                      sourceType: selectedSourceType,
                      sourceFilePath: filePath,
                      sourceFileName: fileName,
                      sourceImportedAt: sourceImportedAt,
                      sourceDeviceInfo: sourceDeviceInfoController.text.trim(),
                      sourceRawPayload: sourceRawPayloadController.text,
                      originalPdfAttachmentPath: originalPdfPath,
                      originalPdfAttachmentFileName:
                          originalPdfNameController.text.trim().isEmpty
                              ? _fileNameFromPath(originalPdfPath)
                              : originalPdfNameController.text.trim(),
                      measurementTimestamp: measurementTimestamp,
                      initialWeightKg:
                          _parseDouble(initialWeightController.text),
                      finalWeightKg: _parseDouble(finalWeightController.text),
                      chargedKg: _parseDouble(chargedController.text),
                      recoveredKg: _parseDouble(recoveredController.text),
                      netQuantityKg: _parseDouble(netQuantityController.text),
                      scaleIdentifier: scaleIdentifierController.text.trim(),
                      cylinderIdentifier:
                          cylinderIdentifierController.text.trim(),
                      notes: notesController.text.trim(),
                      createdAt: current?.createdAt ?? now,
                      updatedAt: DateTime.now(),
                    );
                    await widget.repository.saveAgfrWeighingReport(item);
                    if (selectedReportId.trim().isNotEmpty) {
                      AgfrReportRecord? linkedReport;
                      for (final report in _reports) {
                        if (report.id == selectedReportId.trim()) {
                          linkedReport = report;
                          break;
                        }
                      }
                      if (linkedReport != null) {
                        await widget.repository.saveAgfrReport(
                          linkedReport.copyWith(
                            weighingReportId: item.id,
                            updatedAt: DateTime.now(),
                          ),
                        );
                      }
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Salveaza'),
                ),
              ],
            );
          },
        );
      },
    );

    sourceFilePathController.dispose();
    sourceFileNameController.dispose();
    sourceDeviceInfoController.dispose();
    originalPdfPathController.dispose();
    originalPdfNameController.dispose();
    initialWeightController.dispose();
    finalWeightController.dispose();
    chargedController.dispose();
    recoveredController.dispose();
    netQuantityController.dispose();
    scaleIdentifierController.dispose();
    cylinderIdentifierController.dispose();
    sourceRawPayloadController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _generateReportPdf({
    required AgfrReportRecord report,
    required bool share,
    bool saveAs = false,
  }) async {
    final intervention = _interventionById(report.interventionId);
    final equipment = _equipmentById(report.equipmentId) ??
        (intervention == null
            ? null
            : _equipmentById(intervention.equipmentId));
    if (intervention == null || equipment == null) {
      _snack(
        'Raportul AGFR nu poate fi generat pentru ca lipseste interventia sau echipamentul asociat.',
      );
      return;
    }

    try {
      final company = await widget.repository.loadCompanyProfile();
      if (!mounted) return;
      final client = _clientById(report.clientId);
      final job = _jobById(report.jobId);
      final weighingReport = _weighingReportById(report.weighingReportId);
      if (share) {
        final defaultTo = client?.email.trim() ?? '';
        final subject =
            'Proces-verbal AGFR ${report.reportNumber.trim().isEmpty ? report.id : report.reportNumber.trim()}';
        final body =
            'Buna ziua,\n\nAtasat gasiti proces-verbalul AGFR.\n\nCu stima,';
        final result = await showDialog<Map<String, String>?>(
          context: context,
          builder: (_) => SendDocumentDialog(
            to: defaultTo,
            subject: subject,
            body: body,
          ),
        );
        if (result == null) return;
        final action = result['action'] ?? 'cancel';
        if (action == 'cancel') return;
        if (action == 'mailto') {
          await AgfrReportPdfService.share(
            company: company,
            report: report,
            equipment: equipment,
            intervention: intervention,
            weighingReport: weighingReport,
            client: client,
            job: job,
          );
          if (!mounted) return;
          _snack('Share deschis pentru procesul-verbal AGFR.');
          return;
        }
        if (action == 'queue') {
          try {
            final path = await AgfrReportPdfService.export(
              repository: widget.repository,
              company: company,
              report: report,
              equipment: equipment,
              intervention: intervention,
              weighingReport: weighingReport,
              client: client,
              job: job,
            );
            final inlineAssets = <Map<String, dynamic>>[];
            if (company.logoBase64.trim().isNotEmpty) {
              inlineAssets.add({
                'cid': 'companylogo',
                'filename': 'logo.png',
                'base64': company.logoBase64.trim(),
                'contentType': 'image/png',
              });
            }
            final notif = NotificationCenterService();
            final attachments = [
              await _buildQueueAttachmentFromFile(
                filePath: path,
                fileName: '${report.id}.pdf',
                sourceModule: 'agfr',
                sourceEntityId: report.id,
              ),
            ];
            final queueItem = await notif.sendEmailNotification(
              recipientEmail: result['to'] ?? defaultTo,
              recipientName: client?.name ?? '',
              subject: result['subject'] ?? subject,
              bodyText: result['body'] ?? body,
              bodyHtml: agfrReportHtml(
                recipientName: result['to'] ?? client?.name ?? '',
                companyName: company.companyName,
                reportNumber: report.reportNumber,
                message: result['body'] ?? body,
              ),
              attachments: attachments,
              inlineAssets: inlineAssets,
              sourceModule: 'agfr',
              sourceEntityId: report.id,
              eventType: NotificationEventType.documentGenerated,
              metadata: {'agfr_id': report.id},
            );
            _snack(
              'Email pus in coada: ${queueItem.id}. Statusul final se vede in Notificari / Email log.',
            );
          } catch (e) {
            _snack('Eroare la punerea in coada: $e');
          }
        }
        return;
      }

      final path = await AgfrReportPdfService.export(
        repository: widget.repository,
        company: company,
        report: report,
        equipment: equipment,
        intervention: intervention,
        weighingReport: weighingReport,
        client: client,
        job: job,
        saveAs: saveAs,
      );
      var updated = report.copyWith(
        generatedDocumentPath: path,
        generatedDocumentFileName: _fileNameFromPath(path),
        updatedAt: DateTime.now(),
      );
      var message = 'PDF AGFR generat: $path';

      if (updated.registryEntryId.trim().isEmpty) {
        try {
          final entry = await widget.repository.registerGeneratedDocument(
            registryType: RegistryType.iesire,
            documentCategory: 'Proces verbal AGFR',
            documentTitle:
                'Proces-verbal AGFR ${updated.reportNumber.trim().isEmpty ? updated.id : updated.reportNumber.trim()}',
            documentNumber: updated.reportNumber.trim().isEmpty
                ? updated.id
                : updated.reportNumber.trim(),
            documentDate: updated.operationDate,
            clientId: updated.clientId,
            jobId: updated.jobId,
            recipientName: updated.beneficiaryRepresentative.trim().isEmpty
                ? _clientNameById(updated.clientId)
                : updated.beneficiaryRepresentative.trim(),
            filePath: path,
            fileName: _fileNameFromPath(path),
            notes: 'Document generat din modulul AGFR / F-GAS',
            status: 'emis',
          );
          updated = updated.copyWith(
            registryEntryId: entry.id,
            registryNumber: entry.registryNumber,
            updatedAt: DateTime.now(),
          );
          message =
              'PDF AGFR generat si inregistrat in Registratura (${entry.registryNumber}).';
        } catch (error) {
          message =
              'PDF AGFR generat, dar inregistrarea in Registratura a esuat: $error';
        }
      }

      await widget.repository.saveAgfrReport(updated);
      await _load();
      if (!mounted) return;
      _snack(saveAs ? '$message (Save As).' : message);
      await _showGeneratedAgfrPdfActions(path);
    } on PdfSaveCanceledException {
      _snack('Salvarea documentului a fost anulata.');
    } catch (error) {
      _snack('Nu am putut genera PDF-ul AGFR: $error');
    }
  }

  Future<void> _showGeneratedAgfrPdfActions(String filePath) async {
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
                  'PDF proces-verbal AGFR generat',
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
                        if (result.shouldOfferShare) {
                          await DocumentFileService.shareFile(
                            filePath,
                            subject: 'Proces-verbal AGFR',
                            text: 'Proces-verbal AGFR generat din aplicatie.',
                          );
                        } else if (!result.opened) {
                          _snack(result.message);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await DocumentFileService.shareFile(
                          filePath,
                          subject: 'Proces-verbal AGFR',
                          text: 'Proces-verbal AGFR generat din aplicatie.',
                        );
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
                          _snack(
                            opened
                                ? 'Folder deschis.'
                                : 'Nu am putut deschide folderul.',
                          );
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: filePath),
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                          _snack('Calea PDF a fost copiata.');
                        }
                      },
                      icon: const Icon(Icons.content_copy_outlined),
                      label: const Text('Copiaza calea'),
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

  Future<Map<String, dynamic>> _buildQueueAttachmentFromFile({
    required String filePath,
    required String fileName,
    required String sourceModule,
    required String sourceEntityId,
  }) async {
    final file = File(filePath.trim());
    if (!file.existsSync()) {
      throw StateError('Fisierul atasat nu exista: $filePath');
    }
    final bytes = await file.readAsBytes();
    final normalizedName = _sanitizeAttachmentFileName(fileName);
    if (bytes.length <= _maxInlineAttachmentBytes) {
      return <String, dynamic>{
        'filename': normalizedName,
        'base64': base64Encode(bytes),
        'content_type': 'application/pdf',
        'size_bytes': bytes.length,
      };
    }

    final safeEntity = sourceEntityId.trim().isEmpty
        ? 'unknown'
        : sourceEntityId.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final storagePath =
        'notification_email_attachments/$sourceModule/$safeEntity/${DateTime.now().millisecondsSinceEpoch}_$normalizedName';
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } catch (e) {
      debugPrint('[AGFR] ❌ Storage upload failed: $e');
      rethrow;
    }
    return <String, dynamic>{
      'filename': normalizedName,
      'storage_path': ref.fullPath,
      'storage_bucket': ref.bucket,
      'content_type': 'application/pdf',
      'size_bytes': bytes.length,
      'encoding': 'firebase_storage',
    };
  }

  String _sanitizeAttachmentFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) return 'document.pdf';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  Future<void> _openFieldPhotosForReport(AgfrReportRecord report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldPhotosPage(
          repository: widget.repository,
          sourceModule: 'agfr',
          sourceEntityId: report.id,
          title: 'Poze teren AGFR',
        ),
      ),
    );
  }

  String _fileNameFromPath(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last.trim();
  }

  Widget _buildPvCompliancePanel({
    required String selectedInterventionId,
    required String selectedEquipmentId,
    required String technicianName,
    required String technicianCertificateNumber,
    required String companyAuthorizationNumber,
    required String beneficiaryRepresentative,
    required String selectedWeighingReportId,
    required String companyCertificatePath,
    required String technicianCertificatePath,
    required String conclusions,
    required String clientSignatureBase64,
    required String technicianSignatureBase64,
  }) {
    final intervention = _interventionById(selectedInterventionId);
    final equipment = intervention != null
        ? _equipmentById(intervention.equipmentId)
        : _equipmentById(selectedEquipmentId);

    final needsWeighing = intervention != null &&
        (intervention.operationType == AgfrInterventionType.incarcare ||
            intervention.operationType == AgfrInterventionType.recuperare ||
            intervention.operationType == AgfrInterventionType.completare);

    final needsLeakCheck = intervention != null &&
        (intervention.operationType ==
                AgfrInterventionType.verificareEtanseitate ||
            intervention.operationType == AgfrInterventionType.service ||
            intervention.operationType == AgfrInterventionType.mentenanta);

    final equipmentComplete = equipment != null &&
        equipment.brand.trim().isNotEmpty &&
        equipment.model.trim().isNotEmpty &&
        equipment.serialNumber.trim().isNotEmpty &&
        equipment.refrigerantType.trim().isNotEmpty &&
        equipment.totalChargeKg > 0;

    final leakCheckRecorded =
        intervention != null && intervention.leakCheckResult != null;

    final items = <_AgfrComplianceItem>[
      _AgfrComplianceItem(
        label: 'Interventie AGFR selectata',
        passed: intervention != null,
        blocking: true,
        hint: 'PV-ul trebuie legat de o interventie AGFR valida.',
      ),
      _AgfrComplianceItem(
        label:
            'Echipament identificat complet (brand, model, serie, refrigerant, masa)',
        passed: equipmentComplete,
        blocking: true,
        hint: 'Reg. (UE) 2024/573 impune identificarea completa a instalatiei.',
      ),
      _AgfrComplianceItem(
        label: 'Tehnician F-GAS autorizat (nume + nr. certificat)',
        passed: technicianName.trim().isNotEmpty &&
            technicianCertificateNumber.trim().isNotEmpty,
        blocking: true,
        hint:
            'Operatiunile F-GAS se efectueaza exclusiv de personal certificat.',
      ),
      _AgfrComplianceItem(
        label: 'Nr. autorizatie F-GAS societate',
        passed: companyAuthorizationNumber.trim().isNotEmpty,
        blocking: true,
        hint: 'Societatea trebuie sa detina autorizatie F-GAS valabila.',
      ),
      _AgfrComplianceItem(
        label: 'Reprezentant beneficiar completat',
        passed: beneficiaryRepresentative.trim().isNotEmpty,
        blocking: false,
        hint:
            'Recomandat pentru opozabilitate juridica si evidenta destinatarului.',
      ),
      _AgfrComplianceItem(
        label:
            'Raport de cantarire atasat${needsWeighing ? ' (OBLIGATORIU – incarcare/recuperare/completare)' : ''}',
        passed: selectedWeighingReportId.trim().isNotEmpty,
        blocking: needsWeighing,
        hint: needsWeighing
            ? 'Incarcare/recuperare/completare refrigerant impun cantarire documentata conform Reg. (UE) 2024/573.'
            : 'Recomandat pentru trasabilitate cantitativa a agentului frigorific.',
      ),
      if (needsLeakCheck)
        _AgfrComplianceItem(
          label: 'Rezultat verificare etanseitate inregistrat in interventie',
          passed: leakCheckRecorded,
          blocking: false,
          hint:
              'Verificarea de etanseitate trebuie sa mentioneze rezultatul (pass/fail) conform Art. 5 Reg. (UE) 2024/573.',
        ),
      _AgfrComplianceItem(
        label: 'Concluzii completate',
        passed: conclusions.trim().isNotEmpty,
        blocking: false,
        hint:
            'Concluziile documenteaza starea finala a instalatiei si recomandarile.',
      ),
      _AgfrComplianceItem(
        label: 'Anexa A – Certificat F-GAS firma (fisier atasat)',
        passed: companyCertificatePath.trim().isNotEmpty,
        blocking: false,
        hint:
            'Copia autorizatiei F-GAS a societatii sporeste valoarea probatorie a documentului.',
      ),
      _AgfrComplianceItem(
        label: 'Anexa A – Certificat F-GAS tehnician (fisier atasat)',
        passed: technicianCertificatePath.trim().isNotEmpty,
        blocking: false,
        hint:
            'Copia certificatului F-GAS al tehnicianului este ceruta de Reg. (UE) 2024/573.',
      ),
      _AgfrComplianceItem(
        label: 'Semnatura beneficiar colectata',
        passed: clientSignatureBase64.trim().isNotEmpty,
        blocking: false,
        hint:
            'Semnatura beneficiarului confirma receptionarea si acceptarea lucrarii.',
      ),
      _AgfrComplianceItem(
        label: 'Semnatura tehnician colectata',
        passed: technicianSignatureBase64.trim().isNotEmpty,
        blocking: false,
        hint: 'Semnatura tehnicianului autentifica documentul F-GAS.',
      ),
    ];

    final blockingFailed = items.where((i) => i.blocking && !i.passed).length;
    final optionalFailed = items.where((i) => !i.blocking && !i.passed).length;
    final allPassed = blockingFailed == 0 && optionalFailed == 0;

    final headerColor = blockingFailed > 0
        ? Colors.red.shade700
        : optionalFailed > 0
            ? Colors.orange.shade700
            : Colors.green.shade700;

    final statusText = allPassed
        ? 'Documentul este complet din punct de vedere juridic F-GAS'
        : blockingFailed > 0
            ? '$blockingFailed element${blockingFailed > 1 ? 'e obligatorii lipsesc' : ' obligatoriu lipseste'} – documentul NU poate fi generat PDF'
            : '$optionalFailed element${optionalFailed > 1 ? 'e recomandate lipsesc' : ' recomandat lipseste'} – documentul poate fi generat';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: headerColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: blockingFailed > 0 || optionalFailed > 0,
          leading: Icon(
            allPassed
                ? Icons.verified_outlined
                : blockingFailed > 0
                    ? Icons.gpp_bad_outlined
                    : Icons.warning_amber_outlined,
            color: headerColor,
          ),
          title: Text(
            'Conformitate juridica F-GAS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: headerColor,
            ),
          ),
          subtitle: Text(
            statusText,
            style: TextStyle(color: headerColor, fontSize: 12),
          ),
          children: items.map((item) {
            final iconData = item.passed
                ? Icons.check_circle_outline
                : item.blocking
                    ? Icons.cancel_outlined
                    : Icons.info_outline;
            final color = item.passed
                ? Colors.green.shade600
                : item.blocking
                    ? Colors.red.shade600
                    : Colors.orange.shade700;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconData, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: item.passed
                                ? null
                                : item.blocking
                                    ? Colors.red.shade700
                                    : Colors.orange.shade800,
                            fontWeight: item.blocking && !item.passed
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                        if (!item.passed && item.hint.trim().isNotEmpty)
                          Text(
                            item.hint,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatePreview(String filePath) {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fișierul nu a fost găsit: $normalizedPath',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }

      final extension = normalizedPath.split('.').last.toLowerCase();
      final isPdf = extension == 'pdf';
      final isImage = const <String>{'png', 'jpg', 'jpeg', 'webp', 'gif'}
          .contains(extension);

      if (!isPdf && !isImage) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tip fișier nesuportat: $extension. Utilizați PDF, PNG, JPG, WEBP sau GIF.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }

      // PDF Preview
      if (isPdf) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade400),
            borderRadius: BorderRadius.circular(6),
            color: Colors.blue.shade50,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  size: 40,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    'PDF încărcat',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Image Preview
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported,
                        color: Colors.grey.shade600),
                    const SizedBox(height: 4),
                    Text(
                      'Nu se poate încărca imaginea',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (error) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eroare la încărcarea fișierului: $error',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final equipments = _filteredEquipments;
    final interventions =
        _filteredInterventions.take(10).toList(growable: false);
    final reports = _filteredReports.take(10).toList(growable: false);
    final weighingReports =
        _filteredWeighingReports.take(10).toList(growable: false);
    final registeredReports =
        _reports.where((item) => item.registryEntryId.trim().isNotEmpty).length;

    return Scaffold(
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Adauga',
        onSelected: (value) {
          if (value == 'equipment') {
            _openEquipmentForm();
            return;
          }
          if (value == 'intervention') {
            _openInterventionForm();
            return;
          }
          if (value == 'report') {
            _openReportForm();
            return;
          }
          if (value == 'weighing') {
            _openWeighingReportForm();
          }
        },
        itemBuilder: (context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'equipment',
            child: ListTile(
              leading: Icon(Icons.precision_manufacturing_outlined),
              title: Text('Echipament AGFR'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'intervention',
            child: ListTile(
              leading: Icon(Icons.build_circle_outlined),
              title: Text('Interventie AGFR'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Proces-verbal AGFR'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem<String>(
            value: 'weighing',
            child: ListTile(
              leading: Icon(Icons.scale_outlined),
              title: Text('Raport cantarire AGFR'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        child: FloatingActionButton.extended(
          onPressed: null,
          label: const Text('Adauga'),
          icon: const Icon(Icons.add),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Registru intern AGFR / F-GAS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fundatia operationala pentru echipamente cu refrigerant, interventii si baza proceselor-verbale AGFR, separat de raportarea oficiala.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                'Echipamente',
                '${_equipments.length}',
                Icons.precision_manufacturing_outlined,
              ),
              _metricCard(
                'Interventii',
                '${_interventions.length}',
                Icons.build_circle_outlined,
              ),
              _metricCard(
                'PV AGFR',
                '${_reports.length}',
                Icons.description_outlined,
              ),
              _metricCard(
                'Rapoarte cantarire',
                '${_weighingReports.length}',
                Icons.scale_outlined,
              ),
              _metricCard(
                'In Registratura',
                '$registeredReports',
                Icons.library_books_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText:
                        'Cauta dupa client, serie, echipament, refrigerant, tehnician',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _openEquipmentForm(),
                icon: const Icon(Icons.precision_manufacturing_outlined),
                label: const Text('Echipament'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    _equipments.isEmpty ? null : () => _openInterventionForm(),
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Interventie'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    _interventions.isEmpty ? null : () => _openReportForm(),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Proces-verbal'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _interventions.isEmpty
                    ? null
                    : () => _openWeighingReportForm(),
                icon: const Icon(Icons.scale_outlined),
                label: const Text('Cantarire'),
              ),
              const SizedBox(width: 8),
              const HelpModuleButton(moduleId: 'agfr'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Echipamente / instalatii',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (equipments.isEmpty)
                    const Text('Nu exista echipamente AGFR salvate inca.')
                  else
                    ...equipments.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.ac_unit_outlined),
                        ),
                        title: Text(_equipmentSummary(item.id)),
                        subtitle: Text(
                          '${item.clientName} | ${_entityTypeLabel(item.entityType)} | ${item.equipmentCategory.label} | ${item.refrigerantType} | ${item.totalChargeKg.toStringAsFixed(2)} kg | ${item.location.trim().isEmpty ? '-' : item.location}',
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Acțiuni',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'intervention',
                              child: ListTile(
                                leading: Icon(Icons.playlist_add_outlined),
                                title: Text('Adaugă intervenție'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'report',
                              child: ListTile(
                                leading: Icon(Icons.description_outlined),
                                title: Text('Adaugă proces-verbal'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editează'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'intervention':
                                _openInterventionForm(seedEquipmentId: item.id);
                              case 'report':
                                _openReportForm(seedEquipmentId: item.id);
                              case 'edit':
                                _openEquipmentForm(current: item);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interventii recente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (interventions.isEmpty)
                    const Text('Nu exista interventii AGFR salvate inca.')
                  else
                    ...interventions.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.build_outlined),
                        ),
                        title: Text(
                          '${item.operationType.label} | ${item.clientName}',
                        ),
                        subtitle: Text(
                          '${_formatDate(item.operationDate)} | ${_equipmentSummary(item.equipmentId)}\n${item.refrigerantType} | Incarcat ${item.chargedKg.toStringAsFixed(2)} kg | Recuperat ${item.recoveredKg.toStringAsFixed(2)} kg',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Acțiuni',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'pv',
                              child: ListTile(
                                leading: Icon(Icons.description_outlined),
                                title: Text('Crează proces-verbal'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'weighing',
                              child: ListTile(
                                leading: Icon(Icons.scale_outlined),
                                title: Text('Adaugă raport cântărire'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editează'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'pv':
                                _openReportForm(seedInterventionId: item.id);
                              case 'weighing':
                                _openWeighingReportForm(
                                    seedInterventionId: item.id);
                              case 'edit':
                                _openInterventionForm(current: item);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapoarte cantarire AGFR',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (weighingReports.isEmpty)
                    const Text(
                        'Nu exista rapoarte de cantarire AGFR salvate inca.')
                  else
                    ...weighingReports.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.scale_outlined),
                        ),
                        title: Text(
                          item.sourceFileName.trim().isEmpty
                              ? '${item.sourceType.label} | ${_formatDate(item.operationDate)}'
                              : item.sourceFileName.trim(),
                        ),
                        subtitle: Text(
                          '${_clientNameById(item.clientId).trim().isEmpty ? '-' : _clientNameById(item.clientId)} | ${item.sourceType.label} | ${item.netQuantityKg.toStringAsFixed(2)} kg\nPDF Testo: ${item.originalPdfAttachmentFileName.trim().isEmpty ? 'neatasat' : item.originalPdfAttachmentFileName.trim()} | PV: ${_reportLabelById(item.reportId)}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Editeaza',
                              onPressed: () =>
                                  _openWeighingReportForm(current: item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Procese-verbale AGFR',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (reports.isEmpty)
                    const Text(
                        'Nu exista procese-verbale AGFR salvate pana in acest moment.')
                  else
                    ...reports.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(
                          item.reportNumber.trim().isEmpty
                              ? item.id
                              : item.reportNumber.trim(),
                        ),
                        subtitle: Text(
                          '${_formatDate(item.operationDate)} | ${_clientNameById(item.clientId).trim().isEmpty ? '-' : _clientNameById(item.clientId)} | ${_equipmentSummary(item.equipmentId)}\nRegistratura: ${item.registryEntryId.trim().isEmpty ? 'nealocat' : item.registryEntryId.trim()} | Anexa B: ${item.weighingReportId.trim().isEmpty ? 'neasociata' : 'asociata'} | PDF: ${item.generatedDocumentFileName.trim().isEmpty ? 'negenerat' : item.generatedDocumentFileName.trim()}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Acțiuni',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'pdf',
                              child: ListTile(
                                leading: Icon(Icons.picture_as_pdf_outlined),
                                title: Text('Generează PDF'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'save_as',
                              child: ListTile(
                                leading: Icon(Icons.save_as_outlined),
                                title: Text('Salvează ca...'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: ListTile(
                                leading: Icon(Icons.share_outlined),
                                title: Text('Share PDF'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'photos',
                              child: ListTile(
                                leading: Icon(Icons.photo_camera_outlined),
                                title: Text('Poze teren'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editează'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'pdf':
                                _generateReportPdf(report: item, share: false);
                              case 'save_as':
                                _generateReportPdf(
                                    report: item, share: false, saveAs: true);
                              case 'share':
                                _generateReportPdf(report: item, share: true);
                              case 'photos':
                                _openFieldPhotosForReport(item);
                              case 'edit':
                                _openReportForm(current: item);
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fundatie proces-verbal AGFR',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Procesul-verbal AGFR este pregatit pentru generare PDF operationala, cu formulare apropiata de modelele PV AGFR / PV AGFR CLIVET INEU. Documentul utilizeaza datele din echipament, interventie, client, lucrare si profil companie, include semnaturi, anexele documentare si mentine legatura cu Registratura.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar:
                            const Icon(Icons.description_outlined, size: 16),
                        label: Text('${_reports.length} procese-verbale'),
                      ),
                      const Chip(
                        avatar: Icon(Icons.verified_outlined, size: 16),
                        label: Text('Anexa A societate pregatita'),
                      ),
                      const Chip(
                        avatar: Icon(Icons.badge_outlined, size: 16),
                        label: Text('Anexa A tehnician pregatita'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.link_outlined, size: 16),
                        label: Text(
                            'Documente legate in Registratura: $registeredReports'),
                      ),
                      const Chip(
                        avatar: Icon(Icons.cloud_done_outlined, size: 16),
                        label: Text('Documentatie coerenta cross-device'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _parseDouble(String raw) {
  return double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;
}

class _AgfrComplianceItem {
  const _AgfrComplianceItem({
    required this.label,
    required this.passed,
    required this.blocking,
    this.hint = '',
  });
  final String label;
  final bool passed;
  final bool blocking;
  final String hint;
}
