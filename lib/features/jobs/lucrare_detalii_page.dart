// ignore_for_file: dead_code, unused_element, unused_local_variable, unused_field, prefer_final_locals, unnecessary_string_interpolations, no_leading_underscores_for_local_identifiers, unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/auth/app_role_policy.dart';
import '../../core/company_profile.dart';
import '../../core/app_models.dart';
import '../../core/local_store.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/document_file_service.dart';
import '../../core/pdf_document_branding.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';
import '../ai_assistant/ai_assistant_action_catalog.dart';
import '../ai_assistant/ai_assistant_models.dart';
import '../ai_assistant/ai_assistant_service.dart';
import '../ai_assistant/ai_assistant_sheet.dart';
import '../clients/client_models.dart';
import '../product_catalog/product_catalog_service.dart';
import '../product_catalog/product_sales_models.dart';
import '../product_catalog/warranty_certificate_editor_dialog.dart';
import '../product_catalog/warranty_certificate_pdf_service.dart';
import '../field_photos/field_photos_page.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_service.dart';
import '../notifications/send_document_dialog.dart';
import '../registratura/registry_models.dart';
import '../registratura/registry_store.dart';
import '../master/master_local_store.dart';
import '../partners/partner_models.dart';
import 'firebase_lucrari_repository.dart';
import 'firebase_job_site_documents_repository.dart';
import 'job_models.dart';
import 'deviz_lucrare_pdf_service.dart';
import '../../core/integrations/smartbill_service.dart';
import 'job_partner_models.dart';
import 'job_site_document_models.dart';
import 'job_site_document_services.dart';
import 'job_site_documents_cloud_repository.dart';
import 'job_site_documents_page.dart';
import 'lucrare_raport_page.dart';
import 'job_document_type_utils.dart';
import 'lucrare_raport_complet_page.dart';
import 'lucrari_cloud_repository.dart';
import 'situatie_lucrari_pdf_service.dart';
import 'contract_pdf_service.dart';
import '../../core/pdf_actions_helper.dart';
import '../oferte/local_oferte_repository.dart';
import '../oferte/offer_models.dart';
import '../deviz_tehnic/deviz_tehnic_models.dart';
import '../deviz_tehnic/deviz_tehnic_repository.dart';
import 'lucrare_detalii_models.dart';
import 'lucrare_detalii_widgets.dart';
import 'lucrare_format_utils.dart';
import 'lucrare_import_parser.dart';
import 'dialogs/partner_dialogs.dart';
import 'dialogs/beneficiary_dialogs.dart';
import 'dialogs/own_vehicle_dialog.dart';
import 'dialogs/contract_dialog.dart';
import 'dialogs/work_task_dialog.dart';

class LucrareDetaliiPage extends StatefulWidget {
  const LucrareDetaliiPage({
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
  State<LucrareDetaliiPage> createState() => _LucrareDetaliiPageState();
}

class _LucrareDetaliiPageState extends State<LucrareDetaliiPage> {
  static const int _maxInlineAttachmentBytes = 550 * 1024;

  bool get _isTechnician => AppRolePolicy.isTechnician(widget.roleKey);

  late JobRecord _jobSnapshot;
  LucrariCloudRepository? _cloudRepository;

  // --- Profit & Partener ---
  String _selectedProfitPartnerId = '';
  String _selectedProfitPartnerName = '';
  double _partnerProfitPercent = 0.0;
  double _partnerResources = 0.0;
  double _profitTaxPercent = 16.0;
  late TextEditingController _profitTaxCtrl;
  late TextEditingController _partnerProfitPercentCtrl;
  late TextEditingController _partnerResourcesCtrl;
  final ProductCatalogService _productCatalogService = ProductCatalogService();
  final NotificationCenterService _notificationService =
      NotificationCenterService();
  final JobSiteDocumentTemplateService _jobSiteDocumentTemplateService =
      const JobSiteDocumentTemplateService();
  bool _isRunningAi = false;

  late final AiAssistantService _aiAssistantService;

  List<AiAssistantQuickAction> get _jobAiActions {
    final contextual =
        AiAssistantActionCatalog.actionById('jobs_contextual_chat');
    final materialReception =
        AiAssistantActionCatalog.actionById('job_site_material_reception_pv');
    final finalReception =
        AiAssistantActionCatalog.actionById('job_site_final_reception_pv');

    final actions = <AiAssistantQuickAction>[
      if (contextual != null) contextual,
      if (materialReception != null)
        _remapAiAction(
          materialReception,
          id: 'job_details_material_reception_pv',
          defaultTargetKey: 'job_site_direct_pv_montaj',
        ),
      if (finalReception != null)
        _remapAiAction(
          finalReception,
          id: 'job_details_pif_ventilation',
          label: 'PV recepție finală / PIF ventilație',
          defaultPrompt:
              '${finalReception.defaultPrompt}\n\nȚintește explicit un document de tip PV PIF ventilație / recuperator.',
          defaultTargetKey: 'job_site_direct_pif_ventilation',
        ),
      if (finalReception != null)
        _remapAiAction(
          finalReception,
          id: 'job_details_pif_vrf',
          label: 'PV recepție finală / PIF VRF',
          defaultPrompt:
              '${finalReception.defaultPrompt}\n\nȚintește explicit un document de tip PV PIF VRF / climatizare.',
          defaultTargetKey: 'job_site_direct_pif_vrf',
        ),
    ];

    if (actions.isNotEmpty) {
      return actions;
    }
    return AiAssistantActionCatalog.actionsFor(AiAssistantContextType.jobs);
  }

  AiAssistantQuickAction _remapAiAction(
    AiAssistantQuickAction source, {
    required String id,
    required String defaultTargetKey,
    String? label,
    String? description,
    String? defaultPrompt,
  }) {
    return AiAssistantQuickAction(
      id: id,
      contextType: source.contextType,
      label: label ?? source.label,
      description: description ?? source.description,
      defaultPrompt: defaultPrompt ?? source.defaultPrompt,
      toolNames: source.toolNames,
      defaultTargetKey: defaultTargetKey,
      delicate: source.delicate,
    );
  }

  Future<List<Map<String, dynamic>>> _readTeamsFromSharedSource() async {
    final teams = await MasterLocalStore.readTeams();
    final byId = <String, Map<String, dynamic>>{};
    for (final team in teams) {
      final id = team.id.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = <String, dynamic>{
        'id': id,
        'name': team.name.trim(),
        'notes': team.notes,
        'memberIds': team.memberIds,
        'members': team.memberIds,
      };
    }
    return byId.values.toList(growable: false);
  }

  List<String> _extractTeamMembers(Map<String, dynamic> team) {
    final dynamic rawMembers = team['members'] ??
        team['memberIds'] ??
        team['employees'] ??
        team['employeeIds'];
    if (rawMembers is List) {
      return rawMembers
          .map((member) {
            if (member is Map) {
              final name = '${member['name'] ?? ''}'.trim();
              if (name.isNotEmpty) {
                return name;
              }
              return '${member['id'] ?? ''}'.trim();
            }
            return '$member'.trim();
          })
          .where((member) => member.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic> _normalizeTeamRaw(Object? item) {
    if (item is Map) {
      final team = Map<String, dynamic>.from(item);
      final id = '${team['id'] ?? ''}'.trim();
      final name = '${team['name'] ?? team['title'] ?? ''}'.trim();
      final members = _extractTeamMembers(team);
      return <String, dynamic>{
        'id': id,
        'name': name,
        'notes': '${team['notes'] ?? ''}',
        'memberIds': members,
        'members': members,
      };
    }

    // Support typed team objects returned by repository methods.
    try {
      final dynamic team = item;
      final id = '${team.id ?? team.teamId ?? ''}'.trim();
      final name = '${team.name ?? team.title ?? ''}'.trim();
      final dynamic rawMembers =
          team.members ?? team.memberIds ?? team.employeeIds ?? team.employees;
      final members = <String>[
        if (rawMembers is List)
          ...rawMembers.map((member) {
            if (member is Map) {
              final memberName = '${member['name'] ?? ''}'.trim();
              if (memberName.isNotEmpty) {
                return memberName;
              }
              return '${member['id'] ?? ''}'.trim();
            }
            try {
              final dynamic memberObj = member;
              final memberName = '${memberObj.name ?? ''}'.trim();
              if (memberName.isNotEmpty) {
                return memberName;
              }
            } catch (_) {/* intenționat ignorat: probare duck-typing .name pe membru dynamic */}
            return '$member'.trim();
          }).where((member) => member.isNotEmpty),
      ];
      return <String, dynamic>{
        'id': id,
        'name': name,
        'notes': '${team.notes ?? ''}',
        'memberIds': members,
        'members': members,
      };
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  bool _isLoading = true;

  List<LucrareOption> _teams = const [];
  List<LucrareOption> _employees = const [];
  List<Map<String, dynamic>> _teamsSourceRows = const [];
  List<LucrareMaterialOption> _materialsCatalog = const [];
  LucrareOption? _assignedTeam;
  String _assignedTeamMembersLabel = '';

  List<Map<String, dynamic>> _appointments = const [];
  List<Map<String, dynamic>> _materials = const [];
  List<Map<String, dynamic>> _labor = const [];
  List<Map<String, dynamic>> _timeEntries = const [];
  List<JobPartner> _partners = const [];
  List<JobPartnerWorker> _partnerWorkers = const [];
  List<JobPartnerVehicle> _partnerVehicles = const [];
  List<JobOwnVehicle> _ownVehicles = const [];
  List<VehicleRecord> _masterOwnVehicles = const [];
  List<BeneficiarySuppliedEquipment> _beneficiarySuppliedEquipment = const [];
  List<BeneficiarySuppliedMaterial> _beneficiarySuppliedMaterials = const [];
  List<PartnerRecord> _masterPartners = const [];
  List<PartnerWorkerRecord> _masterPartnerWorkers = const [];
  List<PartnerVehicleRecord> _masterPartnerVehicles = const [];
  List<ClientRecord> _clients = const [];
  List<WarrantyCertificateRecord> _warrantyCertificates =
      const <WarrantyCertificateRecord>[];
  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _journal = const [];
  Map<String, bool> _checklist = const {};
  List<Map<String, dynamic>> _workTaskEntries = const [];
  Map<String, dynamic>? _latestReportRegistryRow;
  Map<String, String> _commercialSettings = const {};
  double _defaultVatPercent = 21.0;
  String? _selectedAppointmentFilterId;

  String get _teamKey => 'job_team_v4_${widget.job.id}';
  String get _appointmentsKey => 'job_appointments_v4_${widget.job.id}';
  String get _materialsKey => 'job_materials_v4_${widget.job.id}';
  String get _laborKey => 'job_labor_v4_${widget.job.id}';
  String get _timeEntriesKey => 'job_time_entries_v1_${widget.job.id}';
  String get _partnersKey => 'job_partners_v1_${widget.job.id}';
  String get _partnerWorkersKey => 'job_partner_workers_v1_${widget.job.id}';
  String get _partnerVehiclesKey => 'job_partner_vehicles_v1_${widget.job.id}';
  String get _ownVehiclesKey => 'job_own_vehicles_v1_${widget.job.id}';
  String get _documentsKey => 'job_documents_v1_${widget.job.id}';
  String get _journalKey => 'job_journal_v1_${widget.job.id}';
  String get _checklistKey => 'job_checklist_v1_${widget.job.id}';
  String get _workTaskEntriesKey => 'job_work_tasks_v1_${widget.job.id}';
  String get _beneficiaryEquipmentKey =>
      'job_beneficiary_equipment_v1_${widget.job.id}';
  String get _beneficiaryMaterialsKey =>
      'job_beneficiary_materials_v1_${widget.job.id}';
  String get _commercialSettingsKey => 'commercial_settings_v1';

  static const List<MapEntry<String, String>> _checklistDefs = [
    MapEntry<String, String>('programare_facuta', 'Programare facuta'),
    MapEntry<String, String>('echipa_alocata', 'Echipa alocata'),
    MapEntry<String, String>('materiale_alocate', 'Materiale alocate'),
    MapEntry<String, String>('executie_inceputa', 'Executie inceputa'),
    MapEntry<String, String>('pif_realizat', 'PIF realizat'),
    MapEntry<String, String>('lucrare_finalizata', 'Lucrare finalizata'),
  ];
  static const List<String> _documentTypes = [
    'Proces verbal',
    'Fisa interventie',
    'PIF',
    'Ofertă',
    'Deviz',
    'Contract',
    'Receptie',
    'Contract',
    'Oferta',
    'Deviz',
  ];
  static const List<String> _documentStatuses = [
    'Draft',
    'Final',
    'Revizuit',
  ];

  Map<String, bool> _defaultChecklist() => {
        for (final entry in _checklistDefs) entry.key: false,
      };

  Map<String, String> _defaultCommercialSettings() => <String, String>{
        'vatPercent': _defaultVatPercent.toStringAsFixed(0),
        'paymentTerm': '30 zile',
        'offerValidity': '30 zile',
        'executionTerm': 'Conform graficului agreat',
        'advance': '0',
        'installments': 'Conform etapelor de executie',
        'penalties': '0.1% / zi intarziere',
        'materialsProvider': 'Executant',
        'logisticsProvider': 'Executant',
        'receptionClause': 'Recepția se face pe bază de PV/PIF semnat.',
        'defaultSignatures': 'Executant: __________ | Beneficiar: __________',
      };

  Map<String, String> _mergeCommercialSettings(Map<String, dynamic>? raw) {
    final merged = <String, String>{..._defaultCommercialSettings()};
    if (raw == null) {
      return merged;
    }
    raw.forEach((key, value) {
      final normalizedKey = '$key'.trim();
      if (normalizedKey.isEmpty) return;
      final normalizedValue = '${value ?? ''}'.trim();
      if (normalizedValue.isNotEmpty) {
        merged[normalizedKey] = normalizedValue;
      }
    });
    return merged;
  }

  String _commercialValue(String key) =>
      (_commercialSettings[key] ?? _defaultCommercialSettings()[key] ?? '')
          .trim();

  Future<void> _saveCommercialSettings(Map<String, String> next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_commercialSettingsKey, jsonEncode(next));
    if (!mounted) return;
    setState(() {
      _commercialSettings = next;
    });
  }

  String _normalizeDocumentType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'process_verbal' ||
        value == 'proces_verbal' ||
        value == 'proces verbal' ||
        value == 'pv') {
      return 'process_verbal';
    }
    if (value == 'pif') {
      return 'pif';
    }
    return 'other';
  }

  String _documentTypeLabelFromType(String type) {
    switch (_normalizeDocumentType(type)) {
      case 'process_verbal':
        return 'Proces verbal';
      case 'pif':
        return 'PIF';
      case 'oferta':
      case 'offer':
        return 'Ofertă';
      case 'deviz':
      case 'estimate':
        return 'Deviz';
      case 'contract':
        return 'Contract';
      default:
        return 'Deviz';
    }
  }

  String _extractDocumentTypeLabel(Map<String, dynamic> row) {
    final quickType =
        ((row['type'] ?? row['tipDocument'] ?? row['documentType']) ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll('ă', 'a')
            .replaceAll('â', 'a')
            .replaceAll('î', 'i')
            .replaceAll('ș', 's')
            .replaceAll('ş', 's')
            .replaceAll('ț', 't')
            .replaceAll('ţ', 't');
    if (quickType.contains('deviz') || quickType == 'dv') {
      return 'Deviz';
    }
    final tip = '${row['tipDocument'] ?? ''}'.trim();
    if (tip.isNotEmpty) return tip;
    return _documentTypeLabelFromType('${row['type'] ?? ''}');
  }

  @override
  void initState() {
    super.initState();
    _aiAssistantService = AiAssistantService(repository: widget.repository);
    _jobSnapshot = widget.job;
    _selectedProfitPartnerId = widget.job.partnerId;
    _selectedProfitPartnerName = widget.job.partnerName;
    _partnerProfitPercent = widget.job.partnerProfitPercent;
    _partnerResources = widget.job.partnerResources;
    _profitTaxPercent = widget.job.profitTaxPercent;
    _profitTaxCtrl = TextEditingController(
        text: widget.job.profitTaxPercent.toStringAsFixed(1));
    _partnerProfitPercentCtrl = TextEditingController(
        text: widget.job.partnerProfitPercent.toStringAsFixed(1));
    _partnerResourcesCtrl = TextEditingController(
        text: widget.job.partnerResources.toStringAsFixed(2));
    _refreshCloudRepository();
    // Future.microtask evită blocarea primului frame (CLAUDE.md ANTI-PATTERN 2)
    Future.microtask(_loadData);
    // Reîncarcă din cloud când Firebase devine disponibil după startup
    // (CLAUDE.md ANTI-PATTERN 4 — pagini care nu se reîncarcă după startup)
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    _profitTaxCtrl.dispose();
    _partnerProfitPercentCtrl.dispose();
    _partnerResourcesCtrl.dispose();
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.isOnline &&
        mounted &&
        _appointments.isEmpty &&
        !_isLoading) {
      _loadData();
    }
  }

  void _refreshCloudRepository() {
    if (FirebaseBootstrap.isInitialized) {
      _cloudRepository ??= FirebaseLucrariRepository();
    }
  }

  Future<void> _loadData() async {
    await OfflineSyncRuntime.instance.syncPending();
    _refreshCloudRepository();
    setState(() => _isLoading = true);
    // Paralelizare: toate fetch-urile sunt independente — reducere ~70% timp incarcare
    final loadResults = await Future.wait<dynamic>(<Future<dynamic>>[
      SharedPreferences.getInstance(), // [0]
      widget.repository.loadCompanyProfile(), // [1]
      _readTeams(), // [2]
      _readEmployees(), // [3]
      _readTeamsFromSharedSource(), // [4]
      _readMaterials(), // [5]
      _readRemoteAppointments(), // [6]
      widget.repository.listClients(), // [7]
      widget.repository.listPartners(), // [8]
      widget.repository.listPartnerWorkers(), // [9]
      widget.repository.listPartnerVehicles(), // [10]
      _productCatalogService.listWarrantyCertificates(), // [11]
      RegistryStore.readEntries(), // [12]
      AppRepository.create()
          .then((r) => r.listVehicles(activeOnly: true)), // [13]
    ]);
    final prefs = loadResults[0] as SharedPreferences;
    final companyProfile = loadResults[1] as CompanyProfile;
    _defaultVatPercent = companyProfile.defaultVatPercent;
    final teams = loadResults[2] as List<LucrareOption>;
    final employees = loadResults[3] as List<LucrareOption>;
    final teamsFromStore = loadResults[4] as List<Map<String, dynamic>>;
    final catalog = loadResults[5] as List<LucrareMaterialOption>;
    final remoteAppointments = loadResults[6] as List<Map<String, dynamic>>;
    final clients = loadResults[7] as List<ClientRecord>;
    final masterPartners = loadResults[8] as List<PartnerRecord>;
    final masterPartnerWorkers = loadResults[9] as List<PartnerWorkerRecord>;
    final masterPartnerVehicles = loadResults[10] as List<PartnerVehicleRecord>;
    final warrantyCertificates =
        loadResults[11] as List<WarrantyCertificateRecord>;
    final registryRows = loadResults[12] as List<Map<String, dynamic>>;
    final masterOwnVehicles = loadResults[13] as List<VehicleRecord>;

    final localAppointments = _readRows(prefs.getString(_appointmentsKey));
    final merged = <String, Map<String, dynamic>>{};
    for (final row in remoteAppointments) {
      final id = (row['id'] ?? '').toString().trim();
      if (id.isNotEmpty) merged[id] = row;
    }
    for (final row in localAppointments) {
      final id = (row['id'] ?? '').toString().trim();
      if (id.isNotEmpty) merged[id] = row;
    }
    final documentsRows = _readRows(prefs.getString(_documentsKey));
    final partnersRows = _readRows(prefs.getString(_partnersKey));
    final partnerWorkersRows = _readRows(prefs.getString(_partnerWorkersKey));
    final partnerVehiclesRows = _readRows(prefs.getString(_partnerVehiclesKey));
    final ownVehiclesRows = _readRows(prefs.getString(_ownVehiclesKey));
    final journalRows = _readRows(prefs.getString(_journalKey));
    final checklist = _readChecklist(prefs.getString(_checklistKey));
    final workTaskEntriesRows = _readRows(prefs.getString(_workTaskEntriesKey));
    final beneficiaryEquipmentRows =
        _readRows(prefs.getString(_beneficiaryEquipmentKey));
    final beneficiaryMaterialsRows =
        _readRows(prefs.getString(_beneficiaryMaterialsKey));
    Map<String, String> commercialSettings = _defaultCommercialSettings();
    final rawCommercialSettings = prefs.getString(_commercialSettingsKey);
    if (rawCommercialSettings != null &&
        rawCommercialSettings.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCommercialSettings);
        if (decoded is Map) {
          commercialSettings =
              _mergeCommercialSettings(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('[LucrareDetalii] parsare commercial settings eșuată: $e');
      }
    }
    final latestReportRegistryRow =
        _latestRegistryReportForCurrentJob(registryRows);

    LucrareOption? savedTeam;
    final rawTeam = prefs.getString(_teamKey);
    if (rawTeam != null && rawTeam.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTeam);
        if (decoded is Map) {
          savedTeam = LucrareOption.fromMap(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('[LucrareDetalii] parsare echipă salvată eșuată: $e');
      }
    }

    final availableTeamIds = teamsFromStore
        .map((team) => '${team['id'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (savedTeam != null && !availableTeamIds.contains(savedTeam.id)) {
      savedTeam = null;
      await prefs.remove(_teamKey);
    }

    String assignedMembersLabel = '';
    if (savedTeam != null) {
      Map<String, dynamic>? selectedTeam;
      for (final team in teamsFromStore) {
        if ('${team['id'] ?? ''}'.trim() == savedTeam.id) {
          selectedTeam = team;
          break;
        }
      }
      if (selectedTeam != null) {
        final members = _extractTeamMembers(selectedTeam);
        if (members.isNotEmpty) {
          final resolved = members
              .map((memberId) {
                for (final employee in employees) {
                  if (employee.id == memberId &&
                      employee.label.trim().isNotEmpty) {
                    return employee.label.trim();
                  }
                }
                return memberId;
              })
              .where((name) => name.trim().isNotEmpty)
              .toList(growable: false);
          assignedMembersLabel = resolved.join(', ');
        }
      }
    }

    _teamsSourceRows = teamsFromStore;
    final localMaterials = _readRows(prefs.getString(_materialsKey));
    final materialsFromJob = _cloneRows(_jobSnapshot.materials);
    final effectiveMaterials = _jobSnapshot.materialsUpdatedAt != null
        ? materialsFromJob
        : (materialsFromJob.isNotEmpty ? materialsFromJob : localMaterials);
    final hasSyncedOperationalDetails = _jobSnapshot.detailsUpdatedAt != null;
    final syncedAssignedTeam = _jobSnapshot.assignedTeamId.trim().isEmpty &&
            _jobSnapshot.assignedTeamLabel.trim().isEmpty
        ? null
        : LucrareOption(
            id: _jobSnapshot.assignedTeamId.trim(),
            label: _jobSnapshot.assignedTeamLabel.trim(),
          );
    final effectiveAssignedTeam =
        hasSyncedOperationalDetails ? syncedAssignedTeam : savedTeam;
    final effectiveAssignedMembersLabel = hasSyncedOperationalDetails
        ? (_jobSnapshot.assignedTeamMembersLabel.trim().isNotEmpty
            ? _jobSnapshot.assignedTeamMembersLabel.trim()
            : (syncedAssignedTeam == null
                ? ''
                : _teamMembersLabelFor(syncedAssignedTeam.id)))
        : assignedMembersLabel;
    final effectiveDocuments = hasSyncedOperationalDetails
        ? _cloneRows(_jobSnapshot.documents)
        : documentsRows;
    final effectiveLabor = hasSyncedOperationalDetails
        ? _dedupeLaborRows(_cloneRows(_jobSnapshot.laborEntries))
        : _dedupeLaborRows(_readRows(prefs.getString(_laborKey)));
    final effectiveJournal = hasSyncedOperationalDetails
        ? _cloneRows(_jobSnapshot.journalEntries)
        : journalRows;
    final effectiveChecklist = hasSyncedOperationalDetails
        ? (_jobSnapshot.checklist.isEmpty
            ? _defaultChecklist()
            : _cloneChecklist(_jobSnapshot.checklist))
        : checklist;
    final effectiveWorkTaskEntries = hasSyncedOperationalDetails
        ? _cloneRows(_jobSnapshot.workTaskEntries)
        : workTaskEntriesRows;
    final effectivePartners = hasSyncedOperationalDetails
        ? _jobSnapshot.jobPartners
            .map(JobPartner.fromMap)
            .where((partner) => partner.id.isNotEmpty)
            .toList(growable: false)
        : partnersRows
            .map(JobPartner.fromMap)
            .where((partner) => partner.id.isNotEmpty)
            .toList(growable: false);
    final effectivePartnerWorkers = hasSyncedOperationalDetails
        ? _jobSnapshot.jobPartnerWorkers
            .map(JobPartnerWorker.fromMap)
            .where((worker) => worker.id.isNotEmpty)
            .toList(growable: false)
        : partnerWorkersRows
            .map(JobPartnerWorker.fromMap)
            .where((worker) => worker.id.isNotEmpty)
            .toList(growable: false);
    final effectivePartnerVehicles = hasSyncedOperationalDetails
        ? _jobSnapshot.jobPartnerVehicles
            .map(JobPartnerVehicle.fromMap)
            .where((vehicle) => vehicle.id.isNotEmpty)
            .toList(growable: false)
        : partnerVehiclesRows
            .map(JobPartnerVehicle.fromMap)
            .where((vehicle) => vehicle.id.isNotEmpty)
            .toList(growable: false);
    final effectiveOwnVehicles = hasSyncedOperationalDetails
        ? _jobSnapshot.jobOwnVehicles
            .map(JobOwnVehicle.fromMap)
            .where((vehicle) => vehicle.id.isNotEmpty)
            .toList(growable: false)
        : ownVehiclesRows
            .map(JobOwnVehicle.fromMap)
            .where((vehicle) => vehicle.id.isNotEmpty)
            .toList(growable: false);
    final effectiveBeneficiaryEquipment = hasSyncedOperationalDetails
        ? _jobSnapshot.beneficiarySuppliedEquipment
        : beneficiaryEquipmentRows
            .map(BeneficiarySuppliedEquipment.fromMap)
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);
    final effectiveBeneficiaryMaterials = hasSyncedOperationalDetails
        ? _jobSnapshot.beneficiarySuppliedMaterials
        : beneficiaryMaterialsRows
            .map(BeneficiarySuppliedMaterial.fromMap)
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);

    if (!mounted) return;
    setState(() {
      final nextAppointments = merged.values.toList(growable: false);
      if (_selectedAppointmentFilterId != null &&
          !nextAppointments.any(
            (row) => _appointmentIdOf(row) == _selectedAppointmentFilterId,
          )) {
        _selectedAppointmentFilterId = null;
      }
      _teams = teams;
      _employees = employees;
      _teamsSourceRows = teamsFromStore;
      _materialsCatalog = catalog;
      _assignedTeam = effectiveAssignedTeam;
      _assignedTeamMembersLabel = effectiveAssignedMembersLabel;
      _appointments = nextAppointments;
      _materials = effectiveMaterials;
      _labor = effectiveLabor;
      _timeEntries = _cloneRows(_jobSnapshot.timeEntries);
      _partners = effectivePartners;
      _partnerWorkers = effectivePartnerWorkers;
      _partnerVehicles = effectivePartnerVehicles;
      _ownVehicles = effectiveOwnVehicles;
      _masterOwnVehicles = masterOwnVehicles;
      _beneficiarySuppliedEquipment = effectiveBeneficiaryEquipment;
      _beneficiarySuppliedMaterials = effectiveBeneficiaryMaterials;
      _clients = clients;
      _masterPartners = masterPartners;
      _masterPartnerWorkers = masterPartnerWorkers;
      _masterPartnerVehicles = masterPartnerVehicles;
      _warrantyCertificates = warrantyCertificates;
      _documents = effectiveDocuments;
      _journal = effectiveJournal;
      _checklist = effectiveChecklist;
      _workTaskEntries = effectiveWorkTaskEntries;
      _commercialSettings = commercialSettings;
      _latestReportRegistryRow = latestReportRegistryRow;
      _isLoading = false;
    });
  }

  ClientRecord? _clientRecordForJob() {
    for (final item in _clients) {
      if (item.id == _jobSnapshot.clientId) return item;
    }
    return null;
  }

  List<WarrantyCertificateRecord> get _jobWarrantyCertificates {
    final rows = _warrantyCertificates
        .where(
          (item) =>
              item.sourceType == WarrantyCertificateSourceType.job &&
              item.jobId == _jobSnapshot.id,
        )
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  WarrantyCertificateRecord? _certificateForJobEquipment(
    BeneficiarySuppliedEquipment? equipment,
  ) {
    for (final item in _jobWarrantyCertificates) {
      if (equipment == null) {
        if (item.sourceEquipmentId.trim().isEmpty) {
          return item;
        }
        continue;
      }
      if (item.sourceEquipmentId == equipment.id) {
        return item;
      }
      if (item.sourceEquipmentId.trim().isEmpty &&
          item.serialNumberOutdoor.trim().isNotEmpty &&
          item.serialNumberOutdoor.trim() == equipment.serialNumber.trim()) {
        return item;
      }
    }
    return null;
  }

  Future<BeneficiarySuppliedEquipment?> _pickWarrantyEquipment() async {
    final rows = _beneficiarySuppliedEquipment;
    if (rows.isEmpty) return null;
    if (rows.length == 1) return rows.first;
    return showDialog<BeneficiarySuppliedEquipment?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alege echipamentul pentru certificat'),
        content: SizedBox(
          width: 640,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('Certificat general pentru lucrare'),
                  subtitle: Text(_jobSnapshot.title.trim().isEmpty
                      ? '-'
                      : _jobSnapshot.title.trim()),
                  onTap: () => Navigator.of(context).pop(null),
                );
              }
              final item = rows[index - 1];
              final details = <String>[
                if (item.equipmentType.trim().isNotEmpty)
                  item.equipmentType.trim(),
                if (item.brand.trim().isNotEmpty) item.brand.trim(),
                if (item.model.trim().isNotEmpty) item.model.trim(),
                if (item.serialNumber.trim().isNotEmpty)
                  'SN ${item.serialNumber.trim()}',
              ].join(' | ');
              return ListTile(
                title:
                    Text(item.name.trim().isEmpty ? 'Echipament' : item.name),
                subtitle: Text(details.isEmpty ? '-' : details),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunta'),
          ),
        ],
      ),
    );
  }

  DateTime? _latestPifDate() {
    DateTime? parseLooseDate(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      final parsedIso = DateTime.tryParse(value);
      if (parsedIso != null) return parsedIso;
      final parts = value.split('.');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
      return null;
    }

    DateTime? latest;
    for (final row in _documents) {
      final type =
          '${row['type'] ?? row['tipDocument'] ?? row['subtype'] ?? ''}'
              .trim()
              .toLowerCase();
      final number =
          '${row['numarDocument'] ?? row['number'] ?? ''}'.trim().toLowerCase();
      if (!type.contains('pif') && !number.startsWith('pif')) {
        continue;
      }
      final rawDate =
          '${row['dataDocument'] ?? row['date'] ?? row['createdAt'] ?? ''}'
              .trim();
      final parsed = parseLooseDate(rawDate);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    return latest;
  }

  Future<WarrantyCertificateRecord> _buildJobWarrantyCertificate({
    required BeneficiarySuppliedEquipment? equipment,
    WarrantyCertificateRecord? existing,
  }) async {
    final now = DateTime.now();
    final identity = existing == null
        ? _productCatalogService.nextCertificateIdentity(
            _warrantyCertificates,
            now: now,
          )
        : (
            series: existing.certificateSeries,
            number: existing.certificateNumber,
          );
    final company = await widget.repository.loadCompanyProfile();
    final client = _clientRecordForJob();
    final effectiveDate = _latestPifDate() ??
        _jobSnapshot.closedDate ??
        _jobSnapshot.dueDate ??
        now;
    final buyerAddressParts = <String>[
      client?.address.trim() ?? '',
      client?.city.trim() ?? '',
      client?.county.trim() ?? '',
    ]..removeWhere((item) => item.isEmpty);
    final sellerName = company.companyName.trim().isNotEmpty
        ? company.companyName.trim()
        : company.contactName.trim();
    final installerPersons = _assignedTeamMembersLabel.trim().isNotEmpty
        ? _assignedTeamMembersLabel.trim()
        : _assignedTeam?.label.trim() ?? '';
    final titleParts = <String>[
      _jobSnapshot.jobCode.trim(),
      _jobSnapshot.title.trim(),
      _jobSnapshot.location.trim(),
    ]..removeWhere((item) => item.isEmpty);

    return WarrantyCertificateRecord(
      id: existing?.id ?? 'warranty-certificate-${now.microsecondsSinceEpoch}',
      saleId: existing?.saleId ?? '',
      sourceType: WarrantyCertificateSourceType.job,
      jobId: _jobSnapshot.id,
      jobTitle: existing?.jobTitle ?? titleParts.join(' | '),
      sourceEquipmentId: existing?.sourceEquipmentId ?? equipment?.id ?? '',
      sourceEquipmentLabel: existing?.sourceEquipmentLabel ??
          equipment?.name.trim() ??
          _jobSnapshot.title.trim(),
      certificateSeries: identity.series.trim(),
      certificateNumber: identity.number.trim(),
      documentDate: existing?.documentDate ?? effectiveDate,
      equipmentType: existing?.equipmentType ??
          equipment?.equipmentType.trim() ??
          _jobSnapshot.category.trim(),
      brand: existing?.brand ?? equipment?.brand.trim() ?? '',
      model: existing?.model ?? equipment?.model.trim() ?? '',
      serialNumberIndoor: existing?.serialNumberIndoor ?? '',
      serialNumberOutdoor:
          existing?.serialNumberOutdoor ?? equipment?.serialNumber.trim() ?? '',
      invoiceNumber: existing?.invoiceNumber ?? '',
      saleDate: existing?.saleDate ?? effectiveDate,
      warrantyMonths: existing?.warrantyMonths ?? 24,
      warrantyStartDate: existing?.warrantyStartDate ?? effectiveDate,
      warrantyEndDate: existing?.warrantyEndDate ??
          DateTime(
            (existing?.warrantyStartDate ?? effectiveDate).year,
            (existing?.warrantyStartDate ?? effectiveDate).month +
                (existing?.warrantyMonths ?? 24),
            (existing?.warrantyStartDate ?? effectiveDate).day,
          ),
      sellerName: existing?.sellerName ?? sellerName,
      sellerAddress: existing?.sellerAddress ?? company.address.trim(),
      sellerEmail: existing?.sellerEmail ?? company.email.trim(),
      sellerPhone: existing?.sellerPhone ?? company.phone.trim(),
      sellerTaxId: existing?.sellerTaxId ?? company.cui.trim(),
      buyerClientId: existing?.buyerClientId ?? _jobSnapshot.clientId,
      buyerName: existing?.buyerName ??
          (widget.clientName.trim().isEmpty ? '-' : widget.clientName.trim()),
      buyerAddress: existing?.buyerAddress ?? buyerAddressParts.join(', '),
      buyerPhone: existing?.buyerPhone ??
          client?.phone.trim() ??
          _jobSnapshot.contactPhone.trim(),
      buyerTaxOrCnp: existing?.buyerTaxOrCnp ?? client?.cui.trim() ?? '',
      installerName: existing?.installerName ?? sellerName,
      installerAddress: existing?.installerAddress ?? company.address.trim(),
      installerEmail: existing?.installerEmail ?? company.email.trim(),
      installerPhone: existing?.installerPhone ?? company.phone.trim(),
      installerTaxId: existing?.installerTaxId ?? company.cui.trim(),
      installerPersons: existing?.installerPersons ?? installerPersons,
      installationDate: existing?.installationDate ?? effectiveDate,
      termsText:
          existing?.termsText ?? ProductCatalogService.defaultWarrantyTerms,
      registryEntryId: existing?.registryEntryId ?? '',
      documentType: existing?.documentType ?? 'warranty_certificate',
      sourceModule: existing?.sourceModule ?? 'jobs',
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

  Future<void> _openWarrantyCertificateFlow() async {
    final equipment = await _pickWarrantyEquipment();
    if (!mounted) return;
    final existing = _certificateForJobEquipment(equipment);
    final initial = await _buildJobWarrantyCertificate(
      equipment: equipment,
      existing: existing,
    );
    if (!mounted) return;
    final saved = await showDialog<WarrantyCertificateRecord>(
      context: context,
      builder: (context) => WarrantyCertificateEditorDialog(initial: initial),
    );
    if (saved == null) return;
    await _productCatalogService.saveWarrantyCertificate(saved);
    await _loadData();
  }

  Future<void> _generateJobWarrantyCertificatePdf(
    WarrantyCertificateRecord certificate, {
    required bool share,
    bool saveAs = false,
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
        final registryEntry = await widget.repository.registerGeneratedDocument(
          registryType: RegistryType.iesire,
          documentCategory: 'Certificat garantie',
          documentTitle:
              'Certificat de garantie ${persisted.fullCertificateNumber}',
          documentNumber: persisted.fullCertificateNumber.trim().isEmpty
              ? persisted.id
              : persisted.fullCertificateNumber,
          documentDate: persisted.documentDate,
          issuerName: persisted.sellerName,
          recipientName: persisted.buyerName,
          clientId: _jobSnapshot.clientId,
          jobId: _jobSnapshot.id,
          filePath: filePath,
          fileName: persisted.generatedDocumentFileName,
          notes: 'Generat din modulul Lucrari.',
          status: 'emis',
        );
        persisted = persisted.copyWith(registryEntryId: registryEntry.id);
      }
      await _productCatalogService.saveWarrantyCertificate(persisted);
      if (!mounted) return;
      if (share) {
        await DocumentFileService.shareFile(
          filePath,
          subject: 'Certificat garantie ${persisted.fullCertificateNumber}',
          text: persisted.jobTitle.trim(),
        );
      } else {
        final result = await DocumentFileService.openFile(filePath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
      await _loadData();
    } on PdfSaveCanceledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvarea documentului a fost anulata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut genera certificatul: $error')),
      );
    }
  }

  Future<void> _openFieldPhotosForJob() async {
    final jobId =
        _jobSnapshot.id.trim().isEmpty ? widget.job.id : _jobSnapshot.id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldPhotosPage(
          repository: widget.repository,
          sourceModule: 'jobs',
          sourceEntityId: jobId,
          title: 'Poze teren lucrare',
        ),
      ),
    );
  }

  Future<void> _openFieldPhotosForDocument(int index) async {
    if (index < 0 || index >= _documents.length) {
      return;
    }
    final row = _documents[index];
    final documentId = '${row['id'] ?? ''}'.trim();
    if (documentId.isEmpty) {
      return;
    }
    final jobId =
        _jobSnapshot.id.trim().isEmpty ? widget.job.id : _jobSnapshot.id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldPhotosPage(
          repository: widget.repository,
          sourceModule: 'job_document',
          sourceEntityId: jobId,
          documentId: documentId,
          title: 'Poze teren document PV/PIF',
        ),
      ),
    );
  }

  Future<void> _openJobSiteDocumentsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobSiteDocumentsPage(
          repository: widget.repository,
          job: _jobSnapshot,
          clientName: widget.clientName,
          roleKey: widget.roleKey,
        ),
      ),
    );
  }

  Future<List<LucrareOption>> _readTeams() async {
    final local = await MasterLocalStore.readTeams();
    if (local.isNotEmpty) {
      return local
          .map((e) => LucrareOption(id: e.id, label: e.name.isEmpty ? e.id : e.name))
          .toList(growable: false);
    }
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listTeamsLookup() as Future<dynamic>);
      if (raw is Iterable) return _toOptions(raw);
    } catch (e) {
      debugPrint('[LucrareDetalii] listTeamsLookup eșuat, încerc sursa următoare: $e');
    }
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listTeams() as Future<dynamic>);
      if (raw is Iterable) return _toOptions(raw);
    } catch (e) {
      debugPrint('[LucrareDetalii] listTeams eșuat: $e');
    }
    return const [];
  }

  Future<List<LucrareOption>> _readEmployees() async {
    try {
      final lookup = await widget.repository.listEmployeesLookup();
      final rows = lookup.map(LucrareOption.fromAny).toList(growable: false);
      if (rows.isNotEmpty) return _dedupeOptions(rows);
    } catch (e) {
      debugPrint('[LucrareDetalii] listEmployeesLookup eșuat, încerc sursa următoare: $e');
    }
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listEmployees() as Future<dynamic>);
      if (raw is Iterable) return _toOptions(raw);
    } catch (e) {
      debugPrint('[LucrareDetalii] listEmployees eșuat: $e');
    }
    final local = await MasterLocalStore.readEmployees();
    if (local.isNotEmpty) {
      return local
          .where((e) => e.active)
          .map(
            (e) => LucrareOption(
              id: e.id,
              label: e.name.isEmpty ? e.id : e.name,
              hourlyRate: e.effectiveTarifOrar,
              dailyAllowance: e.dailyAllowance,
              defaultLodgingCost: e.defaultLodgingCost,
              requiresLodgingByDefault: e.requiresLodgingByDefault,
              active: e.active,
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  Future<List<LucrareMaterialOption>> _readMaterials() async {
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listMaterials() as Future<dynamic>);
      if (raw is Iterable) return _toMaterials(raw);
    } catch (e) {
      debugPrint('[LucrareDetalii] listMaterials eșuat, încerc sursa următoare: $e');
    }
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listMaterialsLookup() as Future<dynamic>);
      if (raw is Iterable) return _toMaterials(raw);
    } catch (e) {
      debugPrint('[LucrareDetalii] listMaterialsLookup eșuat: $e');
    }
    final local = await MasterLocalStore.readMaterials();
    if (local.isNotEmpty) {
      return local
          .map(
            (e) => LucrareMaterialOption(
              id: e.id,
              name: e.name.isEmpty ? e.id : e.name,
              um: e.unit,
              price: e.price,
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _readRemoteAppointments() async {
    try {
      final dynamic repo = widget.repository;
      final dynamic raw = await (repo.listAppointments() as Future<dynamic>);
      if (raw is! Iterable) return const [];
      return raw
          .map(_appointmentFromAny)
          .where(
              (row) => (row['jobId'] ?? '').toString().trim() == widget.job.id)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<LucrareOption> _toOptions(Iterable raw) => _dedupeOptions(
        raw
            .map(LucrareOption.fromAny)
            .where((e) => e.id.isNotEmpty)
            .toList(growable: false),
      );

  List<LucrareMaterialOption> _toMaterials(Iterable raw) => _dedupeMaterials(
        raw
            .map(LucrareMaterialOption.fromAny)
            .where((e) => e.id.isNotEmpty)
            .toList(growable: false),
      );

  List<LucrareOption> _dedupeOptions(List<LucrareOption> rows) {
    final map = <String, LucrareOption>{};
    for (final row in rows) {
      map[row.id] = row;
    }
    return map.values.toList(growable: false);
  }

  List<LucrareMaterialOption> _dedupeMaterials(List<LucrareMaterialOption> rows) {
    final map = <String, LucrareMaterialOption>{};
    for (final row in rows) {
      map[row.id] = row;
    }
    return map.values.toList(growable: false);
  }

  Map<String, dynamic> _appointmentFromAny(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final id = _safeRead(() => (raw as dynamic).id);
    final jobId = _safeRead(() => (raw as dynamic).jobId);
    final title = _safeRead(() => (raw as dynamic).title);
    final location = _safeRead(() => (raw as dynamic).location);
    final date = _safeRead(() => (raw as dynamic).scheduledDate).isNotEmpty
        ? _safeRead(() => (raw as dynamic).scheduledDate)
        : _safeRead(() => (raw as dynamic).date);
    return {
      'id': id,
      'jobId': jobId,
      'title': title,
      'location': location,
      'date': date
    };
  }

  String _safeRead(dynamic Function() getter) {
    try {
      return getter()?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _readRows(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[LucrareDetalii] parsare rânduri JSON eșuată: $e');
    }
    return const [];
  }

  List<Map<String, dynamic>> _cloneRows(List<Map<String, dynamic>> rows) {
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, bool> _cloneChecklist(Map<String, bool> value) {
    return Map<String, bool>.from(value);
  }

  Map<String, bool> _readChecklist(String? raw) {
    final defaults = _defaultChecklist();
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String, bool>{...defaults};
        for (final entry in _checklistDefs) {
          out[entry.key] = _asBool(decoded[entry.key]);
        }
        return out;
      }
    } catch (e) {
      debugPrint('[LucrareDetalii] parsare checklist eșuată, folosesc default: $e');
    }
    return defaults;
  }

  Future<void> _saveRows(String key, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(rows));
  }

  Future<void> _persistTimeEntries(List<Map<String, dynamic>> entries) async {
    final normalized = _cloneRows(entries);
    await _saveRows(_timeEntriesKey, normalized);
    final now = DateTime.now();
    final nextJob = _jobSnapshot.copyWith(
      timeEntries: normalized,
      updatedAt: now,
    );
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertJob(nextJob);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }
    _jobSnapshot = await widget.repository.saveJob(nextJob);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    }
  }

  Future<void> _persistJobMaterials(List<Map<String, dynamic>> rows) async {
    final normalized = _cloneRows(rows);
    await _saveRows(_materialsKey, normalized);
    final now = DateTime.now();
    final nextJob = _jobSnapshot.copyWith(
      materials: normalized,
      materialsUpdatedAt: now,
      updatedAt: now,
    );
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertJob(nextJob);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }
    _jobSnapshot = await widget.repository.saveJob(nextJob);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    }
  }

  Future<void> _savePartnerProfit() async {
    final now = DateTime.now();
    final nextJob = _jobSnapshot.copyWith(
      partnerId: _selectedProfitPartnerId,
      partnerName: _selectedProfitPartnerName,
      partnerProfitPercent: _partnerProfitPercent,
      partnerResources: _partnerResources,
      profitTaxPercent: _profitTaxPercent,
      updatedAt: now,
    );
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertJob(nextJob);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }
    _jobSnapshot = await widget.repository.saveJob(nextJob);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    }
    if (mounted) _snack('Împărțire profit salvată.');
  }

  Widget _buildPartnerProfitSection() {
    final grossProfit = _estimatedValue - _realTotalCost;
    final taxAmount = grossProfit > 0 ? grossProfit * _profitTaxPercent / 100 : 0.0;
    final netProfit = grossProfit - taxAmount;
    final partnerShare = netProfit > 0 ? netProfit * _partnerProfitPercent / 100 : 0.0;
    final totalOwed = partnerShare + _partnerResources;
    final companyKeeps = netProfit - partnerShare;

    String fmt(double v) => '${v.toStringAsFixed(2)} RON';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _profitRow(
              'Profit brut (Venit − Costuri)',
              fmt(grossProfit),
              Icons.show_chart,
              grossProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
            ),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: _profitTaxCtrl,
                decoration: const InputDecoration(
                  labelText: 'Impozit profit %',
                  suffixText: '%',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null && mounted) {
                    setState(() => _profitTaxPercent = parsed.clamp(0, 100));
                  }
                },
              ),
            ),
            _profitRow(
              'Profit NET',
              fmt(netProfit),
              Icons.account_balance_outlined,
              netProfit >= 0 ? Colors.indigo : Colors.red.shade700,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_masterPartners.isEmpty)
          Text(
            'Nu există parteneri înregistrați.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedProfitPartnerId.isNotEmpty &&
                    _masterPartners
                        .any((p) => p.id == _selectedProfitPartnerId)
                ? _selectedProfitPartnerId
                : null,
            decoration: const InputDecoration(
              labelText: 'Partener profit',
              helperText: 'Selectează partenerul cu care împarți profitul',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Fără partener'),
              ),
              ..._masterPartners.map(
                (p) => DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                ),
              ),
            ],
            onChanged: (id) {
              if (!mounted) return;
              setState(() {
                _selectedProfitPartnerId = id ?? '';
                _selectedProfitPartnerName =
                    id != null && id.isNotEmpty
                        ? (_masterPartners
                                .firstWhere(
                                  (p) => p.id == id,
                                  orElse: () => _masterPartners.first,
                                )
                                .name)
                        : '';
              });
            },
          ),
        if (_selectedProfitPartnerId.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: _partnerProfitPercentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Procent partener',
                    suffixText: '%',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null && mounted) {
                      setState(
                          () => _partnerProfitPercent = parsed.clamp(0, 100));
                    }
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  controller: _partnerResourcesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resurse partener (RON)',
                    suffixText: 'RON',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null && mounted) {
                      setState(
                          () => _partnerResources = parsed < 0 ? 0 : parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calcul împărțire profit — $_selectedProfitPartnerName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const Divider(height: 16),
                _partnerSummaryRow('Profit NET', fmt(netProfit)),
                _partnerSummaryRow(
                  'Procent partener',
                  '${_partnerProfitPercent.toStringAsFixed(1)}%',
                ),
                _partnerSummaryRow('Parte profit', fmt(partnerShare)),
                _partnerSummaryRow('Resurse partener', fmt(_partnerResources)),
                const Divider(height: 16),
                _partnerSummaryRow(
                  'TOTAL DATORAT partenerului',
                  fmt(totalOwed),
                  bold: true,
                  color: Colors.red.shade700,
                ),
                _partnerSummaryRow(
                  'Rămâne la firmă',
                  fmt(companyKeeps),
                  bold: true,
                  color: Colors.green.shade700,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _savePartnerProfit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvează împărțire profit'),
        ),
      ],
    );
  }

  Widget _partnerSummaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey.shade700,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistOperationalJobDetails({
    LucrareOption? assignedTeam,
    List<Map<String, dynamic>>? documents,
    List<Map<String, dynamic>>? labor,
    List<Map<String, dynamic>>? journal,
    Map<String, bool>? checklist,
    List<Map<String, dynamic>>? workTaskEntries,
    List<JobPartner>? partners,
    List<JobPartnerWorker>? partnerWorkers,
    List<JobPartnerVehicle>? partnerVehicles,
    List<JobOwnVehicle>? ownVehicles,
    List<BeneficiarySuppliedEquipment>? beneficiaryEquipment,
    List<BeneficiarySuppliedMaterial>? beneficiaryMaterials,
  }) async {
    final resolvedDocuments = _cloneRows(documents ?? _documents);
    final resolvedLabor = _cloneRows(labor ?? _labor);
    final resolvedJournal = _cloneRows(journal ?? _journal);
    final resolvedChecklist = _cloneChecklist(checklist ?? _checklist);
    final resolvedWorkTaskEntries =
        _cloneRows(workTaskEntries ?? _workTaskEntries);
    final resolvedPartners = (partners ?? _partners)
        .map((item) => item.toMap())
        .toList(growable: false);
    final resolvedPartnerWorkers = (partnerWorkers ?? _partnerWorkers)
        .map((item) => item.toMap())
        .toList(growable: false);
    final resolvedPartnerVehicles = (partnerVehicles ?? _partnerVehicles)
        .map((item) => item.toMap())
        .toList(growable: false);
    final resolvedOwnVehicles = (ownVehicles ?? _ownVehicles)
        .map((item) => item.toMap())
        .toList(growable: false);
    final resolvedBeneficiaryEquipment =
        (beneficiaryEquipment ?? _beneficiarySuppliedEquipment)
            .map((item) => item.toMap())
            .toList(growable: false);
    final resolvedBeneficiaryMaterials =
        (beneficiaryMaterials ?? _beneficiarySuppliedMaterials)
            .map((item) => item.toMap())
            .toList(growable: false);
    final resolvedTeam = assignedTeam ?? _assignedTeam;

    await _saveRows(_documentsKey, resolvedDocuments);
    await _saveRows(_laborKey, resolvedLabor);
    await _saveRows(_journalKey, resolvedJournal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checklistKey, jsonEncode(resolvedChecklist));
    await _saveRows(_workTaskEntriesKey, resolvedWorkTaskEntries);
    await _saveRows(_partnersKey, resolvedPartners);
    await _saveRows(_partnerWorkersKey, resolvedPartnerWorkers);
    await _saveRows(_partnerVehiclesKey, resolvedPartnerVehicles);
    await _saveRows(_ownVehiclesKey, resolvedOwnVehicles);
    await _saveRows(_beneficiaryEquipmentKey, resolvedBeneficiaryEquipment);
    await _saveRows(_beneficiaryMaterialsKey, resolvedBeneficiaryMaterials);
    if (resolvedTeam == null) {
      await prefs.remove(_teamKey);
    } else {
      await prefs.setString(_teamKey, jsonEncode(resolvedTeam.toMap()));
    }

    final now = DateTime.now();
    final nextJob = _jobSnapshot.copyWith(
      detailsUpdatedAt: now,
      updatedAt: now,
      assignedTeamId: resolvedTeam?.id ?? '',
      assignedTeamLabel: resolvedTeam?.label ?? '',
      assignedTeamMembersLabel:
          resolvedTeam == null ? '' : _teamMembersLabelFor(resolvedTeam.id),
      documents: resolvedDocuments,
      laborEntries: resolvedLabor,
      journalEntries: resolvedJournal,
      checklist: resolvedChecklist,
      workTaskEntries: resolvedWorkTaskEntries,
      jobPartners: resolvedPartners,
      jobPartnerWorkers: resolvedPartnerWorkers,
      jobPartnerVehicles: resolvedPartnerVehicles,
      jobOwnVehicles: resolvedOwnVehicles,
      beneficiarySuppliedEquipment: resolvedBeneficiaryEquipment
          .map(BeneficiarySuppliedEquipment.fromMap)
          .toList(growable: false),
      beneficiarySuppliedMaterials: resolvedBeneficiaryMaterials
          .map(BeneficiarySuppliedMaterial.fromMap)
          .toList(growable: false),
    );
    _refreshCloudRepository();
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertJob(nextJob);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }
    _jobSnapshot = await widget.repository.saveJob(nextJob);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    }
  }

  String _teamMembersLabelFor(String teamId) {
    final id = teamId.trim();
    if (id.isEmpty) return '';
    final members = _extractTeamMembers(
      _teamsSourceRows.firstWhere(
        (row) => '${row['id'] ?? ''}'.trim() == id,
        orElse: () => const <String, dynamic>{},
      ),
    );
    if (members.isEmpty) return '';
    final resolved = members
        .map((memberId) {
          for (final employee in _employees) {
            if (employee.id == memberId && employee.label.trim().isNotEmpty) {
              return employee.label.trim();
            }
          }
          return memberId;
        })
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
    return resolved.join(', ');
  }

  String _newPartnerEntityId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _savePartners(List<JobPartner> partners) async {
    await _persistOperationalJobDetails(partners: partners);
    if (!mounted) return;
    setState(() {
      _partners = partners;
    });
  }

  Future<void> _savePartnerWorkers(List<JobPartnerWorker> workers) async {
    await _persistOperationalJobDetails(partnerWorkers: workers);
    if (!mounted) return;
    setState(() {
      _partnerWorkers = workers;
    });
  }

  Future<void> _savePartnerVehicles(List<JobPartnerVehicle> vehicles) async {
    await _persistOperationalJobDetails(partnerVehicles: vehicles);
    if (!mounted) return;
    setState(() {
      _partnerVehicles = vehicles;
    });
  }

  Future<void> _saveOwnVehicles(List<JobOwnVehicle> vehicles) async {
    await _persistOperationalJobDetails(ownVehicles: vehicles);
    if (!mounted) return;
    setState(() {
      _ownVehicles = vehicles;
    });
  }

  Future<void> _saveChecklist(Map<String, bool> value) async {
    await _persistOperationalJobDetails(checklist: value);
    if (!mounted) return;
    setState(() => _checklist = Map<String, bool>.from(value));
  }

  Future<void> _saveBeneficiaryEquipment(
    List<BeneficiarySuppliedEquipment> value,
  ) async {
    await _persistOperationalJobDetails(beneficiaryEquipment: value);
    if (!mounted) return;
    setState(() => _beneficiarySuppliedEquipment = value);
  }

  Future<void> _saveBeneficiaryMaterials(
    List<BeneficiarySuppliedMaterial> value,
  ) async {
    await _persistOperationalJobDetails(beneficiaryMaterials: value);
    if (!mounted) return;
    setState(() => _beneficiarySuppliedMaterials = value);
  }

  String _sequenceKeyForType(String type) {
    switch (_normalizeDocumentType(type)) {
      case 'process_verbal':
        return 'doc_seq_pv_v1';
      case 'pif':
        return 'doc_seq_pif_v1';
      default:
        return 'doc_seq_other_v1';
    }
  }

  String _prefixForType(String type) {
    switch (_normalizeDocumentType(type)) {
      case 'process_verbal':
        return 'PV';
      case 'pif':
        return 'PIF';
      default:
        return 'DOC';
    }
  }

  int _extractSequenceNumber(String value, String prefix) {
    final normalized = value.trim().toUpperCase();
    final expected = '$prefix-';
    if (!normalized.startsWith(expected)) return 0;
    final raw = normalized.substring(expected.length);
    return int.tryParse(raw) ?? 0;
  }

  int _maxSequenceInRows(List<Map<String, dynamic>> rows, String prefix) {
    var max = 0;
    for (final row in rows) {
      final number = '${row['numarDocument'] ?? row['number'] ?? ''}';
      final seq = _extractSequenceNumber(number, prefix);
      if (seq > max) {
        max = seq;
      }
    }
    return max;
  }

  int _maxSequenceInJobs(Iterable<JobRecord> jobs, String prefix) {
    var max = 0;
    for (final job in jobs) {
      final seq = _maxSequenceInRows(job.documents, prefix);
      if (seq > max) {
        max = seq;
      }
    }
    return max;
  }

  Future<int> _maxSequenceAcrossAllJobs(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    var max = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('job_documents_v1_')) continue;
      final rows = _readRows(prefs.getString(key));
      final seq = _maxSequenceInRows(rows, prefix);
      if (seq > max) {
        max = seq;
      }
    }
    try {
      final localJobs = await widget.repository.listJobs();
      final localJobsMax = _maxSequenceInJobs(localJobs, prefix);
      if (localJobsMax > max) {
        max = localJobsMax;
      }
    } catch (e) {
      debugPrint('[LucrareDetalii] citire secvență max din jobs locale eșuată: $e');
    }
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        final cloudJobs = await cloud.listJobs();
        final cloudMax = _maxSequenceInJobs(cloudJobs, prefix);
        if (cloudMax > max) {
          max = cloudMax;
        }
      } catch (_) {
        // Fallback la datele locale daca citirea cloud esueaza temporar.
      }
    }
    return max;
  }

  Future<String> _nextDocumentNumber(String type) async {
    final normalizedType = _normalizeDocumentType(type);
    final prefix = _prefixForType(normalizedType);
    final key = _sequenceKeyForType(normalizedType);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(key) ?? 0;
    final currentRowsMax = _maxSequenceInRows(_documents, prefix);
    final globalMax = await _maxSequenceAcrossAllJobs(prefix);
    final next =
        [stored, currentRowsMax, globalMax].reduce((a, b) => a > b ? a : b) + 1;
    await prefs.setInt(key, next);
    return '$prefix-${next.toString().padLeft(4, '0')}';
  }

  Future<void> _appendJournal({
    required String action,
    required String message,
  }) async {
    final rows = _cloneRows(_journal).toList(growable: true);
    rows.insert(0, <String, dynamic>{
      'id': 'journal-${DateTime.now().microsecondsSinceEpoch}',
      'action': action,
      'message': message,
      'at': DateTime.now().toIso8601String(),
      'jobId': widget.job.id,
    });
    await _persistOperationalJobDetails(journal: rows);
    if (!mounted) return;
    setState(() => _journal = rows);
  }

  String _unwrapAiDraftContent(String content) {
    final trimmed = content.trim();
    final fenced =
        RegExp(r'^```[a-zA-Z0-9_-]*\s*([\s\S]*?)\s*```$').firstMatch(trimmed);
    if (fenced != null) {
      return (fenced.group(1) ?? '').trim();
    }
    return trimmed;
  }

  List<BeneficiarySuppliedMaterial> _parseAiBeneficiaryMaterials(
    String content,
  ) {
    final normalized = _unwrapAiDraftContent(content);
    if (normalized.isEmpty) return const <BeneficiarySuppliedMaterial>[];

    try {
      final decoded = jsonDecode(normalized);
      final candidateRows = <dynamic>[];
      if (decoded is List) {
        candidateRows.addAll(decoded);
      } else if (decoded is Map) {
        final rawList =
            decoded['items'] ?? decoded['materials'] ?? decoded['rows'];
        if (rawList is List) {
          candidateRows.addAll(rawList);
        }
      }
      if (candidateRows.isNotEmpty) {
        return candidateRows
            .asMap()
            .entries
            .map((entry) {
              final row = entry.value;
              if (row is Map<String, dynamic>) {
                final material = BeneficiarySuppliedMaterial.fromMap(row);
                return material.name.trim().isEmpty ? null : material;
              }
              if (row is Map) {
                final material = BeneficiarySuppliedMaterial.fromMap(
                  Map<String, dynamic>.from(row),
                );
                return material.name.trim().isEmpty ? null : material;
              }
              if (row is String) {
                return _parseImportedBeneficiaryMaterial(row, entry.key);
              }
              return null;
            })
            .whereType<BeneficiarySuppliedMaterial>()
            .toList(growable: false);
      }
    } catch (_) {
      // Fallback to line parsing below.
    }

    return LineSplitter.split(normalized)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _parseImportedBeneficiaryMaterial(entry.value, entry.key),
        )
        .whereType<BeneficiarySuppliedMaterial>()
        .toList(growable: false);
  }

  String? _checklistKeyFromAny(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;
    for (final entry in _checklistDefs) {
      final key = entry.key
          .trim()
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final label = entry.value
          .trim()
          .toLowerCase()
          .replaceAll('ă', 'a')
          .replaceAll('â', 'a')
          .replaceAll('î', 'i')
          .replaceAll('ș', 's')
          .replaceAll('ş', 's')
          .replaceAll('ț', 't')
          .replaceAll('ţ', 't')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (normalized == key || normalized == label) {
        return entry.key;
      }
    }
    return null;
  }

  Map<String, bool> _parseAiChecklistUpdate(String content) {
    final normalized = _unwrapAiDraftContent(content);
    final updates = <String, bool>{};
    if (normalized.isEmpty) return updates;

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final resolvedKey = _checklistKeyFromAny('$key');
          if (resolvedKey != null) {
            updates[resolvedKey] = _asBool(value);
          }
        });
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final rawKey =
                '${item['key'] ?? item['id'] ?? item['label'] ?? item['name'] ?? ''}';
            final resolvedKey = _checklistKeyFromAny(rawKey);
            if (resolvedKey == null) continue;
            updates[resolvedKey] = _asBool(
              item['checked'] ?? item['value'] ?? item['done'] ?? true,
            );
          } else if (item is String) {
            final resolvedKey = _checklistKeyFromAny(item);
            if (resolvedKey != null) {
              updates[resolvedKey] = true;
            }
          }
        }
      }
    } catch (_) {
      for (final rawLine in LineSplitter.split(normalized)) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final isChecked = line.startsWith('[x]') ||
            line.startsWith('[X]') ||
            line.toLowerCase().startsWith('da ') ||
            line.toLowerCase().startsWith('true ') ||
            line.toLowerCase().startsWith('bifat ') ||
            line.startsWith('+');
        final isUnchecked = line.startsWith('[ ]') ||
            line.toLowerCase().startsWith('nu ') ||
            line.toLowerCase().startsWith('false ') ||
            line.toLowerCase().startsWith('debifat ') ||
            line.startsWith('-');
        final cleaned = line
            .replaceFirst(RegExp(r'^\[(x|X| )\]\s*'), '')
            .replaceFirst(
                RegExp(r'^(da|nu|true|false|bifat|debifat)\s+',
                    caseSensitive: false),
                '')
            .replaceFirst(RegExp(r'^[-+*•]\s*'), '')
            .trim();
        final resolvedKey = _checklistKeyFromAny(cleaned);
        if (resolvedKey == null) continue;
        updates[resolvedKey] = isUnchecked ? false : (isChecked ? true : true);
      }
    }

    return updates;
  }

  Map<String, dynamic>? _parseAiAssociatedDocument(String content) {
    final normalized = _unwrapAiDraftContent(content);
    if (normalized.isEmpty) return null;

    String selectedType = 'Deviz';
    String selectedStatus = _documentStatuses.first;
    String title = _jobSnapshot.title.trim().isEmpty
        ? widget.job.title
        : _jobSnapshot.title.trim();
    String number = '';
    String date = _formatDate(DateTime.now());
    String notes = normalized;

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        selectedType =
            '${decoded['tipDocument'] ?? decoded['type'] ?? decoded['documentType'] ?? selectedType}'
                .trim();
        selectedStatus = '${decoded['status'] ?? selectedStatus}'.trim();
        title = '${decoded['titlu'] ?? decoded['title'] ?? title}'.trim();
        number =
            '${decoded['numarDocument'] ?? decoded['number'] ?? ''}'.trim();
        date = '${decoded['dataDocument'] ?? decoded['date'] ?? date}'.trim();
        notes =
            '${decoded['observatii'] ?? decoded['notes'] ?? decoded['content'] ?? notes}'
                .trim();
      }
    } catch (_) {
      final lines = LineSplitter.split(normalized).toList(growable: false);
      final notesLines = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('tip:') || lower.startsWith('tip document:')) {
          selectedType = trimmed.split(':').skip(1).join(':').trim();
          continue;
        }
        if (lower.startsWith('titlu:')) {
          title = trimmed.split(':').skip(1).join(':').trim();
          continue;
        }
        if (lower.startsWith('numar:') || lower.startsWith('număr:')) {
          number = trimmed.split(':').skip(1).join(':').trim();
          continue;
        }
        if (lower.startsWith('data:')) {
          date = trimmed.split(':').skip(1).join(':').trim();
          continue;
        }
        if (lower.startsWith('status:')) {
          selectedStatus = trimmed.split(':').skip(1).join(':').trim();
          continue;
        }
        if (lower.startsWith('observatii:') ||
            lower.startsWith('observații:')) {
          notesLines.add(trimmed.split(':').skip(1).join(':').trim());
          continue;
        }
        notesLines.add(trimmed);
      }
      if (notesLines.isNotEmpty) {
        notes = notesLines.join('\n').trim();
      }
    }

    final availableTypes = _dedupeDropdownValues(_documentTypes);
    final normalizedType = selectedType.trim().toLowerCase();
    for (final candidate in availableTypes) {
      if (candidate.trim().toLowerCase() == normalizedType) {
        selectedType = candidate;
        break;
      }
    }
    if (!availableTypes.any(
      (candidate) =>
          candidate.trim().toLowerCase() == selectedType.trim().toLowerCase(),
    )) {
      selectedType = 'Deviz';
    }
    if (!_documentStatuses.contains(selectedStatus)) {
      selectedStatus = _documentStatuses.first;
    }
    if (title.trim().isEmpty) {
      title = _jobSnapshot.title.trim().isEmpty
          ? widget.job.title
          : _jobSnapshot.title.trim();
    }

    return <String, dynamic>{
      'id': 'job-doc-ai-${DateTime.now().microsecondsSinceEpoch}',
      'jobId': widget.job.id,
      'client': widget.clientName,
      'location': widget.job.location,
      'type': _normalizeDocumentType(selectedType),
      'tipDocument': selectedType,
      'documentSubtype': _documentSubtypeFromSelectedType(selectedType),
      'titlu': title.trim(),
      'numarDocument': number.trim(),
      'dataDocument':
          date.trim().isEmpty ? _formatDate(DateTime.now()) : date.trim(),
      'observatii': notes.trim(),
      'status': selectedStatus,
      'filePath': '',
      'pdfPath': '',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'typeLegacy': selectedType,
      'title': title.trim(),
      'number': number.trim(),
      'date': date.trim().isEmpty ? _formatDate(DateTime.now()) : date.trim(),
      'notes': notes.trim(),
    };
  }

  String get _jobSiteDocumentsCacheKey {
    final jobId =
        _jobSnapshot.id.trim().isEmpty ? widget.job.id : _jobSnapshot.id;
    return 'job_site_documents_v1_$jobId';
  }

  JobSiteDocumentsCloudRepository? get _jobSiteDocumentsCloudRepository {
    if (!FirebaseBootstrap.isInitialized) {
      return null;
    }
    return FirebaseJobSiteDocumentsRepository();
  }

  Future<List<JobSiteDocumentRecord>> _readJobSiteDocumentsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_jobSiteDocumentsCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <JobSiteDocumentRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <JobSiteDocumentRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (row) => JobSiteDocumentRecord.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <JobSiteDocumentRecord>[];
    }
  }

  Future<void> _writeJobSiteDocumentsCache(
    List<JobSiteDocumentRecord> rows,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _jobSiteDocumentsCacheKey,
      jsonEncode(rows.map((row) => row.toMap()).toList(growable: false)),
    );
  }

  Future<List<JobSiteDocumentRecord>> _readExistingJobSiteDocuments() async {
    final cloud = _jobSiteDocumentsCloudRepository;
    final jobId =
        _jobSnapshot.id.trim().isEmpty ? widget.job.id : _jobSnapshot.id;
    if (cloud != null) {
      try {
        final rows = await cloud.listDocumentsForJob(jobId);
        await _writeJobSiteDocumentsCache(rows);
        return rows;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
      }
    }
    return _readJobSiteDocumentsCache();
  }

  String _nextJobSiteDocumentNumber(
    JobSiteDocumentType type,
    List<JobSiteDocumentRecord> existing,
  ) {
    final sameTypeCount =
        existing.where((item) => item.documentType == type).length;
    return '${type.shortCode}-${(sameTypeCount + 1).toString().padLeft(4, '0')}';
  }

  Map<String, String> _parseAiDocumentSections(String content) {
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

  JobSiteDocumentRecord _applyAiBodyToJobSiteDocument(
    JobSiteDocumentRecord draft,
    String content,
  ) {
    final sections = _parseAiDocumentSections(content);
    final title = sections['titlu'];
    final subtitle = sections['subtitlu'];
    final observations = sections['observații'] ?? sections['observatii'];
    final conclusions = sections['concluzii'];
    final probes = sections['probe'];
    final nextStep = sections['etapa următoare'] ?? sections['etapa urmatoare'];

    return draft.copyWith(
      documentTitle:
          (title ?? '').trim().isNotEmpty ? title!.trim() : draft.documentTitle,
      documentSubtitle: (subtitle ?? '').trim().isNotEmpty
          ? subtitle!.trim()
          : draft.documentSubtitle,
      observations: (observations ?? '').trim().isNotEmpty
          ? observations!.trim()
          : draft.observations,
      conclusions: sections.isEmpty
          ? content.trim()
          : ((conclusions ?? '').trim().isNotEmpty
              ? conclusions!.trim()
              : draft.conclusions),
      probesSummary: (probes ?? '').trim().isNotEmpty
          ? probes!.trim()
          : draft.probesSummary,
      preparedForNextStep: (nextStep ?? '').trim().isNotEmpty
          ? nextStep!.trim()
          : draft.preparedForNextStep,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveJobSiteDocumentRecord(
      JobSiteDocumentRecord document) async {
    final updated = document.copyWith(updatedAt: DateTime.now());
    final cached = await _readJobSiteDocumentsCache();
    final next = <JobSiteDocumentRecord>[
      for (final item in cached)
        if (item.id != updated.id) item,
      updated,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final cloud = _jobSiteDocumentsCloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertDocument(updated);
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        queuedOffline = true;
      }
    }

    await _writeJobSiteDocumentsCache(next);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueDocument(updated);
    }
  }

  Future<JobSiteDocumentRecord> _createAiJobSiteDocument(
    JobSiteDocumentType type,
    String content,
  ) async {
    final existing = await _readExistingJobSiteDocuments();
    var draft = await _jobSiteDocumentTemplateService.createDraft(
      job: _jobSnapshot,
      clientName: widget.clientName,
      documentType: type,
      documentNumber: _nextJobSiteDocumentNumber(type, existing),
    );
    draft = _applyAiBodyToJobSiteDocument(draft, content);
    await _saveJobSiteDocumentRecord(draft);
    return draft;
  }

  Future<AiAssistantRuntimeContext> _buildJobAiContext() async {
    final currentUser = await widget.repository.loadCurrentUser();
    final jobId =
        _jobSnapshot.id.trim().isEmpty ? widget.job.id : _jobSnapshot.id;
    final jobLabel = _jobSnapshot.jobCode.trim().isNotEmpty
        ? _jobSnapshot.jobCode.trim()
        : (_jobSnapshot.title.trim().isNotEmpty
            ? _jobSnapshot.title.trim()
            : 'Lucrare');
    return AiAssistantRuntimeContext(
      contextType: AiAssistantContextType.jobs,
      module: 'lucrari',
      entityId: jobId,
      entityLabel: jobLabel,
      userId: (currentUser?.email ?? '').trim().isNotEmpty
          ? currentUser!.email.trim()
          : (currentUser?.id ?? ''),
      contextLabel: 'Lucrare $jobLabel',
      primaryData: <String, dynamic>{
        ..._jobSnapshot.toMap(),
        'client_name_live': widget.clientName.trim(),
        'assigned_team_label_live': _assignedTeam?.label ?? '',
        'assigned_team_members_live': _assignedTeamMembersLabel,
      },
      relatedData: <String, dynamic>{
        'job': _jobSnapshot.toMap(),
        'client': _clientRecordForJob()?.toMap() ??
            <String, dynamic>{
              'name': widget.clientName.trim(),
            },
        'appointments': _cloneRows(_appointments),
        'materials': _cloneRows(_materials),
        'labor': _cloneRows(_labor),
        'documents': _cloneRows(_documents),
        'journal': _cloneRows(_journal),
        'beneficiary_supplied_equipment': _beneficiarySuppliedEquipment
            .map((item) => item.toMap())
            .toList(growable: false),
        'beneficiary_supplied_materials': _beneficiarySuppliedMaterials
            .map((item) => item.toMap())
            .toList(growable: false),
      },
      insertionTargets: const <AiAssistantInsertionTarget>[
        AiAssistantInsertionTarget(
          key: 'job_beneficiary_materials',
          label: 'Materiale beneficiar',
          description:
              'Insereaza sau completeaza lista materialelor furnizate de beneficiar. Pentru liste, raspunsul ideal este JSON array sau linii de forma denumire | UM | cantitate | observatii.',
          insertMode: AiAssistantInsertMode.append,
        ),
        AiAssistantInsertionTarget(
          key: 'job_operational_journal',
          label: 'Jurnal operativ',
          description: 'Adauga o nota operativa scurta in istoricul lucrarii.',
          insertMode: AiAssistantInsertMode.append,
        ),
        AiAssistantInsertionTarget(
          key: 'job_associated_document',
          label: 'Document asociat',
          description:
              'Creeaza un document asociat nou. Format recomandat: JSON object sau campuri Tip, Titlu, Numar, Data, Status, Observatii.',
          insertMode: AiAssistantInsertMode.append,
        ),
        AiAssistantInsertionTarget(
          key: 'job_operational_checklist',
          label: 'Etape operative',
          description:
              'Bifeaza sau debifeaza checklist-ul lucrarii pe baza unui JSON map sau a unei liste de etape.',
          insertMode: AiAssistantInsertMode.replace,
        ),
        AiAssistantInsertionTarget(
          key: 'job_site_direct_pv_montaj',
          label: 'PV montaj / execuție',
          description:
              'Creeaza direct un PV de montaj / executie in modulul PV/PIF si distribuie draftul AI in campurile principale.',
          insertMode: AiAssistantInsertMode.append,
        ),
        AiAssistantInsertionTarget(
          key: 'job_site_direct_pif_ventilation',
          label: 'PIF ventilație / recuperator',
          description:
              'Creeaza direct un PV PIF ventilatie / recuperator in modulul PV/PIF folosind contextul lucrarii.',
          insertMode: AiAssistantInsertMode.append,
        ),
        AiAssistantInsertionTarget(
          key: 'job_site_direct_pif_vrf',
          label: 'PIF VRF / climatizare',
          description:
              'Creeaza direct un PV PIF VRF / climatizare in modulul PV/PIF folosind contextul lucrarii.',
          insertMode: AiAssistantInsertMode.append,
        ),
      ],
      metadata: const <String, dynamic>{
        'surface': 'job_details_page',
      },
    );
  }

  Future<void> _openJobAiAssistant() async {
    setState(() => _isRunningAi = true);
    try {
      final runtimeContext = await _buildJobAiContext();
      if (!mounted) return;
      await AiAssistantSheet.show(
        context: context,
        title: 'Asistent AI lucrare',
        service: _aiAssistantService,
        runtimeContext: runtimeContext,
        actions: _jobAiActions,
        initialActionId: 'jobs_contextual_chat',
        onInsertDraft: _applyJobAiDraft,
      );
    } finally {
      if (mounted) {
        setState(() => _isRunningAi = false);
      }
    }
  }

  Future<bool> _applyJobAiDraft(String targetKey, String content) async {
    final normalized = _unwrapAiDraftContent(content);
    if (normalized.isEmpty) return false;
    switch (targetKey) {
      case 'job_beneficiary_materials':
        final imported = _parseAiBeneficiaryMaterials(normalized);
        if (imported.isEmpty) {
          _snack('Draftul AI nu conține materiale beneficiar recognoscibile.');
          return false;
        }
        final next = _mergeBeneficiaryMaterialImports(
          _beneficiarySuppliedMaterials,
          imported,
        );
        await _saveBeneficiaryMaterials(next);
        await _appendJournal(
          action: 'beneficiary_material_ai_inserted',
          message: 'AI a propus ${imported.length} materiale beneficiar.',
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draftul AI a fost inserat în materialele beneficiarului (${imported.length} poziții).',
            ),
          ),
        );
        return true;
      case 'job_operational_journal':
        await _appendJournal(
          action: 'ai_operational_note',
          message: normalized,
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draftul AI a fost adăugat în jurnalul lucrării.'),
          ),
        );
        return true;
      case 'job_associated_document':
        final created = _parseAiAssociatedDocument(normalized);
        if (created == null) {
          _snack('Draftul AI nu conține un document recognoscibil.');
          return false;
        }
        final nextDocuments = [..._documents, created];
        await _persistOperationalJobDetails(documents: nextDocuments);
        if (!mounted) return false;
        setState(() => _documents = nextDocuments);
        await _appendJournal(
          action: 'document_ai_inserted',
          message:
              'AI a creat documentul: ${created['tipDocument'] ?? created['type'] ?? '-'} ${created['titlu'] ?? created['title'] ?? ''}'
                  .trim(),
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draftul AI a fost inserat ca document asociat.'),
          ),
        );
        return true;
      case 'job_operational_checklist':
        final updates = _parseAiChecklistUpdate(normalized);
        if (updates.isEmpty) {
          _snack('Draftul AI nu conține etape operative recognoscibile.');
          return false;
        }
        final nextChecklist = Map<String, bool>.from(_checklist);
        nextChecklist.addAll(updates);
        await _saveChecklist(nextChecklist);
        final touchedLabels = _checklistDefs
            .where((entry) => updates.containsKey(entry.key))
            .map((entry) => entry.value)
            .join(', ');
        await _appendJournal(
          action: 'checklist_ai_updated',
          message: touchedLabels.isEmpty
              ? 'AI a actualizat etapele operative.'
              : 'AI a actualizat etapele operative: $touchedLabels',
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draftul AI a actualizat ${updates.length} etape operative.',
            ),
          ),
        );
        return true;
      case 'job_site_direct_pv_montaj':
        final pvMontaj = await _createAiJobSiteDocument(
          JobSiteDocumentType.montajExecutie,
          normalized,
        );
        await _appendJournal(
          action: 'job_site_document_ai_created',
          message:
              'AI a creat ${pvMontaj.documentType.label}: ${pvMontaj.documentNumber}',
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI a creat ${pvMontaj.documentNumber} în modulul PV/PIF.',
            ),
          ),
        );
        return true;
      case 'job_site_direct_pif_ventilation':
        final pifVentilation = await _createAiJobSiteDocument(
          JobSiteDocumentType.pifVentilatieRecuperator,
          normalized,
        );
        await _appendJournal(
          action: 'job_site_document_ai_created',
          message:
              'AI a creat ${pifVentilation.documentType.label}: ${pifVentilation.documentNumber}',
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI a creat ${pifVentilation.documentNumber} în modulul PV/PIF.',
            ),
          ),
        );
        return true;
      case 'job_site_direct_pif_vrf':
        final pifVrf = await _createAiJobSiteDocument(
          JobSiteDocumentType.pifVrfClimatizare,
          normalized,
        );
        await _appendJournal(
          action: 'job_site_document_ai_created',
          message:
              'AI a creat ${pifVrf.documentType.label}: ${pifVrf.documentNumber}',
        );
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI a creat ${pifVrf.documentNumber} în modulul PV/PIF.',
            ),
          ),
        );
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveTeam(LucrareOption? team) async {
    await _persistOperationalJobDetails(assignedTeam: team);
    await _loadData();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  PartnerRecord? _masterPartnerById(String partnerId) {
    for (final partner in _masterPartners) {
      if (partner.id == partnerId) return partner;
    }
    return null;
  }

  List<PartnerWorkerRecord> _masterWorkersForJobPartner(JobPartner partner) {
    final masterPartnerId = partner.masterPartnerId.trim();
    if (masterPartnerId.isEmpty) return const <PartnerWorkerRecord>[];
    return _masterPartnerWorkers
        .where((item) => item.partnerId == masterPartnerId)
        .toList(growable: false);
  }

  List<PartnerVehicleRecord> _masterVehiclesForJobPartner(JobPartner partner) {
    final masterPartnerId = partner.masterPartnerId.trim();
    if (masterPartnerId.isEmpty) return const <PartnerVehicleRecord>[];
    return _masterPartnerVehicles
        .where((item) => item.partnerId == masterPartnerId)
        .toList(growable: false);
  }

  Future<JobPartner?> _showPartnerDialog({JobPartner? existing}) =>
      showPartnerDialog(
        context,
        masterPartners: _masterPartners,
        jobId: widget.job.id,
        onValidationError: _snack,
        existing: existing,
      );

  Future<JobPartnerWorker?> _showPartnerWorkerDialog({
    required JobPartner partner,
    JobPartnerWorker? existing,
  }) =>
      showPartnerWorkerDialog(
        context,
        partner: partner,
        masterWorkers: _masterWorkersForJobPartner(partner),
        jobId: widget.job.id,
        onValidationError: _snack,
        existing: existing,
      );

  Future<JobPartnerVehicle?> _showPartnerVehicleDialog({
    required JobPartner partner,
    JobPartnerVehicle? existing,
  }) =>
      showPartnerVehicleDialog(
        context,
        partner: partner,
        masterVehicles: _masterVehiclesForJobPartner(partner),
        jobId: widget.job.id,
        onValidationError: _snack,
        existing: existing,
      );

  Future<BeneficiarySuppliedEquipment?> _showBeneficiaryEquipmentDialog({
    BeneficiarySuppliedEquipment? existing,
  }) =>
      showBeneficiaryEquipmentDialog(
        context,
        onValidationError: _snack,
        existing: existing,
      );

  Future<BeneficiarySuppliedMaterial?> _showBeneficiaryMaterialDialog({
    BeneficiarySuppliedMaterial? existing,
  }) =>
      showBeneficiaryMaterialDialog(
        context,
        onValidationError: _snack,
        existing: existing,
      );

  String _decodeImportBytes(Uint8List bytes) => lucrareDecodeImportBytes(bytes);

  String _decodeXmlText(String raw) => lucrareDecodeXmlText(raw);

  String _extractDocxText(Uint8List bytes) => lucrareExtractDocxText(bytes);

  String _extractXlsxText(Uint8List bytes) => lucrareExtractXlsxText(bytes);

  List<String> _splitImportedMaterialLine(String line) =>
      lucrareSplitImportedMaterialLine(line);

  bool _looksLikeImportHeader(String line) =>
      lucrareLooksLikeImportHeader(line);

  BeneficiarySuppliedMaterial? _parseImportedBeneficiaryMaterial(
    String rawLine,
    int index,
  ) =>
      lucrareParseImportedBeneficiaryMaterial(rawLine, index);

  List<BeneficiarySuppliedMaterial> _mergeBeneficiaryMaterialImports(
    List<BeneficiarySuppliedMaterial> existing,
    List<BeneficiarySuppliedMaterial> imported,
  ) =>
      lucrareMergeBeneficiaryMaterialImports(existing, imported);

  Future<void> _onImportBeneficiaryMaterials() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const ['txt', 'csv', 'tsv', 'json', 'docx', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null &&
        picked.path != null &&
        picked.path!.trim().isNotEmpty) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      _snack('Nu am putut citi fișierul selectat.');
      return;
    }

    final extension = picked.extension?.trim().toLowerCase() ?? '';
    List<BeneficiarySuppliedMaterial> imported = const [];
    try {
      if (extension == 'json') {
        final decoded = jsonDecode(_decodeImportBytes(bytes));
        if (decoded is List) {
          imported = decoded
              .map((row) {
                if (row is Map<String, dynamic>) {
                  return BeneficiarySuppliedMaterial.fromMap(row);
                }
                if (row is Map) {
                  return BeneficiarySuppliedMaterial.fromMap(
                    Map<String, dynamic>.from(row),
                  );
                }
                return null;
              })
              .whereType<BeneficiarySuppliedMaterial>()
              .where((item) => item.name.trim().isNotEmpty)
              .toList(growable: false);
        }
      }

      if (imported.isEmpty) {
        final text = switch (extension) {
          'docx' => _extractDocxText(bytes),
          'xlsx' => _extractXlsxText(bytes),
          _ => _decodeImportBytes(bytes),
        };
        final lines = LineSplitter.split(text)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false);
        imported = lines
            .asMap()
            .entries
            .map(
              (entry) =>
                  _parseImportedBeneficiaryMaterial(entry.value, entry.key),
            )
            .whereType<BeneficiarySuppliedMaterial>()
            .toList(growable: false);
      }
    } catch (error) {
      _snack('Importul materialelor a eșuat: $error');
      return;
    }

    if (imported.isEmpty) {
      _snack('Nu am găsit materiale importabile în fișierul selectat.');
      return;
    }

    final next = _mergeBeneficiaryMaterialImports(
      _beneficiarySuppliedMaterials,
      imported,
    );
    await _saveBeneficiaryMaterials(next);
    await _appendJournal(
      action: 'beneficiary_material_imported',
      message:
          'Materiale beneficiar importate: ${imported.length} poziții din ${picked.name}',
    );
    _snack(
        'Am importat ${imported.length} poziții în materialele beneficiarului.');
  }

  Future<void> _onAddBeneficiaryEquipment() async {
    final created = await _showBeneficiaryEquipmentDialog();
    if (created == null) return;
    final next = <BeneficiarySuppliedEquipment>[
      ..._beneficiarySuppliedEquipment,
      created,
    ];
    await _saveBeneficiaryEquipment(next);
    await _appendJournal(
      action: 'beneficiary_equipment_added',
      message: 'Echipament beneficiar adaugat: ${created.name}',
    );
    _snack('Echipament beneficiar adaugat: ${created.name}');
  }

  Future<void> _onEditBeneficiaryEquipment(int index) async {
    if (index < 0 || index >= _beneficiarySuppliedEquipment.length) return;
    final updated = await _showBeneficiaryEquipmentDialog(
      existing: _beneficiarySuppliedEquipment[index],
    );
    if (updated == null) return;
    final next = [..._beneficiarySuppliedEquipment];
    next[index] = updated;
    await _saveBeneficiaryEquipment(next);
    await _appendJournal(
      action: 'beneficiary_equipment_updated',
      message: 'Echipament beneficiar editat: ${updated.name}',
    );
    _snack('Echipament beneficiar actualizat: ${updated.name}');
  }

  Future<void> _onDeleteBeneficiaryEquipment(int index) async {
    if (index < 0 || index >= _beneficiarySuppliedEquipment.length) return;
    final item = _beneficiarySuppliedEquipment[index];
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sterge echipamentul beneficiarului?'),
            content:
                Text('Echipamentul ${item.name} va fi eliminat din lucrare.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Renunta'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sterge'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final next = [..._beneficiarySuppliedEquipment]..removeAt(index);
    await _saveBeneficiaryEquipment(next);
    await _appendJournal(
      action: 'beneficiary_equipment_deleted',
      message: 'Echipament beneficiar sters: ${item.name}',
    );
    _snack('Echipament beneficiar sters: ${item.name}');
  }

  Future<void> _onAddBeneficiaryMaterial() async {
    final created = await _showBeneficiaryMaterialDialog();
    if (created == null) return;
    final next = <BeneficiarySuppliedMaterial>[
      ..._beneficiarySuppliedMaterials,
      created,
    ];
    await _saveBeneficiaryMaterials(next);
    await _appendJournal(
      action: 'beneficiary_material_added',
      message: 'Material beneficiar adaugat: ${created.name}',
    );
    _snack('Material beneficiar adaugat: ${created.name}');
  }

  Future<void> _onEditBeneficiaryMaterial(int index) async {
    if (index < 0 || index >= _beneficiarySuppliedMaterials.length) return;
    final updated = await _showBeneficiaryMaterialDialog(
      existing: _beneficiarySuppliedMaterials[index],
    );
    if (updated == null) return;
    final next = [..._beneficiarySuppliedMaterials];
    next[index] = updated;
    await _saveBeneficiaryMaterials(next);
    await _appendJournal(
      action: 'beneficiary_material_updated',
      message: 'Material beneficiar editat: ${updated.name}',
    );
    _snack('Material beneficiar actualizat: ${updated.name}');
  }

  Future<void> _onDeleteBeneficiaryMaterial(int index) async {
    if (index < 0 || index >= _beneficiarySuppliedMaterials.length) return;
    final item = _beneficiarySuppliedMaterials[index];
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sterge materialul beneficiarului?'),
            content:
                Text('Materialul ${item.name} va fi eliminat din lucrare.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Renunta'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sterge'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final next = [..._beneficiarySuppliedMaterials]..removeAt(index);
    await _saveBeneficiaryMaterials(next);
    await _appendJournal(
      action: 'beneficiary_material_deleted',
      message: 'Material beneficiar sters: ${item.name}',
    );
    _snack('Material beneficiar sters: ${item.name}');
  }

  Future<void> _onAddPartner() async {
    final created = await _showPartnerDialog();
    if (created == null) return;
    final next = <JobPartner>[..._partners, created];
    await _savePartners(next);
    await _appendJournal(
      action: 'partner_added',
      message: 'Partener adaugat: ${created.name}',
    );
    _snack('Partener adaugat: ${created.name}');
  }

  Future<void> _onEditPartner(JobPartner partner) async {
    final updated = await _showPartnerDialog(existing: partner);
    if (updated == null) return;
    final next = _partners
        .map((entry) => entry.id == updated.id ? updated : entry)
        .toList(growable: false);
    await _savePartners(next);
    await _appendJournal(
      action: 'partner_updated',
      message: 'Partener editat: ${updated.name}',
    );
    _snack('Partener actualizat: ${updated.name}');
  }

  Future<void> _onDeletePartner(JobPartner partner) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sterge partenerul?'),
            content: Text(
              'Partenerul ${partner.name} va fi sters impreuna cu personalul si autovehiculele asociate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Renunta'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sterge'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _savePartners(
      _partners
          .where((entry) => entry.id != partner.id)
          .toList(growable: false),
    );
    await _savePartnerWorkers(
      _partnerWorkers
          .where((entry) => entry.partnerId != partner.id)
          .toList(growable: false),
    );
    await _savePartnerVehicles(
      _partnerVehicles
          .where((entry) => entry.partnerId != partner.id)
          .toList(growable: false),
    );
    await _appendJournal(
      action: 'partner_deleted',
      message: 'Partener sters: ${partner.name}',
    );
    _snack('Partener sters: ${partner.name}');
  }

  Future<void> _onAddPartnerWorker(JobPartner partner) async {
    final created = await _showPartnerWorkerDialog(partner: partner);
    if (created == null) return;
    final next = <JobPartnerWorker>[..._partnerWorkers, created];
    await _savePartnerWorkers(next);
    await _appendJournal(
      action: 'partner_worker_added',
      message: 'Personal partener adaugat: ${created.fullName}',
    );
    _snack('Personal partener adaugat: ${created.fullName}');
  }

  Future<void> _onEditPartnerWorker(
    JobPartner partner,
    JobPartnerWorker worker,
  ) async {
    final updated =
        await _showPartnerWorkerDialog(partner: partner, existing: worker);
    if (updated == null) return;
    final next = _partnerWorkers
        .map((entry) => entry.id == updated.id ? updated : entry)
        .toList(growable: false);
    await _savePartnerWorkers(next);
    await _appendJournal(
      action: 'partner_worker_updated',
      message: 'Personal partener editat: ${updated.fullName}',
    );
    _snack('Personal partener actualizat: ${updated.fullName}');
  }

  Future<void> _onDeletePartnerWorker(JobPartnerWorker worker) async {
    await _savePartnerWorkers(
      _partnerWorkers.where((entry) => entry.id != worker.id).toList(
            growable: false,
          ),
    );
    await _appendJournal(
      action: 'partner_worker_deleted',
      message: 'Personal partener sters: ${worker.fullName}',
    );
    _snack('Personal partener sters: ${worker.fullName}');
  }

  Future<void> _onAddPartnerVehicle(JobPartner partner) async {
    final created = await _showPartnerVehicleDialog(partner: partner);
    if (created == null) return;
    final next = <JobPartnerVehicle>[..._partnerVehicles, created];
    await _savePartnerVehicles(next);
    await _appendJournal(
      action: 'partner_vehicle_added',
      message: 'Autovehicul partener adaugat: ${created.vehicleName}',
    );
    _snack('Autovehicul partener adaugat: ${created.vehicleName}');
  }

  Future<void> _onEditPartnerVehicle(
    JobPartner partner,
    JobPartnerVehicle vehicle,
  ) async {
    final updated =
        await _showPartnerVehicleDialog(partner: partner, existing: vehicle);
    if (updated == null) return;
    final next = _partnerVehicles
        .map((entry) => entry.id == updated.id ? updated : entry)
        .toList(growable: false);
    await _savePartnerVehicles(next);
    await _appendJournal(
      action: 'partner_vehicle_updated',
      message: 'Autovehicul partener editat: ${updated.vehicleName}',
    );
    _snack('Autovehicul partener actualizat: ${updated.vehicleName}');
  }

  Future<void> _onDeletePartnerVehicle(JobPartnerVehicle vehicle) async {
    await _savePartnerVehicles(
      _partnerVehicles.where((entry) => entry.id != vehicle.id).toList(
            growable: false,
          ),
    );
    await _appendJournal(
      action: 'partner_vehicle_deleted',
      message: 'Autovehicul partener sters: ${vehicle.vehicleName}',
    );
    _snack('Autovehicul partener sters: ${vehicle.vehicleName}');
  }

  Future<void> _onAddOwnVehicle() async {
    final created = await _showOwnVehicleDialog();
    if (created == null) return;
    final next = <JobOwnVehicle>[..._ownVehicles, created];
    await _saveOwnVehicles(next);
    await _appendJournal(
      action: 'own_vehicle_added',
      message: 'Autoturism propriu adaugat: ${created.vehicleName}',
    );
    _snack('Autoturism propriu adaugat: ${created.vehicleName}');
  }

  Future<void> _onEditOwnVehicle(JobOwnVehicle vehicle) async {
    final updated = await _showOwnVehicleDialog(existing: vehicle);
    if (updated == null) return;
    final next = _ownVehicles
        .map((entry) => entry.id == updated.id ? updated : entry)
        .toList(growable: false);
    await _saveOwnVehicles(next);
    await _appendJournal(
      action: 'own_vehicle_updated',
      message: 'Autoturism propriu editat: ${updated.vehicleName}',
    );
    _snack('Autoturism propriu actualizat: ${updated.vehicleName}');
  }

  Future<void> _onDeleteOwnVehicle(JobOwnVehicle vehicle) async {
    await _saveOwnVehicles(
      _ownVehicles
          .where((entry) => entry.id != vehicle.id)
          .toList(growable: false),
    );
    await _appendJournal(
      action: 'own_vehicle_deleted',
      message: 'Autoturism propriu sters: ${vehicle.vehicleName}',
    );
    _snack('Autoturism propriu sters: ${vehicle.vehicleName}');
  }

  Future<JobOwnVehicle?> _showOwnVehicleDialog({JobOwnVehicle? existing}) =>
      showOwnVehicleDialog(
        context,
        masterOwnVehicles: _masterOwnVehicles,
        jobId: widget.job.id,
        onValidationError: _snack,
        existing: existing,
      );

  Future<void> _onAssignTeam() async {
    final teamsFromStore = await _readTeamsFromSharedSource();
    final dialogTeams = _dedupeOptions(
      teamsFromStore
          .map(
            (team) => LucrareOption(
              id: '${team['id'] ?? ''}'.trim(),
              label: '${team['name'] ?? ''}'.trim(),
            ),
          )
          .where((team) => team.id.isNotEmpty)
          .toList(growable: false),
    );
    if (dialogTeams.isEmpty) {
      _snack('Nu există echipe definite.');
      return;
    }
    String? selected = _assignedTeam?.id;
    if (selected != null &&
        dialogTeams.where((team) => team.id == selected).length != 1) {
      selected = null;
    }
    if (!mounted) return;
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alege echipa'),
        content: DropdownButtonFormField<String?>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'Echipă'),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Fără echipă')),
            ...dialogTeams.map((e) =>
                DropdownMenuItem<String?>(value: e.id, child: Text(e.label))),
          ],
          onChanged: (value) => selected = value,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop('__cancel__'),
              child: const Text('Anulează')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Salvează')),
        ],
      ),
    );
    if (result == '__cancel__') return;
    final picked = dialogTeams.where((e) => e.id == result).toList();
    await _saveTeam(picked.isEmpty ? null : picked.first);
    await _appendJournal(
      action: picked.isEmpty ? 'team_removed' : 'team_changed',
      message: picked.isEmpty
          ? 'Echipa a fost eliminata de pe lucrare.'
          : 'Echipa alocata: ${picked.first.label}',
    );
  }

  Future<void> _onAddAppointment() async {
    final titleController = TextEditingController(
      text: widget.clientName.trim().isEmpty
          ? 'Programare lucrare'
          : widget.clientName.trim(),
    );
    final locationController = TextEditingController(text: widget.job.location);
    DateTime date = DateTime.now();

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adaugă programare pentru această lucrare'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titlu'),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Locație'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (picked == null) return;
                    setDialogState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_formatDate(date)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'id': 'job-appt-${DateTime.now().millisecondsSinceEpoch}',
                'jobId': widget.job.id,
                'title': titleController.text.trim(),
                'location': locationController.text.trim(),
                'date': _formatDate(date),
              }),
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    locationController.dispose();
    if (created == null) return;

    final next = <Map<String, dynamic>>[created, ..._appointments];
    await _saveRows(_appointmentsKey, next);
    if (!mounted) return;
    setState(() => _appointments = next);
    await _appendJournal(
      action: 'appointment_added',
      message: 'Programare adaugata: ${created['title'] ?? '-'}',
    );
  }

  Future<void> _upsertLocalAppointment(Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final localRows =
        _readRows(prefs.getString(_appointmentsKey)).toList(growable: true);
    final id = '${row['id'] ?? ''}'.trim();
    final index = localRows.indexWhere((e) => '${e['id'] ?? ''}'.trim() == id);
    if (index >= 0) {
      localRows[index] = row;
    } else {
      localRows.insert(0, row);
    }
    await _saveRows(_appointmentsKey, localRows);
  }

  String _appointmentIdOf(Map<String, dynamic> row) {
    return '${row['id'] ?? row['appointmentId'] ?? ''}'.trim();
  }

  String _linkedAppointmentIdOfDocument(Map<String, dynamic> row) {
    return '${row['sourceAppointmentId'] ?? row['appointmentId'] ?? row['linkedAppointmentId'] ?? ''}'
        .trim();
  }

  List<Map<String, dynamic>> _documentsLinkedToAppointment(
    String appointmentId,
  ) {
    if (appointmentId.trim().isEmpty) return const [];
    return _documentsForDisplay(_documents)
        .where((doc) => _linkedAppointmentIdOfDocument(doc) == appointmentId)
        .toList(growable: false);
  }

  int _documentIndexInRawList(Map<String, dynamic> document) {
    final id = '${document['id'] ?? document['localId'] ?? ''}'.trim();
    if (id.isNotEmpty) {
      return _documents.indexWhere(
        (row) => '${row['id'] ?? row['localId'] ?? ''}'.trim() == id,
      );
    }
    final number = '${document['numarDocument'] ?? document['number'] ?? ''}'
        .trim()
        .toUpperCase();
    final title =
        '${document['titlu'] ?? document['title'] ?? ''}'.trim().toLowerCase();
    final date = '${document['dataDocument'] ?? document['date'] ?? ''}'.trim();
    return _documents.indexWhere((row) {
      final rowNumber =
          '${row['numarDocument'] ?? row['number'] ?? ''}'.trim().toUpperCase();
      final rowTitle =
          '${row['titlu'] ?? row['title'] ?? ''}'.trim().toLowerCase();
      final rowDate = '${row['dataDocument'] ?? row['date'] ?? ''}'.trim();
      return rowNumber == number && rowTitle == title && rowDate == date;
    });
  }

  void _toggleAppointmentDocumentFilter(Map<String, dynamic> appointment) {
    final appointmentId = _appointmentIdOf(appointment);
    if (appointmentId.isEmpty) {
      _snack('Programarea selectata nu are ID valid.');
      return;
    }
    setState(() {
      _selectedAppointmentFilterId =
          _selectedAppointmentFilterId == appointmentId ? null : appointmentId;
    });
  }

  Future<void> _onOpenLinkedAppointmentFromDocument(
    Map<String, dynamic> document,
  ) async {
    final appointmentId = _linkedAppointmentIdOfDocument(document);
    if (appointmentId.isEmpty) {
      _snack('Documentul nu are o programare legata.');
      return;
    }
    final index = _appointments.indexWhere(
      (row) => _appointmentIdOf(row) == appointmentId,
    );
    if (index < 0) {
      _snack('Programarea legata nu mai exista in lista.');
      return;
    }
    await _onOpenAppointment(index);
  }

  Future<void> _onOpenLatestLinkedDocumentFromAppointment(
    Map<String, dynamic> appointment,
  ) async {
    final appointmentId = _appointmentIdOf(appointment);
    if (appointmentId.isEmpty) {
      _snack('Programarea nu are ID valid pentru legare documente.');
      return;
    }

    int latestIndex = -1;
    DateTime latestUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0);

    for (var i = 0; i < _documents.length; i++) {
      final candidate = _documents[i];
      if (_linkedAppointmentIdOfDocument(candidate) != appointmentId) {
        continue;
      }
      final updatedAt = DateTime.tryParse('${candidate['updatedAt'] ?? ''}') ??
          DateTime.tryParse('${candidate['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (latestIndex < 0 || updatedAt.isAfter(latestUpdatedAt)) {
        latestIndex = i;
        latestUpdatedAt = updatedAt;
      }
    }

    if (latestIndex < 0) {
      _snack('Nu exista documente legate de aceasta programare.');
      return;
    }
    await _onViewDocumentFixed(latestIndex);
  }

  Future<void> _onOpenAppointment(int index) async {
    if (index < 0 || index >= _appointments.length) {
      return;
    }
    final row = _appointments[index];
    final openEdit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row['title'] ?? 'Programare'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: ${row['date'] ?? '-'}'),
            const SizedBox(height: 4),
            Text('Locație: ${row['location'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Închide'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Editează'),
          ),
        ],
      ),
    );
    if (openEdit == true) {
      await _onEditAppointment(index);
    }
  }

  Future<void> _onEditAppointment(int index) async {
    if (index < 0 || index >= _appointments.length) {
      return;
    }
    final row = _appointments[index];
    final titleController =
        TextEditingController(text: '${row['title'] ?? ''}');
    final locationController =
        TextEditingController(text: '${row['location'] ?? ''}');
    DateTime date = _parseDateOrNow('${row['date'] ?? ''}');

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editează programare'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titlu'),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Locație'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (picked == null) return;
                    setDialogState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_formatDate(date)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                ...row,
                'id':
                    '${row['id'] ?? 'job-appt-${DateTime.now().millisecondsSinceEpoch}'}',
                'jobId': '${row['jobId'] ?? widget.job.id}',
                'title': titleController.text.trim(),
                'location': locationController.text.trim(),
                'date': _formatDate(date),
              }),
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    locationController.dispose();
    if (updated == null) return;

    await _upsertLocalAppointment(updated);
    await _loadData();
    await _appendJournal(
      action: 'appointment_edited',
      message: 'Programare editata: ${updated['title'] ?? '-'}',
    );
  }

  Future<void> _onDeleteAppointment(int index) async {
    if (index < 0 || index >= _appointments.length) {
      return;
    }

    final row = _appointments[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere programare'),
        content:
            const Text('Sigur vrei să ștergi această programare asociată?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final id = '${row['id'] ?? ''}'.trim();
    if (id.isNotEmpty) {
      try {
        await widget.repository.deleteAppointment(id);
      } catch (e) {
        debugPrint('[LucrareDetalii] deleteAppointment eșuat (queue rămâne plasă de siguranță): $e');
      }
      // Queue the delete in OfflineSyncRuntime as a safety net — ensures the
      // tombstone is written even if the repository call above partially failed.
      try {
        await OfflineSyncRuntime.instance.queueAppointmentDelete(id);
      } catch (e) {
        debugPrint('[LucrareDetalii] queueAppointmentDelete eșuat: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final localRows = _readRows(prefs.getString(_appointmentsKey));
    final nextLocalRows = localRows
        .where((e) => '${e['id'] ?? ''}'.trim() != id)
        .toList(growable: false);
    await _saveRows(_appointmentsKey, nextLocalRows);

    if (!mounted) return;
    setState(() {
      _appointments = _appointments
          .where((e) => '${e['id'] ?? ''}'.trim() != id)
          .toList(growable: false);
      if (_selectedAppointmentFilterId == id) {
        _selectedAppointmentFilterId = null;
      }
    });
    await _appendJournal(
      action: 'appointment_deleted',
      message: 'Programare stearsa: ${row['title'] ?? '-'}',
    );
  }

  Future<void> _onAddMaterial() async {
    LucrareMaterialOption? selectedMaterial;
    final nameController = TextEditingController();
    final umController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: '0');

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adaugă material'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Autocomplete material — sugestii live din catalog ──
                Autocomplete<LucrareMaterialOption>(
                  displayStringForOption: (m) => m.name,
                  optionsBuilder: (textEditingValue) {
                    final q = textEditingValue.text.toLowerCase().trim();
                    if (q.isEmpty) return _materialsCatalog.take(8);
                    return _materialsCatalog
                        .where((m) => m.name.toLowerCase().contains(q))
                        .take(10);
                  },
                  onSelected: (m) {
                    setDialogState(() {
                      selectedMaterial = m;
                      umController.text = m.um;
                      priceController.text = m.price.toStringAsFixed(2);
                    });
                  },
                  fieldViewBuilder:
                      (ctx, autoCtrl, focusNode, onFieldSubmitted) {
                    // Sincronizează controller-ul intern cu nameController
                    autoCtrl.addListener(
                        () => nameController.text = autoCtrl.text);
                    return TextField(
                      controller: autoCtrl,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Material',
                        hintText:
                            'Tastează pentru sugestii sau scriere liberă...',
                      ),
                      onChanged: (_) =>
                          setDialogState(() => selectedMaterial = null),
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) {
                    final rows = options.toList(growable: false);
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                            minWidth: 380,
                            maxWidth: 560,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: rows.length,
                            itemBuilder: (_, i) {
                              final m = rows[i];
                              return ListTile(
                                dense: true,
                                title: Text(m.name),
                                subtitle: Text(
                                    'UM: ${m.um} • Preț: ${m.price.toStringAsFixed(2)}'),
                                onTap: () => onSelected(m),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: umController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Unitate măsură'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Cantitate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Preț unitar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final qty = double.tryParse(
                        qtyController.text.replaceAll(',', '.')) ??
                    0;
                final price = double.tryParse(
                        priceController.text.replaceAll(',', '.')) ??
                    0;
                final um = umController.text.trim();
                final matId = selectedMaterial?.id ??
                    'mat-${DateTime.now().millisecondsSinceEpoch}';
                Navigator.of(context).pop({
                  'id': 'job-mat-${DateTime.now().millisecondsSinceEpoch}',
                  'materialId': matId,
                  'name': name,
                  'um': um.isEmpty ? (selectedMaterial?.um ?? '') : um,
                  'qty': qty,
                  'price': price,
                  'total': qty * price,
                });
              },
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    umController.dispose();
    qtyController.dispose();
    priceController.dispose();
    if (created == null) return;

    // Dacă materialul nu era în catalog, îl adaugă automat pentru viitoare sugestii
    final savedName = '${created['name'] ?? ''}'.trim();
    if (selectedMaterial == null && savedName.isNotEmpty) {
      final existing = await MasterLocalStore.readMaterials();
      final alreadyExists = existing.any(
          (m) => m.name.toLowerCase() == savedName.toLowerCase());
      if (!alreadyExists) {
        final newMat = MasterMaterial(
          id: '${created['materialId']}',
          name: savedName,
          unit: '${created['um'] ?? ''}',
          price:
              double.tryParse('${created['price'] ?? 0}'.replaceAll(',', '.')) ??
                  0,
          notes: '',
        );
        await MasterLocalStore.writeMaterials([...existing, newMat]);
        // Actualizează catalogul în pagina curentă
        setState(() {
          _materialsCatalog = [
            ..._materialsCatalog,
            LucrareMaterialOption(
              id: newMat.id,
              name: newMat.name,
              um: newMat.unit,
              price: newMat.price,
            ),
          ];
        });
      }
    }

    final next = <Map<String, dynamic>>[..._materials, created];
    await _persistJobMaterials(next);
    if (!mounted) return;
    setState(() => _materials = next);
    await _appendJournal(
      action: 'material_added',
      message: 'Material adaugat: ${created['name'] ?? '-'}',
    );
  }

  Future<void> _onEditMaterial(int index) async {
    if (index < 0 || index >= _materials.length) {
      return;
    }
    final row = _materials[index];
    final existingName = '${row['name'] ?? ''}'.trim();
    // Caută în catalog după ID sau după nume
    LucrareMaterialOption? selectedMaterial;
    final existingId = '${row['materialId'] ?? ''}'.trim();
    if (existingId.isNotEmpty) {
      selectedMaterial = _materialsCatalog
          .where((m) => m.id == existingId)
          .fold<LucrareMaterialOption?>(null, (_, m) => m);
    }
    selectedMaterial ??= _materialsCatalog
        .where((m) => m.name.toLowerCase() == existingName.toLowerCase())
        .fold<LucrareMaterialOption?>(null, (_, m) => m);

    final nameController = TextEditingController(text: existingName);
    final umController = TextEditingController(text: '${row['um'] ?? ''}');
    final qtyController =
        TextEditingController(text: _asDouble(row['qty']).toString());
    final priceController =
        TextEditingController(text: _asDouble(row['price']).toString());

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalPreview() {
            final qty =
                double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0;
            final price =
                double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
            return qty * price;
          }

          return AlertDialog(
            scrollable: true,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actionsOverflowDirection: VerticalDirection.down,
            title: const Text('Editează material'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Autocomplete material cu text pre-completat ────────
                  Autocomplete<LucrareMaterialOption>(
                    initialValue: TextEditingValue(text: existingName),
                    displayStringForOption: (m) => m.name,
                    optionsBuilder: (textEditingValue) {
                      final q = textEditingValue.text.toLowerCase().trim();
                      if (q.isEmpty) return _materialsCatalog.take(8);
                      return _materialsCatalog
                          .where((m) => m.name.toLowerCase().contains(q))
                          .take(10);
                    },
                    onSelected: (m) {
                      setDialogState(() {
                        selectedMaterial = m;
                        nameController.text = m.name;
                        umController.text = m.um;
                        priceController.text = m.price.toStringAsFixed(2);
                      });
                    },
                    fieldViewBuilder:
                        (ctx, autoCtrl, focusNode, onFieldSubmitted) {
                      autoCtrl.addListener(
                          () => nameController.text = autoCtrl.text);
                      return TextField(
                        controller: autoCtrl,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Material',
                          hintText: 'Tastează pentru sugestii...',
                        ),
                        onChanged: (_) =>
                            setDialogState(() => selectedMaterial = null),
                      );
                    },
                    optionsViewBuilder: (ctx, onSelected, options) {
                      final rows = options.toList(growable: false);
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 240,
                              minWidth: 380,
                              maxWidth: 560,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: rows.length,
                              itemBuilder: (_, i) {
                                final m = rows[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(m.name),
                                  subtitle: Text(
                                      'UM: ${m.um} • Preț: ${m.price.toStringAsFixed(2)}'),
                                  onTap: () => onSelected(m),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: umController,
                    decoration: const InputDecoration(labelText: 'UM'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Cantitate'),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Preț unitar'),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total: ${totalPreview().toStringAsFixed(2)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final qty = double.tryParse(
                          qtyController.text.replaceAll(',', '.')) ??
                      0;
                  final price = double.tryParse(
                          priceController.text.replaceAll(',', '.')) ??
                      0;
                  final matId = selectedMaterial?.id ??
                      '${row['materialId'] ?? 'mat-${DateTime.now().millisecondsSinceEpoch}'}';
                  final um = umController.text.trim().isEmpty
                      ? (selectedMaterial?.um ?? '${row['um'] ?? ''}')
                      : umController.text.trim();
                  Navigator.of(context).pop({
                    ...row,
                    'id': '${row['id'] ?? 'job-mat-${DateTime.now().millisecondsSinceEpoch}'}',
                    'materialId': matId,
                    'name': name,
                    'um': um,
                    'qty': qty,
                    'price': price,
                    'total': qty * price,
                  });
                },
                child: const Text('Salvează'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    umController.dispose();
    qtyController.dispose();
    priceController.dispose();
    if (updated == null) return;

    // Dacă materialul editat e nou (nu din catalog), adaugă-l în catalog
    final savedName = '${updated['name'] ?? ''}'.trim();
    if (selectedMaterial == null && savedName.isNotEmpty) {
      final existing = await MasterLocalStore.readMaterials();
      final alreadyExists = existing.any(
          (m) => m.name.toLowerCase() == savedName.toLowerCase());
      if (!alreadyExists) {
        final newMat = MasterMaterial(
          id: '${updated['materialId']}',
          name: savedName,
          unit: '${updated['um'] ?? ''}',
          price: double.tryParse(
                  '${updated['price'] ?? 0}'.replaceAll(',', '.')) ??
              0,
          notes: '',
        );
        await MasterLocalStore.writeMaterials([...existing, newMat]);
        if (mounted) {
          setState(() {
            _materialsCatalog = [
              ..._materialsCatalog,
              LucrareMaterialOption(
                id: newMat.id,
                name: newMat.name,
                um: newMat.unit,
                price: newMat.price,
              ),
            ];
          });
        }
      }
    }

    final next = [..._materials];
    next[index] = updated;
    await _persistJobMaterials(next);
    if (!mounted) return;
    setState(() => _materials = next);
    await _appendJournal(
      action: 'material_edited',
      message: 'Material editat: ${updated['name'] ?? '-'}',
    );
  }

  Future<void> _onDeleteMaterial(int index) async {
    if (index < 0 || index >= _materials.length) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere material'),
        content: const Text('Sigur vrei să ștergi acest material asociat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final deletedName = '${_materials[index]['name'] ?? '-'}';
    final next = [..._materials]..removeAt(index);
    await _persistJobMaterials(next);
    if (!mounted) return;
    setState(() => _materials = next);
    await _appendJournal(
      action: 'material_deleted',
      message: 'Material sters: $deletedName',
    );
  }

  Future<void> _onAddLabor() async {
    var options = <Map<String, dynamic>>[
      if (_assignedTeam != null)
        {
          'id': 'team:${_assignedTeam!.id}',
          'label': 'Echipă: ${_assignedTeam!.label}',
          'dailyAllowance':
              _teamDailyAllowanceById(_assignedTeam!.id, _teamsSourceRows),
          'defaultLodgingCost':
              _teamLodgingById(_assignedTeam!.id, _teamsSourceRows),
          'requiresLodgingByDefault':
              _teamRequiresLodgingById(_assignedTeam!.id, _teamsSourceRows),
        },
      ..._employees.where((e) => e.active).map(
            (e) => {
              'id': 'emp:${e.id}',
              'label': e.label,
              'hourlyRate': e.hourlyRate,
              'dailyAllowance': e.dailyAllowance,
              'defaultLodgingCost': e.defaultLodgingCost,
              'requiresLodgingByDefault': e.requiresLodgingByDefault,
            },
          ),
    ];

    options = _dedupeDropdownOptions(options);
    if (options.isEmpty) {
      _snack('Nu există angajați disponibili.');
      return;
    }

    String? selectedWhoId;
    DateTime periodStart = DateTime.now();
    DateTime periodEnd = DateTime.now();
    final hoursController = TextEditingController(text: '8');
    final hoursPerDayController = TextEditingController(text: '8');
    final tripDaysController = TextEditingController(text: '0');
    double selectedPerDiemPerDay = 0.0;
    double selectedLodgingPerDay = 0.0;
    bool includeDiurna = false;
    bool includeCazare = false;
    final zileDiurnaController = TextEditingController(text: '0');
    final valoareDiurnaController = TextEditingController(text: '0');
    final noptiCazareController = TextEditingController(text: '0');
    final valoareCazareController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    void syncComputedValues() {
      if (periodEnd.isBefore(periodStart)) {
        periodEnd = periodStart;
      }
      final tripDays =
          _laborPeriodDays(periodStart: periodStart, periodEnd: periodEnd);
      final hoursPerDay = _sanitizeLaborHoursPerDay(hoursPerDayController.text);
      hoursPerDayController.text = _formatDecimal(hoursPerDay);
      hoursController.text = _formatDecimal(tripDays * hoursPerDay);
      tripDaysController.text = _formatDecimal(tripDays);
      zileDiurnaController.text =
          includeDiurna ? _formatDecimal(tripDays) : '0';
      noptiCazareController.text =
          includeCazare ? _formatDecimal(tripDays) : '0';
    }

    syncComputedValues();

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adaugă manoperă / ore'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: selectedWhoId,
                    decoration:
                        const InputDecoration(labelText: 'Persoană / echipă'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selectează'),
                      ),
                      ...options.map(
                        (o) => DropdownMenuItem<String?>(
                          value: o['id'],
                          child: Text(o['label'] ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      selectedWhoId = value;
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      final selected = options
                          .where((o) => '${o['id'] ?? ''}' == value)
                          .toList();
                      if (selected.isEmpty) return;
                      final selectedItem = selected.first;
                      final normalizedType =
                          value.startsWith('team:') ? 'team' : 'person';
                      final rate = _laborRateForWhoId(
                        value,
                        type: normalizedType,
                        whoLabel: '${selectedItem['label'] ?? '-'}',
                      );
                      final diurnaPerDay = normalizedType == 'team'
                          ? _teamDailyAllowanceById(
                              value.substring(5), _teamsSourceRows)
                          : _asDouble(selectedItem['dailyAllowance']);
                      final cazarePerNight = normalizedType == 'team'
                          ? _teamLodgingById(
                              value.substring(5), _teamsSourceRows)
                          : _asDouble(selectedItem['defaultLodgingCost']);
                      final requiresCazare = normalizedType == 'team'
                          ? _teamRequiresLodgingById(
                              value.substring(5), _teamsSourceRows)
                          : (selectedItem['requiresLodgingByDefault'] == true);
                      selectedPerDiemPerDay = diurnaPerDay;
                      selectedLodgingPerDay = cazarePerNight;
                      includeDiurna = diurnaPerDay > 0;
                      includeCazare = requiresCazare && cazarePerNight > 0;
                      valoareDiurnaController.text =
                          diurnaPerDay.toStringAsFixed(2);
                      valoareCazareController.text =
                          cazarePerNight.toStringAsFixed(2);
                      syncComputedValues();
                      if (rate > 0) {
                        // keep in sync with displayed/calculated rate
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: periodStart,
                              firstDate: DateTime(DateTime.now().year - 5),
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              periodStart = picked;
                              syncComputedValues();
                            });
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Start: ${_formatDate(periodStart)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: periodEnd.isBefore(periodStart)
                                  ? periodStart
                                  : periodEnd,
                              firstDate: periodStart,
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              periodEnd = picked;
                              syncComputedValues();
                            });
                          },
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text('Sfârșit: ${_formatDate(periodEnd)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursPerDayController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Ore/zi'),
                          onChanged: (_) => setDialogState(syncComputedValues),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Ore totale',
                            helperText: 'Se recalculează din perioadă x ore/zi',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: zileDiurnaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Zile diurnă'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valoareDiurnaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valoare diurnă/zi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noptiCazareController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Nopți cazare'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valoareCazareController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valoare cazare/noapte'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tripDaysController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Numar zile deplasare'),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeDiurna,
                    title: const Text('Include diurna'),
                    subtitle: Text(
                        'Valoare/zi: ${selectedPerDiemPerDay.toStringAsFixed(2)}'),
                    onChanged: (value) => setDialogState(() {
                      includeDiurna = value;
                      syncComputedValues();
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeCazare,
                    title: const Text('Include cazare'),
                    subtitle: Text(
                        'Valoare/zi: ${selectedLodgingPerDay.toStringAsFixed(2)}'),
                    onChanged: (value) => setDialogState(() {
                      includeCazare = value;
                      syncComputedValues();
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Observații'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează')),
            FilledButton(
              onPressed: () {
                if (selectedWhoId == null || selectedWhoId!.trim().isEmpty) {
                  return;
                }
                final normalizedSelection =
                    _safeDropdownValue(selectedWhoId, options);
                if (normalizedSelection == null) return;
                final selected = options
                    .where((o) => o['id'] == normalizedSelection)
                    .toList();
                if (selected.isEmpty) return;
                if (periodEnd.isBefore(periodStart)) {
                  periodEnd = periodStart;
                }
                final hours = double.tryParse(
                        hoursController.text.replaceAll(',', '.')) ??
                    0;
                final tripDays = double.tryParse(
                        tripDaysController.text.replaceAll(',', '.')) ??
                    0;
                final valoareDiurnaPeZi = selectedPerDiemPerDay;
                final valoareCazarePeNoapte = selectedLodgingPerDay;
                final zileDiurna = includeDiurna ? tripDays : 0.0;
                final noptiCazare = includeCazare ? tripDays : 0.0;
                final rate = _laborRateForWhoId(
                  normalizedSelection,
                  type: normalizedSelection.startsWith('team:')
                      ? 'team'
                      : 'person',
                  whoLabel: '${selected.first['label'] ?? '-'}',
                );
                final costOre = hours * rate;
                final costDiurna = zileDiurna * valoareDiurnaPeZi;
                final costCazare = noptiCazare * valoareCazarePeNoapte;
                Navigator.of(context).pop({
                  'id': 'job-labor-${DateTime.now().millisecondsSinceEpoch}',
                  'jobId': widget.job.id,
                  'whoId': normalizedSelection,
                  'type': normalizedSelection.startsWith('team:')
                      ? 'team'
                      : 'person',
                  'whoLabel': '${selected.first['label'] ?? '-'}',
                  'who': '${selected.first['label'] ?? '-'}',
                  'date': _formatDate(periodStart),
                  'periodStartDate': _encodeLaborPeriodDate(periodStart),
                  'periodEndDate': _encodeLaborPeriodDate(periodEnd),
                  'hoursPerDay':
                      _sanitizeLaborHoursPerDay(hoursPerDayController.text),
                  'hours': hours,
                  'hourlyRate': rate,
                  'tripDays': tripDays,
                  'includeDiurna': includeDiurna,
                  'includeCazare': includeCazare,
                  'zileDiurna': zileDiurna,
                  'valoareDiurnaPeZi': valoareDiurnaPeZi,
                  'noptiCazare': noptiCazare,
                  'valoareCazarePeNoapte': valoareCazarePeNoapte,
                  'costOre': costOre,
                  'costDiurna': costDiurna,
                  'costCazare': costCazare,
                  'costTotalLinie': costOre + costDiurna + costCazare,
                  'notes': notesController.text.trim(),
                });
              },
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );

    hoursController.dispose();
    hoursPerDayController.dispose();
    tripDaysController.dispose();
    zileDiurnaController.dispose();
    valoareDiurnaController.dispose();
    noptiCazareController.dispose();
    valoareCazareController.dispose();
    notesController.dispose();
    if (created == null) return;

    final next = <Map<String, dynamic>>[..._labor, created];
    await _saveLaborRows(next);
    await _appendJournal(
      action: 'labor_added',
      message: 'Manopera adaugata: ${created['who'] ?? '-'}',
    );
  }

  double _asDouble(dynamic raw) => lucrareAsDouble(raw);

  bool _asBool(dynamic raw) => lucrareAsBool(raw);

  String _formatDecimal(double value) => lucrareFormatDecimal(value);

  DateTime _dateOnly(DateTime value) => lucrareDateOnly(value);

  DateTime? _tryParseLaborDate(dynamic raw) => lucrareTryParseLaborDate(raw);

  String _encodeLaborPeriodDate(DateTime value) =>
      lucrareEncodeLaborPeriodDate(value);

  double _laborPeriodDays({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final start = _dateOnly(periodStart);
    final end = periodEnd.isBefore(periodStart) ? start : _dateOnly(periodEnd);
    return end.difference(start).inDays.toDouble() + 1;
  }

  double _sanitizeLaborHoursPerDay(dynamic raw) {
    final value = _asDouble(raw);
    return value > 0 ? value : 8.0;
  }

  DateTime? _laborPeriodStart(Map<String, dynamic> row) {
    return _tryParseLaborDate(
      row['periodStartDate'] ?? row['startDate'] ?? row['date'],
    );
  }

  DateTime? _laborPeriodEnd(Map<String, dynamic> row) {
    return _tryParseLaborDate(
      row['periodEndDate'] ?? row['endDate'] ?? row['periodStartDate'],
    );
  }

  double _laborHoursPerDay(Map<String, dynamic> row) {
    final explicit = _asDouble(row['hoursPerDay']);
    if (explicit > 0) return explicit;
    final hours = _asDouble(row['hours']);
    final tripDays = _laborTripDays(row);
    if (hours > 0 && tripDays > 0) {
      return hours / tripDays;
    }
    return 8.0;
  }

  String _laborPeriodLabel(Map<String, dynamic> row) {
    final start = _laborPeriodStart(row);
    if (start == null) {
      final date = '${row['date'] ?? ''}'.trim();
      return date.isEmpty ? '-' : date;
    }
    final end = _laborPeriodEnd(row) ?? start;
    final startLabel = _formatDate(start);
    final endLabel = _formatDate(end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return '$startLabel - $endLabel';
  }

  List<JobPartnerWorker> _partnerWorkersFor(String partnerId) {
    return _partnerWorkers
        .where((worker) => worker.partnerId == partnerId)
        .toList(growable: false);
  }

  List<JobPartnerVehicle> _partnerVehiclesFor(String partnerId) {
    return _partnerVehicles
        .where((vehicle) => vehicle.partnerId == partnerId)
        .toList(growable: false);
  }

  double _partnerWorkersTotalFor(String partnerId) {
    return _partnerWorkersFor(partnerId)
        .fold<double>(0, (sum, worker) => sum + worker.total);
  }

  double _partnerVehiclesTotalFor(String partnerId) {
    return _partnerVehiclesFor(partnerId)
        .fold<double>(0, (sum, vehicle) => sum + vehicle.total);
  }

  double _partnerTotalFor(String partnerId) {
    return _partnerWorkersTotalFor(partnerId) +
        _partnerVehiclesTotalFor(partnerId);
  }

  String _currencyLabel(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) {
      return 'RON';
    }
    if (normalized.length == 1) {
      return normalized.first;
    }
    return 'monede mixte';
  }

  String _partnerWorkerCurrencyFor(String partnerId) {
    return _currencyLabel(
      _partnerWorkersFor(partnerId).map((worker) => worker.currency),
    );
  }

  String _partnerVehicleCurrencyFor(String partnerId) {
    return _currencyLabel(
      _partnerVehiclesFor(partnerId).map((vehicle) => vehicle.currency),
    );
  }

  String _partnerCurrencyFor(String partnerId) {
    return _currencyLabel([
      ..._partnerWorkersFor(partnerId).map((worker) => worker.currency),
      ..._partnerVehiclesFor(partnerId).map((vehicle) => vehicle.currency),
    ]);
  }

  double get _partnerWorkersTotal =>
      _partnerWorkers.fold<double>(0, (sum, worker) => sum + worker.total);

  double get _partnerVehiclesTotal =>
      _partnerVehicles.fold<double>(0, (sum, vehicle) => sum + vehicle.total);

  double get _partnersTotal => _partnerWorkersTotal + _partnerVehiclesTotal;

  String get _partnerWorkersCurrency =>
      _currencyLabel(_partnerWorkers.map((worker) => worker.currency));

  String get _partnerVehiclesCurrency =>
      _currencyLabel(_partnerVehicles.map((vehicle) => vehicle.currency));

  String get _partnersCurrency => _currencyLabel([
        ..._partnerWorkers.map((worker) => worker.currency),
        ..._partnerVehicles.map((vehicle) => vehicle.currency),
      ]);

  double get _ownVehiclesTotal =>
      _ownVehicles.fold<double>(0, (sum, v) => sum + v.total);

  String get _ownVehiclesCurrency =>
      _currencyLabel(_ownVehicles.map((v) => v.currency));

  double _materialLineTotal(Map<String, dynamic> row) {
    final explicit = _asDouble(row['total']);
    if (explicit > 0) {
      return explicit;
    }
    return _asDouble(row['qty']) * _asDouble(row['price']);
  }

  List<Map<String, dynamic>> _dedupeDropdownOptions(
      List<Map<String, dynamic>> source) {
    final byValue = <String, Map<String, dynamic>>{};
    for (final option in source) {
      final rawValue = '${option['id'] ?? ''}'.trim();
      if (rawValue.isEmpty) continue;

      String normalizedValue = rawValue;
      if (rawValue.startsWith('emp:team:')) {
        normalizedValue =
            'team:${rawValue.substring('emp:team:'.length).trim()}';
      } else if (rawValue.startsWith('emp:echipa:') ||
          rawValue.startsWith('emp:echipă:')) {
        normalizedValue =
            'team:${rawValue.substring(rawValue.indexOf(':') + 1).replaceFirst('echipa:', '').replaceFirst('echipă:', '').trim()}';
      } else if (rawValue.startsWith('echipa:') ||
          rawValue.startsWith('echipă:')) {
        normalizedValue =
            'team:${rawValue.substring(rawValue.indexOf(':') + 1).trim()}';
      } else if (!rawValue.startsWith('emp:') &&
          !rawValue.startsWith('team:')) {
        normalizedValue = 'emp:$rawValue';
      }

      if (byValue.containsKey(normalizedValue)) continue;
      byValue[normalizedValue] = {
        ...option,
        'id': normalizedValue,
      };
    }
    return byValue.values.toList(growable: false);
  }

  String? _safeDropdownValue(
      String? value, List<Map<String, dynamic>> options) {
    if (value == null) return null;
    var normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('emp:team:')) {
      normalized = 'team:${normalized.substring('emp:team:'.length).trim()}';
    } else if (normalized.startsWith('emp:echipa:') ||
        normalized.startsWith('emp:echipă:')) {
      normalized =
          'team:${normalized.substring(normalized.indexOf(':') + 1).replaceFirst('echipa:', '').replaceFirst('echipă:', '').trim()}';
    }
    if (normalized.startsWith('echipa:') || normalized.startsWith('echipă:')) {
      normalized =
          'team:${normalized.substring(normalized.indexOf(':') + 1).trim()}';
    }
    if (!normalized.startsWith('emp:') && !normalized.startsWith('team:')) {
      normalized = 'emp:$normalized';
    }
    final count =
        options.where((o) => '${o['id'] ?? ''}'.trim() == normalized).length;
    return count == 1 ? normalized : null;
  }

  String _normalizeEmployeeRef(String raw) {
    var value = raw.trim();
    if (value.startsWith('emp:')) {
      value = value.substring(4).trim();
    }
    return value.toLowerCase();
  }

  double _employeeRateById(String employeeId) {
    final normalizedRef = _normalizeEmployeeRef(employeeId);
    if (normalizedRef.isEmpty) return 0;

    for (final employee in _employees) {
      if (!employee.active) continue;
      final employeeIdNormalized = _normalizeEmployeeRef(employee.id);
      final employeeLabelNormalized = employee.label.trim().toLowerCase();
      if (employeeIdNormalized == normalizedRef ||
          employeeLabelNormalized == normalizedRef) {
        return employee.hourlyRate;
      }
    }
    return 0;
  }

  double _teamRateById(String teamId, List<Map<String, dynamic>> teamRows) {
    String normalizeTeamRef(String raw) {
      var value = raw.trim().toLowerCase();
      if (value.startsWith('team:')) {
        value = value.substring(5).trim();
      } else if (value.startsWith('emp:team:')) {
        value = value.substring('emp:team:'.length).trim();
      } else if (value.startsWith('emp:echipa:')) {
        value = value.substring('emp:echipa:'.length).trim();
      } else if (value.startsWith('emp:echipă:')) {
        value = value.substring('emp:echipă:'.length).trim();
      } else if (value.startsWith('emp:echipă:')) {
        value = value.substring('emp:echipă:'.length).trim();
      } else if (value.startsWith('echipa:')) {
        value = value.substring('echipa:'.length).trim();
      } else if (value.startsWith('echipă:')) {
        value = value.substring('echipă:'.length).trim();
      } else if (value.startsWith('echipă:')) {
        value = value.substring('echipă:'.length).trim();
      }
      return value;
    }

    final probe = normalizeTeamRef(teamId);
    if (probe.isEmpty) return 0;

    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = normalizeTeamRef('${row['id'] ?? ''}');
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;

    final explicitTeamRate = _asDouble(
      teamRow['hourlyRate'] ??
          teamRow['hourly_rate'] ??
          teamRow['tarifOrar'] ??
          teamRow['tarif_orar'] ??
          teamRow['rate'],
    );
    if (explicitTeamRate > 0) return explicitTeamRate;

    final members = _extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;

    var teamRate = 0.0;
    for (final member in members) {
      teamRate += _employeeRateById(member);
    }
    return teamRate;
  }

  LucrareOption? _findActiveEmployeeByRef(String reference) {
    final normalizedRef = _normalizeEmployeeRef(reference);
    if (normalizedRef.isEmpty) return null;
    for (final employee in _employees) {
      if (!employee.active) continue;
      final employeeIdNormalized = _normalizeEmployeeRef(employee.id);
      final employeeLabelNormalized = employee.label.trim().toLowerCase();
      if (employeeIdNormalized == normalizedRef ||
          employeeLabelNormalized == normalizedRef) {
        return employee;
      }
    }
    return null;
  }

  double _employeeDailyAllowanceByRef(String reference) {
    final employee = _findActiveEmployeeByRef(reference);
    return employee?.dailyAllowance ?? 0;
  }

  double _employeeLodgingByRef(String reference) {
    final employee = _findActiveEmployeeByRef(reference);
    if (employee == null) return 0;
    if (!employee.requiresLodgingByDefault) return 0;
    return employee.defaultLodgingCost;
  }

  bool _employeeRequiresLodgingByRef(String reference) {
    final employee = _findActiveEmployeeByRef(reference);
    return employee?.requiresLodgingByDefault ?? false;
  }

  double _teamDailyAllowanceById(
      String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return 0;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;
    final members = _extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;
    var total = 0.0;
    for (final member in members) {
      total += _employeeDailyAllowanceByRef(member);
    }
    return total;
  }

  double _teamLodgingById(String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return 0;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return 0;
    final members = _extractTeamMembers(teamRow);
    if (members.isEmpty) return 0;
    var total = 0.0;
    for (final member in members) {
      total += _employeeLodgingByRef(member);
    }
    return total;
  }

  bool _teamRequiresLodgingById(
      String teamId, List<Map<String, dynamic>> teamRows) {
    final probe = teamId.trim().toLowerCase();
    if (probe.isEmpty) return false;
    Map<String, dynamic>? teamRow;
    for (final row in teamRows) {
      final rowId = '${row['id'] ?? ''}'.trim().toLowerCase();
      final rowName = '${row['name'] ?? ''}'.trim().toLowerCase();
      if (rowId == probe || rowName == probe) {
        teamRow = row;
        break;
      }
    }
    if (teamRow == null) return false;
    final members = _extractTeamMembers(teamRow);
    if (members.isEmpty) return false;
    for (final member in members) {
      if (_employeeRequiresLodgingByRef(member)) return true;
    }
    return false;
  }

  String _normalizedKeyPart(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(':', '_');
  }

  String _canonicalLaborType({
    required String rawType,
    required String rawWhoId,
    required String rawWhoLabel,
  }) {
    final type = rawType.trim().toLowerCase();
    if (type == 'team' || type == 'echipa' || type == 'echipă') {
      return 'team';
    }
    if (type == 'person' ||
        type == 'employee' ||
        type == 'persoana' ||
        type == 'persoană') {
      return 'person';
    }

    final whoId = rawWhoId.trim().toLowerCase();
    if (whoId.startsWith('team:') ||
        whoId.startsWith('emp:team:') ||
        whoId.startsWith('emp:echipa:') ||
        whoId.startsWith('emp:echipă:') ||
        whoId.startsWith('echipa:') ||
        whoId.startsWith('echipă:')) {
      return 'team';
    }
    if (whoId.startsWith('emp:')) {
      return 'person';
    }

    final whoLabel = rawWhoLabel.trim().toLowerCase();
    if (whoLabel.startsWith('echipa') || whoLabel.startsWith('echipă')) {
      return 'team';
    }
    return 'person';
  }

  String _canonicalLaborWhoId({
    required String rawWhoId,
    required String normalizedType,
    required String rawWhoLabel,
  }) {
    var value = rawWhoId.trim();
    if (value.startsWith('emp:team:')) {
      value = 'team:${value.substring('emp:team:'.length).trim()}';
    } else if (value.startsWith('emp:echipa:') ||
        value.startsWith('emp:echipă:')) {
      value =
          'team:${value.substring(value.indexOf(':') + 1).replaceFirst('echipa:', '').replaceFirst('echipă:', '').trim()}';
    } else if (value.startsWith('echipa:') || value.startsWith('echipă:')) {
      value = 'team:${value.substring(value.indexOf(':') + 1).trim()}';
    }

    if (value.startsWith('team:')) {
      final id = value.substring(5).trim();
      if (id.isNotEmpty) return 'team:$id';
    }
    if (value.startsWith('emp:')) {
      final id = value.substring(4).trim();
      if (id.isNotEmpty) return 'emp:$id';
    }
    if (value.isNotEmpty) {
      final prefix = normalizedType == 'team' ? 'team' : 'emp';
      return '$prefix:$value';
    }

    final label = rawWhoLabel.trim();
    if (label.isNotEmpty) {
      final cleanedLabel = label
          .replaceFirst(RegExp(r'^echip[ăa]\s*:\s*', caseSensitive: false), '')
          .trim();
      final key =
          _normalizedKeyPart(cleanedLabel.isEmpty ? label : cleanedLabel);
      final prefix = normalizedType == 'team' ? 'team' : 'emp';
      return '$prefix:$key';
    }
    return normalizedType == 'team' ? 'team:unknown' : 'emp:unknown';
  }

  double _teamRateByWhoLabel(String rawWhoLabel) {
    var label = rawWhoLabel.trim();
    if (label.isEmpty) return 0;
    label = label
        .replaceFirst(RegExp(r'^echip[ăa]\s*:\s*', caseSensitive: false), '')
        .trim();
    if (label.isEmpty) return 0;

    for (final row in _teamsSourceRows) {
      final rowId = '${row['id'] ?? ''}'.trim();
      final rowName = '${row['name'] ?? ''}'.trim();
      if (rowId.isEmpty && rowName.isEmpty) continue;
      final sameById =
          rowId.isNotEmpty && rowId.toLowerCase() == label.toLowerCase();
      final sameByName =
          rowName.isNotEmpty && rowName.toLowerCase() == label.toLowerCase();
      if (!sameById && !sameByName) continue;
      if (rowId.isNotEmpty) {
        return _teamRateById(rowId, _teamsSourceRows);
      }
      final members = _extractTeamMembers(row);
      if (members.isEmpty) return 0;
      return members.fold<double>(
          0, (sum, memberId) => sum + _employeeRateById(memberId));
    }
    return 0;
  }

  double _laborRateForWhoId(String whoId, {String? type, String? whoLabel}) {
    final normalizedType = _canonicalLaborType(
      rawType: type ?? '',
      rawWhoId: whoId,
      rawWhoLabel: whoLabel ?? '',
    );
    final value = _canonicalLaborWhoId(
      rawWhoId: whoId,
      normalizedType: normalizedType,
      rawWhoLabel: whoLabel ?? '',
    );
    if (value.isEmpty) return 0;

    if (value.startsWith('team:')) {
      final teamRate = _teamRateById(value.substring(5), _teamsSourceRows);
      if (teamRate > 0) return teamRate;
      final fallbackByLabel = _teamRateByWhoLabel(whoLabel ?? '');
      if (fallbackByLabel > 0) return fallbackByLabel;
      return 0;
    }
    if (value.startsWith('emp:')) {
      return _employeeRateById(value.substring(4));
    }
    return 0;
  }

  double _laborRateForRow(Map<String, dynamic> row) {
    final explicit = _asDouble(row['hourlyRate']);
    if (explicit > 0) return explicit;
    final whoId = '${row['whoId'] ?? ''}'.trim();
    final type = '${row['type'] ?? ''}'.trim();
    final whoLabel = '${row['whoLabel'] ?? row['who'] ?? ''}'.trim();
    return _laborRateForWhoId(whoId, type: type, whoLabel: whoLabel);
  }

  double _laborOreCost(Map<String, dynamic> row) {
    final hours = _asDouble(row['hours']);
    final rate = _laborRateForRow(row);
    return hours * rate;
  }

  double _laborTripDays(Map<String, dynamic> row) => (() {
        final periodStart = _laborPeriodStart(row);
        final periodEnd = _laborPeriodEnd(row);
        if (periodStart != null) {
          return _laborPeriodDays(
            periodStart: periodStart,
            periodEnd: periodEnd ?? periodStart,
          );
        }
        return _asDouble(row['tripDays'] ??
            row['zileDeplasare'] ??
            row['zileDiurna'] ??
            row['noptiCazare']);
      })();

  bool _laborIncludePerDiem(Map<String, dynamic> row) {
    if (row.containsKey('includeDiurna')) {
      return _asBool(row['includeDiurna']);
    }
    return _asDouble(row['zileDiurna'] ?? row['daysPerDiem']) > 0;
  }

  bool _laborIncludeLodging(Map<String, dynamic> row) {
    if (row.containsKey('includeCazare')) {
      return _asBool(row['includeCazare']);
    }
    return _asDouble(row['noptiCazare'] ?? row['nightsLodging']) > 0;
  }

  double _laborDaysPerDiem(Map<String, dynamic> row) {
    final fromFlags = _laborIncludePerDiem(row) ? _laborTripDays(row) : 0.0;
    if (fromFlags > 0) return fromFlags;
    return _asDouble(row['zileDiurna'] ?? row['daysPerDiem']);
  }

  double _laborPerDiemPerDay(Map<String, dynamic> row) =>
      _asDouble(row['valoareDiurnaPeZi'] ?? row['perDiemPerDay']);

  double _laborNightsLodging(Map<String, dynamic> row) {
    final fromFlags = _laborIncludeLodging(row) ? _laborTripDays(row) : 0.0;
    if (fromFlags > 0) return fromFlags;
    return _asDouble(row['noptiCazare'] ?? row['nightsLodging']);
  }

  double _laborLodgingPerNight(Map<String, dynamic> row) =>
      _asDouble(row['valoareCazarePeNoapte'] ?? row['lodgingPerNight']);

  double _laborPerDiemCost(Map<String, dynamic> row) {
    final explicit = _asDouble(row['costDiurna']);
    if (explicit > 0) return explicit;
    return _laborDaysPerDiem(row) * _laborPerDiemPerDay(row);
  }

  double _laborLodgingCost(Map<String, dynamic> row) {
    final explicit = _asDouble(row['costCazare']);
    if (explicit > 0) return explicit;
    return _laborNightsLodging(row) * _laborLodgingPerNight(row);
  }

  double _laborTotalLineCost(Map<String, dynamic> row) {
    final costOre = _laborOreCost(row);
    final costDiurna = _laborPerDiemCost(row);
    final costCazare = _laborLodgingCost(row);
    final calculated = costOre + costDiurna + costCazare;
    if (calculated > 0) return calculated;
    final legacy =
        _asDouble(row['costTotalLinie'] ?? row['costTotalLine'] ?? row['cost']);
    if (legacy > 0) return legacy;
    return costOre;
  }

  double _laborLineCost(Map<String, dynamic> row) {
    return _laborTotalLineCost(row);
  }

  DateTime _parseDateOrNow(String raw) => lucrareParseDateOrNow(raw);

  String _laborTypeOf(Map<String, dynamic> row) {
    return _canonicalLaborType(
      rawType: '${row['type'] ?? ''}',
      rawWhoId: '${row['whoId'] ?? ''}',
      rawWhoLabel: '${row['whoLabel'] ?? row['who'] ?? ''}',
    );

    final explicit = '${row['type'] ?? ''}'.trim().toLowerCase();
    if (explicit == 'team' || explicit == 'echipa') {
      return 'team';
    }
    if (explicit == 'person' ||
        explicit == 'employee' ||
        explicit == 'persoana') {
      return 'person';
    }
    final whoId = '${row['whoId'] ?? ''}'.trim().toLowerCase();
    if (whoId.startsWith('team:')) {
      return 'team';
    }
    if (whoId.startsWith('emp:')) {
      return 'person';
    }
    final who = '${row['who'] ?? ''}'.toLowerCase();
    if (who.startsWith('echipa') ||
        who.startsWith('echipă') ||
        who.contains('echipa')) {
      return 'team';
    }
    return 'person';
  }

  Map<String, dynamic> _normalizeLaborRow(Map<String, dynamic> row) {
    final nRawWhoId = '${row['whoId'] ?? ''}';
    final nRawWhoLabel = '${row['whoLabel'] ?? row['who'] ?? ''}'.trim();
    final nType = _canonicalLaborType(
      rawType: '${row['type'] ?? ''}',
      rawWhoId: nRawWhoId,
      rawWhoLabel: nRawWhoLabel,
    );
    final nWhoId = _canonicalLaborWhoId(
      rawWhoId: nRawWhoId,
      normalizedType: nType,
      rawWhoLabel: nRawWhoLabel,
    );
    final nWhoLabel = nRawWhoLabel.isEmpty
        ? (nType == 'team' ? 'Echipa' : 'Persoana')
        : nRawWhoLabel;
    final nDate = '${row['date'] ?? ''}'.trim().isEmpty
        ? _formatDate(DateTime.now())
        : '${row['date'] ?? ''}'.trim();
    final nPeriodStart =
        _laborPeriodStart(row) ?? _tryParseLaborDate(nDate) ?? DateTime.now();
    final nPeriodEnd = _laborPeriodEnd(row) ?? nPeriodStart;
    final nFallbackRate = _laborRateForWhoId(
      nWhoId,
      type: nType,
      whoLabel: nWhoLabel,
    );
    final nExplicitRate = _asDouble(row['hourlyRate']);
    final nRate = nExplicitRate > 0 ? nExplicitRate : nFallbackRate;
    final nRawJobId = '${row['jobId'] ?? ''}'.trim();
    final nRawZileDiurna = _asDouble(row['zileDiurna'] ?? row['daysPerDiem']);
    final nValDiurna =
        _asDouble(row['valoareDiurnaPeZi'] ?? row['perDiemPerDay']);
    final nRawNoptiCazare =
        _asDouble(row['noptiCazare'] ?? row['nightsLodging']);
    final nValCazare =
        _asDouble(row['valoareCazarePeNoapte'] ?? row['lodgingPerNight']);
    final nTripDays = _laborPeriodDays(
      periodStart: nPeriodStart,
      periodEnd: nPeriodEnd,
    );
    final nIncludeDiurna = row.containsKey('includeDiurna')
        ? _asBool(row['includeDiurna'])
        : nRawZileDiurna > 0;
    final nIncludeCazare = row.containsKey('includeCazare')
        ? _asBool(row['includeCazare'])
        : nRawNoptiCazare > 0;
    final nZileDiurna = nIncludeDiurna ? nTripDays : 0.0;
    final nNoptiCazare = nIncludeCazare ? nTripDays : 0.0;
    final nHoursPerDay = _sanitizeLaborHoursPerDay(
      row['hoursPerDay'] ??
          ((nTripDays > 0 && _asDouble(row['hours']) > 0)
              ? (_asDouble(row['hours']) / nTripDays)
              : 8.0),
    );
    final nHours = nTripDays * nHoursPerDay;
    final nCostOre = nHours * nRate;
    final nCostDiurna = _asDouble(row['costDiurna']) > 0
        ? _asDouble(row['costDiurna'])
        : (nZileDiurna * nValDiurna);
    final nCostCazare = _asDouble(row['costCazare']) > 0
        ? _asDouble(row['costCazare'])
        : (nNoptiCazare * nValCazare);
    final nLegacyTotal =
        _asDouble(row['costTotalLinie'] ?? row['costTotalLine'] ?? row['cost']);
    final nCostTotal = (() {
      final value = nCostOre + nCostDiurna + nCostCazare;
      if (value > 0) return value;
      if (nLegacyTotal > 0) return nLegacyTotal;
      return nCostOre;
    })();
    return {
      'id':
          '${row['id'] ?? 'job-labor-${DateTime.now().millisecondsSinceEpoch}'}',
      'jobId': nRawJobId.isEmpty ? widget.job.id : nRawJobId,
      'whoId': nWhoId,
      'type': nType,
      'whoLabel': nWhoLabel,
      'who': nWhoLabel,
      'date': _formatDate(nPeriodStart),
      'periodStartDate': _encodeLaborPeriodDate(nPeriodStart),
      'periodEndDate': _encodeLaborPeriodDate(nPeriodEnd),
      'hoursPerDay': nHoursPerDay,
      'hours': nHours,
      'hourlyRate': nRate,
      'tripDays': nTripDays,
      'includeDiurna': nIncludeDiurna,
      'includeCazare': nIncludeCazare,
      'zileDiurna': nZileDiurna,
      'valoareDiurnaPeZi': nValDiurna,
      'noptiCazare': nNoptiCazare,
      'valoareCazarePeNoapte': nValCazare,
      'costOre': nCostOre,
      'costDiurna': nCostDiurna,
      'costCazare': nCostCazare,
      'costTotalLinie': nCostTotal,
      'notes': '${row['notes'] ?? ''}'.trim(),
    };

    final rawWhoId = '${row['whoId'] ?? ''}'.trim();
    final rawType = '${row['type'] ?? ''}'.trim().toLowerCase();
    final normalizedType =
        rawType == 'team' || rawWhoId.startsWith('team:') ? 'team' : 'person';
    final normalizedWhoId = rawWhoId.isEmpty
        ? '${normalizedType == 'team' ? 'team' : 'emp'}:${(row['who'] ?? '').toString().trim().toLowerCase()}'
        : rawWhoId;
    final normalizedWho = '${row['who'] ?? ''}'.trim().isEmpty
        ? (normalizedType == 'team' ? 'Echipă' : 'Persoană')
        : '${row['who'] ?? ''}'.trim();
    final normalizedDate = '${row['date'] ?? ''}'.trim().isEmpty
        ? _formatDate(DateTime.now())
        : '${row['date'] ?? ''}'.trim();
    return {
      'id':
          '${row['id'] ?? 'job-labor-${DateTime.now().millisecondsSinceEpoch}'}',
      'whoId': normalizedWhoId,
      'type': normalizedType,
      'who': normalizedWho,
      'date': normalizedDate,
      'hours': _asDouble(row['hours']),
      'hourlyRate': _asDouble(row['hourlyRate']),
      'notes': '${row['notes'] ?? ''}'.trim(),
    };
  }

  String _laborDedupKey(Map<String, dynamic> row) {
    final type = '${row['type'] ?? ''}'.trim().toLowerCase();
    final whoId = '${row['whoId'] ?? ''}'.trim().toLowerCase();
    final date = '${row['date'] ?? ''}'.trim();
    final periodEnd = '${row['periodEndDate'] ?? ''}'.trim();
    final hoursPerDay = _formatDecimal(_asDouble(row['hoursPerDay']));
    return '$type|$whoId|$date|$periodEnd|$hoursPerDay';
  }

  List<Map<String, dynamic>> _dedupeLaborRows(List<Map<String, dynamic>> rows) {
    final merged = <String, Map<String, dynamic>>{};
    for (final raw in rows) {
      final row = _normalizeLaborRow(raw);
      final key = _laborDedupKey(row);
      if (!merged.containsKey(key)) {
        merged[key] = row;
        continue;
      }
      final existing = merged[key]!;
      final existingHours = _asDouble(existing['hours']);
      final newHours = _asDouble(row['hours']);
      final existingRate = _asDouble(existing['hourlyRate']);
      final newRate = _asDouble(row['hourlyRate']);
      final existingDays = _asDouble(existing['zileDiurna']);
      final newDays = _asDouble(row['zileDiurna']);
      final existingPerDiemValue = _asDouble(existing['valoareDiurnaPeZi']);
      final newPerDiemValue = _asDouble(row['valoareDiurnaPeZi']);
      final existingNights = _asDouble(existing['noptiCazare']);
      final newNights = _asDouble(row['noptiCazare']);
      final existingTripDays = _asDouble(existing['tripDays']);
      final newTripDays = _asDouble(row['tripDays']);
      final existingIncludeDiurna = _asBool(existing['includeDiurna']);
      final newIncludeDiurna = _asBool(row['includeDiurna']);
      final existingIncludeCazare = _asBool(existing['includeCazare']);
      final newIncludeCazare = _asBool(row['includeCazare']);
      final existingLodgingValue = _asDouble(existing['valoareCazarePeNoapte']);
      final newLodgingValue = _asDouble(row['valoareCazarePeNoapte']);
      final notesA = '${existing['notes'] ?? ''}'.trim();
      final notesB = '${row['notes'] ?? ''}'.trim();
      final mergedNotes = <String>[
        if (notesA.isNotEmpty) notesA,
        if (notesB.isNotEmpty && notesB != notesA) notesB,
      ].join(' | ');
      final mergedHours = existingHours + newHours;
      final mergedRate = existingRate > 0 ? existingRate : newRate;
      final mergedDays = existingDays + newDays;
      final mergedPerDiem =
          existingPerDiemValue > 0 ? existingPerDiemValue : newPerDiemValue;
      final mergedNights = existingNights + newNights;
      final mergedTripDays = existingTripDays + newTripDays;
      final mergedIncludeDiurna = existingIncludeDiurna || newIncludeDiurna;
      final mergedIncludeCazare = existingIncludeCazare || newIncludeCazare;
      final mergedLodging =
          existingLodgingValue > 0 ? existingLodgingValue : newLodgingValue;
      final mergedCostOre = mergedHours * mergedRate;
      final mergedCostDiurna = mergedDays * mergedPerDiem;
      final mergedCostCazare = mergedNights * mergedLodging;
      merged[key] = {
        ...existing,
        'hours': mergedHours,
        'hourlyRate': mergedRate,
        'tripDays': mergedTripDays,
        'includeDiurna': mergedIncludeDiurna,
        'includeCazare': mergedIncludeCazare,
        'zileDiurna': mergedDays,
        'valoareDiurnaPeZi': mergedPerDiem,
        'noptiCazare': mergedNights,
        'valoareCazarePeNoapte': mergedLodging,
        'costOre': mergedCostOre,
        'costDiurna': mergedCostDiurna,
        'costCazare': mergedCostCazare,
        'costTotalLinie': mergedCostOre + mergedCostDiurna + mergedCostCazare,
        'notes': mergedNotes,
      };
    }
    return merged.values.toList(growable: false);
  }

  Future<void> _saveLaborRows(List<Map<String, dynamic>> rows) async {
    final normalized = rows.map(_normalizeLaborRow).toList(growable: false);
    final deduped = _dedupeLaborRows(normalized);
    await _persistOperationalJobDetails(labor: deduped);
    if (!mounted) return;
    setState(() => _labor = deduped);
  }

  double get _materialsTotal =>
      _materials.fold<double>(0, (sum, row) => sum + _materialLineTotal(row));

  double get _laborOreTotal =>
      _labor.fold<double>(0, (sum, row) => sum + _laborOreCost(row));

  double get _laborDiurnaTotal =>
      _labor.fold<double>(0, (sum, row) => sum + _laborPerDiemCost(row));

  double get _laborCazareTotal =>
      _labor.fold<double>(0, (sum, row) => sum + _laborLodgingCost(row));

  double get _laborTotalCost =>
      _labor.fold<double>(0, (sum, row) => sum + _laborTotalLineCost(row));

  double get _laborCompleteTotal => _laborTotalCost;

  double get _realTotalCost => _materialsTotal + _laborTotalCost;

  double get _estimatedValue => widget.job.estimatedValue ?? 0;

  double get _estimatedVsRealDifference => _estimatedValue - _realTotalCost;

  Widget _buildTimeTrackingSection() {
    double hoursForEntry(Map<String, dynamic> e) {
      final clockIn = DateTime.tryParse(e['clock_in']?.toString() ?? '');
      final clockOut = DateTime.tryParse(e['clock_out']?.toString() ?? '');
      if (clockIn == null || clockOut == null) return 0;
      return clockOut.difference(clockIn).inMinutes / 60.0;
    }

    String formatDt(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    Future<void> addOrEditEntry([Map<String, dynamic>? existing]) async {
      final techController = TextEditingController(
          text: existing?['technician_name']?.toString() ?? '');
      final notesController =
          TextEditingController(text: existing?['notes']?.toString() ?? '');
      var clockIn = existing != null
          ? (DateTime.tryParse(existing['clock_in']?.toString() ?? '') ??
              DateTime.now())
          : DateTime.now();
      var clockOut = existing != null && existing['clock_out'] != null
          ? DateTime.tryParse(existing['clock_out'].toString())
          : null;
      String? localError;

      Future<DateTime?> pickDateTime(BuildContext ctx, DateTime initial) async {
        final date = await showDatePicker(
          context: ctx,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (date == null) return null;
        if (!ctx.mounted) return null;
        final time = await showTimePicker(
            context: ctx, initialTime: TimeOfDay.fromDateTime(initial));
        if (time == null) return null;
        return DateTime(
            date.year, date.month, date.day, time.hour, time.minute);
      }

      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setS) => AlertDialog(
            title: Text(existing == null ? 'Adaugă pontaj' : 'Editează pontaj'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: techController,
                      decoration: const InputDecoration(
                          labelText: 'Tehnician / angajat'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Intrare (clock-in)'),
                      subtitle: Text(formatDt(clockIn.toIso8601String())),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final dt = await pickDateTime(context, clockIn);
                        if (dt != null) setS(() => clockIn = dt);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ieșire (clock-out)'),
                      subtitle: Text(clockOut == null
                          ? 'Neînregistrat'
                          : formatDt(clockOut!.toIso8601String())),
                      trailing: const Icon(Icons.schedule_outlined),
                      onTap: () async {
                        final dt =
                            await pickDateTime(context, clockOut ?? clockIn);
                        if (dt != null) setS(() => clockOut = dt);
                      },
                    ),
                    if (clockOut != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Ore lucrate: ${hoursForEntry({
                                'clock_in': clockIn.toIso8601String(),
                                'clock_out': clockOut!.toIso8601String()
                              }).toStringAsFixed(2)}h',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notesController,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Observații'),
                    ),
                    if ((localError ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(localError!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () {
                  if (techController.text.trim().isEmpty) {
                    setS(
                        () => localError = 'Completează numele tehnicianului.');
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Salvează'),
              ),
            ],
          ),
        ),
      );
      techController.dispose();
      notesController.dispose();
      if (saved != true || !mounted) return;
      final entry = <String, dynamic>{
        'id': existing?['id'] ?? 'te-${DateTime.now().microsecondsSinceEpoch}',
        'technician_name': techController.text.trim(),
        'clock_in': clockIn.toIso8601String(),
        'clock_out': clockOut?.toIso8601String(),
        'notes': notesController.text.trim(),
      };
      final updated = [
        ..._timeEntries.where((e) => e['id'] != entry['id']),
        entry,
      ];
      setState(() => _timeEntries = updated);
      await _persistTimeEntries(updated);
    }

    final totalHours =
        _timeEntries.fold<double>(0, (s, e) => s + hoursForEntry(e));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_timeEntries.isEmpty)
          const Text('Nu există înregistrări de pontaj.')
        else ...[
          ..._timeEntries.map((e) {
            final hours = hoursForEntry(e);
            final name = e['technician_name']?.toString() ?? '-';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              title: Text(name),
              subtitle: Text(
                'In: ${formatDt(e['clock_in']?.toString())} → '
                'Out: ${formatDt(e['clock_out']?.toString())}'
                '${e['notes']?.toString().isNotEmpty == true ? '\n${e['notes']}' : ''}',
              ),
              trailing: Wrap(
                spacing: 0,
                children: [
                  if (hours > 0)
                    Chip(
                      label: Text('${hours.toStringAsFixed(1)}h',
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => addOrEditEntry(e),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () async {
                      final updated = _timeEntries
                          .where((x) => x['id'] != e['id'])
                          .toList();
                      setState(() => _timeEntries = updated);
                      await _persistTimeEntries(updated);
                    },
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Total ore: ${totalHours.toStringAsFixed(2)}h',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => addOrEditEntry(),
          icon: const Icon(Icons.add),
          label: const Text('Adaugă pontaj'),
        ),
      ],
    );
  }

  Widget _buildProfitabilitySection() {
    final matTotal = _materialsTotal;
    final laborTotal = _laborTotalCost;
    final totalCost = _realTotalCost;
    final contractVal = _estimatedValue;
    final diff = contractVal > 0 ? contractVal - totalCost : 0.0;
    final margin = contractVal > 0 ? (diff / contractVal * 100) : 0.0;
    final overBudget = contractVal > 0 && totalCost > contractVal;

    String fmt(double v) => v.toStringAsFixed(2);

    Color marginColor(double m) {
      if (m >= 20) return Colors.green.shade700;
      if (m >= 10) return Colors.orange.shade700;
      return Colors.red.shade700;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _profitRow('Materiale (cost)', '${fmt(matTotal)} RON',
                Icons.inventory_2_outlined, Colors.blueGrey),
            _profitRow('Manoperă (cost)', '${fmt(laborTotal)} RON',
                Icons.engineering_outlined, Colors.blueGrey),
            _profitRow(
              'Total cost real',
              '${fmt(totalCost)} RON',
              Icons.calculate_outlined,
              Colors.grey.shade700,
            ),
            if (contractVal > 0) ...[
              _profitRow(
                'Valoare contract / deviz',
                '${fmt(contractVal)} RON',
                Icons.request_quote_outlined,
                Colors.indigo,
              ),
              _profitRow(
                overBudget ? 'Depășire buget' : 'Profit estimat',
                '${overBudget ? '-' : '+'}${fmt(diff.abs())} RON',
                overBudget ? Icons.trending_down : Icons.trending_up,
                overBudget ? Colors.red.shade700 : Colors.green.shade700,
              ),
              _profitRow(
                'Marjă estimată',
                '${margin.toStringAsFixed(1)}%',
                Icons.percent,
                contractVal > 0 ? marginColor(margin) : Colors.grey,
              ),
            ] else
              const Text(
                'Completează valoarea estimată/contract pe lucrare pentru a vedea marja.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        if (contractVal > 0 && totalCost == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Adaugă materiale și manoperă pentru a calcula costul real.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _profitRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ],
    );
  }

  double get _personHoursTotal => _labor
      .where((row) => _laborTypeOf(row) == 'person')
      .fold<double>(0, (sum, row) => sum + _asDouble(row['hours']));

  double get _teamHoursTotal => _labor
      .where((row) => _laborTypeOf(row) == 'team')
      .fold<double>(0, (sum, row) => sum + _asDouble(row['hours']));

  Future<void> _onEditLabor(int index) async {
    if (index < 0 || index >= _labor.length) {
      return;
    }

    var options = <Map<String, dynamic>>[
      if (_assignedTeam != null)
        {
          'id': 'team:${_assignedTeam!.id}',
          'label': 'Echipă: ${_assignedTeam!.label}',
          'dailyAllowance':
              _teamDailyAllowanceById(_assignedTeam!.id, _teamsSourceRows),
          'defaultLodgingCost':
              _teamLodgingById(_assignedTeam!.id, _teamsSourceRows),
          'requiresLodgingByDefault':
              _teamRequiresLodgingById(_assignedTeam!.id, _teamsSourceRows),
        },
      ..._employees.where((e) => e.active).map(
            (e) => {
              'id': 'emp:${e.id}',
              'label': e.label,
              'hourlyRate': e.hourlyRate,
              'dailyAllowance': e.dailyAllowance,
              'defaultLodgingCost': e.defaultLodgingCost,
              'requiresLodgingByDefault': e.requiresLodgingByDefault,
            },
          ),
    ];
    options = _dedupeDropdownOptions(options);
    if (options.isEmpty) {
      _snack('Nu există angajați disponibili.');
      return;
    }

    final row = _labor[index];
    String? selectedWhoId = '${row['whoId'] ?? ''}'.trim();
    if (selectedWhoId.isEmpty) {
      final who = '${row['who'] ?? ''}'.trim();
      for (final option in options) {
        if ((option['label'] ?? '').trim() == who) {
          selectedWhoId = option['id'];
          break;
        }
      }
      if ((selectedWhoId == null || selectedWhoId.isEmpty) &&
          _laborTypeOf(row) == 'team' &&
          _assignedTeam != null) {
        selectedWhoId = 'team:${_assignedTeam!.id}';
      }
    }
    selectedWhoId = _safeDropdownValue(selectedWhoId, options);

    DateTime date = _parseDateOrNow('${row['date'] ?? ''}');
    DateTime periodStart = _laborPeriodStart(row) ?? date;
    DateTime periodEnd = _laborPeriodEnd(row) ?? periodStart;
    final hoursController =
        TextEditingController(text: _asDouble(row['hours']).toString());
    final hoursPerDayController = TextEditingController(
      text: _formatDecimal(_laborHoursPerDay(row)),
    );
    final tripDaysController =
        TextEditingController(text: _laborTripDays(row).toString());
    final zileDiurnaController =
        TextEditingController(text: _laborDaysPerDiem(row).toString());
    final valoareDiurnaController =
        TextEditingController(text: _laborPerDiemPerDay(row).toString());
    final noptiCazareController =
        TextEditingController(text: _laborNightsLodging(row).toString());
    final valoareCazareController =
        TextEditingController(text: _laborLodgingPerNight(row).toString());
    double selectedPerDiemPerDay = _laborPerDiemPerDay(row);
    double selectedLodgingPerDay = _laborLodgingPerNight(row);
    bool includeDiurna = _laborIncludePerDiem(row);
    bool includeCazare = _laborIncludeLodging(row);
    final notesController =
        TextEditingController(text: '${row['notes'] ?? ''}');

    void syncComputedValues() {
      if (periodEnd.isBefore(periodStart)) {
        periodEnd = periodStart;
      }
      final tripDays =
          _laborPeriodDays(periodStart: periodStart, periodEnd: periodEnd);
      final hoursPerDay = _sanitizeLaborHoursPerDay(hoursPerDayController.text);
      hoursPerDayController.text = _formatDecimal(hoursPerDay);
      hoursController.text = _formatDecimal(tripDays * hoursPerDay);
      tripDaysController.text = _formatDecimal(tripDays);
      zileDiurnaController.text =
          includeDiurna ? _formatDecimal(tripDays) : '0';
      noptiCazareController.text =
          includeCazare ? _formatDecimal(tripDays) : '0';
    }

    syncComputedValues();

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editează manoperă / ore'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: selectedWhoId,
                    decoration:
                        const InputDecoration(labelText: 'Persoană / echipă'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selectează'),
                      ),
                      ...options.map(
                        (o) => DropdownMenuItem<String?>(
                          value: o['id'],
                          child: Text(o['label'] ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      selectedWhoId = value;
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      final selected = options
                          .where((o) => '${o['id'] ?? ''}' == value)
                          .toList();
                      if (selected.isEmpty) return;
                      final selectedItem = selected.first;
                      final normalizedType =
                          value.startsWith('team:') ? 'team' : 'person';
                      final diurnaPerDay = normalizedType == 'team'
                          ? _teamDailyAllowanceById(
                              value.substring(5), _teamsSourceRows)
                          : _asDouble(selectedItem['dailyAllowance']);
                      final cazarePerNight = normalizedType == 'team'
                          ? _teamLodgingById(
                              value.substring(5), _teamsSourceRows)
                          : _asDouble(selectedItem['defaultLodgingCost']);
                      final requiresCazare = normalizedType == 'team'
                          ? _teamRequiresLodgingById(
                              value.substring(5), _teamsSourceRows)
                          : (selectedItem['requiresLodgingByDefault'] == true);
                      selectedPerDiemPerDay = diurnaPerDay;
                      selectedLodgingPerDay = cazarePerNight;
                      includeDiurna = diurnaPerDay > 0;
                      includeCazare = requiresCazare && cazarePerNight > 0;
                      valoareDiurnaController.text =
                          diurnaPerDay.toStringAsFixed(2);
                      valoareCazareController.text =
                          cazarePerNight.toStringAsFixed(2);
                      syncComputedValues();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: periodStart,
                              firstDate: DateTime(DateTime.now().year - 5),
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              periodStart = picked;
                              syncComputedValues();
                            });
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Start: ${_formatDate(periodStart)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: periodEnd.isBefore(periodStart)
                                  ? periodStart
                                  : periodEnd,
                              firstDate: periodStart,
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              periodEnd = picked;
                              syncComputedValues();
                            });
                          },
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text('Sfârșit: ${_formatDate(periodEnd)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursPerDayController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Ore/zi'),
                          onChanged: (_) => setDialogState(syncComputedValues),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Ore totale',
                            helperText: 'Se recalculează din perioadă x ore/zi',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: zileDiurnaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Zile diurnă'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valoareDiurnaController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valoare diurnă/zi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noptiCazareController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Nopți cazare'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valoareCazareController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valoare cazare/noapte'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tripDaysController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Numar zile deplasare'),
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeDiurna,
                    title: const Text('Include diurna'),
                    subtitle: Text(
                        'Valoare/zi: ${selectedPerDiemPerDay.toStringAsFixed(2)}'),
                    onChanged: (value) => setDialogState(() {
                      includeDiurna = value;
                      syncComputedValues();
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeCazare,
                    title: const Text('Include cazare'),
                    subtitle: Text(
                        'Valoare/zi: ${selectedLodgingPerDay.toStringAsFixed(2)}'),
                    onChanged: (value) => setDialogState(() {
                      includeCazare = value;
                      syncComputedValues();
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Observații'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează')),
            FilledButton(
              onPressed: () {
                if (selectedWhoId == null || selectedWhoId!.trim().isEmpty) {
                  return;
                }
                final normalizedSelection =
                    _safeDropdownValue(selectedWhoId, options);
                if (normalizedSelection == null) return;
                final selected = options
                    .where((o) => o['id'] == normalizedSelection)
                    .toList();
                if (selected.isEmpty) return;
                if (periodEnd.isBefore(periodStart)) {
                  periodEnd = periodStart;
                }
                final hours = double.tryParse(
                        hoursController.text.replaceAll(',', '.')) ??
                    0;
                final zileDiurna = double.tryParse(
                        zileDiurnaController.text.replaceAll(',', '.')) ??
                    0;
                final valoareDiurnaPeZi = selectedPerDiemPerDay > 0
                    ? selectedPerDiemPerDay
                    : (double.tryParse(
                          valoareDiurnaController.text.replaceAll(',', '.'),
                        ) ??
                        0);
                final noptiCazare = double.tryParse(
                        noptiCazareController.text.replaceAll(',', '.')) ??
                    0;
                final valoareCazarePeNoapte = selectedLodgingPerDay > 0
                    ? selectedLodgingPerDay
                    : (double.tryParse(
                          valoareCazareController.text.replaceAll(',', '.'),
                        ) ??
                        0);
                final tripDays = double.tryParse(
                        tripDaysController.text.replaceAll(',', '.')) ??
                    (zileDiurna > 0 ? zileDiurna : noptiCazare);
                final includeDiurnaNow = includeDiurna || zileDiurna > 0;
                final includeCazareNow = includeCazare || noptiCazare > 0;
                final normalizedDaysPerDiem = includeDiurnaNow ? tripDays : 0.0;
                final normalizedNightsLodging =
                    includeCazareNow ? tripDays : 0.0;
                final rate = _laborRateForWhoId(
                  normalizedSelection,
                  type: normalizedSelection.startsWith('team:')
                      ? 'team'
                      : 'person',
                  whoLabel: '${selected.first['label'] ?? '-'}',
                );
                final costOre = hours * rate;
                final costDiurna = normalizedDaysPerDiem * valoareDiurnaPeZi;
                final costCazare =
                    normalizedNightsLodging * valoareCazarePeNoapte;
                Navigator.of(context).pop({
                  'id':
                      '${row['id'] ?? 'job-labor-${DateTime.now().millisecondsSinceEpoch}'}',
                  'jobId': '${row['jobId'] ?? widget.job.id}',
                  'whoId': normalizedSelection,
                  'type': normalizedSelection.startsWith('team:')
                      ? 'team'
                      : 'person',
                  'whoLabel': '${selected.first['label'] ?? '-'}',
                  'who': '${selected.first['label'] ?? '-'}',
                  'date': _formatDate(periodStart),
                  'periodStartDate': _encodeLaborPeriodDate(periodStart),
                  'periodEndDate': _encodeLaborPeriodDate(periodEnd),
                  'hoursPerDay':
                      _sanitizeLaborHoursPerDay(hoursPerDayController.text),
                  'hours': hours,
                  'hourlyRate': rate,
                  'tripDays': tripDays,
                  'includeDiurna': includeDiurnaNow,
                  'includeCazare': includeCazareNow,
                  'zileDiurna': normalizedDaysPerDiem,
                  'valoareDiurnaPeZi': valoareDiurnaPeZi,
                  'noptiCazare': normalizedNightsLodging,
                  'valoareCazarePeNoapte': valoareCazarePeNoapte,
                  'costOre': costOre,
                  'costDiurna': costDiurna,
                  'costCazare': costCazare,
                  'costTotalLinie': costOre + costDiurna + costCazare,
                  'notes': notesController.text.trim(),
                });
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );

    hoursController.dispose();
    hoursPerDayController.dispose();
    tripDaysController.dispose();
    zileDiurnaController.dispose();
    valoareDiurnaController.dispose();
    noptiCazareController.dispose();
    valoareCazareController.dispose();
    notesController.dispose();
    if (updated == null) return;

    final next = [..._labor];
    next[index] = updated;
    await _saveLaborRows(next);
    await _appendJournal(
      action: 'labor_edited',
      message: 'Manopera editata: ${updated['who'] ?? '-'}',
    );
  }

  Future<void> _onDeleteLabor(int index) async {
    if (index < 0 || index >= _labor.length) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ștergere înregistrare'),
        content: const Text(
            'Sigur vrei să ștergi această înregistrare de manoperă?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final deletedWho = '${_labor[index]['who'] ?? '-'}';
    final next = [..._labor]..removeAt(index);
    await _saveLaborRows(next);
    await _appendJournal(
      action: 'labor_deleted',
      message: 'Manopera stearsa: $deletedWho',
    );
  }

  Future<Map<String, dynamic>?> _showGeneratedDocumentDialog({
    required String documentType,
    required String defaultTitle,
    required String detailsLabelA,
    required String detailsLabelB,
    required String defaultNumber,
    String? defaultDate,
    String? defaultDetailsA,
    String? defaultDetailsB,
    String? notesPrefix,
  }) async {
    String selectedStatus = _documentStatuses.first;
    final titleController = TextEditingController(text: defaultTitle);
    final numberController = TextEditingController(text: defaultNumber);
    final dateController = TextEditingController(
      text: (defaultDate ?? '').trim().isEmpty
          ? _formatDate(DateTime.now())
          : (defaultDate ?? '').trim(),
    );
    final detailsAController =
        TextEditingController(text: (defaultDetailsA ?? '').trim());
    final detailsBController =
        TextEditingController(text: (defaultDetailsB ?? '').trim());
    final normalizedNotesPrefix = (notesPrefix ?? '').trim();
    final notesController = TextEditingController(
      text:
          '${normalizedNotesPrefix.isEmpty ? '' : '$normalizedNotesPrefix\n\n'}Cod lucrare: ${widget.job.jobCode}\nTitlu: ${widget.job.title}\nClient: ${widget.clientName}\nLocatie: ${widget.job.location}\nStatus lucrare: ${'${widget.job.status.label}'.replaceAll('\uFFFD', '').replaceAll('', '')}\nEchipa: ${_assignedTeam?.label ?? '-'}\nProgramari: ${_appointments.length}\nMateriale: ${_materials.length}\nManopera/ore: ${_labor.length}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Genereaza $documentType'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Titlu document'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: numberController,
                    decoration:
                        const InputDecoration(labelText: 'Numar document'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: dateController,
                    decoration:
                        const InputDecoration(labelText: 'Data document'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration:
                        const InputDecoration(labelText: 'Status document'),
                    items: _documentStatuses
                        .map((status) => DropdownMenuItem<String>(
                            value: status, child: Text(status)))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: detailsAController,
                    decoration: InputDecoration(labelText: detailsLabelA),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: detailsBController,
                    decoration: InputDecoration(labelText: detailsLabelB),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Observatii'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuleaza'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'title': titleController.text.trim(),
                'number': numberController.text.trim(),
                'date': dateController.text.trim(),
                'status': selectedStatus,
                'detailsA': detailsAController.text.trim(),
                'detailsB': detailsBController.text.trim(),
                'notes': notesController.text.trim(),
              }),
              child: const Text('Genereaza'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    numberController.dispose();
    dateController.dispose();
    detailsAController.dispose();
    detailsBController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _onGenerateProcesVerbal({
    Map<String, dynamic>? appointment,
  }) async {
    final autoNumber = await _nextDocumentNumber('process_verbal');
    final appointmentId = '${appointment?['id'] ?? ''}'.trim();
    final appointmentTitle =
        '${appointment?['title'] ?? appointment?['name'] ?? '-'}'.trim();
    final appointmentDate =
        '${appointment?['date'] ?? appointment?['scheduledDate'] ?? ''}'.trim();
    final appointmentLocation =
        '${appointment?['location'] ?? widget.job.location}'.trim();
    final appointmentNotes =
        '${appointment?['notes'] ?? appointment?['observatii'] ?? ''}'.trim();
    final payload = await _showGeneratedDocumentDialog(
      documentType: 'Proces verbal',
      defaultTitle: appointment == null
          ? 'Proces verbal - ${widget.job.jobCode}'
          : 'Proces verbal - ${widget.job.jobCode} - ${appointmentTitle.isEmpty ? '-' : appointmentTitle}',
      detailsLabelA: 'Obiect / Descriere',
      detailsLabelB: 'Constatari',
      defaultNumber: autoNumber,
      defaultDate: appointmentDate,
      defaultDetailsA: appointment == null
          ? ''
          : 'Interventie conform programarii: ${appointmentTitle.isEmpty ? '-' : appointmentTitle}\nLocatie: ${appointmentLocation.isEmpty ? '-' : appointmentLocation}',
      defaultDetailsB: appointment == null
          ? ''
          : 'Data programare: ${appointmentDate.isEmpty ? '-' : appointmentDate}',
      notesPrefix: appointment == null
          ? null
          : 'Programare selectata\nTitlu: ${appointmentTitle.isEmpty ? '-' : appointmentTitle}\nData: ${appointmentDate.isEmpty ? '-' : appointmentDate}\nLocatie: ${appointmentLocation.isEmpty ? '-' : appointmentLocation}${appointmentNotes.isEmpty ? '' : '\nObservatii programare: $appointmentNotes'}',
    );
    if (payload == null) return;

    final nowIso = DateTime.now().toIso8601String();
    final resolvedNumber = '${payload['number'] ?? ''}'.trim().isEmpty
        ? autoNumber
        : '${payload['number']}';
    final appointmentsSnapshot = _appointments
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final materialsSnapshot = _materials
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final laborSnapshot =
        _labor.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    final beneficiaryEquipmentSnapshot = _beneficiarySuppliedEquipment
        .map((e) => e.toMap())
        .toList(growable: false);
    final beneficiaryMaterialsSnapshot = _beneficiarySuppliedMaterials
        .map((e) => e.toMap())
        .toList(growable: false);
    final doc = <String, dynamic>{
      'id': 'job-doc-${DateTime.now().microsecondsSinceEpoch}',
      'jobId': widget.job.id,
      'client': widget.clientName,
      'location': widget.job.location,
      'type': 'process_verbal',
      'tipDocument': 'Proces verbal',
      'titlu': payload['title'] ?? '',
      'numarDocument': resolvedNumber,
      'dataDocument': payload['date'] ?? '',
      'observatii': payload['notes'] ?? '',
      'status': payload['status'] ?? _documentStatuses.first,
      'filePath': '',
      'pdfPath': '',
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'generatedFromJob': true,
      'documentSubtype': 'pv',
      'sourceAppointmentId': appointmentId,
      'sourceAppointmentTitle': appointmentTitle,
      'sourceAppointmentDate': appointmentDate,
      'sourceAppointmentLocation': appointmentLocation,
      'obiectDescriere': payload['detailsA'] ?? '',
      'constatari': payload['detailsB'] ?? '',
      'jobCode': widget.job.jobCode,
      'jobTitle': widget.job.title,
      'jobStatus': widget.job.status.label,
      'teamLabel': _assignedTeam?.label ?? '-',
      'teamMembers': _assignedTeamMembersLabel,
      'appointmentsCount': _appointments.length,
      'materialsCount': _materials.length,
      'laborCount': _labor.length,
      'appointmentsSnapshot': appointmentsSnapshot,
      'materialsSnapshot': materialsSnapshot,
      'laborSnapshot': laborSnapshot,
      'beneficiarySuppliedEquipmentSnapshot': beneficiaryEquipmentSnapshot,
      'beneficiarySuppliedMaterialsSnapshot': beneficiaryMaterialsSnapshot,
      // legacy aliases
      'typeLegacy': 'Proces verbal',
      'title': payload['title'] ?? '',
      'number': resolvedNumber,
      'date': payload['date'] ?? '',
      'notes': payload['notes'] ?? '',
    };

    final next = [..._documents, doc];
    for (var i = 0; i < next.length; i++) {
      next[i] = await _registerDocumentForRegistry(next[i]);
    }
    for (var i = 0; i < next.length; i++) {
      next[i] = await _registerDocumentForRegistry(next[i]);
    }
    for (var i = 0; i < next.length; i++) {
      next[i] = await _registerDocumentForRegistry(next[i]);
    }
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('Proces verbal generat si salvat.');
    await _appendJournal(
      action: 'document_generated',
      message: 'Proces verbal generat: ${doc['titlu'] ?? '-'}',
    );
  }

  Future<void> _onGeneratePif({
    Map<String, dynamic>? appointment,
  }) async {
    final autoNumber = await _nextDocumentNumber('pif');
    final appointmentId = '${appointment?['id'] ?? ''}'.trim();
    final appointmentTitle =
        '${appointment?['title'] ?? appointment?['name'] ?? '-'}'.trim();
    final appointmentDate =
        '${appointment?['date'] ?? appointment?['scheduledDate'] ?? ''}'.trim();
    final appointmentLocation =
        '${appointment?['location'] ?? widget.job.location}'.trim();
    final appointmentNotes =
        '${appointment?['notes'] ?? appointment?['observatii'] ?? ''}'.trim();
    final payload = await _showGeneratedDocumentDialog(
      documentType: 'PIF',
      defaultTitle: appointment == null
          ? 'PIF - ${widget.job.jobCode}'
          : 'PIF - ${widget.job.jobCode} - ${appointmentTitle.isEmpty ? '-' : appointmentTitle}',
      detailsLabelA: 'Descriere punere in functiune',
      detailsLabelB: 'Parametri / rezultate',
      defaultNumber: autoNumber,
      defaultDate: appointmentDate,
      defaultDetailsA: appointment == null
          ? ''
          : 'Punere in functiune conform programarii: ${appointmentTitle.isEmpty ? '-' : appointmentTitle}\nLocatie: ${appointmentLocation.isEmpty ? '-' : appointmentLocation}',
      defaultDetailsB: appointment == null
          ? ''
          : 'Data programare: ${appointmentDate.isEmpty ? '-' : appointmentDate}',
      notesPrefix: appointment == null
          ? null
          : 'Programare selectata\nTitlu: ${appointmentTitle.isEmpty ? '-' : appointmentTitle}\nData: ${appointmentDate.isEmpty ? '-' : appointmentDate}\nLocatie: ${appointmentLocation.isEmpty ? '-' : appointmentLocation}${appointmentNotes.isEmpty ? '' : '\nObservatii programare: $appointmentNotes'}',
    );
    if (payload == null) return;

    final nowIso = DateTime.now().toIso8601String();
    final resolvedNumber = '${payload['number'] ?? ''}'.trim().isEmpty
        ? autoNumber
        : '${payload['number']}';
    final appointmentsSnapshot = _appointments
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final materialsSnapshot = _materials
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final laborSnapshot =
        _labor.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    final beneficiaryEquipmentSnapshot = _beneficiarySuppliedEquipment
        .map((e) => e.toMap())
        .toList(growable: false);
    final beneficiaryMaterialsSnapshot = _beneficiarySuppliedMaterials
        .map((e) => e.toMap())
        .toList(growable: false);
    final doc = <String, dynamic>{
      'id': 'job-doc-${DateTime.now().microsecondsSinceEpoch}',
      'jobId': widget.job.id,
      'client': widget.clientName,
      'location': widget.job.location,
      'type': 'pif',
      'tipDocument': 'PIF',
      'titlu': payload['title'] ?? '',
      'numarDocument': resolvedNumber,
      'dataDocument': payload['date'] ?? '',
      'observatii': payload['notes'] ?? '',
      'status': payload['status'] ?? _documentStatuses.first,
      'filePath': '',
      'pdfPath': '',
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'generatedFromJob': true,
      'documentSubtype': 'pif',
      'sourceAppointmentId': appointmentId,
      'sourceAppointmentTitle': appointmentTitle,
      'sourceAppointmentDate': appointmentDate,
      'sourceAppointmentLocation': appointmentLocation,
      'descrierePunereInFunctiune': payload['detailsA'] ?? '',
      'parametriRezultate': payload['detailsB'] ?? '',
      'jobCode': widget.job.jobCode,
      'jobTitle': widget.job.title,
      'jobStatus': widget.job.status.label,
      'teamLabel': _assignedTeam?.label ?? '-',
      'teamMembers': _assignedTeamMembersLabel,
      'appointmentsCount': _appointments.length,
      'materialsCount': _materials.length,
      'laborCount': _labor.length,
      'appointmentsSnapshot': appointmentsSnapshot,
      'materialsSnapshot': materialsSnapshot,
      'laborSnapshot': laborSnapshot,
      'beneficiarySuppliedEquipmentSnapshot': beneficiaryEquipmentSnapshot,
      'beneficiarySuppliedMaterialsSnapshot': beneficiaryMaterialsSnapshot,
      // legacy aliases
      'typeLegacy': 'PIF',
      'title': payload['title'] ?? '',
      'number': resolvedNumber,
      'date': payload['date'] ?? '',
      'notes': payload['notes'] ?? '',
    };

    final next = [..._documents, doc];
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('PIF generat si salvat.');
    await _appendJournal(
      action: 'document_generated',
      message: 'PIF generat: ${doc['titlu'] ?? '-'}',
    );
  }

  Future<void> _onGenerateOferta() async {
    await _createTemplateDocumentFromJob(
      type: 'oferta',
      documentLabel: 'Oferta',
      titlePrefix: 'Oferta',
    );
  }

  Future<void> _onGenerateDeviz() async {
    await _createTemplateDocumentFromJob(
      type: 'deviz',
      documentLabel: 'Deviz',
      titlePrefix: 'Deviz',
    );
  }

  Future<void> _onGenerateContract() async {
    final contractData = await _showContractDialog();
    if (contractData == null) return;
    if (!mounted) return;

    try {
      final path = await ContractPdfService.export(
        repository: widget.repository,
        data: contractData,
      );
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: 'Contract ${widget.job.jobCode}',
        shareSubject: 'Contract de prestări servicii',
        shareText: 'Contract PRO TERM SRL — ${widget.job.title}',
      );
    } catch (e) {
      if (mounted) _snack('Eroare la generarea contractului: $e');
    }
  }

  Future<ContractData?> _showContractDialog() {
    final materialTotal =
        _materials.fold<double>(0, (s, i) => s + _materialLineTotal(i));
    final laborTotal =
        _labor.fold<double>(0, (s, i) => s + _laborTotalLineCost(i));
    return showContractDialog(
      context,
      materialTotal: materialTotal,
      laborTotal: laborTotal,
      clientName: widget.clientName,
      jobCode: widget.job.jobCode,
      jobTitle: widget.job.title,
      location: widget.job.location,
      teamName: _assignedTeam?.label ?? '',
      teamMembers: _assignedTeamMembersLabel,
    );
  }

  Map<String, String> _buildTemplateSections({
    required String type,
    required double materialTotal,
    required double laborTotal,
    required double subtotal,
    required double vatPercent,
    required double vatTotal,
    required double grandTotal,
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String teamName,
    required String teamMembers,
  }) {
    final clientName =
        widget.clientName.trim().isEmpty ? '-' : widget.clientName.trim();
    final jobCode =
        widget.job.jobCode.trim().isEmpty ? '-' : widget.job.jobCode.trim();
    final jobTitle =
        widget.job.title.trim().isEmpty ? '-' : widget.job.title.trim();
    final jobLocation =
        widget.job.location.trim().isEmpty ? '-' : widget.job.location.trim();
    final jobStatus = widget.job.status.label.trim().isEmpty
        ? '-'
        : widget.job.status.label.trim();
    final estimated = _asDouble(widget.job.estimatedValue);
    final teamLabel = teamName.trim().isEmpty ? '-' : teamName.trim();
    final teamMembersLabel =
        teamMembers.trim().isEmpty ? '-' : teamMembers.trim();
    final emitent = companyName.trim().isEmpty ? 'Emitent' : companyName.trim();

    final materialsSummary = _materials.isEmpty
        ? '- Nu exista materiale asociate.'
        : _materials.map((item) {
            final name = '${item['name'] ?? '-'}'.trim();
            final um = '${item['um'] ?? '-'}'.trim();
            final qty = _asDouble(item['qty']).toStringAsFixed(2);
            final price = _asDouble(item['price']).toStringAsFixed(2);
            final total = _materialLineTotal(item).toStringAsFixed(2);
            return '- $name | UM: $um | Cant: $qty | Pret: $price | Total: $total';
          }).join('\n');

    final laborSummary = _labor.isEmpty
        ? '- Nu exista manopera/ore asociate.'
        : _labor.map((item) {
            final who = '${item['who'] ?? '-'}'.trim();
            final date = '${item['date'] ?? '-'}'.trim();
            final hours = _asDouble(item['hours']).toStringAsFixed(2);
            final rate = _laborRateForRow(item).toStringAsFixed(2);
            final cost = _laborTotalLineCost(item).toStringAsFixed(2);
            return '- $who | Data: $date | Ore: $hours | Tarif: $rate | Total: $cost';
          }).join('\n');

    final financialLines = [
      'Total materiale: ${materialTotal.toStringAsFixed(2)}',
      'Total manopera: ${laborTotal.toStringAsFixed(2)}',
      'Subtotal: ${subtotal.toStringAsFixed(2)}',
      'TVA (${vatPercent.toStringAsFixed(0)}%): ${vatTotal.toStringAsFixed(2)}',
      'Total general: ${grandTotal.toStringAsFixed(2)}',
      'Valoare estimata lucrare: ${estimated.toStringAsFixed(2)}',
    ].join('\n');

    switch (type.trim().toLowerCase()) {
      case 'oferta':
        return {
          'contentA': [
            'Antet oferta',
            'Client: $clientName',
            'Referinta lucrare: $jobCode - $jobTitle',
            'Locatie: $jobLocation',
            'Status lucrare: $jobStatus',
            'Obiect oferta: Executie lucrari conform fisei.',
            '',
            'Lista comerciala / sintetica',
            materialsSummary,
            '',
            'Echipa alocata: $teamLabel',
            'Membri echipa: $teamMembersLabel',
            '',
            financialLines,
          ].join('\n'),
          'contentB': [
            'Termen executie: -',
            'Termen plata: -',
            'Valabilitate oferta: -',
            'Data document: ${DateTime.now().toIso8601String().split('T').first}',
          ].join('\n'),
          'notes': [
            'Observatii:',
            '- Oferta este precompletata automat din fisa lucrarii.',
            '- Completeaza termenii comerciali inainte de transmitere.',
            if (emitent.isNotEmpty) 'Emitent: $emitent',
            if (companyAddress.trim().isNotEmpty)
              'Adresa emitent: ${companyAddress.trim()}',
            if (companyPhone.trim().isNotEmpty)
              'Telefon emitent: ${companyPhone.trim()}',
            if (companyEmail.trim().isNotEmpty)
              'Email emitent: ${companyEmail.trim()}',
          ].join('\n'),
        };
      case 'deviz':
        return {
          'contentA': [
            'Antet deviz',
            'Client: $clientName',
            'Referinta lucrare: $jobCode - $jobTitle',
            'Locatie: $jobLocation',
            '',
            'Materiale',
            materialsSummary,
            '',
            'Manopera / ore',
            laborSummary,
          ].join('\n'),
          'contentB': [
            'Totaluri',
            financialLines,
            '',
            'Observatii tehnice/comerciale:',
            '-',
          ].join('\n'),
          'notes': [
            'Document deviz precompletat automat din datele lucrarii.',
            'Echipa alocata: $teamLabel',
            'Membri echipa: $teamMembersLabel',
          ].join('\n'),
        };
      case 'contract':
        return {
          'contentA': [
            'Art. 1 - Partile contractante',
            '- Prestator/Executant: $emitent',
            '- Beneficiar/Antreprenor: $clientName',
            '',
            'Art. 2 - Obiectul contractului',
            '- Lucrare: $jobTitle ($jobCode)',
            '- Locatie: $jobLocation',
            '- Status curent: $jobStatus',
            '',
            'Art. 3 - Documente si referinte',
            '- Fisa lucrare: $jobCode',
            '- Programari asociate: ${_appointments.length}',
            '- Echipa alocata: $teamLabel',
            '- Cod lucrare: $jobCode',
            '',
            'Art. 4 - Pretul contractului',
            financialLines,
            '',
            'Art. 5 - Conditii comerciale',
            '- Avans: -',
            '- Transe de plata: -',
            '- Termen de plata: -',
            '- TVA aplicabil: 19%',
          ].join('\n'),
          'contentB': [
            'Art. 6 - Durata / termen executie: -',
            'Art. 7 - Obligatiile executantului: -',
            'Art. 8 - Obligatiile beneficiarului/antreprenorului: -',
            'Art. 9 - Materiale / utilaje / logistica:',
            '- Furnizare materiale: de stabilit',
            '- Utilaje / nacela / schela: de stabilit',
            '- Ridicare echipamente: de stabilit',
            'Art. 10 - Receptie / PV / PIF:',
            '- Conditii de receptie: -',
            '- Cine asigura PIF/documente finale: -',
            'Art. 11 - Penalitati: -',
            'Art. 12 - Forta majora: -',
            'Art. 13 - Incetarea contractului: -',
            'Art. 14 - Litigii: -',
            'Art. 15 - Dispozitii finale: -',
            '',
            'Semnaturi:',
            'Responsabil: ____________________',
            'Beneficiar: ____________________',
          ].join('\n'),
          'notes': [
            'Contract precompletat automat.',
            'Completeaza clauzele juridice finale inainte de validare.',
          ].join('\n'),
        };
      default:
        return {
          'contentA': 'Referinta lucrare: $jobCode - $jobTitle',
          'contentB': financialLines,
          'notes': 'Document precompletat automat din fisa lucrarii.',
        };
    }
  }

  Future<void> _createTemplateDocumentFromJob({
    required String type,
    required String documentLabel,
    required String titlePrefix,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final company = await _loadCompanyBrandingMap();
    final materialTotal = _materials.fold<double>(
      0,
      (sum, item) => sum + _materialLineTotal(item),
    );
    final laborTotal = _labor.fold<double>(
      0,
      (sum, item) => sum + _laborTotalLineCost(item),
    );
    const vatPercent = 19.0;
    final subtotal = materialTotal + laborTotal;
    final vatTotal = subtotal * vatPercent / 100;
    final grandTotal = subtotal + vatTotal;
    final companyName = _readCompanyField(company, const [
      'companyName',
      'name',
      'company_name',
      'numeFirma',
    ]);
    final companyAddress = _readCompanyField(company, const [
      'address',
      'companyAddress',
      'company_address',
      'adresa',
    ]);
    final companyPhone = _readCompanyField(company, const [
      'phone',
      'companyPhone',
      'company_phone',
      'telefon',
    ]);
    final companyEmail = _readCompanyField(company, const [
      'email',
      'companyEmail',
      'company_email',
    ]);
    final teamName = _assignedTeam?.label ?? '';
    final teamMembers = _assignedTeamMembersLabel;
    final templateSections = _buildTemplateSections(
      type: type,
      materialTotal: materialTotal,
      laborTotal: laborTotal,
      subtotal: subtotal,
      vatPercent: vatPercent,
      vatTotal: vatTotal,
      grandTotal: grandTotal,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      teamName: teamName,
      teamMembers: teamMembers,
    );
    final template = <String, dynamic>{
      'id': 'job-doc-${now.microsecondsSinceEpoch}',
      'type': type,
      'tipDocument': documentLabel,
      'typeLegacy': documentLabel,
      'documentSubtype': type,
      'numarDocument': '',
      'number': '',
      'dataDocument': nowIso.split('T').first,
      'date': nowIso.split('T').first,
      'titlu': '$titlePrefix - ${widget.job.jobCode}',
      'title': '$titlePrefix - ${widget.job.jobCode}',
      'status': 'Draft',
      'jobId': widget.job.id,
      'jobCode': widget.job.jobCode,
      'titluLucrare': widget.job.title,
      'jobTitle': widget.job.title,
      'clientName': widget.clientName,
      'location': widget.job.location,
      'jobStatus': widget.job.status.label,
      'estimatedValue': widget.job.estimatedValue,
      'teamName': teamName,
      'teamMembers': teamMembers,
      'programariSnapshot': _appointments
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'materialeSnapshot': _materials
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'manoperaSnapshot': _labor
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'beneficiarySuppliedEquipmentSnapshot': _beneficiarySuppliedEquipment
          .map((e) => e.toMap())
          .toList(growable: false),
      'beneficiarySuppliedMaterialsSnapshot': _beneficiarySuppliedMaterials
          .map((e) => e.toMap())
          .toList(growable: false),
      'materialTotal': materialTotal,
      'laborTotal': laborTotal,
      'subtotal': subtotal,
      'vatPercent': vatPercent,
      'vatTotal': vatTotal,
      'total': grandTotal,
      'grandTotal': grandTotal,
      'companySnapshot': company,
      'obiectDescriere': templateSections['contentA'] ?? '',
      'constatari': templateSections['contentB'] ?? '',
      'descrierePunereInFunctiune': templateSections['contentA'] ?? '',
      'parametriRezultate': templateSections['contentB'] ?? '',
      'observatii': templateSections['notes'] ?? '',
      'pdfPath': '',
      'filePath': '',
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };
    if (type.trim().toLowerCase() == 'contract') {
      template['contractPreset'] = 'Standard';
      final vatDefault = _commercialValue('vatPercent');
      final paymentDefault = _commercialValue('paymentTerm');
      final executionDefault = _commercialValue('executionTerm');
      final validityDefault = _commercialValue('offerValidity');
      final advanceDefault = _commercialValue('advance');
      final installmentsDefault = _commercialValue('installments');
      final penaltiesDefault = _commercialValue('penalties');
      final materialsProviderDefault = _commercialValue('materialsProvider');
      final logisticsProviderDefault = _commercialValue('logisticsProvider');
      final receptionDefault = _commercialValue('receptionClause');
      final signaturesDefault = _commercialValue('defaultSignatures');
      if (vatDefault.isNotEmpty) {
        template['vatPercent'] = vatDefault;
        template['tvaContract'] = vatDefault;
      }
      if (paymentDefault.isNotEmpty) {
        template['termenPlata'] = paymentDefault;
        template['conditiiPlata'] = paymentDefault;
      }
      if (executionDefault.isNotEmpty) {
        template['termenExecutie'] = executionDefault;
        template['durataExecutie'] = executionDefault;
      }
      if (validityDefault.isNotEmpty) {
        template['valabilitateOferta'] = validityDefault;
      }
      if (advanceDefault.isNotEmpty) {
        template['avans'] = advanceDefault;
      }
      if (installmentsDefault.isNotEmpty) {
        template['transePlata'] = installmentsDefault;
      }
      if (penaltiesDefault.isNotEmpty) {
        template['penalitati'] = penaltiesDefault;
      }
      if (materialsProviderDefault.isNotEmpty) {
        template['materiale'] = materialsProviderDefault;
      }
      if (logisticsProviderDefault.isNotEmpty) {
        template['logistica'] = logisticsProviderDefault;
      }
      if (receptionDefault.isNotEmpty) {
        template['receptie'] = receptionDefault;
      }
      if (signaturesDefault.isNotEmpty) {
        template['semnaturi'] = signaturesDefault;
      }
      final vatForTemplate = _commercialValue('vatPercent').trim();
      if (vatForTemplate.isNotEmpty) {
        final patched = <String, dynamic>{};
        template.forEach((key, value) {
          if (value is String) {
            patched[key] = value
                .replaceAll('TVA (19%)', 'TVA ($vatForTemplate%)')
                .replaceAll('TVA (19 %)', 'TVA ($vatForTemplate%)')
                .replaceAll('TVA: 19', 'TVA: $vatForTemplate');
          } else {
            patched[key] = value;
          }
        });
        template
          ..clear()
          ..addAll(patched);
      }
      template['partiContractante'] =
          'Prestator: ${companyName.trim().isEmpty ? '-' : companyName}\nBeneficiar: ${widget.clientName.trim().isEmpty ? '-' : widget.clientName}';
      template['documenteReferinte'] =
          'Cod lucrare: ${widget.job.jobCode}\nTitlu lucrare: ${widget.job.title}\nLocatie: ${widget.job.location}';
      template['durataExecutie'] = '-';
      template['avans'] = '-';
      template['transePlata'] = '-';
      template['tvaContract'] = vatPercent.toStringAsFixed(2);
      template['conditiiPlata'] = '-';
      template['termenExecutie'] = '-';
      template['obligatiiParti'] = '-';
      template['obligatiiBeneficiar'] = '-';
      template['materialeLogistica'] =
          'Materiale: de stabilit\nUtilaje / nacela / schela: de stabilit\nRidicare echipamente: de stabilit';
      template['receptie'] = '-';
      template['penalitati'] = '-';
      template['fortaMajora'] = '-';
      template['incetareContract'] = '-';
      template['litigii'] = '-';
      template['dispozitiiFinale'] = '-';
      template['semnaturi'] =
          'Responsabil: ____________________\nBeneficiar: ____________________';
      template['obiectContract'] = 'Obiect contract: ${widget.job.title}';
    }
    final registered = await _registerDocumentForRegistry(template);
    final next = [..._documents, registered];
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) {
      return;
    }
    setState(() => _documents = next);
    _snack('$documentLabel generat si salvat.');
    await _appendJournal(
      action: 'document_generated',
      message: '$documentLabel generat: ${registered['titlu'] ?? '-'}',
    );
  }

  bool _isBusinessTemplateType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'oferta':
      case 'deviz':
      case 'contract':
        return true;
      default:
        return false;
    }
  }

  String _readDocField(
    Map<String, dynamic> row,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _showBusinessTemplateEditor(
    Map<String, dynamic> row,
    String type,
  ) async {
    final normalizedType = type.trim().toLowerCase();
    final titleCtrl = TextEditingController(
      text: _readDocField(row, const ['titlu', 'title']),
    );
    final numberCtrl = TextEditingController(
      text: _readDocField(row, const ['numarDocument', 'number']),
    );
    final dateCtrl = TextEditingController(
      text: _readDocField(row, const ['dataDocument', 'date']),
    );
    final statusCtrl = TextEditingController(
      text: _readDocField(row, const ['status'], fallback: 'Draft'),
    );
    final clientCtrl = TextEditingController(
      text: _readDocField(row, const ['clientName', 'client']),
    );
    final jobCodeCtrl = TextEditingController(
      text: _readDocField(row, const ['jobCode', 'job_id', 'jobId']),
    );
    final jobTitleCtrl = TextEditingController(
      text: _readDocField(row, const ['jobTitle', 'titluLucrare']),
    );
    final locationCtrl = TextEditingController(
      text: _readDocField(row, const ['location', 'locatie']),
    );
    final objectCtrl = TextEditingController(
      text: _readDocField(
        row,
        const ['obiectContract', 'obiectOferta', 'obiectDescriere'],
      ),
    );
    final contentCtrl = TextEditingController(
      text: _readDocField(row, const ['continutComercial', 'constatari']),
    );
    final notesCtrl = TextEditingController(
      text: _readDocField(row, const ['observatii', 'notes']),
    );
    final subtotalCtrl = TextEditingController(
      text: _readDocField(row, const ['subtotal']),
    );
    final vatCtrl = TextEditingController(
      text: _readDocField(row, const ['vatPercent'], fallback: '19'),
    );
    final totalCtrl = TextEditingController(
      text: _readDocField(row, const ['grandTotal', 'total']),
    );
    final termExecCtrl = TextEditingController(
      text: _readDocField(row, const ['termenExecutie', 'executionTerm']),
    );
    final termPayCtrl = TextEditingController(
      text: _readDocField(row, const ['termenPlata', 'paymentTerm']),
    );
    final validityCtrl = TextEditingController(
      text: _readDocField(row, const ['valabilitateOferta', 'offerValidity']),
    );
    final partsCtrl = TextEditingController(
      text: _readDocField(row, const ['partiContractante', 'contractParties']),
    );
    final refsCtrl = TextEditingController(
      text: _readDocField(row, const ['documenteReferinte', 'references']),
    );
    final durationCtrl = TextEditingController(
      text: _readDocField(row, const ['durataExecutie', 'executionDuration']),
    );
    final advanceCtrl = TextEditingController(
      text: _readDocField(row, const ['avans', 'advanceAmount']),
    );
    final installmentsCtrl = TextEditingController(
      text: _readDocField(row, const ['transePlata', 'paymentInstallments']),
    );
    final vatContractCtrl = TextEditingController(
      text: _readDocField(row, const ['tvaContract', 'vatContract']),
    );
    final beneficiaryObligationsCtrl = TextEditingController(
      text: _readDocField(
        row,
        const ['obligatiiBeneficiar', 'beneficiaryObligations'],
      ),
    );
    final logisticsCtrl = TextEditingController(
      text: _readDocField(
          row, const ['materialeLogistica', 'materialsLogistics']),
    );
    final forceMajeureCtrl = TextEditingController(
      text: _readDocField(row, const ['fortaMajora', 'forceMajeure']),
    );
    final terminationCtrl = TextEditingController(
      text: _readDocField(row, const ['incetareContract', 'termination']),
    );
    final litigiiCtrl = TextEditingController(
      text: _readDocField(row, const ['litigii', 'disputes']),
    );
    final finalClausesCtrl = TextEditingController(
      text: _readDocField(row, const ['dispozitiiFinale', 'finalClauses']),
    );
    final obligationsCtrl = TextEditingController(
      text: _readDocField(row, const ['obligatiiParti', 'obligations']),
    );
    final penaltiesCtrl = TextEditingController(
      text: _readDocField(row, const ['penalitati', 'penalties']),
    );
    final receptionCtrl = TextEditingController(
      text: _readDocField(row, const ['receptie', 'reception']),
    );
    final signaturesCtrl = TextEditingController(
      text: _readDocField(row, const ['semnaturi', 'signatures']),
    );
    final materialsCtrl = TextEditingController(
      text: _readDocField(row, const ['materialeDetaliu', 'obiectDescriere']),
    );
    final laborCtrl = TextEditingController(
      text: _readDocField(row, const ['manoperaDetaliu', 'constatari']),
    );
    final totalMaterialsCtrl = TextEditingController(
      text: _readDocField(row, const ['materialTotal']),
    );
    final totalLaborCtrl = TextEditingController(
      text: _readDocField(row, const ['laborTotal']),
    );
    const offerPresetOptions = <String>[
      'Standard',
      'Premium',
      'Manoperă separată',
      'Materiale beneficiar',
      'Materiale + logistică beneficiar',
    ];
    void applyCommercialDefaultsToControllers() {
      void applyIfBlank(TextEditingController ctrl, String value) {
        final current = ctrl.text.trim();
        if (current.isEmpty ||
            current == '-' ||
            current == '0' ||
            current == '0.00') {
          if (value.trim().isNotEmpty) {
            ctrl.text = value.trim();
          }
        }
      }

      void applyVatIfDefault(TextEditingController ctrl) {
        final value = _commercialValue('vatPercent').trim();
        if (value.isEmpty) return;
        final current = ctrl.text.trim();
        if (current.isEmpty ||
            current == '-' ||
            current == '19' ||
            current == '19.0' ||
            current == '19.00' ||
            current == '19%') {
          ctrl.text = value;
        }
      }

      if (normalizedType == 'oferta') {
        applyVatIfDefault(vatCtrl);
        applyIfBlank(termExecCtrl, _commercialValue('executionTerm'));
        applyIfBlank(termPayCtrl, _commercialValue('paymentTerm'));
        applyIfBlank(validityCtrl, _commercialValue('offerValidity'));
        applyIfBlank(notesCtrl, _commercialValue('materialsProvider'));
      } else if (normalizedType == 'deviz') {
        applyVatIfDefault(vatCtrl);
        applyIfBlank(termExecCtrl, _commercialValue('executionTerm'));
        applyIfBlank(termPayCtrl, _commercialValue('paymentTerm'));
        applyIfBlank(notesCtrl, _commercialValue('materialsProvider'));
      } else if (normalizedType == 'contract') {
        applyIfBlank(durationCtrl, _commercialValue('executionTerm'));
        applyIfBlank(termPayCtrl, _commercialValue('paymentTerm'));
        applyIfBlank(advanceCtrl, _commercialValue('advance'));
        applyIfBlank(installmentsCtrl, _commercialValue('installments'));
        applyVatIfDefault(vatContractCtrl);
        applyIfBlank(penaltiesCtrl, _commercialValue('penalties'));
        applyIfBlank(logisticsCtrl, _commercialValue('logisticsProvider'));
        applyIfBlank(receptionCtrl, _commercialValue('receptionClause'));
        applyIfBlank(signaturesCtrl, _commercialValue('defaultSignatures'));
      }
    }

    applyCommercialDefaultsToControllers();

    const devizPresetOptions = <String>[
      'Standard',
      'Materiale + manoperă',
      'Manoperă separată',
      'Materiale beneficiar',
      'Materiale + logistică beneficiar',
    ];
    const contractPresets = <String>[
      'Standard',
      'Cu avans',
      'Cu tranșe',
      'Materiale beneficiar',
      'Logistică beneficiar',
      'Materiale + logistică beneficiar',
    ];
    String selectedOfferPresetLocal =
        (row['offerPreset'] as String?)?.trim() ?? 'Standard';
    if (!offerPresetOptions.contains(selectedOfferPresetLocal)) {
      selectedOfferPresetLocal = 'Standard';
    }
    String selectedDevizPresetLocal =
        (row['devizPreset'] as String?)?.trim() ?? 'Standard';
    if (!devizPresetOptions.contains(selectedDevizPresetLocal)) {
      selectedDevizPresetLocal = 'Standard';
    }
    final void Function(void Function()) setStateDialog = setState;
    void _applyOfferPresetValuesUnified(String preset) {
      Map<String, String> values;
      switch (preset) {
        case 'Premium':
          values = <String, String>{
            'object':
                'Ofertă completă pentru execuția lucrării, incluzând materiale, manoperă, testare și punere în funcțiune.',
            'content':
                'Soluția propusă include livrarea echipamentelor, montajul profesionist, verificări funcționale și predare documentație.',
            'termExec': 'Termen orientativ de execuție: 10-15 zile lucrătoare.',
            'termPay':
                'Plata se realizează conform etapelor convenite, pe baza documentelor de predare și recepție.',
            'validity': 'Oferta este valabilă 30 de zile calendaristice.',
            'notes':
                'Varianta Premium include coordonare extinsă, suport tehnic și prioritizare în programare.',
          };
          break;
        case 'Manoperă separată':
          values = <String, String>{
            'object':
                'Ofertă cu evidențiere distinctă a materialelor și a manoperei pentru lucrarea solicitată.',
            'content':
                'Materialele și manopera sunt prezentate separat pentru transparență comercială și control bugetar.',
            'termExec':
                'Termen de execuție conform graficului agreat cu beneficiarul.',
            'termPay':
                'Plata materialelor și a manoperei se face separat, conform etapelor de execuție.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Manopera este tarifată distinct față de materiale. Eventualele lucrări suplimentare se vor oferta separat.',
          };
          break;
        case 'Materiale beneficiar':
          values = <String, String>{
            'object':
                'Ofertă orientată pe servicii de montaj și execuție, cu materiale furnizate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera, montajul și verificările specifice. Materialele sunt asigurate de beneficiar.',
            'termExec':
                'Termenul de execuție se stabilește după disponibilitatea materialelor pe șantier.',
            'termPay':
                'Plata se face pentru servicii de manoperă și operațiuni conexe.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Calitatea, conformitatea și cantitatea materialelor furnizate de beneficiar rămân în responsabilitatea acestuia.',
          };
          break;
        case 'Materiale + logistică beneficiar':
          values = <String, String>{
            'object':
                'Ofertă de execuție cu materiale și logistică asigurate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera și coordonarea operațională. Beneficiarul asigură materialele și logistica necesară.',
            'termExec':
                'Termenul de execuție este condiționat de disponibilitatea materialelor și a logisticii la data intervenției.',
            'termPay':
                'Plata se efectuează pentru manoperă și servicii tehnice prestate.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Beneficiarul asigură materiale, nacelă/schelă, ridicare echipamente și utilaje auxiliare necesare execuției.',
          };
          break;
        case 'Standard':
        default:
          values = <String, String>{
            'object': 'Ofertă comercială pentru lucrările solicitate.',
            'content':
                'Oferta include operațiunile necesare conform cerințelor transmise și condițiilor din teren.',
            'termExec': 'Termen de execuție: conform programării agreate.',
            'termPay':
                'Termen de plată: conform condițiilor comerciale agreate.',
            'validity': 'Valabilitate ofertă: 15 zile calendaristice.',
            'notes':
                'Oferta poate fi ajustată în funcție de modificări de cantități sau condiții de execuție.',
          };
      }
      objectCtrl.text = values['object'] ?? '';
      contentCtrl.text = values['content'] ?? '';
      termExecCtrl.text = values['termExec'] ?? '';
      termPayCtrl.text = values['termPay'] ?? '';
      validityCtrl.text = values['validity'] ?? '';
      notesCtrl.text = values['notes'] ?? '';
    }

    void applyOfferPresetValues(String preset) {
      _applyOfferPresetValuesUnified(preset);
    }

    void _applyDevizPresetValuesUnified(String preset) {
      Map<String, String> values;
      switch (preset) {
        case 'Materiale + manoperă':
          values = <String, String>{
            'object': 'Deviz lucrări cu materiale și manoperă incluse.',
            'content':
                'Devizul include poziții de materiale, manoperă și operațiuni conexe necesare execuției.',
            'notes':
                'Totalurile reflectă consumurile estimate de materiale și manoperă pentru lucrarea curentă.',
          };
          break;
        case 'Manoperă separată':
          values = <String, String>{
            'object': 'Deviz cu evidențiere separată a manoperei.',
            'content':
                'Materialele și manopera sunt prezentate distinct pentru transparență în analiză și ofertare.',
            'notes':
                'Manopera este separată de materiale; eventualele lucrări suplimentare vor fi tratate pe poziții distincte.',
          };
          break;
        case 'Materiale beneficiar':
          values = <String, String>{
            'object':
                'Deviz orientat pe manoperă și servicii, cu materiale asigurate de beneficiar.',
            'content':
                'Materialele sunt furnizate de beneficiar/antreprenor; devizul acoperă manopera și activitățile tehnice asociate.',
            'notes':
                'Beneficiarul răspunde pentru disponibilitatea și conformitatea materialelor puse la dispoziție.',
          };
          break;
        case 'Materiale + logistică beneficiar':
          values = <String, String>{
            'object':
                'Deviz manoperă cu materiale și logistică furnizate de beneficiar.',
            'content':
                'Devizul acoperă executarea lucrărilor; materialele și logistica (nacelă/schelă/ridicare echipamente) sunt asigurate de beneficiar.',
            'notes':
                'Costurile auxiliare de logistică ale beneficiarului nu sunt incluse în totalurile devizului executantului.',
          };
          break;
        case 'Standard':
        default:
          values = <String, String>{
            'object':
                'Deviz lucrări conform cerințelor și datelor disponibile.',
            'content':
                'Structura devizului include pozițiile tehnico-economice necesare execuției lucrării.',
            'notes':
                'Devizul poate fi actualizat în funcție de modificări de cantități, condiții de șantier sau cerințe suplimentare.',
          };
      }
      objectCtrl.text = values['object'] ?? '';
      contentCtrl.text = values['content'] ?? '';
      notesCtrl.text = values['notes'] ?? '';
    }

    Future<void> _onDevizPresetSelectedUnified(String? value) async {
      if (value == null || value == selectedDevizPresetLocal) {
        return;
      }
      final hasEditedContent = objectCtrl.text.trim().isNotEmpty ||
          contentCtrl.text.trim().isNotEmpty ||
          notesCtrl.text.trim().isNotEmpty;
      if (hasEditedContent) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicare preset deviz'),
            content: const Text(
              'Aplicarea presetului poate suprascrie secțiunile editate manual. Continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aplică presetul'),
              ),
            ],
          ),
        );
        if (confirm != true) {
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        selectedDevizPresetLocal = value;
        _applyDevizPresetValuesUnified(value);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset deviz aplicat: $value')),
      );
    }

    Future<void> _onOfferPresetSelectedUnified(String? value) async {
      if (value == null || value == selectedOfferPresetLocal) {
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aplicare preset ofertă'),
          content: const Text(
            'Aplicarea presetului poate suprascrie secțiunile comerciale editate manual. Continui?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aplică presetul'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return;
      }
      if (!mounted) return;
      setState(() {
        selectedOfferPresetLocal = value;
        _applyOfferPresetValuesUnified(value);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset ofertă aplicat: $value')),
      );
    }

    Future<void> onOfferPresetSelected(
      String? value, [
      Object? _ignoredSetStateDialog,
      Object? _ignoredExtra,
    ]) {
      return _onOfferPresetSelectedUnified(value);
    }

    Future<void> _onOfferPresetSelectedLocal(
      String? value, [
      Object? _ignoredSetStateDialog,
      Object? _ignoredExtra,
    ]) {
      return _onOfferPresetSelectedUnified(value);
    }

    void _applyOfferPresetValuesLocalLegacy(String preset) {
      Map<String, String> values;
      switch (preset) {
        case 'Premium':
          values = <String, String>{
            'object':
                'Ofertă completă pentru execuția lucrării, incluzând materiale, manoperă, testare și punere în funcțiune.',
            'content':
                'Soluția propusă include livrarea echipamentelor, montajul profesionist, verificări funcționale și predare documentație.',
            'termExec': 'Termen orientativ de execuție: 10-15 zile lucrătoare.',
            'termPay':
                'Plata se realizează conform etapelor convenite, pe baza documentelor de predare și recepție.',
            'validity': 'Oferta este valabilă 30 de zile calendaristice.',
            'notes':
                'Varianta Premium include coordonare extinsă, suport tehnic și prioritizare în programare.',
          };
          break;
        case 'Manoperă separată':
          values = <String, String>{
            'object':
                'Ofertă cu evidențiere distinctă a materialelor și a manoperei pentru lucrarea solicitată.',
            'content':
                'Materialele și manopera sunt prezentate separat pentru transparență comercială și control bugetar.',
            'termExec':
                'Termen de execuție conform graficului agreat cu beneficiarul.',
            'termPay':
                'Plata materialelor și a manoperei se face separat, conform etapelor de execuție.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Manopera este tarifată distinct față de materiale. Eventualele lucrări suplimentare se vor oferta separat.',
          };
          break;
        case 'Materiale beneficiar':
          values = <String, String>{
            'object':
                'Ofertă orientată pe servicii de montaj și execuție, cu materiale furnizate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera, montajul și verificările specifice. Materialele sunt asigurate de beneficiar.',
            'termExec':
                'Termenul de execuție se stabilește după disponibilitatea materialelor pe șantier.',
            'termPay':
                'Plata se face pentru servicii de manoperă și operațiuni conexe.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Calitatea, conformitatea și cantitatea materialelor furnizate de beneficiar rămân în responsabilitatea acestuia.',
          };
          break;
        case 'Materiale + logistică beneficiar':
          values = <String, String>{
            'object':
                'Ofertă de execuție cu materiale și logistică asigurate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera și coordonarea operațională. Beneficiarul asigură materialele și logistica necesară.',
            'termExec':
                'Termenul de execuție este condiționat de disponibilitatea materialelor și a logisticii la data intervenției.',
            'termPay':
                'Plata se efectuează pentru manoperă și servicii tehnice prestate.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Beneficiarul asigură materiale, nacelă/schelă, ridicare echipamente și utilaje auxiliare necesare execuției.',
          };
          break;
        case 'Standard':
        default:
          values = <String, String>{
            'object': 'Ofertă comercială pentru lucrările solicitate.',
            'content':
                'Oferta include operațiunile necesare conform cerințelor transmise și condițiilor din teren.',
            'termExec': 'Termen de execuție: conform programării agreate.',
            'termPay':
                'Termen de plată: conform condițiilor comerciale agreate.',
            'validity': 'Valabilitate ofertă: 15 zile calendaristice.',
            'notes':
                'Oferta poate fi ajustată în funcție de modificări de cantități sau condiții de execuție.',
          };
      }
      objectCtrl.text = values['object'] ?? '';
      contentCtrl.text = values['content'] ?? '';
      termExecCtrl.text = values['termExec'] ?? '';
      termPayCtrl.text = values['termPay'] ?? '';
      validityCtrl.text = values['validity'] ?? '';
      notesCtrl.text = values['notes'] ?? '';
    }

    Future<void> _onOfferPresetSelectedLocalLegacy(
      String? value, [
      Object? _ignoredSetStateDialog,
      Object? _ignoredExtra,
    ]) {
      return _onOfferPresetSelectedUnified(value);
    }

    const offerPresets = <String>[
      'Standard',
      'Premium',
      'Manoperă separată',
      'Materiale beneficiar',
      'Materiale + logistică beneficiar',
    ];
    var selectedContractPreset = _readDocField(
      row,
      const ['contractPreset'],
      fallback: 'Standard',
    );
    if (!contractPresets.contains(selectedContractPreset)) {
      selectedContractPreset = 'Standard';
    }
    var selectedOfferPreset = _readDocField(
      row,
      const ['offerPreset'],
      fallback: 'Standard',
    );
    if (!offerPresets.contains(selectedOfferPreset)) {
      selectedOfferPreset = 'Standard';
    }
    var baselineSnapshot = '';

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    Widget field(TextEditingController c, String label, {int maxLines = 1}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          textCapitalization: TextCapitalization.sentences,
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
    }

    String buildMaterialsDetails() {
      if (_materials.isEmpty) {
        return '- Nu exista materiale asociate.';
      }
      return _materials.map((item) {
        final name = '${item['name'] ?? '-'}'.trim();
        final um = '${item['um'] ?? '-'}'.trim();
        final qty = _asDouble(item['qty']).toStringAsFixed(2);
        final price = _asDouble(item['price']).toStringAsFixed(2);
        final total = _materialLineTotal(item).toStringAsFixed(2);
        return '- $name | UM: $um | Cant: $qty | Pret: $price | Total: $total';
      }).join('\n');
    }

    String buildLaborDetails() {
      if (_labor.isEmpty) {
        return '- Nu exista manopera/ore asociate.';
      }
      return _labor.map((item) {
        final who = '${item['who'] ?? '-'}'.trim();
        final date = '${item['date'] ?? '-'}'.trim();
        final hours = _asDouble(item['hours']).toStringAsFixed(2);
        final rate = _laborRateForRow(item).toStringAsFixed(2);
        final total = _laborTotalLineCost(item).toStringAsFixed(2);
        return '- $who | Data: $date | Ore: $hours | Tarif: $rate | Total: $total';
      }).join('\n');
    }

    String buildSnapshot() {
      return [
        titleCtrl.text,
        numberCtrl.text,
        dateCtrl.text,
        statusCtrl.text,
        clientCtrl.text,
        jobCodeCtrl.text,
        jobTitleCtrl.text,
        locationCtrl.text,
        objectCtrl.text,
        contentCtrl.text,
        notesCtrl.text,
        subtotalCtrl.text,
        vatCtrl.text,
        totalCtrl.text,
        termExecCtrl.text,
        termPayCtrl.text,
        validityCtrl.text,
        partsCtrl.text,
        refsCtrl.text,
        durationCtrl.text,
        advanceCtrl.text,
        installmentsCtrl.text,
        vatContractCtrl.text,
        obligationsCtrl.text,
        beneficiaryObligationsCtrl.text,
        logisticsCtrl.text,
        penaltiesCtrl.text,
        receptionCtrl.text,
        forceMajeureCtrl.text,
        terminationCtrl.text,
        litigiiCtrl.text,
        finalClausesCtrl.text,
        signaturesCtrl.text,
        materialsCtrl.text,
        laborCtrl.text,
        totalMaterialsCtrl.text,
        totalLaborCtrl.text,
        selectedOfferPreset,
        selectedContractPreset,
      ].join('||');
    }

    Map<String, String> _offerPresetValuesLocal(String preset) {
      final subtotalValue =
          subtotalCtrl.text.trim().isEmpty ? '-' : subtotalCtrl.text.trim();
      final vatValue = vatCtrl.text.trim().isEmpty ? '-' : vatCtrl.text.trim();
      final totalValue =
          totalCtrl.text.trim().isEmpty ? '-' : totalCtrl.text.trim();
      switch (preset) {
        case 'Premium':
          return {
            'object':
                'Obiect ofertă: Soluție completă premium pentru ${widget.job.title}',
            'content': [
              'Soluție comercială premium, configurată pentru performanță și fiabilitate extinsă.',
              'Include implementare completă, reglaje finale și suport la recepție.',
              'Beneficii: execuție controlată, documentare clară și livrare profesională către client.',
              '',
              'Subtotal: $subtotalValue',
              'TVA (%): $vatValue',
              'Total: $totalValue',
            ].join('\n'),
            'termExec': 'Conform planificării tehnice agreate',
            'termPay': 'Conform graficului comercial agreat',
            'validity': '30 zile',
            'notes':
                'Ofertă premium precompletată. Se pot ajusta opțiunile comerciale conform negocierii.',
          };
        case 'Manoperă separată':
          return {
            'object':
                'Obiect ofertă: Execuție cu evidențiere distinctă materiale/manoperă',
            'content': [
              'Secțiune materiale: valoare separată față de manoperă.',
              'Secțiune manoperă: tarifare distinctă pentru montaj/execuție.',
              '',
              'Subtotal: $subtotalValue',
              'TVA (%): $vatValue',
              'Total: $totalValue',
            ].join('\n'),
            'termExec': 'Conform etapizării de execuție',
            'termPay': 'Materiale și manoperă conform condițiilor comerciale',
            'validity': '30 zile',
            'notes':
                'Model manoperă separată: valorile pot fi ajustate punctual pe capitole.',
          };
        case 'Materiale beneficiar':
          return {
            'object':
                'Obiect ofertă: Manoperă / montaj cu materiale furnizate de beneficiar',
            'content': [
              'Materialele sunt furnizate de beneficiar/antreprenor.',
              'Oferta acoperă manopera, montajul, reglajele și serviciile de execuție.',
              '',
              'Subtotal: $subtotalValue',
              'TVA (%): $vatValue',
              'Total: $totalValue',
            ].join('\n'),
            'termExec': 'Conform disponibilității materialelor la beneficiar',
            'termPay':
                'Plată servicii de manoperă conform termenului contractual',
            'validity': '30 zile',
            'notes':
                'Clauză comercială: materialele nu sunt incluse în prețul ofertat de executant.',
          };
        case 'Materiale + logistică beneficiar':
          return {
            'object':
                'Obiect ofertă: Manoperă cu materiale și logistică asigurate de beneficiar',
            'content': [
              'Materialele și logistica (nacelă/schela/ridicare/utilaje auxiliare) sunt asigurate de beneficiar/antreprenor.',
              'Oferta acoperă execuția, montajul și suportul la recepție.',
              '',
              'Subtotal: $subtotalValue',
              'TVA (%): $vatValue',
              'Total: $totalValue',
            ].join('\n'),
            'termExec':
                'Conform accesului și logisticii asigurate de beneficiar',
            'termPay': 'Conform condițiilor comerciale agreate',
            'validity': '30 zile',
            'notes':
                'Clauză comercială: materialele și logistica rămân în sarcina beneficiarului.',
          };
        case 'Standard':
        default:
          return {
            'object': 'Obiect ofertă: ${widget.job.title}',
            'content': [
              'Structură comercială standard pentru lucrarea curentă.',
              '',
              'Subtotal: $subtotalValue',
              'TVA (%): $vatValue',
              'Total: $totalValue',
            ].join('\n'),
            'termExec': 'Conform planificării',
            'termPay': 'Conform termenului agreat',
            'validity': '30 zile',
            'notes':
                'Ofertă standard precompletată din fișa lucrării. Toate secțiunile rămân editabile.',
          };
      }
    }

    void _applyOfferPresetValuesLocalLegacy2(String preset) {
      final values = _offerPresetValuesLocal(preset);
      selectedOfferPreset = preset;
      objectCtrl.text = values['object'] ?? objectCtrl.text;
      contentCtrl.text = values['content'] ?? contentCtrl.text;
      termExecCtrl.text = values['termExec'] ?? termExecCtrl.text;
      termPayCtrl.text = values['termPay'] ?? termPayCtrl.text;
      validityCtrl.text = values['validity'] ?? validityCtrl.text;
      notesCtrl.text = values['notes'] ?? notesCtrl.text;
    }

    Future<void> _onOfferPresetSelectedLocalLegacy2(
      String preset, {
      StateSetter? dialogSetState,
    }) async {
      if (selectedOfferPreset == preset) {
        return;
      }
      final changed = buildSnapshot() != baselineSnapshot;
      if (changed) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicare preset ofertă'),
            content: const Text(
              'Presetul poate suprascrie secțiuni comerciale deja editate. Continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aplică presetul'),
              ),
            ],
          ),
        );
        if (confirm != true) {
          return;
        }
      }
      if (dialogSetState != null) {
        dialogSetState(() {
          applyOfferPresetValues(preset);
        });
      } else {
        applyOfferPresetValues(preset);
      }
      baselineSnapshot = buildSnapshot();
      if (mounted) {
        _snack('Preset ofertă aplicat.');
      }
    }

    Map<String, String> offerPresetValues(String preset) {
      switch (preset) {
        case 'Premium':
          return <String, String>{
            'object':
                'Ofertă completă pentru execuția lucrării, incluzând materiale, manoperă, testare și punere în funcțiune.',
            'content':
                'Soluția propusă include livrarea echipamentelor, montajul profesionist, verificări funcționale și predare documentație.',
            'termExec': 'Termen orientativ de execuție: 10-15 zile lucrătoare.',
            'termPay':
                'Plata se realizează conform etapelor convenite, pe baza documentelor de predare și recepție.',
            'validity': 'Oferta este valabilă 30 de zile calendaristice.',
            'notes':
                'Varianta Premium include coordonare extinsă, suport tehnic și prioritizare în programare.',
          };
        case 'Manoperă separată':
          return <String, String>{
            'object':
                'Ofertă cu evidențiere distinctă a materialelor și a manoperei pentru lucrarea solicitată.',
            'content':
                'Materialele și manopera sunt prezentate separat pentru transparență comercială și control bugetar.',
            'termExec':
                'Termen de execuție conform graficului agreat cu beneficiarul.',
            'termPay':
                'Plata materialelor și a manoperei se face separat, conform etapelor de execuție.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Manopera este tarifată distinct față de materiale. Eventualele lucrări suplimentare se vor oferta separat.',
          };
        case 'Materiale beneficiar':
          return <String, String>{
            'object':
                'Ofertă orientată pe servicii de montaj și execuție, cu materiale furnizate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera, montajul și verificările specifice. Materialele sunt asigurate de beneficiar.',
            'termExec':
                'Termenul de execuție se stabilește după disponibilitatea materialelor pe șantier.',
            'termPay':
                'Plata se face pentru servicii de manoperă și operațiuni conexe.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Calitatea, conformitatea și cantitatea materialelor furnizate de beneficiar rămân în responsabilitatea acestuia.',
          };
        case 'Materiale + logistică beneficiar':
          return <String, String>{
            'object':
                'Ofertă de execuție cu materiale și logistică asigurate de beneficiar/antreprenor.',
            'content':
                'Executantul asigură manopera și coordonarea operațională. Beneficiarul asigură materialele și logistica necesară.',
            'termExec':
                'Termenul de execuție este condiționat de disponibilitatea materialelor și a logisticii la data intervenției.',
            'termPay':
                'Plata se efectuează pentru manoperă și servicii tehnice prestate.',
            'validity': 'Oferta este valabilă 15 zile calendaristice.',
            'notes':
                'Beneficiarul asigură materiale, nacelă/schelă, ridicare echipamente și utilaje auxiliare necesare execuției.',
          };
        case 'Standard':
        default:
          return <String, String>{
            'object': 'Ofertă comercială pentru lucrările solicitate.',
            'content':
                'Oferta include operațiunile necesare conform cerințelor transmise și condițiilor din teren.',
            'termExec': 'Termen de execuție: conform programării agreate.',
            'termPay':
                'Termen de plată: conform condițiilor comerciale agreate.',
            'validity': 'Valabilitate ofertă: 15 zile calendaristice.',
            'notes':
                'Oferta poate fi ajustată în funcție de modificări de cantități sau condiții de execuție.',
          };
      }
    }

    void _applyOfferPresetValuesLocalLegacy3(String preset) {
      final values = offerPresetValues(preset);
      objectCtrl.text = values['object'] ?? '';
      contentCtrl.text = values['content'] ?? '';
      termExecCtrl.text = values['termExec'] ?? '';
      termPayCtrl.text = values['termPay'] ?? '';
      validityCtrl.text = values['validity'] ?? '';
      notesCtrl.text = values['notes'] ?? '';
    }

    Future<void> _onOfferPresetSelectedLegacy(
      String? value, [
      Object? _ignoredSetStateDialog,
      Object? _ignoredExtra,
    ]) async {
      if (value == null || value == selectedOfferPresetLocal) {
        return;
      }
      final previousPreset = selectedOfferPresetLocal;
      const shouldConfirm = true;
      if (shouldConfirm) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicare preset ofertă'),
            content: const Text(
              'Aplicarea presetului poate suprascrie secțiunile comerciale editate manual. Continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aplică presetul'),
              ),
            ],
          ),
        );
        if (confirm != true) {
          setState(() {
            selectedOfferPresetLocal = previousPreset;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        selectedOfferPresetLocal = value;
        final values = _offerPresetValuesLocal(value);
        objectCtrl.text = values['object'] ?? '';
        contentCtrl.text = values['content'] ?? '';
        termExecCtrl.text = values['termExec'] ?? '';
        termPayCtrl.text = values['termPay'] ?? '';
        validityCtrl.text = values['validity'] ?? '';
        notesCtrl.text = values['notes'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preset ofertă aplicat: $value')),
      );
    }

    Map<String, String> presetValues(String preset) {
      switch (preset) {
        case 'Cu avans':
          return {
            'advance': '30% avans la semnarea contractului',
            'installments':
                'Diferența de 70% la recepția finală, în baza PV/PIF.',
            'payment':
                'Plata avansului în 3 zile lucrătoare de la semnare; soldul în 5 zile de la recepție.',
            'logistics':
                'Materiale și logistică asigurate conform planificării agreate între părți.',
          };
        case 'Cu tranșe':
          return {
            'advance': '-',
            'installments':
                'Tranșa 1: 40% la mobilizare; Tranșa 2: 40% la progres tehnic; Tranșa 3: 20% la recepție.',
            'payment':
                'Fiecare tranșă se plătește în 5 zile lucrătoare de la emiterea documentelor aferente.',
            'logistics':
                'Materiale și logistică asigurate conform anexei tehnice.',
          };
        case 'Materiale beneficiar':
          return {
            'advance': '-',
            'installments': '-',
            'payment':
                'Plata manoperei se face conform situațiilor de lucrări.',
            'logistics':
                'Materialele sunt furnizate de beneficiar/antreprenor. Executantul asigură manopera, montajul și punerea în operă.',
            'beneficiary':
                'Beneficiarul asigură materialele conform specificațiilor tehnice.',
            'contractor':
                'Executantul răspunde pentru manoperă, montaj și calitatea execuției.',
          };
        case 'Logistică beneficiar':
          return {
            'advance': '-',
            'installments': '-',
            'payment': 'Plata se efectuează conform termenului contractual.',
            'logistics':
                'Beneficiarul/antreprenorul asigură nacela, schela, ridicarea echipamentelor și utilajele auxiliare.',
            'beneficiary':
                'Beneficiarul asigură logistica necesară accesului și manipulării echipamentelor.',
          };
        case 'Materiale + logistică beneficiar':
          return {
            'advance': '-',
            'installments': '-',
            'payment':
                'Plata manoperei se efectuează la termen, conform documentelor de recepție.',
            'logistics':
                'Beneficiarul/antreprenorul asigură atât materialele, cât și logistica (nacelă/schela/ridicare/utile).',
            'beneficiary':
                'Beneficiarul asigură materialele și logistica integrală conform specificațiilor.',
            'contractor':
                'Executantul asigură strict manopera, montajul, reglajele și suportul la recepție.',
          };
        case 'Standard':
        default:
          return {
            'advance': '-',
            'installments': '-',
            'payment':
                'Plata se efectuează la termen, în baza situației de lucrări/facturii emise.',
            'logistics':
                'Materialele și logistica se asigură conform înțelegerii comerciale și anexelor tehnice.',
          };
      }
    }

    void applyPresetValues(String preset) {
      final values = presetValues(preset);
      selectedContractPreset = preset;
      advanceCtrl.text = values['advance'] ?? advanceCtrl.text;
      installmentsCtrl.text = values['installments'] ?? installmentsCtrl.text;
      termPayCtrl.text = values['payment'] ?? termPayCtrl.text;
      logisticsCtrl.text = values['logistics'] ?? logisticsCtrl.text;
      if ((values['contractor'] ?? '').trim().isNotEmpty) {
        obligationsCtrl.text = values['contractor'] ?? obligationsCtrl.text;
      }
      if ((values['beneficiary'] ?? '').trim().isNotEmpty) {
        beneficiaryObligationsCtrl.text =
            values['beneficiary'] ?? beneficiaryObligationsCtrl.text;
      }
      if (receptionCtrl.text.trim().isEmpty) {
        receptionCtrl.text =
            'Recepția se finalizează prin Proces-verbal și/sau PIF, după caz.';
      }
    }

    Future<void> onPresetSelected(
      String preset, {
      StateSetter? dialogSetState,
    }) async {
      if (selectedContractPreset == preset) {
        return;
      }
      final changed = buildSnapshot() != baselineSnapshot;
      if (changed) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicare preset contractual'),
            content: const Text(
              'Presetul poate suprascrie clauzele comerciale deja editate. Continui?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Aplică presetul'),
              ),
            ],
          ),
        );
        if (confirm != true) {
          return;
        }
      }
      if (dialogSetState != null) {
        dialogSetState(() {
          applyPresetValues(preset);
        });
      } else {
        applyPresetValues(preset);
      }
      baselineSnapshot = buildSnapshot();
      if (mounted) {
        _snack('Preset contractual aplicat.');
      }
    }

    baselineSnapshot = buildSnapshot();

    Future<bool> confirmReloadIfNeeded() async {
      final changed = buildSnapshot() != baselineSnapshot;
      if (!changed) {
        return true;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reincarca din lucrare'),
          content: const Text(
            'Datele introduse manual pot fi suprascrise. Continui reincarcarea?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Anuleaza'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reincarca'),
            ),
          ],
        ),
      );
      return confirm == true;
    }

    Future<bool> reloadFromCurrentJob({
      bool askConfirmation = true,
      bool showSuccessMessage = true,
    }) async {
      final shouldReload =
          askConfirmation ? await confirmReloadIfNeeded() : true;
      if (!shouldReload) {
        return false;
      }

      final company = await _loadCompanyBrandingMap();
      final companyName = _readCompanyField(company, const [
        'companyName',
        'name',
        'company_name',
        'numeFirma',
      ]);
      final companyAddress = _readCompanyField(company, const [
        'address',
        'companyAddress',
        'company_address',
        'adresa',
      ]);
      final companyPhone = _readCompanyField(company, const [
        'phone',
        'companyPhone',
        'company_phone',
        'telefon',
      ]);
      final companyEmail = _readCompanyField(company, const [
        'email',
        'companyEmail',
        'company_email',
      ]);

      final materialTotal = _materials.fold<double>(
        0,
        (sum, item) => sum + _materialLineTotal(item),
      );
      final laborTotal = _labor.fold<double>(
        0,
        (sum, item) => sum + _laborTotalLineCost(item),
      );
      final subtotal = materialTotal + laborTotal;
      final vatPercent =
          double.tryParse(vatCtrl.text.replaceAll(',', '.')) ?? 19;
      final vatTotal = subtotal * vatPercent / 100;
      final grandTotal = subtotal + vatTotal;
      final teamName = _assignedTeam?.label ?? '';
      final teamMembers = _assignedTeamMembersLabel;

      final sections = _buildTemplateSections(
        type: normalizedType,
        materialTotal: materialTotal,
        laborTotal: laborTotal,
        subtotal: subtotal,
        vatPercent: vatPercent,
        vatTotal: vatTotal,
        grandTotal: grandTotal,
        companyName: companyName,
        companyAddress: companyAddress,
        companyPhone: companyPhone,
        companyEmail: companyEmail,
        teamName: teamName,
        teamMembers: teamMembers,
      );

      clientCtrl.text = widget.clientName;
      jobCodeCtrl.text = widget.job.jobCode;
      jobTitleCtrl.text = widget.job.title;
      locationCtrl.text = widget.job.location;
      subtotalCtrl.text = subtotal.toStringAsFixed(2);
      vatCtrl.text = vatPercent.toStringAsFixed(2);
      totalCtrl.text = grandTotal.toStringAsFixed(2);
      totalMaterialsCtrl.text = materialTotal.toStringAsFixed(2);
      totalLaborCtrl.text = laborTotal.toStringAsFixed(2);
      notesCtrl.text = sections['notes'] ?? notesCtrl.text;

      if (normalizedType == 'oferta') {
        objectCtrl.text = 'Obiect oferta: ${widget.job.title}';
        vatCtrl.text = _commercialValue('vatPercent');
        termExecCtrl.text = _commercialValue('executionTerm');
        termPayCtrl.text = _commercialValue('paymentTerm');
        validityCtrl.text = _commercialValue('offerValidity');
        contentCtrl.text = sections['contentA'] ?? '';
        termExecCtrl.text = '-';
        termPayCtrl.text = '-';
        validityCtrl.text = '-';
      } else if (normalizedType == 'deviz') {
        vatCtrl.text = _commercialValue('vatPercent');
        termExecCtrl.text = _commercialValue('executionTerm');
        termPayCtrl.text = _commercialValue('paymentTerm');
        materialsCtrl.text = buildMaterialsDetails();
        laborCtrl.text = buildLaborDetails();
      } else if (normalizedType == 'contract') {
        advanceCtrl.text = _commercialValue('advance');
        installmentsCtrl.text = _commercialValue('installments');
        vatContractCtrl.text = _commercialValue('vatPercent');
        penaltiesCtrl.text = _commercialValue('penalties');
        logisticsCtrl.text = _commercialValue('logisticsProvider');
        receptionCtrl.text = _commercialValue('receptionClause');
        signaturesCtrl.text = _commercialValue('defaultSignatures');
        partsCtrl.text =
            'Prestator: ${companyName.trim().isEmpty ? '-' : companyName}\nBeneficiar: ${widget.clientName.trim().isEmpty ? '-' : widget.clientName}';
        objectCtrl.text = 'Obiect contract: ${widget.job.title}';
        refsCtrl.text =
            'Cod lucrare: ${widget.job.jobCode}\nTitlu lucrare: ${widget.job.title}\nLocatie: ${widget.job.location}';
        durationCtrl.text = '-';
        vatContractCtrl.text = vatPercent.toStringAsFixed(2);
        advanceCtrl.text = '-';
        installmentsCtrl.text = '-';
        termPayCtrl.text = '-';
        termExecCtrl.text = '-';
        obligationsCtrl.text = '-';
        beneficiaryObligationsCtrl.text = '-';
        logisticsCtrl.text =
            'Materiale: de stabilit\nUtilaje / nacela / schela: de stabilit\nRidicare echipamente: de stabilit';
        penaltiesCtrl.text = '-';
        receptionCtrl.text = '-';
        forceMajeureCtrl.text = '-';
        terminationCtrl.text = '-';
        litigiiCtrl.text = '-';
        finalClausesCtrl.text = '-';
        signaturesCtrl.text =
            'Responsabil: ____________________\nBeneficiar: ____________________';
      }

      baselineSnapshot = buildSnapshot();
      if (mounted && showSuccessMessage) {
        _snack('Date reincarcate din lucrare.');
      }
      return true;
    }

    Map<String, dynamic> buildEditedPayload({
      bool markRegenerateExportPdf = false,
    }) {
      final next = <String, dynamic>{
        ...row,
        'type': normalizedType,
        'documentSubtype': normalizedType,
        'numarDocument': numberCtrl.text.trim(),
        'number': numberCtrl.text.trim(),
        'dataDocument': dateCtrl.text.trim(),
        'date': dateCtrl.text.trim(),
        'status':
            statusCtrl.text.trim().isEmpty ? 'Draft' : statusCtrl.text.trim(),
        'titlu': titleCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
        'clientName': clientCtrl.text.trim(),
        'jobCode': jobCodeCtrl.text.trim(),
        'jobTitle': jobTitleCtrl.text.trim(),
        'titluLucrare': jobTitleCtrl.text.trim(),
        'location': locationCtrl.text.trim(),
        'observatii': notesCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (normalizedType == 'oferta') {
        next['obiectOferta'] = objectCtrl.text.trim();
        next['continutComercial'] = contentCtrl.text.trim();
        next['subtotal'] = subtotalCtrl.text.trim();
        next['vatPercent'] = vatCtrl.text.trim();
        next['grandTotal'] = totalCtrl.text.trim();
        next['total'] = totalCtrl.text.trim();
        next['termenExecutie'] = termExecCtrl.text.trim();
        next['termenPlata'] = termPayCtrl.text.trim();
        next['valabilitateOferta'] = validityCtrl.text.trim();
        next['obiectDescriere'] = objectCtrl.text.trim();
        next['constatari'] = contentCtrl.text.trim();
      } else if (normalizedType == 'deviz') {
        next['materialeDetaliu'] = materialsCtrl.text.trim();
        next['manoperaDetaliu'] = laborCtrl.text.trim();
        next['materialTotal'] = totalMaterialsCtrl.text.trim();
        next['laborTotal'] = totalLaborCtrl.text.trim();
        next['vatPercent'] = vatCtrl.text.trim();
        next['grandTotal'] = totalCtrl.text.trim();
        next['total'] = totalCtrl.text.trim();
        next['obiectDescriere'] = materialsCtrl.text.trim();
        next['constatari'] = laborCtrl.text.trim();
      } else if (normalizedType == 'contract') {
        next['offerPreset'] = selectedOfferPresetLocal;
        if (normalizedType == 'deviz') {
          next['devizPreset'] = selectedDevizPresetLocal;
        }
        next['contractPreset'] = selectedContractPreset;
        next['partiContractante'] = partsCtrl.text.trim();
        next['obiectContract'] = objectCtrl.text.trim();
        next['documenteReferinte'] = refsCtrl.text.trim();
        next['durataExecutie'] = durationCtrl.text.trim();
        next['avans'] = advanceCtrl.text.trim();
        next['transePlata'] = installmentsCtrl.text.trim();
        next['tvaContract'] = vatContractCtrl.text.trim();
        next['conditiiPlata'] = termPayCtrl.text.trim();
        next['termenExecutie'] = termExecCtrl.text.trim();
        next['obligatiiParti'] = obligationsCtrl.text.trim();
        next['obligatiiBeneficiar'] = beneficiaryObligationsCtrl.text.trim();
        next['materialeLogistica'] = logisticsCtrl.text.trim();
        next['penalitati'] = penaltiesCtrl.text.trim();
        next['receptie'] = receptionCtrl.text.trim();
        next['fortaMajora'] = forceMajeureCtrl.text.trim();
        next['incetareContract'] = terminationCtrl.text.trim();
        next['litigii'] = litigiiCtrl.text.trim();
        next['dispozitiiFinale'] = finalClausesCtrl.text.trim();
        next['semnaturi'] = signaturesCtrl.text.trim();
        next['grandTotal'] = totalCtrl.text.trim();
        next['total'] = totalCtrl.text.trim();
        next['obiectDescriere'] = objectCtrl.text.trim();
        next['constatari'] = [
          if (refsCtrl.text.trim().isNotEmpty)
            'Referinte: ${refsCtrl.text.trim()}',
          if (durationCtrl.text.trim().isNotEmpty)
            'Durata: ${durationCtrl.text.trim()}',
          if (advanceCtrl.text.trim().isNotEmpty)
            'Avans: ${advanceCtrl.text.trim()}',
          if (installmentsCtrl.text.trim().isNotEmpty)
            'Transe plata: ${installmentsCtrl.text.trim()}',
          if (vatContractCtrl.text.trim().isNotEmpty)
            'TVA: ${vatContractCtrl.text.trim()}',
          if (obligationsCtrl.text.trim().isNotEmpty)
            'Obligatii: ${obligationsCtrl.text.trim()}',
          if (beneficiaryObligationsCtrl.text.trim().isNotEmpty)
            'Obligatii beneficiar: ${beneficiaryObligationsCtrl.text.trim()}',
          if (logisticsCtrl.text.trim().isNotEmpty)
            'Materiale/utilaje/logistica: ${logisticsCtrl.text.trim()}',
          if (penaltiesCtrl.text.trim().isNotEmpty)
            'Penalitati: ${penaltiesCtrl.text.trim()}',
          if (receptionCtrl.text.trim().isNotEmpty)
            'Receptie/PV/PIF: ${receptionCtrl.text.trim()}',
          if (forceMajeureCtrl.text.trim().isNotEmpty)
            'Forta majora: ${forceMajeureCtrl.text.trim()}',
          if (terminationCtrl.text.trim().isNotEmpty)
            'Incetare contract: ${terminationCtrl.text.trim()}',
          if (litigiiCtrl.text.trim().isNotEmpty)
            'Litigii: ${litigiiCtrl.text.trim()}',
          if (finalClausesCtrl.text.trim().isNotEmpty)
            'Dispozitii finale: ${finalClausesCtrl.text.trim()}',
          if (signaturesCtrl.text.trim().isNotEmpty)
            'Semnaturi: ${signaturesCtrl.text.trim()}',
        ].join('\n');
      }

      if (markRegenerateExportPdf) {
        next['__regenerate_export_pdf'] = true;
      }
      return next;
    }

    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(
                normalizedType == 'oferta'
                    ? 'Editează Ofertă'
                    : normalizedType == 'deviz'
                        ? 'Editează Deviz'
                        : 'Editează Contract',
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Date document'),
                      field(numberCtrl, 'Număr document'),
                      field(dateCtrl, 'Dată document'),
                      field(statusCtrl, 'Status'),
                      field(titleCtrl, 'Titlu document'),
                      sectionTitle('Date client'),
                      field(clientCtrl, 'Client'),
                      sectionTitle('Referință lucrare'),
                      field(jobCodeCtrl, 'Cod lucrare'),
                      field(jobTitleCtrl, 'Titlu lucrare'),
                      field(locationCtrl, 'Locație'),
                      if (normalizedType == 'oferta') ...[
                        sectionTitle('Conținut ofertă'),
                        field(objectCtrl, 'Obiect ofertă', maxLines: 3),
                        field(contentCtrl, 'Conținut comercial', maxLines: 6),
                        field(subtotalCtrl, 'Subtotal'),
                        field(vatCtrl, 'TVA (%)'),
                        field(totalCtrl, 'Total'),
                        field(termExecCtrl, 'Termen execuție'),
                        field(termPayCtrl, 'Termen plată'),
                        field(validityCtrl, 'Valabilitate ofertă'),
                      ] else if (normalizedType == 'deviz') ...[
                        sectionTitle('Conținut deviz'),
                        field(materialsCtrl, 'Materiale', maxLines: 6),
                        field(laborCtrl, 'Manoperă', maxLines: 6),
                        field(totalMaterialsCtrl, 'Total materiale'),
                        field(totalLaborCtrl, 'Total manoperă'),
                        field(vatCtrl, 'TVA (%)'),
                        field(totalCtrl, 'Total general'),
                      ] else ...[
                        sectionTitle('Preset comercial'),
                        DropdownButtonFormField<String>(
                          initialValue: selectedContractPreset,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: contractPresets
                              .map(
                                (preset) => DropdownMenuItem<String>(
                                  value: preset,
                                  child: Text(preset),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) async {
                            if (value == null) return;
                            await onPresetSelected(
                              value,
                              dialogSetState: dialogSetState,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        sectionTitle('Conținut contract'),
                        sectionTitle('Părțile contractante'),
                        field(partsCtrl, 'Părți contractante', maxLines: 5),
                        sectionTitle('Obiectul contractului'),
                        field(objectCtrl, 'Obiect contract', maxLines: 4),
                        sectionTitle('Documente și referințe ale lucrării'),
                        field(refsCtrl, 'Documente / referințe', maxLines: 3),
                        sectionTitle('Durata / termen execuție'),
                        field(durationCtrl, 'Durata contractului'),
                        field(termExecCtrl, 'Termen execuție'),
                        sectionTitle('Preț și condiții comerciale'),
                        field(totalCtrl, 'Preț contract'),
                        field(vatContractCtrl, 'TVA'),
                        field(advanceCtrl, 'Avans'),
                        field(installmentsCtrl, 'Tranșe de plată', maxLines: 3),
                        field(termPayCtrl, 'Termen de plată', maxLines: 3),
                        sectionTitle('Obligații și logistică'),
                        field(
                          obligationsCtrl,
                          'Obligațiile executantului',
                          maxLines: 4,
                        ),
                        field(
                          beneficiaryObligationsCtrl,
                          'Obligațiile beneficiarului / antreprenorului',
                          maxLines: 4,
                        ),
                        field(
                          logisticsCtrl,
                          'Materiale / utilaje / logistică',
                          maxLines: 4,
                        ),
                        sectionTitle('Recepție și condiții legale'),
                        field(receptionCtrl, 'Recepție / PV / PIF',
                            maxLines: 3),
                        field(penaltiesCtrl, 'Penalități', maxLines: 3),
                        field(forceMajeureCtrl, 'Forță majoră', maxLines: 3),
                        field(
                          terminationCtrl,
                          'Încetarea contractului',
                          maxLines: 3,
                        ),
                        field(litigiiCtrl, 'Litigii', maxLines: 3),
                        field(
                          finalClausesCtrl,
                          'Dispoziții finale',
                          maxLines: 3,
                        ),
                        sectionTitle('Semnături'),
                        field(signaturesCtrl, 'Semnături', maxLines: 3),
                      ],
                      sectionTitle('Observații'),
                      field(notesCtrl, 'Observații', maxLines: 4),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Renunță'),
                ),
                OutlinedButton.icon(
                  onPressed: reloadFromCurrentJob,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reincarca din lucrare'),
                ),
                if (normalizedType == 'oferta')
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedOfferPresetLocal,
                      decoration: const InputDecoration(
                        labelText: 'Preset comercial',
                        isDense: true,
                      ),
                      items: offerPresetOptions
                          .map(
                            (preset) => DropdownMenuItem<String>(
                              value: preset,
                              child: Text(preset),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _onOfferPresetSelectedUnified(value);
                      },
                    ),
                  ),
                if (normalizedType == 'deviz')
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedDevizPresetLocal,
                      decoration: const InputDecoration(
                        labelText: 'Preset deviz',
                        isDense: true,
                      ),
                      items: devizPresetOptions
                          .map(
                            (preset) => DropdownMenuItem<String>(
                              value: preset,
                              child: Text(preset),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _onDevizPresetSelectedUnified(value);
                      },
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final hasExistingPdf = _readDocField(
                      row,
                      const ['pdfPath', 'filePath'],
                    ).isNotEmpty;
                    final changed = buildSnapshot() != baselineSnapshot;
                    if (hasExistingPdf || changed) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Regenerare + export PDF'),
                          content: const Text(
                            'Documentul va fi reîncărcat din lucrare și PDF-ul va fi regenerat/suprascris. Continui?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Anulează'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Continuă'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) {
                        return;
                      }
                    }
                    final ok = await reloadFromCurrentJob(
                      askConfirmation: false,
                      showSuccessMessage: false,
                    );
                    if (!ok) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop(
                      buildEditedPayload(markRegenerateExportPdf: true),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Regenerare completă + export PDF'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(buildEditedPayload());
                  },
                  child: const Text('Salvează'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    numberCtrl.dispose();
    dateCtrl.dispose();
    statusCtrl.dispose();
    clientCtrl.dispose();
    jobCodeCtrl.dispose();
    jobTitleCtrl.dispose();
    locationCtrl.dispose();
    objectCtrl.dispose();
    contentCtrl.dispose();
    notesCtrl.dispose();
    subtotalCtrl.dispose();
    vatCtrl.dispose();
    totalCtrl.dispose();
    termExecCtrl.dispose();
    termPayCtrl.dispose();
    validityCtrl.dispose();
    partsCtrl.dispose();
    refsCtrl.dispose();
    durationCtrl.dispose();
    advanceCtrl.dispose();
    installmentsCtrl.dispose();
    vatContractCtrl.dispose();
    obligationsCtrl.dispose();
    beneficiaryObligationsCtrl.dispose();
    logisticsCtrl.dispose();
    penaltiesCtrl.dispose();
    receptionCtrl.dispose();
    forceMajeureCtrl.dispose();
    terminationCtrl.dispose();
    litigiiCtrl.dispose();
    finalClausesCtrl.dispose();
    signaturesCtrl.dispose();
    materialsCtrl.dispose();
    laborCtrl.dispose();
    totalMaterialsCtrl.dispose();
    totalLaborCtrl.dispose();

    return edited;
  }

  Future<void> _onViewDocumentFixed(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final doc = Map<String, dynamic>.from(_documents[index]);

    String clean(String value) => _sanitizeDisplayText(value)
        .replaceAll('', '')
        .replaceAll('\u00A0', ' ')
        .trim();

    final type = clean(_resolveDocumentTypeLabel(doc));
    final title = clean('${doc['titlu'] ?? doc['title'] ?? '-'}');
    final number = clean('${doc['numarDocument'] ?? doc['number'] ?? ''}');
    final date = clean('${doc['dataDocument'] ?? doc['date'] ?? ''}');
    final status = clean('${doc['status'] ?? '-'}');
    final notes = clean('${doc['observatii'] ?? doc['notes'] ?? ''}');
    final jobStatus = clean('${widget.job.status.label}');

    if (!mounted) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actionsOverflowDirection: VerticalDirection.down,
          title:
              Text(type.isEmpty ? 'Vizualizare document' : 'Vizualizare $type'),
          content: SizedBox(
            width: 760,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.68,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  [
                    if (type.isNotEmpty) 'Tip document: $type',
                    if (title.isNotEmpty) 'Titlu: $title',
                    if (number.isNotEmpty) 'Numar: $number',
                    if (date.isNotEmpty) 'Data: $date',
                    if (status.isNotEmpty) 'Status: $status',
                    'Status lucrare: $jobStatus',
                    if (notes.isNotEmpty) 'Observatii: $notes',
                  ].join('\n'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onOpenDocumentPdf(index);
              },
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Deschide PDF'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _onExportDocumentPdf(index);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Regenerare'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _onExportDocumentPdf(index, saveAs: true);
              },
              icon: const Icon(Icons.save_as_outlined),
              label: const Text('Save As'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openFieldPhotosForDocument(index);
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Poze'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Inchide'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onEditDocumentSmart(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final type = _normalizeDocumentType(
      '${row['type'] ?? row['tipDocument'] ?? row['documentSubtype'] ?? ''}',
    );
    if (!_isBusinessTemplateType(type)) {
      await _onEditDocument(index);
      return;
    }
    final edited = await _showBusinessTemplateEditor(row, type);
    if (edited == null) {
      return;
    }
    final regenerateAndExport = edited['__regenerate_export_pdf'] == true;
    final cleanedEdited = Map<String, dynamic>.from(edited)
      ..remove('__regenerate_export_pdf');
    final next = [..._documents];
    next[index] = await _registerDocumentForRegistry(cleanedEdited);
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) {
      return;
    }
    setState(() => _documents = next);
    _snack('Document actualizat.');
    if (regenerateAndExport) {
      await _onExportDocumentPdf(index);
      if (!mounted) {
        return;
      }
      _snack('Document regenerat și exportat PDF.');
      await _appendJournal(
        action: 'document_regenerated_exported',
        message:
            'Document regenerat + PDF: ${next[index]['tipDocument'] ?? next[index]['type'] ?? '-'} ${next[index]['numarDocument'] ?? next[index]['number'] ?? ''}',
      );
    }
    await _appendJournal(
      action: 'document_updated',
      message:
          'Document actualizat: ${next[index]['tipDocument'] ?? next[index]['type'] ?? '-'} ${next[index]['titlu'] ?? next[index]['title'] ?? ''}',
    );
  }

  Future<void> _onAddDocument() async {
    final typeOptions = _dedupeDropdownValues(_documentTypes);
    String selectedType =
        typeOptions.isNotEmpty ? typeOptions.first : _documentTypes.first;
    String selectedStatus = _documentStatuses.first;
    final titleController = TextEditingController(text: widget.job.title);
    final numberController = TextEditingController();
    final dateController =
        TextEditingController(text: _formatDate(DateTime.now()));
    final filePathController = TextEditingController();
    final notesController = TextEditingController(
      text:
          'Cod lucrare: ${widget.job.jobCode}\nClient: ${widget.clientName}\nLocatie: ${widget.job.location}',
    );

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adauga document'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: typeOptions
                              .where(
                                (option) =>
                                    option.toLowerCase() ==
                                    selectedType.trim().toLowerCase(),
                              )
                              .length ==
                          1
                      ? typeOptions.firstWhere(
                          (option) =>
                              option.toLowerCase() ==
                              selectedType.trim().toLowerCase(),
                        )
                      : null,
                  decoration: const InputDecoration(labelText: 'Tip document'),
                  items: typeOptions
                      .map((type) => DropdownMenuItem<String>(
                          value: type, child: Text(type)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titlu'),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: numberController,
                  decoration:
                      const InputDecoration(labelText: 'Numar / Referinta'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _documentStatuses
                      .map((status) => DropdownMenuItem<String>(
                          value: status, child: Text(status)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStatus = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Data'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: filePathController,
                        decoration: const InputDecoration(
                          labelText: 'File path / PDF path (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const <String>[
                            'pdf',
                            'png',
                            'jpg',
                            'jpeg',
                            'webp',
                            'doc',
                            'docx',
                            'xls',
                            'xlsx',
                          ],
                        );
                        final pickedPath =
                            result?.files.single.path?.trim() ?? '';
                        if (pickedPath.isEmpty) {
                          return;
                        }
                        setDialogState(() {
                          filePathController.text = pickedPath;
                        });
                      },
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('Alege fisier'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Observatii'),
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuleaza'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'id': 'job-doc-${DateTime.now().microsecondsSinceEpoch}',
                'jobId': widget.job.id,
                'client': widget.clientName,
                'location': widget.job.location,
                'type': _normalizeDocumentType(selectedType),
                'tipDocument': selectedType,
                'documentSubtype':
                    _documentSubtypeFromSelectedType(selectedType),
                'titlu': titleController.text.trim(),
                'numarDocument': numberController.text.trim(),
                'dataDocument': dateController.text.trim(),
                'observatii': notesController.text.trim(),
                'status': selectedStatus,
                'filePath': filePathController.text.trim(),
                'pdfPath': filePathController.text.trim(),
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
                // legacy aliases for backward compatibility
                'typeLegacy': selectedType,
                'title': titleController.text.trim(),
                'number': numberController.text.trim(),
                'date': dateController.text.trim(),
                'notes': notesController.text.trim(),
              }),
              child: const Text('Salveaza'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    numberController.dispose();
    dateController.dispose();
    filePathController.dispose();
    notesController.dispose();
    if (created == null) return;

    final next = [..._documents, created];
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('Document salvat.');
    await _appendJournal(
      action: 'document_added',
      message:
          'Document adaugat: ${created['tipDocument'] ?? created['type'] ?? '-'} ${created['titlu'] ?? created['title'] ?? ''}'
              .trim(),
    );
  }

  Future<void> _onEditDocument(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final isGenerated = '${row['documentSubtype'] ?? ''}'.trim().isNotEmpty;
    List<String> _dedupeDocTypeValues(Iterable<String> values) {
      final seen = <String>{};
      final out = <String>[];
      for (final raw in values) {
        final value = _sanitizeDisplayText(raw);
        if (value.isEmpty) continue;
        final key = value.toLowerCase();
        if (seen.add(key)) out.add(value);
      }
      return out;
    }

    final typeOptions = _dedupeDocTypeValues(_documentTypes);
    String selectedType = '${row['tipDocument'] ?? ''}'.trim();
    if (selectedType.isEmpty) {
      selectedType = _documentTypeLabelFromType('${row['type'] ?? ''}');
    }
    final hasSelectedType = typeOptions.any(
      (option) => option.toLowerCase() == selectedType.toLowerCase(),
    );
    if (!hasSelectedType && typeOptions.isNotEmpty) {
      selectedType = typeOptions.first;
    }
    String selectedStatus =
        '${row['status'] ?? _documentStatuses.first}'.trim().isEmpty
            ? _documentStatuses.first
            : '${row['status'] ?? _documentStatuses.first}'.trim();
    if (!_documentStatuses.contains(selectedStatus)) {
      selectedStatus = _documentStatuses.first;
    }
    final titleController =
        TextEditingController(text: '${row['titlu'] ?? row['title'] ?? ''}');
    final numberController = TextEditingController(
      text: '${row['numarDocument'] ?? row['number'] ?? ''}',
    );
    final dateController = TextEditingController(
      text: '${row['dataDocument'] ?? row['date'] ?? ''}',
    );
    final filePathController = TextEditingController(
      text: '${row['filePath'] ?? row['pdfPath'] ?? ''}',
    );
    final notesController = TextEditingController(
      text: '${row['observatii'] ?? row['notes'] ?? ''}',
    );

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editeaza document'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: typeOptions
                              .where(
                                (option) =>
                                    option.toLowerCase() ==
                                    selectedType.trim().toLowerCase(),
                              )
                              .length ==
                          1
                      ? typeOptions.firstWhere(
                          (option) =>
                              option.toLowerCase() ==
                              selectedType.trim().toLowerCase(),
                        )
                      : null,
                  decoration: const InputDecoration(labelText: 'Tip document'),
                  items: typeOptions
                      .map((type) => DropdownMenuItem<String>(
                          value: type, child: Text(type)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titlu'),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: numberController,
                  decoration:
                      const InputDecoration(labelText: 'Numar / Referinta'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _documentStatuses
                      .map((status) => DropdownMenuItem<String>(
                          value: status, child: Text(status)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStatus = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Data'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: filePathController,
                        decoration: const InputDecoration(
                          labelText: 'File path / PDF path (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const <String>[
                            'pdf',
                            'png',
                            'jpg',
                            'jpeg',
                            'webp',
                            'doc',
                            'docx',
                            'xls',
                            'xlsx',
                          ],
                        );
                        final pickedPath =
                            result?.files.single.path?.trim() ?? '';
                        if (pickedPath.isEmpty) {
                          return;
                        }
                        setDialogState(() {
                          filePathController.text = pickedPath;
                        });
                      },
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('Alege fisier'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Observatii'),
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuleaza'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                ...row,
                'type': isGenerated
                    ? '${row['type'] ?? _normalizeDocumentType(selectedType)}'
                    : _normalizeDocumentType(selectedType),
                'tipDocument':
                    isGenerated ? _extractDocumentTypeLabel(row) : selectedType,
                'titlu': titleController.text.trim(),
                'numarDocument': isGenerated
                    ? '${row['numarDocument'] ?? row['number'] ?? ''}'
                    : numberController.text.trim(),
                'dataDocument': dateController.text.trim(),
                'observatii': notesController.text.trim(),
                'status': selectedStatus,
                'filePath': filePathController.text.trim(),
                'pdfPath': filePathController.text.trim(),
                'updatedAt': DateTime.now().toIso8601String(),
                // legacy aliases
                'typeLegacy': selectedType,
                'title': titleController.text.trim(),
                'number': isGenerated
                    ? '${row['numarDocument'] ?? row['number'] ?? ''}'
                    : numberController.text.trim(),
                'date': dateController.text.trim(),
                'notes': notesController.text.trim(),
              }),
              child: const Text('Salveaza'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    numberController.dispose();
    dateController.dispose();
    filePathController.dispose();
    notesController.dispose();
    if (updated == null) return;

    final next = [..._documents];
    next[index] = updated;
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('Document actualizat.');
    await _appendJournal(
      action: 'document_edited',
      message:
          'Document editat: ${updated['tipDocument'] ?? updated['type'] ?? '-'} ${updated['titlu'] ?? updated['title'] ?? ''}'
              .trim(),
    );
  }

  Future<void> _onDeleteDocument(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stergere document'),
        content: const Text('Sigur vrei sa stergi acest document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuleaza'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sterge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final next = [..._documents]..removeAt(index);
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('Document sters.');
    await _appendJournal(
      action: 'document_deleted',
      message:
          'Document sters: ${row['tipDocument'] ?? row['type'] ?? '-'} ${row['titlu'] ?? row['title'] ?? ''}'
              .trim(),
    );
  }

  Future<void> _onViewDocument(int index) async {
    await _onViewDocumentFixed(index);
    return;
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final type = _extractDocumentTypeLabel(row);
    final title = '${row['titlu'] ?? row['title'] ?? '-'}';
    final number = '${row['numarDocument'] ?? row['number'] ?? '-'}';
    final date = '${row['dataDocument'] ?? row['date'] ?? '-'}';
    final status = '${row['status'] ?? '-'}';
    final notes = '${row['observatii'] ?? row['notes'] ?? ''}'.trim();
    final filePath = '${row['filePath'] ?? row['pdfPath'] ?? ''}'.trim();
    final subtype = '${row['documentSubtype'] ?? ''}'.trim().toLowerCase();
    final detailsA = subtype == 'pv'
        ? '${row['obiectDescriere'] ?? ''}'.trim()
        : '${row['descrierePunereInFunctiune'] ?? ''}'.trim();
    final detailsB = subtype == 'pv'
        ? '${row['constatari'] ?? ''}'.trim()
        : '${row['parametriRezultate'] ?? ''}'.trim();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vizualizare document'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tip: $type'),
              const SizedBox(height: 4),
              Text('Titlu: $title'),
              const SizedBox(height: 4),
              Text('Numar: $number'),
              const SizedBox(height: 4),
              Text('Data: $date'),
              const SizedBox(height: 4),
              Text('Status: $status'),
              const SizedBox(height: 4),
              Text('Path: ${filePath.isEmpty ? '-' : filePath}'),
              if (detailsA.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                    '${subtype == 'pv' ? 'Obiect / Descriere' : 'Descriere PIF'}: $detailsA'),
              ],
              if (detailsB.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                    '${subtype == 'pv' ? 'Constatari' : 'Parametri / rezultate'}: $detailsB'),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Observatii: $notes'),
              ],
            ],
          ),
        ),
        actions: [
          if (filePath.trim().isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _onOpenDocumentPdf(index);
              },
              child: const Text('Deschide PDF'),
            ),
          if ('${row['documentSubtype'] ?? ''}'.trim().isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _onRegenerateGeneratedDocument(index);
              },
              child: const Text('Regenereaza'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Inchide'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRegenerateGeneratedDocument(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final subtype = '${row['documentSubtype'] ?? ''}'.trim().toLowerCase();
    if (subtype != 'pv' && subtype != 'pif') return;

    final updated = <String, dynamic>{
      ...row,
      'jobId': widget.job.id,
      'client': widget.clientName,
      'location': widget.job.location,
      'jobCode': widget.job.jobCode,
      'jobTitle': widget.job.title,
      'jobStatus': widget.job.status.label,
      'teamLabel': _assignedTeam?.label ?? '-',
      'teamMembers': _assignedTeamMembersLabel,
      'appointmentsCount': _appointments.length,
      'materialsCount': _materials.length,
      'laborCount': _labor.length,
      'appointmentsSnapshot': _appointments
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'materialsSnapshot': _materials
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'laborSnapshot': _labor
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final next = [..._documents];
    next[index] = updated;
    await _persistOperationalJobDetails(documents: next);
    if (!mounted) return;
    setState(() => _documents = next);
    _snack('Document regenerat din datele curente ale lucrarii.');
    await _appendJournal(
      action: 'document_regenerated',
      message:
          'Document regenerat: ${updated['tipDocument'] ?? updated['type'] ?? '-'}',
    );
    final hasPdf =
        '${updated['pdfPath'] ?? updated['filePath'] ?? ''}'.trim().isNotEmpty;
    if (hasPdf) {
      await _onExportDocumentPdf(index);
    }
  }

  Future<void> _onToggleChecklist(String key, bool value) async {
    final next = Map<String, bool>.from(_checklist);
    next[key] = value;
    await _saveChecklist(next);
    final label = _checklistDefs
        .where((entry) => entry.key == key)
        .map((entry) => entry.value)
        .firstWhere(
          (_) => true,
          orElse: () => key,
        );
    await _appendJournal(
      action: 'checklist_updated',
      message: '${value ? 'Bifat' : 'Debifat'}: $label',
    );
  }

  DateTime? _workTaskStartAt(Map<String, dynamic> row) {
    return DateTime.tryParse('${row['startAt'] ?? ''}'.trim());
  }

  DateTime? _workTaskEndAt(Map<String, dynamic> row) {
    return DateTime.tryParse('${row['endAt'] ?? ''}'.trim());
  }

  Duration _workTaskDuration(Map<String, dynamic> row) {
    final start = _workTaskStartAt(row);
    final end = _workTaskEndAt(row);
    if (start == null || end == null) {
      return Duration.zero;
    }
    if (end.isBefore(start)) {
      return Duration.zero;
    }
    return end.difference(start);
  }

  String _workTaskDurationLabel(Map<String, dynamic> row) {
    final duration = _workTaskDuration(row);
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      return '-';
    }
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (hours <= 0) {
      return '${rem}m';
    }
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  List<String> _workTaskWorkers(Map<String, dynamic> row) {
    final raw = row['workers'];
    if (raw is List) {
      return raw
          .map((entry) => '$entry'.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) {
      return const <String>[];
    }
    return text
        .split(RegExp(r'[,;\n]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  List<MapEntry<String, Map<String, dynamic>>> _workloadSummaryByDay() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in _workTaskEntries) {
      final start = _workTaskStartAt(row);
      final end = _workTaskEndAt(row);
      if (start == null || end == null || end.isBefore(start)) {
        continue;
      }
      final key =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final current = grouped[key] ??
          <String, dynamic>{
            'minutes': 0,
            'tasks': 0,
            'people': <String>{},
          };
      current['minutes'] =
          (current['minutes'] as int) + end.difference(start).inMinutes;
      current['tasks'] = (current['tasks'] as int) + 1;
      final people = current['people'] as Set<String>;
      people.addAll(_workTaskWorkers(row));
      grouped[key] = current;
    }
    final rows = grouped.entries.toList(growable: false)
      ..sort((a, b) => b.key.compareTo(a.key));
    return rows;
  }

  String _dayKeyToLabel(String key) {
    final parsed = DateTime.tryParse('${key}T00:00:00');
    if (parsed == null) {
      return key;
    }
    return _formatDate(parsed);
  }

  Future<void> _saveWorkTaskEntries(List<Map<String, dynamic>> rows) async {
    final normalized = _cloneRows(rows);
    await _persistOperationalJobDetails(workTaskEntries: normalized);
    if (!mounted) {
      return;
    }
    setState(() => _workTaskEntries = normalized);
  }

  Future<Map<String, dynamic>?> _openWorkTaskDialog({
    Map<String, dynamic>? initial,
  }) =>
      showWorkTaskDialog(
        context,
        initial: initial,
        initialWorkers:
            _workTaskWorkers(initial ?? const <String, dynamic>{}),
        onValidationError: _snack,
      );

  Future<void> _onAddWorkTask() async {
    final created = await _openWorkTaskDialog();
    if (created == null) {
      return;
    }
    final next = <Map<String, dynamic>>[..._workTaskEntries, created];
    next.sort((a, b) {
      final aStart =
          DateTime.tryParse('${a['startAt'] ?? ''}') ?? DateTime(1970);
      final bStart =
          DateTime.tryParse('${b['startAt'] ?? ''}') ?? DateTime(1970);
      return bStart.compareTo(aStart);
    });
    await _saveWorkTaskEntries(next);
    await _appendJournal(
      action: 'work_task_added',
      message: 'Etapa adaugata: ${created['title']}',
    );
  }

  Future<void> _onEditWorkTask(int index) async {
    if (index < 0 || index >= _workTaskEntries.length) {
      return;
    }
    final current = _workTaskEntries[index];
    final updated = await _openWorkTaskDialog(initial: current);
    if (updated == null) {
      return;
    }
    final next = _cloneRows(_workTaskEntries).toList(growable: true);
    next[index] = updated;
    next.sort((a, b) {
      final aStart =
          DateTime.tryParse('${a['startAt'] ?? ''}') ?? DateTime(1970);
      final bStart =
          DateTime.tryParse('${b['startAt'] ?? ''}') ?? DateTime(1970);
      return bStart.compareTo(aStart);
    });
    await _saveWorkTaskEntries(next);
    await _appendJournal(
      action: 'work_task_updated',
      message: 'Etapa actualizata: ${updated['title']}',
    );
  }

  Future<void> _onDeleteWorkTask(int index) async {
    if (index < 0 || index >= _workTaskEntries.length) {
      return;
    }
    final row = _workTaskEntries[index];
    final next = _cloneRows(_workTaskEntries).toList(growable: true)
      ..removeAt(index);
    await _saveWorkTaskEntries(next);
    await _appendJournal(
      action: 'work_task_deleted',
      message: 'Etapa stearsa: ${row['title'] ?? '-'}',
    );
  }

  Future<void> _onToggleWorkTaskCompleted(int index, bool value) async {
    if (index < 0 || index >= _workTaskEntries.length) {
      return;
    }
    final next = _cloneRows(_workTaskEntries).toList(growable: true);
    final row = <String, dynamic>{...next[index], 'completed': value};
    next[index] = row;
    await _saveWorkTaskEntries(next);
    await _appendJournal(
      action: 'work_task_completed_toggle',
      message: '${value ? 'Finalizat' : 'Re-deschis'}: ${row['title'] ?? '-'}',
    );
  }

  LucrareReportData _buildReportData() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');

    List<Map<String, dynamic>> cloneRows(List<Map<String, dynamic>> source) {
      return source
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    final members = _assignedTeamMembersLabel
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return LucrareReportData(
      generatedAtLabel: '$d.$m.${now.year} $h:$min',
      jobCode: widget.job.jobCode,
      jobTitle: widget.job.title,
      clientName: widget.clientName,
      location: widget.job.location,
      statusLabel: widget.job.status.label,
      estimatedValue: _estimatedValue,
      materialsTotal: _materialsTotal,
      laborOreTotal: _laborOreTotal,
      laborPerDiemTotal: _laborDiurnaTotal,
      laborLodgingTotal: _laborCazareTotal,
      laborCompleteTotal: _laborCompleteTotal,
      realTotal: _realTotalCost,
      estimatedVsReal: _estimatedVsRealDifference,
      materialsCount: _materials.length,
      laborCount: _labor.length,
      appointmentsCount: _appointments.length,
      personHoursTotal: _personHoursTotal,
      teamHoursTotal: _teamHoursTotal,
      currentTeamLabel: _assignedTeam?.label ?? '-',
      teamMembers: members,
      appointments: cloneRows(_appointments),
      materials: cloneRows(_materials),
      labor: cloneRows(_labor),
      documents: cloneRows(_documents),
      workTaskEntries: cloneRows(_workTaskEntries),
      checklist: Map<String, bool>.from(_checklist),
      journal: cloneRows(_journal),
      beneficiarySuppliedEquipment: _beneficiarySuppliedEquipment
          .map((item) => item.toMap())
          .toList(growable: false),
      beneficiarySuppliedMaterials: _beneficiarySuppliedMaterials
          .map((item) => item.toMap())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _buildReportPayload() {
    List<Map<String, dynamic>> cloneRows(List<Map<String, dynamic>> source) =>
        source.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    final appointments = cloneRows(_appointments);
    final materials = cloneRows(_materials);
    final labor = cloneRows(_labor);
    final documents = cloneRows(_documents);

    final materialTotal = materials.fold<double>(0, (sum, row) {
      final map = Map<String, dynamic>.from(row);
      final lineTotal = _asDouble(map['total']) > 0
          ? _asDouble(map['total'])
          : _materialLineTotal(map);
      return sum + lineTotal;
    });

    var laborOreTotal = 0.0;
    var laborPerDiemTotal = 0.0;
    var laborLodgingTotal = 0.0;
    var laborFullTotal = 0.0;
    var personHoursTotal = 0.0;
    var teamHoursTotal = 0.0;

    for (final row in labor) {
      final map = Map<String, dynamic>.from(row);
      laborOreTotal += _laborOreCost(map);
      laborPerDiemTotal += _laborPerDiemCost(map);
      laborLodgingTotal += _laborLodgingCost(map);
      laborFullTotal += _laborTotalLineCost(map);

      final type = '${map['type'] ?? map['entryType'] ?? map['tip'] ?? ''}'
          .trim()
          .toLowerCase();
      final hours = _asDouble(map['hours']) > 0
          ? _asDouble(map['hours'])
          : _asDouble(map['ore']);
      if (type.contains('team') || type.contains('echipa')) {
        teamHoursTotal += hours;
      } else {
        personHoursTotal += hours;
      }
    }

    final estimatedValue = _asDouble(widget.job.estimatedValue);
    final realTotalCost = materialTotal + laborFullTotal;
    final differenceVsEstimate = estimatedValue - realTotalCost;
    final materialsCount = materials.length;
    final laborEntriesCount = labor.length;
    final appointmentsCount = appointments.length;
    final members = _assignedTeamMembersLabel.trim().isEmpty
        ? '-'
        : _assignedTeamMembersLabel.trim();

    return <String, dynamic>{
      'jobCode': widget.job.jobCode,
      'jobTitle': widget.job.title,
      'clientName': widget.clientName,
      'location': widget.job.location,
      'statusLabel': widget.job.status.label,
      'generatedAt': _formatDateTime(DateTime.now().toIso8601String()),
      'estimatedValue': estimatedValue,
      'materialTotal': materialTotal,
      'laborOreTotal': laborOreTotal,
      'laborPerDiemTotal': laborPerDiemTotal,
      'laborLodgingTotal': laborLodgingTotal,
      'laborFullTotal': laborFullTotal,
      'realTotalCost': realTotalCost,
      'differenceVsEstimate': differenceVsEstimate,
      'materialsCount': materialsCount,
      'laborEntriesCount': laborEntriesCount,
      'appointmentsCount': appointmentsCount,
      'personHoursTotal': personHoursTotal,
      'teamHoursTotal': teamHoursTotal,
      'currentTeamLabel': _assignedTeam?.label ?? '-',
      'teamMembers': members,
      'appointments': appointments,
      'materials': materials,
      'labor': labor,
      'documents': documents,
      'workTaskEntries': cloneRows(_workTaskEntries),
      'checklist': Map<String, bool>.from(_checklist),
      'journal': cloneRows(_journal),
      'beneficiarySuppliedEquipment': _beneficiarySuppliedEquipment
          .map((item) => item.toMap())
          .toList(growable: false),
      'beneficiarySuppliedMaterials': _beneficiarySuppliedMaterials
          .map((item) => item.toMap())
          .toList(growable: false),
    };
  }

  void _openReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LucrareRaportCompletPage(
          data: _buildReportPayload(),
          onExportPdf: _exportCompleteReportPdf,
        ),
      ),
    );
  }

  String _formatDate(DateTime value) => lucrareFormatDate(value);

  String _formatDateTime(String raw) => lucrareFormatDateTime(raw);

  String _sanitizeDisplayText(String raw) {
    var value = raw;
    value = value
        .replaceAll('', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('•', ' | ')
        .replaceAll('–', ' - ')
        .replaceAll('—', ' - ')
        .replaceAll('→', ' -> ')
        .replaceAll(RegExp(r'[\u2000-\u200F\u2028-\u202F\u2060-\u206F]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    const transliteration = <String, String>{
      'ă': 'a',
      'Ă': 'A',
      'â': 'a',
      'Â': 'A',
      'î': 'i',
      'Î': 'I',
      'ș': 's',
      'Ș': 'S',
      'ş': 's',
      'Ş': 'S',
      'ț': 't',
      'Ț': 'T',
      'ţ': 't',
      '\u0162': 'T',
    };
    transliteration.forEach((source, target) {
      value = value.replaceAll(source, target);
    });
    return value;
  }

  String _sanitizePdfText(String raw) {
    var value = _sanitizeDisplayText(raw);
    final vatCanonical = _commercialValue('vatPercent').trim();
    if (vatCanonical.isNotEmpty) {
      value = value
          .replaceAll('TVA (19%)', 'TVA ($vatCanonical%)')
          .replaceAll('TVA (19 %)', 'TVA ($vatCanonical%)');
    }
    return value;
  }

  String _sanitizeFilePart(String value) => lucrareSanitizeFilePart(value);

  String _readCompanyField(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = '${map[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _canonicalTypeFromNumber(dynamic rawNumber) {
    final number = '${rawNumber ?? ''}'.trim().toUpperCase();
    if (number.startsWith('CT')) return 'contract';
    if (number.startsWith('DV')) return 'deviz';
    if (number.startsWith('OF')) return 'oferta';
    if (number.startsWith('PV')) return 'pv';
    if (number.startsWith('PIF')) return 'pif';
    if (number.startsWith('RAP')) return 'raport_lucrare';
    return '';
  }

  String _resolveDocumentCanonicalType(Map<String, dynamic> row) {
    final fromNumber =
        _canonicalTypeFromNumber(row['numarDocument'] ?? row['number']);
    if (fromNumber.isNotEmpty) return fromNumber;

    final candidates = <dynamic>[
      row['documentSubtype'],
      row['type'],
      row['tipDocument'],
      row['documentType'],
      row['typeLegacy'],
      row['titlu'],
      row['title'],
    ];
    for (final candidate in candidates) {
      final normalized = normalizeDocumentTypeCanonical(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return _normalizeDocumentType('${row['type'] ?? row['tipDocument'] ?? ''}');
  }

  String _resolveDocumentTypeLabel(Map<String, dynamic> row) {
    final canonical = _resolveDocumentCanonicalType(row);
    if (canonical.isNotEmpty) {
      return documentTypeLabelFromCanonical(canonical);
    }
    return _extractDocumentTypeLabel(row);
  }

  Future<Map<String, dynamic>> _loadCompanyBrandingMap() async {
    try {
      final dynamic profile = await widget.repository.loadCompanyProfile();
      if (profile is Map<String, dynamic>) return profile;
      if (profile is Map) return Map<String, dynamic>.from(profile);
      try {
        final dynamic converted = profile.toMap();
        if (converted is Map<String, dynamic>) return converted;
        if (converted is Map) return Map<String, dynamic>.from(converted);
      } catch (_) {/* intenționat ignorat: probare duck-typing .toMap() pe dynamic */}
    } catch (_) {/* intenționat ignorat: profil fără toMap valid → returnez map gol */}
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _registerDocumentForRegistry(
    Map<String, dynamic> rawRow,
  ) async {
    final row = Map<String, dynamic>.from(rawRow);
    final normalizedType = RegistryStore.normalizeDocumentType(
      row['type'] ?? row['tipDocument'],
    );
    if (normalizedType.isEmpty) {
      return row;
    }

    final existingNumber =
        '${row['numarDocument'] ?? row['number'] ?? ''}'.trim();
    final allocatedNumber = await RegistryStore.allocateNumber(
      type: normalizedType,
      existingNumber: existingNumber,
    );

    final updated = <String, dynamic>{
      ...row,
      'type': normalizedType,
      'tipDocument': _documentTypeLabelFromType(normalizedType),
      'numarDocument': allocatedNumber,
      'number': allocatedNumber,
      'registryNumber': allocatedNumber,
      'registeredAt': DateTime.now().toIso8601String(),
    };

    await _saveRegistryProjectionEntry(
      type: normalizedType,
      number: allocatedNumber,
      title: '${updated['titlu'] ?? updated['title'] ?? ''}'.trim(),
      documentDate:
          '${updated['dataDocument'] ?? updated['date'] ?? ''}'.trim(),
      status: '${updated['status'] ?? ''}'.trim(),
      referenceId: '${updated['id'] ?? ''}'.trim(),
      filePath: '${updated['pdfPath'] ?? updated['filePath'] ?? ''}'.trim(),
    );
    return updated;
  }

  Future<void> _saveRegistryProjectionEntry({
    required String type,
    required String number,
    required String title,
    required String documentDate,
    required String status,
    required String referenceId,
    required String filePath,
  }) async {
    final normalizedType = RegistryStore.normalizeDocumentType(type);
    final registeredAt = DateTime.now();
    final parsedDocumentDate = DateTime.tryParse(documentDate);
    final jobReference = '${widget.job.id}'.trim().isEmpty
        ? widget.job.jobCode
        : '${widget.job.id}'.trim();
    final stableId = referenceId.trim().isNotEmpty
        ? referenceId.trim()
        : 'job_${widget.job.jobCode}_${normalizedType}_${number.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';
    final entry = RegistryEntry(
      id: stableId,
      registryNumber: number,
      registryType: RegistryType.iesire,
      sequenceNumber: _extractRegistrySequence(number),
      year: (parsedDocumentDate ?? registeredAt).year,
      registeredAt: registeredAt,
      documentNumber: number,
      documentDate: parsedDocumentDate,
      documentTitle: title,
      documentCategory: RegistryStore.documentTypeLabelUi(normalizedType),
      issuerName: '',
      recipientName: widget.clientName,
      clientId: '',
      jobId: jobReference,
      offerId: '',
      estimateId: '',
      contractId: '',
      ticketId: '',
      filePath: filePath,
      fileName: '',
      notes: '',
      status: status,
    );
    await widget.repository.saveRegistryEntry(entry);
  }

  int _extractRegistrySequence(String number) {
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(number);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  Uint8List? _decodeLogoBytes(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildDocumentPdfBytes(Map<String, dynamic> row) async {
    final doc = pw.Document();
    final companyMap = await _loadCompanyBrandingMap();
    final companyName = _readCompanyField(companyMap, const [
      'companyName',
      'name',
      'company_name',
      'numeFirma',
    ]);
    final companyPhone = _readCompanyField(companyMap, const [
      'phone',
      'companyPhone',
      'company_phone',
      'telefon',
    ]);
    final companyEmail = _readCompanyField(companyMap, const [
      'email',
      'companyEmail',
      'company_email',
    ]);
    final companyCui = _readCompanyField(companyMap, const [
      'cui',
      'companyCui',
      'company_cui',
    ]);
    final companyReg = _readCompanyField(companyMap, const [
      'tradeRegister',
      'companyTradeRegister',
      'company_trade_register',
      'regCom',
    ]);
    final companyContact = _readCompanyField(companyMap, const [
      'contactPerson',
      'companyContactName',
      'company_contact_name',
      'persoanaContact',
      'persoana_contact',
      'contact',
    ]);
    final companyAddress = _readCompanyField(companyMap, const [
      'address',
      'companyAddress',
      'company_address',
      'adresa',
    ]);
    final companyLogoRaw = _readCompanyField(companyMap, const [
      'logoBase64',
      'companyLogoBase64',
      'company_logo_base64',
    ]);
    final companyLines = <String>[
      if (companyCui.isNotEmpty) 'CUI/CIF: $companyCui',
      if (companyReg.isNotEmpty) 'Reg. Com.: $companyReg',
      if (companyAddress.isNotEmpty) 'Adresa: $companyAddress',
      if (companyPhone.isNotEmpty) 'Telefon: $companyPhone',
      if (companyEmail.isNotEmpty) 'Email: $companyEmail',
      if (companyContact.isNotEmpty) 'Persoana contact: $companyContact',
    ];
    final logoBytes = _decodeLogoBytes(companyLogoRaw);
    final normalizedType = _resolveDocumentCanonicalType(row);
    final typeLabel = _resolveDocumentTypeLabel(row);
    final documentTitle = typeLabel;
    final number = '${row['numarDocument'] ?? row['number'] ?? '-'}';
    final date = '${row['dataDocument'] ?? row['date'] ?? '-'}';
    final title = '${row['titlu'] ?? row['title'] ?? '-'}';
    final status = '${row['status'] ?? '-'}';
    final notes = '${row['observatii'] ?? row['notes'] ?? ''}';
    final detailsA =
        '${row['obiectDescriere'] ?? row['descrierePunereInFunctiune'] ?? ''}';
    final detailsB = '${row['constatari'] ?? row['parametriRezultate'] ?? ''}';
    final subtype = normalizedType.isEmpty
        ? normalizeDocumentTypeCanonical(
            '${row['documentSubtype'] ?? row['type'] ?? row['tipDocument'] ?? ''}',
          )
        : normalizedType;

    final appointmentSourceRaw = row['programariSnapshot'];
    final materialSourceRaw = row['materialeSnapshot'];
    final laborSourceRaw = row['manoperaSnapshot'];
    final beneficiaryEquipmentSourceRaw =
        row['beneficiarySuppliedEquipmentSnapshot'];
    final beneficiaryMaterialsSourceRaw =
        row['beneficiarySuppliedMaterialsSnapshot'];
    final appointmentSource =
        appointmentSourceRaw is List ? appointmentSourceRaw : _appointments;
    final materialSource =
        materialSourceRaw is List ? materialSourceRaw : _materials;
    final laborSource = laborSourceRaw is List ? laborSourceRaw : _labor;
    final beneficiaryEquipmentSource = beneficiaryEquipmentSourceRaw is List
        ? beneficiaryEquipmentSourceRaw
        : _beneficiarySuppliedEquipment.map((entry) => entry.toMap()).toList(
              growable: false,
            );
    final beneficiaryMaterialsSource = beneficiaryMaterialsSourceRaw is List
        ? beneficiaryMaterialsSourceRaw
        : _beneficiarySuppliedMaterials.map((entry) => entry.toMap()).toList(
              growable: false,
            );

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 170,
              child: pw.Text(
                _sanitizePdfText(label),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(_sanitizePdfText(value))),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          _sanitizePdfText(title),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
      );
    }

    pw.Widget infoBlock({
      required String title,
      required List<pw.Widget> children,
    }) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            sectionTitle(title),
            ...children,
          ],
        ),
      );
    }

    String asMoney(dynamic raw, {String fallback = '-'}) {
      if (raw == null) return fallback;
      final text = '$raw'.trim();
      if (text.isEmpty || text == '-') return fallback;
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value == null) return _sanitizePdfText(text);
      return value.toStringAsFixed(2);
    }

    double asPercent(dynamic raw) {
      if (raw == null) return 0;
      final text = '$raw'.trim();
      if (text.isEmpty || text == '-') return 0;
      return _asDouble(text.replaceAll('%', '')).toDouble();
    }

    String percentLabel(double value) {
      if (value <= 0) return '-';
      final rounded = value.roundToDouble();
      if ((value - rounded).abs() < 0.0001) {
        return rounded.toStringAsFixed(0);
      }
      var out = value.toStringAsFixed(2);
      out = out.replaceAll(RegExp(r'0+$'), '');
      out = out.replaceAll(RegExp(r'\.$'), '');
      return out;
    }

    List<pw.Widget> simpleList(String title, List<String> rows) {
      return [
        pw.Text(
          _sanitizePdfText(title),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text('Nu exista date.')
        else
          ...rows.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- '),
                    pw.Expanded(
                      child: pw.Text(
                        _sanitizePdfText(e).replaceAll(' | ', '\n'),
                      ),
                    ),
                  ],
                ),
              )),
      ];
    }

    final appointmentsText = appointmentSource.map((e) {
      final dateText = '${e['date'] ?? '-'}';
      final titleText = '${e['title'] ?? '-'}';
      final locText = '${e['location'] ?? '-'}';
      return 'Data: $dateText | Titlu: $titleText | Locatie: $locText';
    }).toList(growable: false);

    final materialsText = materialSource.map((e) {
      final total = _asDouble(e['total']) > 0
          ? _asDouble(e['total'])
          : _materialLineTotal(Map<String, dynamic>.from(e as Map));
      return 'Material: ${e['name'] ?? '-'} | UM: ${e['um'] ?? '-'} | Cant: ${_asDouble(e['qty']).toStringAsFixed(2)} | Pret: ${_asDouble(e['price']).toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);

    final laborText = laborSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return 'Data: ${map['date'] ?? '-'} | Resursa: ${map['who'] ?? '-'} | Ore: ${_asDouble(map['hours']).toStringAsFixed(2)} | Tarif: ${_laborRateForRow(map).toStringAsFixed(2)} | Cost ore: ${_laborOreCost(map).toStringAsFixed(2)} | Cost diurna: ${_laborPerDiemCost(map).toStringAsFixed(2)} | Cost cazare: ${_laborLodgingCost(map).toStringAsFixed(2)} | Cost total: ${_laborTotalLineCost(map).toStringAsFixed(2)}';
    }).toList(growable: false);
    final beneficiaryEquipmentText = beneficiaryEquipmentSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final details = <String>[
        'Denumire: ${map['name'] ?? map['denumire'] ?? '-'}',
        'Tip: ${map['equipment_type'] ?? map['equipmentType'] ?? map['type'] ?? '-'}',
        'Brand: ${map['brand'] ?? '-'}',
        'Model: ${map['model'] ?? '-'}',
        'Serie: ${map['serial_number'] ?? map['serialNumber'] ?? map['serie'] ?? '-'}',
        'Cantitate: ${_asDouble(map['quantity'] ?? map['cantitate']).toStringAsFixed(2)}',
      ];
      final notes = '${map['notes'] ?? map['observatii'] ?? ''}'.trim();
      if (notes.isNotEmpty) {
        details.add('Observatii: $notes');
      }
      return details.join(' | ');
    }).toList(growable: false);
    final beneficiaryMaterialsText = beneficiaryMaterialsSource.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final details = <String>[
        'Denumire: ${map['name'] ?? map['denumire'] ?? '-'}',
        'UM: ${map['unit'] ?? map['um'] ?? '-'}',
        'Cantitate: ${_asDouble(map['quantity'] ?? map['cantitate']).toStringAsFixed(2)}',
      ];
      final notes = '${map['notes'] ?? map['observatii'] ?? ''}'.trim();
      if (notes.isNotEmpty) {
        details.add('Observatii: $notes');
      }
      return details.join(' | ');
    }).toList(growable: false);

    final materialTotal = _asDouble(row['materialTotal']) > 0
        ? _asDouble(row['materialTotal'])
        : materialSource.fold<double>(
            0,
            (sum, e) =>
                sum +
                (_asDouble(e['total']) > 0
                    ? _asDouble(e['total'])
                    : _materialLineTotal(Map<String, dynamic>.from(e as Map))),
          );
    final laborTotal = _asDouble(row['laborTotal']) > 0
        ? _asDouble(row['laborTotal'])
        : laborSource.fold<double>(
            0,
            (sum, e) =>
                sum + _laborTotalLineCost(Map<String, dynamic>.from(e as Map)),
          );
    final subtotal = _asDouble(row['subtotal']) > 0
        ? _asDouble(row['subtotal'])
        : materialTotal + laborTotal;
    final vatPercentFromRow = _asDouble(row['vatPercent']).toDouble();
    final vatPercentFromDoc = asPercent(
      _readDocField(row, const ['vatPercent', 'tvaContract']),
    );
    final vatPercentFromGlobal =
        asPercent(_commercialValue('vatPercent')).toDouble();
    final double vatPercent = vatPercentFromDoc > 0
        ? vatPercentFromDoc
        : (vatPercentFromRow > 0
            ? vatPercentFromRow
            : (vatPercentFromGlobal > 0 ? vatPercentFromGlobal : 0));
    final vatTotal = _asDouble(row['vatTotal']) > 0
        ? _asDouble(row['vatTotal'])
        : subtotal * vatPercent / 100;
    final grandTotal = _asDouble(row['grandTotal']) > 0
        ? _asDouble(row['grandTotal'])
        : (_asDouble(row['total']) > 0
            ? _asDouble(row['total'])
            : subtotal + vatTotal);
    final vatCanonical = percentLabel(vatPercent);

    String fixLegacyVatLabel(String input) {
      if (input.trim().isEmpty) return input;
      return input
          .replaceAll('TVA (19%)', 'TVA ($vatCanonical%)')
          .replaceAll('TVA (19 %)', 'TVA ($vatCanonical%)');
    }

    final contractParties = '${row['partiContractante'] ?? ''}'.trim();
    final contractObject =
        '${row['obiectContract'] ?? row['obiectDescriere'] ?? ''}'.trim();
    final contractReferences = '${row['documenteReferinte'] ?? ''}'.trim();
    final contractDuration = '${row['durataExecutie'] ?? ''}'.trim();
    final contractExecutionTerm = '${row['termenExecutie'] ?? ''}'.trim();
    final contractPrice = '${row['grandTotal'] ?? row['total'] ?? ''}'.trim();
    final contractAdvance = '${row['avans'] ?? ''}'.trim();
    final contractInstallments = '${row['transePlata'] ?? ''}'.trim();
    final contractVat =
        '${row['tvaContract'] ?? row['vatPercent'] ?? ''}'.trim();
    final contractPayment = '${row['conditiiPlata'] ?? ''}'.trim();
    final contractorObligations = '${row['obligatiiParti'] ?? ''}'.trim();
    final beneficiaryObligations = '${row['obligatiiBeneficiar'] ?? ''}'.trim();
    final logistics = '${row['materialeLogistica'] ?? ''}'.trim();
    final reception = '${row['receptie'] ?? ''}'.trim();
    final penalties = '${row['penalitati'] ?? ''}'.trim();
    final forceMajeure = '${row['fortaMajora'] ?? ''}'.trim();
    final termination = '${row['incetareContract'] ?? ''}'.trim();
    final disputes = '${row['litigii'] ?? ''}'.trim();
    final finalClauses = '${row['dispozitiiFinale'] ?? ''}'.trim();
    final signatures = '${row['semnaturi'] ?? ''}'.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _sanitizePdfText(
                            companyName.isEmpty ? 'Firma' : companyName),
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      if (companyLines.isNotEmpty)
                        ...companyLines.map(
                          (item) => pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              _sanitizePdfText(item),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (logoBytes != null)
                  pw.Container(
                    width: 64,
                    height: 64,
                    margin: const pw.EdgeInsets.only(left: 10),
                    child: pw.Image(pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain),
                  ),
              ],
            ),
          ),
          pw.Container(height: 1, color: PdfColors.grey500),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              _sanitizePdfText(documentTitle),
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Column(
              children: [
                line('Numar document', number),
                line('Data document', date),
                line('Status document', status),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          infoBlock(
            title: 'Date lucrare',
            children: [
              line('Titlu document', title),
              line('Cod lucrare', widget.job.jobCode),
              line('Titlu lucrare', widget.job.title),
              line('Client', widget.clientName),
              line('Locatie', widget.job.location),
              line(
                'Status lucrare',
                '${widget.job.status.label}'
                    .replaceAll('\uFFFD', ''),
              ),
            ],
          ),
          infoBlock(
            title: 'Echipa alocata',
            children: [
              line('Echipa', _assignedTeam?.label ?? '-'),
              line(
                'Membri',
                _assignedTeamMembersLabel.isEmpty
                    ? '-'
                    : _assignedTeamMembersLabel,
              ),
            ],
          ),
          line(
            'Status lucrare',
            '${widget.job.status.label}'
                .replaceAll('\uFFFD', '')
                .replaceAll('', ''),
          ),
          pw.SizedBox(height: 2),
          if (subtype == 'oferta') ...[
            sectionTitle('Structura comerciala'),
            ...simpleList('Lista comerciala / sintetica', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera (sinteza)', laborText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Totaluri oferta',
              children: [
                line('Subtotal', subtotal.toStringAsFixed(2)),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA ($vatCanonical%)',
                  vatTotal.toStringAsFixed(2),
                ),
                line('Total', grandTotal.toStringAsFixed(2)),
              ],
            ),
            infoBlock(
              title: 'Conditii comerciale',
              children: [
                line(
                  'Termen executie',
                  _commercialValue('executionTerm').isEmpty
                      ? '-'
                      : _commercialValue('executionTerm'),
                ),
                line(
                  'Termen plata',
                  _commercialValue('paymentTerm').isEmpty
                      ? '-'
                      : _commercialValue('paymentTerm'),
                ),
                line(
                  'Valabilitate oferta',
                  _readDocField(row, const [
                    'valabilitateOferta',
                    'offerValidity'
                  ]).trim().isEmpty
                      ? (_commercialValue('offerValidity').isEmpty
                          ? '-'
                          : _commercialValue('offerValidity'))
                      : _readDocField(row,
                          const ['valabilitateOferta', 'offerValidity']).trim(),
                ),
                line('Observatii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else if (subtype == 'deviz') ...[
            sectionTitle('Structura tehnica'),
            ...simpleList('Materiale', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera', laborText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Totaluri deviz',
              children: [
                line('Total materiale', materialTotal.toStringAsFixed(2)),
                line('Total manopera', laborTotal.toStringAsFixed(2)),
                line('Subtotal', subtotal.toStringAsFixed(2)),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA ($vatCanonical%)',
                  vatTotal.toStringAsFixed(2),
                ),
                line('Total general', grandTotal.toStringAsFixed(2)),
              ],
            ),
            infoBlock(
              title: 'Observatii tehnice / comerciale',
              children: [
                line('Detalii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else if (subtype == 'contract') ...[
            infoBlock(
              title: 'Cadru contractual',
              children: [
                line('Parti contractante',
                    contractParties.isEmpty ? '-' : contractParties),
                line('Obiectul contractului',
                    contractObject.isEmpty ? '-' : contractObject),
                line(
                  'Documente si referinte ale lucrarii',
                  contractReferences.isEmpty ? '-' : contractReferences,
                ),
                line(
                  'Durata / termen executie',
                  contractDuration.isEmpty
                      ? (contractExecutionTerm.isEmpty
                          ? '-'
                          : contractExecutionTerm)
                      : contractDuration,
                ),
              ],
            ),
            infoBlock(
              title: 'Conditii comerciale',
              children: [
                line(
                  'Pretul contractului',
                  contractPrice.isEmpty
                      ? grandTotal.toStringAsFixed(2)
                      : asMoney(contractPrice,
                          fallback: grandTotal.toStringAsFixed(2)),
                ),
                line('Conditii de plata',
                    contractPayment.isEmpty ? '-' : contractPayment),
                line('Avans',
                    contractAdvance.isEmpty ? '-' : asMoney(contractAdvance)),
                line('Transe de plata',
                    contractInstallments.isEmpty ? '-' : contractInstallments),
                line(
                  vatCanonical == '-' ? 'TVA' : 'TVA (%)',
                  contractVat.isEmpty
                      ? vatCanonical
                      : percentLabel(asPercent(contractVat)),
                ),
                line('Penalitati', penalties.isEmpty ? '-' : penalties),
              ],
            ),
            infoBlock(
              title: 'Obligatii si executie',
              children: [
                line(
                  'Obligatiile executantului',
                  contractorObligations.isEmpty ? '-' : contractorObligations,
                ),
                line(
                  'Obligatiile beneficiarului / antreprenorului',
                  beneficiaryObligations.isEmpty ? '-' : beneficiaryObligations,
                ),
                line(
                  'Materiale / utilaje / logistica',
                  logistics.isEmpty ? '-' : logistics,
                ),
                line(
                    'Receptie / PV / PIF', reception.isEmpty ? '-' : reception),
                line('Forta majora', forceMajeure.isEmpty ? '-' : forceMajeure),
                line(
                  'Incetarea contractului',
                  termination.isEmpty ? '-' : termination,
                ),
                line('Litigii', disputes.isEmpty ? '-' : disputes),
                line(
                  'Dispozitii finale',
                  finalClauses.isEmpty ? '-' : finalClauses,
                ),
              ],
            ),
            ...simpleList('Referinta operativa', appointmentsText),
            pw.SizedBox(height: 8),
            infoBlock(
              title: 'Observatii',
              children: [
                line('Detalii', notes.isEmpty ? '-' : notes),
              ],
            ),
          ] else ...[
            ...simpleList('Programari asociate', appointmentsText),
            pw.SizedBox(height: 8),
            ...simpleList('Materiale asociate', materialsText),
            pw.SizedBox(height: 8),
            ...simpleList('Manopera / ore', laborText),
            pw.SizedBox(height: 8),
          ],
          if (beneficiaryEquipmentText.isNotEmpty) ...[
            ...simpleList(
              'Echipamente furnizate de beneficiar',
              beneficiaryEquipmentText,
            ),
            pw.SizedBox(height: 8),
          ],
          if (beneficiaryMaterialsText.isNotEmpty) ...[
            ...simpleList(
              'Materiale furnizate de beneficiar',
              beneficiaryMaterialsText,
            ),
            pw.SizedBox(height: 8),
          ],
          if (subtype == 'pv') ...[
            line('Obiect / descriere', detailsA.isEmpty ? '-' : detailsA),
            line('Constatari', detailsB.isEmpty ? '-' : detailsB),
          ] else if (subtype == 'pif') ...[
            line('Descriere punere in functiune',
                detailsA.isEmpty ? '-' : detailsA),
            line('Parametri / rezultate', detailsB.isEmpty ? '-' : detailsB),
          ],
          if (subtype == 'pv' || subtype == 'pif')
            line('Observatii', notes.isEmpty ? '-' : notes),
          pw.SizedBox(height: 12),
          infoBlock(
            title: 'Semnaturi',
            children: [
              if (subtype == 'contract' && signatures.isNotEmpty)
                pw.Text(_sanitizePdfText(signatures))
              else
                pw.Row(
                  children: [
                    pw.Expanded(
                        child: pw.Text('Responsabil: ____________________')),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                        child: pw.Text('Beneficiar: ____________________')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  List<Map<String, dynamic>> _payloadRows(
    Map<String, dynamic> payload,
    String key,
  ) {
    final raw = payload[key];
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Uint8List> _buildCompleteReportPdfBytes(
    Map<String, dynamic> payload,
  ) async {
    final doc = pw.Document();
    final companyMap = await _loadCompanyBrandingMap();
    final companyName = _readCompanyField(companyMap, const [
      'companyName',
      'name',
      'company_name',
      'numeFirma',
    ]);
    final companyPhone = _readCompanyField(companyMap, const [
      'phone',
      'companyPhone',
      'company_phone',
      'telefon',
    ]);
    final companyEmail = _readCompanyField(companyMap, const [
      'email',
      'companyEmail',
      'company_email',
    ]);
    final companyCui = _readCompanyField(companyMap, const [
      'cui',
      'companyCui',
      'company_cui',
    ]);
    final companyReg = _readCompanyField(companyMap, const [
      'tradeRegister',
      'companyTradeRegister',
      'company_trade_register',
      'regCom',
    ]);
    final companyAddress = _readCompanyField(companyMap, const [
      'address',
      'companyAddress',
      'company_address',
      'adresa',
    ]);
    final companyLogoRaw = _readCompanyField(companyMap, const [
      'logoBase64',
      'companyLogoBase64',
      'company_logo_base64',
    ]);
    final logoBytes = _decodeLogoBytes(companyLogoRaw);
    final companyLines = <String>[
      if (companyCui.isNotEmpty) 'CUI/CIF: $companyCui',
      if (companyReg.isNotEmpty) 'Reg. Com.: $companyReg',
      if (companyAddress.isNotEmpty) 'Adresa: $companyAddress',
      if (companyPhone.isNotEmpty) 'Telefon: $companyPhone',
      if (companyEmail.isNotEmpty) 'Email: $companyEmail',
    ];

    final jobCode = '${payload['jobCode'] ?? ''}'.trim();
    final jobTitle = '${payload['jobTitle'] ?? ''}'.trim();
    final clientName = '${payload['clientName'] ?? ''}'.trim();
    final location = '${payload['location'] ?? ''}'.trim();
    final statusLabel = '${payload['statusLabel'] ?? ''}'.trim();
    final generatedAt = '${payload['generatedAt'] ?? ''}'.trim();

    final estimatedValue = _asDouble(payload['estimatedValue']);
    final materialTotal = _asDouble(payload['materialTotal']);
    final laborFullTotal = _asDouble(payload['laborFullTotal']);
    final laborPerDiemTotal = _asDouble(payload['laborPerDiemTotal']);
    final laborLodgingTotal = _asDouble(payload['laborLodgingTotal']);
    final realTotalCost = _asDouble(payload['realTotalCost']);
    final differenceVsEstimate = _asDouble(payload['differenceVsEstimate']);
    final materialsCount = _asDouble(payload['materialsCount']).toInt();
    final laborEntriesCount = _asDouble(payload['laborEntriesCount']).toInt();
    final appointmentsCount = _asDouble(payload['appointmentsCount']).toInt();
    final personHoursTotal = _asDouble(payload['personHoursTotal']);
    final teamHoursTotal = _asDouble(payload['teamHoursTotal']);
    final currentTeamLabel = '${payload['currentTeamLabel'] ?? '-'}'.trim();

    final appointments = _payloadRows(payload, 'appointments');
    final materials = _payloadRows(payload, 'materials');
    final labor = _payloadRows(payload, 'labor');
    final documents = _payloadRows(payload, 'documents');
    final beneficiaryEquipment =
        _payloadRows(payload, 'beneficiarySuppliedEquipment');
    final beneficiaryMaterials =
        _payloadRows(payload, 'beneficiarySuppliedMaterials');

    final documentCounts = <String, int>{
      'oferta': 0,
      'deviz': 0,
      'contract': 0,
      'pv': 0,
      'pif': 0,
    };
    for (final row in documents) {
      final type = normalizeDocumentTypeCanonical(
        '${row['type'] ?? row['tipDocument'] ?? row['documentSubtype'] ?? row['documentType'] ?? row['typeLegacy'] ?? ''}',
      );
      if (documentCounts.containsKey(type)) {
        documentCounts[type] = (documentCounts[type] ?? 0) + 1;
      }
    }

    pw.Widget line(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 190,
              child: pw.Text(
                _sanitizePdfText(label),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(_sanitizePdfText(value))),
          ],
        ),
      );
    }

    List<pw.Widget> simpleList(String title, List<String> rows) {
      return [
        pw.Text(
          _sanitizePdfText(title),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (rows.isEmpty)
          pw.Text('Nu exista date.')
        else
          ...rows.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(_sanitizePdfText(e)),
            ),
          ),
      ];
    }

    String yesNo(int count) => count > 0 ? 'Exista ($count)' : 'Lipseste';

    final appointmentsText = appointments.map((row) {
      final date = '${row['date'] ?? row['data'] ?? '-'}';
      final title = '${row['title'] ?? row['titlu'] ?? '-'}';
      final loc = '${row['location'] ?? row['locatie'] ?? '-'}';
      final status = '${row['status'] ?? '-'}';
      return 'Data: $date | Titlu: $title | Locatie: $loc | Status: $status';
    }).toList(growable: false);

    final materialsText = materials.map((row) {
      final qty = _asDouble(row['qty']);
      final price = _asDouble(row['price']);
      final total = _asDouble(row['total']) > 0
          ? _asDouble(row['total'])
          : _materialLineTotal(row);
      return 'Material: ${row['name'] ?? row['denumire'] ?? '-'} | UM: ${row['um'] ?? '-'} | Cant: ${qty.toStringAsFixed(2)} | Pret: ${price.toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);

    final laborText = labor.map((row) {
      final hours = _asDouble(row['hours']) > 0
          ? _asDouble(row['hours'])
          : _asDouble(row['ore']);
      final rate = _asDouble(row['hourlyRate']);
      final oreCost = _asDouble(row['costOre']) > 0
          ? _asDouble(row['costOre'])
          : _asDouble(row['cost_ore']);
      final diurna = _asDouble(row['costDiurna']) > 0
          ? _asDouble(row['costDiurna'])
          : _asDouble(row['cost_diurna']);
      final cazare = _asDouble(row['costCazare']) > 0
          ? _asDouble(row['costCazare'])
          : _asDouble(row['cost_cazare']);
      final total = _asDouble(row['costTotalLinie']) > 0
          ? _asDouble(row['costTotalLinie'])
          : (_asDouble(row['cost_total_linie']) > 0
              ? _asDouble(row['cost_total_linie'])
              : (oreCost + diurna + cazare));
      return 'Resursa: ${row['whoLabel'] ?? row['who'] ?? row['label'] ?? '-'} | Data: ${row['date'] ?? row['data'] ?? '-'} | Ore: ${hours.toStringAsFixed(2)} | Tarif: ${rate.toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}';
    }).toList(growable: false);
    final beneficiaryEquipmentText = beneficiaryEquipment.map((row) {
      final type =
          '${row['equipment_type'] ?? row['equipmentType'] ?? row['type'] ?? '-'}';
      final brand = '${row['brand'] ?? '-'}';
      final model = '${row['model'] ?? '-'}';
      final serial =
          '${row['serial_number'] ?? row['serialNumber'] ?? row['serie'] ?? '-'}';
      final qty =
          _asDouble(row['quantity'] ?? row['cantitate']).toStringAsFixed(2);
      final notes = '${row['notes'] ?? row['observatii'] ?? ''}'.trim();
      return 'Denumire: ${row['name'] ?? row['denumire'] ?? '-'} | Tip: $type | Brand: $brand | Model: $model | Serie: $serial | Cantitate: $qty${notes.isEmpty ? '' : ' | Observatii: $notes'}';
    }).toList(growable: false);
    final beneficiaryMaterialsText = beneficiaryMaterials.map((row) {
      final qty =
          _asDouble(row['quantity'] ?? row['cantitate']).toStringAsFixed(2);
      final notes = '${row['notes'] ?? row['observatii'] ?? ''}'.trim();
      return 'Denumire: ${row['name'] ?? row['denumire'] ?? '-'} | UM: ${row['unit'] ?? row['um'] ?? '-'} | Cantitate: $qty${notes.isEmpty ? '' : ' | Observatii: $notes'}';
    }).toList(growable: false);

    final lastDocuments = [...documents]..sort(
        (a, b) => '${b['updatedAt'] ?? b['createdAt'] ?? ''}'
            .compareTo('${a['updatedAt'] ?? a['createdAt'] ?? ''}'),
      );
    final docsText = lastDocuments.take(8).map((row) {
      final type = _resolveDocumentTypeLabel(row);
      final number = '${row['numarDocument'] ?? row['number'] ?? '-'}';
      final status = '${row['status'] ?? '-'}';
      final date = '${row['dataDocument'] ?? row['date'] ?? '-'}';
      return '$type - $number | Status: $status | Data: $date';
    }).toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _sanitizePdfText(
                          companyName.isEmpty ? 'Firma' : companyName),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    if (companyLines.isNotEmpty)
                      ...companyLines.map(
                        (item) => pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            _sanitizePdfText(item),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (logoBytes != null)
                pw.Container(
                  width: 64,
                  height: 64,
                  margin: const pw.EdgeInsets.only(left: 10),
                  child: pw.Image(pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.contain),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: PdfColors.grey500),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Raport complet lucrare',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          ...simpleList('Header lucrare', [
            'Cod lucrare: $jobCode',
            'Titlu lucrare: $jobTitle',
            'Client: $clientName',
            'Locatie: $location',
            'Status lucrare: $statusLabel',
            'Generat la: $generatedAt',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Indicatori economici si operativi', [
            'Valoare estimata: ${estimatedValue.toStringAsFixed(2)}',
            'Cost real total: ${realTotalCost.toStringAsFixed(2)}',
            'Diferenta estimat vs real: ${differenceVsEstimate.toStringAsFixed(2)}',
            'Total materiale: ${materialTotal.toStringAsFixed(2)}',
            'Total manopera: ${laborFullTotal.toStringAsFixed(2)}',
            'Total diurna: ${laborPerDiemTotal.toStringAsFixed(2)}',
            'Total cazare: ${laborLodgingTotal.toStringAsFixed(2)}',
            'Numar materiale: $materialsCount',
            'Numar inregistrari ore: $laborEntriesCount',
            'Numar programari: $appointmentsCount',
            'Ore persoane: ${personHoursTotal.toStringAsFixed(2)}',
            'Ore echipe: ${teamHoursTotal.toStringAsFixed(2)}',
            'Echipa alocata: $currentTeamLabel',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Situatie documente', [
            'Oferta: ${yesNo(documentCounts['oferta'] ?? 0)}',
            'Deviz: ${yesNo(documentCounts['deviz'] ?? 0)}',
            'Contract: ${yesNo(documentCounts['contract'] ?? 0)}',
            'PV: ${yesNo(documentCounts['pv'] ?? 0)}',
            'PIF: ${yesNo(documentCounts['pif'] ?? 0)}',
          ]),
          pw.SizedBox(height: 10),
          ...simpleList('Programari asociate', appointmentsText),
          pw.SizedBox(height: 10),
          ...simpleList('Materiale asociate', materialsText),
          pw.SizedBox(height: 10),
          ...simpleList(
            'Echipamente furnizate de beneficiar',
            beneficiaryEquipmentText,
          ),
          pw.SizedBox(height: 10),
          ...simpleList(
            'Materiale furnizate de beneficiar',
            beneficiaryMaterialsText,
          ),
          pw.SizedBox(height: 10),
          ...simpleList('Manopera / ore', laborText),
          pw.SizedBox(height: 10),
          ...simpleList('Ultimele documente utile', docsText),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportCompleteReportPdf(
    Map<String, dynamic> payload, {
    bool saveAs = false,
  }) async {
    try {
      final bytes = await _buildCompleteReportPdfBytes(payload);
      final jobCode = '${payload['jobCode'] ?? widget.job.jobCode}'.trim();
      final fileName =
          'RAPORT_${_sanitizeFilePart(jobCode.isEmpty ? 'JOB' : jobCode)}.pdf';
      final filePath = await PdfSaveService.savePdf(
        repository: widget.repository,
        bytes: bytes,
        fileName: fileName,
        category: PdfDocumentCategory.jobs,
        forceSaveAs: saveAs,
      );
      final reportDate = _formatDate(DateTime.now());
      final reportType = 'raport_lucrare';
      final reportNumber =
          'RAP-${_sanitizeFilePart(jobCode.isEmpty ? 'JOB' : jobCode)}';
      final statusLabel =
          '${payload['statusLabel'] ?? widget.job.status.label}'.trim();
      await _saveRegistryProjectionEntry(
        type: reportType,
        number: reportNumber,
        title: 'Raport lucrare - ${jobCode.isEmpty ? 'JOB' : jobCode}',
        documentDate: reportDate,
        status: statusLabel.isEmpty ? 'Final' : statusLabel,
        referenceId: 'report-${widget.job.jobCode}',
        filePath: filePath,
      );
      if (!mounted) return;
      setState(() {
        _latestReportRegistryRow = <String, dynamic>{
          'type': reportType,
          'source': 'raport_lucrare',
          'number': reportNumber,
          'title': 'Raport lucrare - ${jobCode.isEmpty ? 'JOB' : jobCode}',
          'date': reportDate,
          'status': statusLabel.isEmpty ? 'Final' : statusLabel,
          'client': widget.clientName,
          'jobCode': widget.job.jobCode,
          'jobId': '${widget.job.id}'.trim().isEmpty
              ? widget.job.jobCode
              : '${widget.job.id}',
          'filePath': filePath,
        };
      });
      await _showPostExportActions(
        filePath: filePath,
        successMessage: 'Raport complet exportat PDF.',
      );
      await _appendJournal(
        action: 'report_pdf_exported',
        message: 'Raport complet exportat: $fileName',
      );
    } on PdfSaveCanceledException {
      _snack('Salvarea documentului a fost anulata.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Situație de lucrări
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onGenerateSituatieLucrari() async {
    final job = widget.job;

    // Controlere pentru dialog
    final numberCtrl = TextEditingController(
      text: 'SL-${job.jobCode.isEmpty ? '001' : job.jobCode}',
    );
    final contractNumberCtrl = TextEditingController();
    final contractDateCtrl = TextEditingController();
    final periodStartCtrl = TextEditingController(
      text: job.startDate != null
          ? '${job.startDate!.day.toString().padLeft(2, '0')}.${job.startDate!.month.toString().padLeft(2, '0')}.${job.startDate!.year}'
          : '',
    );
    final periodEndCtrl = TextEditingController(
      text: job.dueDate != null
          ? '${job.dueDate!.day.toString().padLeft(2, '0')}.${job.dueDate!.month.toString().padLeft(2, '0')}.${job.dueDate!.year}'
          : '',
    );
    final vatCtrl = TextEditingController(
      text: _defaultVatPercent.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController(
      text: job.notes.trim(),
    );

    // Sursa EXCLUSIVĂ = liniiPlanificate (copiate din ofertă via import/conversie).
    // _materials/_labor din tab Economic = urmărire internă, NU apar în Situația de Lucrări.
    final hasPlanificate = _jobSnapshot.liniiPlanificate.isNotEmpty;
    final planMateriale = _jobSnapshot.liniiPlanificate
        .where((l) => l.categorie == 'material').toList();
    final planManopera = _jobSnapshot.liniiPlanificate
        .where((l) => l.categorie == 'manopera').toList();
    final matCount = planMateriale.length;
    final laborCount = planManopera.length;

    bool includeMaterials = planMateriale.isNotEmpty;
    bool includeLabor = planManopera.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Generează Situație de Lucrări'),
          scrollable: true,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lucrare: ${job.jobCode} – ${job.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Client: ${widget.clientName}'),
                if (hasPlanificate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Date preluate din oferta ${_jobSnapshot.sourceOfferNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            size: 15, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Nu există linii din ofertă importate. Accesează tab-ul Situație → "Importă linii din ofertă" înainte de generare.',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: numberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Număr document',
                    hintText: 'ex: SL-001',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: contractNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nr. contract (opțional)',
                    hintText: 'ex: CTR-2025/001',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: contractDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dată contract (opțional)',
                    hintText: 'ex: 01.01.2025',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: periodStartCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Început execuție',
                          hintText: 'dd.mm.yyyy',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        textCapitalization: TextCapitalization.sentences,
                        controller: periodEndCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sfârșit execuție',
                          hintText: 'dd.mm.yyyy',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: vatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'TVA (%)',
                    hintText: '19',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observații (opțional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Include în document:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Materiale ($matCount înregistrări'
                      '${hasPlanificate ? " · din ofertă" : ""})'),
                  value: includeMaterials,
                  onChanged: matCount == 0
                      ? null
                      : (v) => setDlg(() => includeMaterials = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Manoperă ($laborCount înregistrări'
                      '${hasPlanificate ? " · din ofertă" : ""})'),
                  value: includeLabor,
                  onChanged: laborCount == 0
                      ? null
                      : (v) => setDlg(() => includeLabor = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Anulează'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generează PDF'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final company = await widget.repository.loadCompanyProfile();
      final branding = DocumentBrandingData.fromCompanyProfile(company);
      final template = company.pdfExportSettings.visualTemplate;

      final vat = double.tryParse(vatCtrl.text.replaceAll(',', '.')) ??
          _defaultVatPercent;

      final materialsForPdf = includeMaterials
          ? planMateriale.map((l) => <String, dynamic>{
                'name': l.denumire,
                'um': l.um,
                'qty': l.cantitateReala,
                'price': l.pretUnitarReal,
                'total': l.totalReal,
                'observatii': l.observatii,
              }).toList(growable: false)
          : <Map<String, dynamic>>[];

      final laborForPdf = includeLabor
          ? planManopera.map((l) => <String, dynamic>{
                'who': l.denumire,
                'um': l.um,
                'hours': l.cantitateReala,
                'rate': l.pretUnitarReal,
                'total': l.totalReal,
                'observatii': l.observatii,
              }).toList(growable: false)
          : <Map<String, dynamic>>[];

      final params = SituatieLucrariParams(
        number:
            numberCtrl.text.trim().isEmpty ? 'SL-001' : numberCtrl.text.trim(),
        documentDate: DateTime.now(),
        jobCode: widget.job.jobCode,
        jobTitle: widget.job.title,
        clientName: widget.clientName,
        contractNumber: contractNumberCtrl.text.trim(),
        contractDate: contractDateCtrl.text.trim(),
        periodStart: periodStartCtrl.text.trim(),
        periodEnd: periodEndCtrl.text.trim(),
        location: widget.job.location.trim(),
        materials: materialsForPdf,
        laborEntries: laborForPdf,
        vatPercent: vat,
        notes: notesCtrl.text.trim(),
        branding: branding,
        template: template,
        regiePercent: widget.job.regiePercent,
        profitPercent: widget.job.profitPercent,
      );

      final bytes = await SituatieLucrariPdfService.buildPdfBytes(params);

      final docNumber = _sanitizeFilePart(
          numberCtrl.text.trim().isEmpty ? 'SL' : numberCtrl.text.trim());
      final jobPart = _sanitizeFilePart(
          widget.job.jobCode.isEmpty ? 'JOB' : widget.job.jobCode);
      final fileName = 'SITUATIE_${docNumber}_${jobPart}.pdf';

      final filePath = await PdfSaveService.savePdf(
        repository: widget.repository,
        bytes: bytes,
        fileName: fileName,
        category: PdfDocumentCategory.jobs,
      );

      final reportDate = _formatDate(DateTime.now());
      await _saveRegistryProjectionEntry(
        type: 'situatie_lucrari',
        number: numberCtrl.text.trim(),
        title: 'Situație lucrări - ${widget.job.jobCode}',
        documentDate: reportDate,
        status: 'Final',
        referenceId: 'sl-${widget.job.jobCode}',
        filePath: filePath,
      );

      if (!mounted) return;

      await _showPostExportActions(
        filePath: filePath,
        successMessage: 'Situație de lucrări generată și salvată.',
      );
      await _appendJournal(
        action: 'situatie_lucrari_exported',
        message: 'Situație de lucrări exportată: $fileName',
      );
    } on PdfSaveCanceledException {
      _snack('Salvarea documentului a fost anulată.');
    } catch (e) {
      if (!mounted) return;
      _snack('Eroare la generarea situației de lucrări: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onExportDocumentPdf(int index, {bool saveAs = false}) async {
    if (index < 0 || index >= _documents.length) return;
    try {
      final row = _documents[index];
      final bytes = await _buildDocumentPdfBytes(row);
      final type =
          _resolveDocumentCanonicalType(Map<String, dynamic>.from(row));
      final prefix = _prefixForType(type);
      final number = '${row['numarDocument'] ?? row['number'] ?? ''}'.trim();
      final numberPart =
          _sanitizeFilePart(number.isEmpty ? '$prefix-0000' : number);
      final jobPart = _sanitizeFilePart(
          widget.job.jobCode.isEmpty ? 'JOB' : widget.job.jobCode);
      final fileName = '${numberPart}_${jobPart}.pdf';
      final filePath = await PdfSaveService.savePdf(
        repository: widget.repository,
        bytes: bytes,
        fileName: fileName,
        category: PdfDocumentCategory.jobs,
        forceSaveAs: saveAs,
      );

      final next = [..._documents];
      next[index] = {
        ...row,
        'filePath': filePath,
        'pdfPath': filePath,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      next[index] = await _registerDocumentForRegistry(next[index]);
      await _persistOperationalJobDetails(documents: next);
      if (!mounted) return;
      setState(() => _documents = next);
      await _appendJournal(
        action: 'document_pdf_exported',
        message:
            'PDF exportat: ${next[index]['tipDocument'] ?? next[index]['type'] ?? '-'} ${next[index]['numarDocument'] ?? next[index]['number'] ?? ''}',
      );
      await _showPostExportActions(
        filePath: filePath,
        successMessage: 'PDF document exportat.',
      );
    } on PdfSaveCanceledException {
      _snack('Salvarea documentului a fost anulata.');
    }
  }

  Future<void> _openFolderForFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      _snack('Fisierul documentului nu a fost gasit.');
      return;
    }
    if (!DocumentFileService.supportsFolderOpen) {
      _snack(
        'Pe mobil poti folosi Deschide sau Share pentru documentul generat.',
      );
      return;
    }
    final folderPath = file.parent.path;
    final directory = Directory(folderPath);
    if (!directory.existsSync()) {
      _snack('Folderul documentului nu a fost gasit.');
      return;
    }
    try {
      final opened = await DocumentFileService.openFolderForFile(filePath);
      if (!opened) {
        _snack('Nu am putut deschide folderul documentului.');
        return;
      }
      _snack('Folder deschis.');
    } catch (_) {
      _snack('Nu am putut deschide folderul.');
    }
  }

  Future<void> _shareFilePath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      _snack('Fisierul documentului nu a fost gasit.');
      return;
    }
    try {
      await DocumentFileService.shareFile(
        filePath,
        subject: file.uri.pathSegments.isEmpty
            ? 'Document generat'
            : file.uri.pathSegments.last,
        text: 'Document generat din aplicatie.',
      );
      _snack('Share deschis.');
    } catch (_) {
      _snack('Nu am putut trimite documentul catre share.');
    }
  }

  Future<void> _showPostExportActions({
    required String filePath,
    required String successMessage,
  }) async {
    if (!mounted) return;
    _snack(successMessage);
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
                  'Export PDF finalizat',
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
                        await _openFilePath(filePath);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareFilePath(filePath);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _sendDocumentDirectEmail(filePath);
                      },
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Trimite direct email'),
                    ),
                    if (!DocumentFileService.isMobilePlatform)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _openFolderForFile(filePath);
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: filePath));
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

  Future<void> _sendDocumentDirectEmail(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      _snack('Fisierul PDF nu a fost gasit pentru trimitere.');
      return;
    }

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'document.pdf';
    final defaultSubject =
        'Document ${widget.job.jobCode.trim().isEmpty ? 'lucrare' : widget.job.jobCode.trim()}';
    final defaultBody =
        'Buna ziua,\n\nAtasat gasiti documentul solicitat.\n\nCu stima,';

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => SendDocumentDialog(
        to: '',
        subject: defaultSubject,
        body: defaultBody,
      ),
    );
    if (result == null || !mounted) return;

    final action = (result['action'] ?? 'cancel').trim();
    if (action == 'cancel') return;
    if (action == 'mailto') {
      await DocumentFileService.shareFile(
        filePath,
        subject: result['subject'] ?? defaultSubject,
        text: result['body'] ?? defaultBody,
      );
      _snack('Share deschis pentru trimitere din clientul local.');
      return;
    }

    try {
      final recipientEmail = (result['to'] ?? '').trim();
      if (recipientEmail.isEmpty) {
        _snack('Completeaza adresa de email a destinatarului.');
        return;
      }
      final subject = (result['subject'] ?? '').trim().isEmpty
          ? defaultSubject
          : (result['subject'] ?? '').trim();
      final body = (result['body'] ?? '').trim().isEmpty
          ? defaultBody
          : (result['body'] ?? '').trim();

      final company = await widget.repository.loadCompanyProfile();
      final inlineAssets = <Map<String, dynamic>>[];
      if (company.logoBase64.trim().isNotEmpty) {
        inlineAssets.add({
          'cid': 'companylogo',
          'filename': 'logo.png',
          'base64': company.logoBase64.trim(),
          'contentType': 'image/png',
        });
      }

      final attachment = await _buildQueueAttachmentFromFile(
        filePath: filePath,
        fileName: fileName,
        sourceModule: 'jobs',
        sourceEntityId: widget.job.id,
      );

      final queueItem = await _notificationService.sendEmailNotification(
        recipientEmail: recipientEmail,
        recipientName: widget.clientName,
        subject: subject,
        bodyText: body,
        bodyHtml: '<p>${body.replaceAll('\n', '<br>')}</p>',
        attachments: <Map<String, dynamic>>[attachment],
        inlineAssets: inlineAssets,
        sourceModule: 'jobs',
        sourceEntityId: widget.job.id,
        eventType: NotificationEventType.documentGenerated,
        metadata: <String, dynamic>{
          'job_code': widget.job.jobCode,
          'document_file_name': fileName,
        },
      );

      _snack('Email pus in coada: ${queueItem.id}');
      _snack(
        'Statusul final se vede in Notificari / Email log.',
      );
    } catch (error) {
      _snack('Eroare la trimiterea directa pe email: $error');
    }
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
    } catch (_) {/* intenționat ignorat: refresh token best-effort înainte de upload */}
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } catch (e) {
      debugPrint('[Lucrare] ❌ Storage upload failed: $e');
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

  Future<void> _openFilePath(String path) async {
    final result = await DocumentFileService.openFile(path);
    _snack(result.message);
    if (result.shouldOfferShare && mounted) {
      await _showNoAppShareFallback(path);
    }
  }

  Future<void> _showNoAppShareFallback(String path) async {
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
                  'Nu exista aplicatie pentru deschidere',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Poti trimite documentul prin Share catre WhatsApp, email sau alta aplicatie disponibila.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _shareFilePath(path);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onOpenDocumentPdf(int index) async {
    if (index < 0 || index >= _documents.length) return;
    final row = _documents[index];
    final path = '${row['pdfPath'] ?? row['filePath'] ?? ''}'.trim();
    if (path.isEmpty) {
      _snack('Documentul nu are PDF generat inca.');
      return;
    }
    await _openFilePath(path);
  }

  String _normalizeDocumentTypeForDashboard(Map<String, dynamic> row) {
    final candidates = <String>[
      '${row['type'] ?? ''}',
      '${row['tipDocument'] ?? ''}',
      '${row['documentSubtype'] ?? ''}',
      '${row['documentType'] ?? ''}',
      '${row['typeLegacy'] ?? ''}',
    ];

    for (final candidate in candidates) {
      final normalized = normalizeDocumentTypeCanonical(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    final fromNumber = _canonicalTypeFromNumber(
      row['numarDocument'] ?? row['number'],
    );
    if (fromNumber.isNotEmpty) return fromNumber;
    return '';
  }

  int? _latestDocumentIndexForType(String normalizedType) {
    for (var i = _documents.length - 1; i >= 0; i--) {
      final row = _documents[i];
      final type = _normalizeDocumentTypeForDashboard(row);
      if (type == normalizedType) {
        return i;
      }
    }
    return null;
  }

  String _normalizeRegistryDocumentType(Map<String, dynamic> row) {
    final fromType = normalizeDocumentTypeCanonical(row['type']);
    if (fromType.isNotEmpty) return fromType;
    final fromSource = normalizeDocumentTypeCanonical(row['source']);
    if (fromSource.isNotEmpty) return fromSource;
    final fromNumber = _canonicalTypeFromNumber(row['number']);
    if (fromNumber.isNotEmpty) return fromNumber;
    return '';
  }

  bool _isRegistryRowForCurrentJob(Map<String, dynamic> row) {
    final currentJobId = '${widget.job.id}'.trim().toLowerCase();
    final currentJobCode = widget.job.jobCode.trim().toLowerCase();
    final rowJobId = '${row['jobId'] ?? ''}'.trim().toLowerCase();
    final rowJobCode = '${row['jobCode'] ?? ''}'.trim().toLowerCase();
    if (currentJobCode.isNotEmpty && rowJobCode == currentJobCode) return true;
    if (currentJobId.isNotEmpty && rowJobId == currentJobId) return true;
    if (currentJobId.isNotEmpty && rowJobCode == currentJobId) return true;
    if (currentJobCode.isNotEmpty && rowJobId == currentJobCode) return true;
    final rowNumber = '${row['number'] ?? ''}'.trim().toLowerCase();
    final rowTitle = '${row['title'] ?? ''}'.trim().toLowerCase();
    final rowReferenceId =
        '${row['referenceId'] ?? row['id'] ?? ''}'.trim().toLowerCase();
    final normalizedJobCode =
        _sanitizeFilePart(widget.job.jobCode).toLowerCase();
    if (normalizedJobCode.isNotEmpty && rowNumber.contains(normalizedJobCode)) {
      return true;
    }
    if (normalizedJobCode.isNotEmpty &&
        rowReferenceId.contains(normalizedJobCode)) {
      return true;
    }
    if (currentJobCode.isNotEmpty && rowTitle.contains(currentJobCode)) {
      return true;
    }
    if (normalizedJobCode.isNotEmpty && rowTitle.contains(normalizedJobCode)) {
      return true;
    }
    return false;
  }

  Map<String, dynamic>? _latestRegistryReportForCurrentJob(
    List<Map<String, dynamic>> rows,
  ) {
    for (final row in rows) {
      if (_normalizeRegistryDocumentType(row) != 'raport_lucrare') {
        continue;
      }
      if (!_isRegistryRowForCurrentJob(row)) {
        continue;
      }
      return Map<String, dynamic>.from(row);
    }
    return null;
  }

  Future<void> _openCommercialSettingsDialog() async {
    final vatCtrl = TextEditingController(text: _commercialValue('vatPercent'));
    final paymentCtrl =
        TextEditingController(text: _commercialValue('paymentTerm'));
    final validityCtrl =
        TextEditingController(text: _commercialValue('offerValidity'));
    final executionCtrl =
        TextEditingController(text: _commercialValue('executionTerm'));
    final advanceCtrl =
        TextEditingController(text: _commercialValue('advance'));
    final installmentsCtrl =
        TextEditingController(text: _commercialValue('installments'));
    final penaltiesCtrl =
        TextEditingController(text: _commercialValue('penalties'));
    final materialsProviderCtrl =
        TextEditingController(text: _commercialValue('materialsProvider'));
    final logisticsProviderCtrl =
        TextEditingController(text: _commercialValue('logisticsProvider'));
    final receptionCtrl =
        TextEditingController(text: _commercialValue('receptionClause'));
    final signaturesCtrl =
        TextEditingController(text: _commercialValue('defaultSignatures'));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget field(TextEditingController ctrl, String label,
            {int maxLines = 1}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: ctrl,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          );
        }

        return AlertDialog(
          scrollable: true,
          title: const Text('Setări comerciale globale'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(vatCtrl, 'TVA implicit (%)'),
                field(paymentCtrl, 'Termen plată implicit'),
                field(validityCtrl, 'Valabilitate ofertă implicită'),
                field(executionCtrl, 'Termen execuție implicit'),
                field(advanceCtrl, 'Avans implicit'),
                field(installmentsCtrl, 'Structură tranșe implicită',
                    maxLines: 2),
                field(penaltiesCtrl, 'Penalități implicite', maxLines: 2),
                field(materialsProviderCtrl, 'Furnizor materiale implicit'),
                field(logisticsProviderCtrl,
                    'Furnizor logistică/utilaje implicit'),
                field(receptionCtrl, 'Clauză recepție / PV / PIF implicită',
                    maxLines: 2),
                field(signaturesCtrl, 'Semnături implicite', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                final next = _mergeCommercialSettings(<String, dynamic>{
                  'vatPercent': vatCtrl.text,
                  'paymentTerm': paymentCtrl.text,
                  'offerValidity': validityCtrl.text,
                  'executionTerm': executionCtrl.text,
                  'advance': advanceCtrl.text,
                  'installments': installmentsCtrl.text,
                  'penalties': penaltiesCtrl.text,
                  'materialsProvider': materialsProviderCtrl.text,
                  'logisticsProvider': logisticsProviderCtrl.text,
                  'receptionClause': receptionCtrl.text,
                  'defaultSignatures': signaturesCtrl.text,
                });
                await _saveCommercialSettings(next);
                if (mounted && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  _snack('Setările comerciale au fost salvate.');
                }
              },
              child: const Text('Salvează'),
            ),
          ],
        );
      },
    );

    vatCtrl.dispose();
    paymentCtrl.dispose();
    validityCtrl.dispose();
    executionCtrl.dispose();
    advanceCtrl.dispose();
    installmentsCtrl.dispose();
    penaltiesCtrl.dispose();
    materialsProviderCtrl.dispose();
    logisticsProviderCtrl.dispose();
    receptionCtrl.dispose();
    signaturesCtrl.dispose();
  }

  Widget _buildCommercialSettingsSummary() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('TVA implicit', _commercialValue('vatPercent')),
        _chip('Termen plată', _commercialValue('paymentTerm')),
        _chip('Valabilitate ofertă', _commercialValue('offerValidity')),
        _chip('Termen execuție', _commercialValue('executionTerm')),
        _chip('Avans', _commercialValue('advance')),
      ],
    );
  }

  Widget _buildQuickDocumentActions() {
    final reportPath =
        '${_latestReportRegistryRow?['filePath'] ?? _latestReportRegistryRow?['pdfPath'] ?? _latestReportRegistryRow?['path'] ?? ''}'
            .trim();
    final hasLatestReport = reportPath.isNotEmpty;
    final localReportIndex = _latestDocumentIndexForType('raport_lucrare');

    Widget action({
      required String label,
      required String type,
      required IconData icon,
    }) {
      final index = _latestDocumentIndexForType(type);
      return OutlinedButton.icon(
        onPressed: index == null ? null : () => _onViewDocumentFixed(index),
        icon: Icon(icon, size: 16),
        label: Text(
            index == null ? '$label (lipseste)' : 'Deschide ultimul $label'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        action(
            label: 'Oferta',
            type: 'oferta',
            icon: Icons.request_quote_outlined),
        action(label: 'Deviz', type: 'deviz', icon: Icons.calculate_outlined),
        action(
            label: 'Contract',
            type: 'contract',
            icon: Icons.description_outlined),
        action(label: 'PV', type: 'pv', icon: Icons.fact_check_outlined),
        action(label: 'PIF', type: 'pif', icon: Icons.build_circle_outlined),
        OutlinedButton.icon(
          onPressed: hasLatestReport
              ? () => _openFilePath(reportPath)
              : (localReportIndex == null
                  ? null
                  : () => _onViewDocumentFixed(localReportIndex)),
          icon: const Icon(Icons.summarize_outlined, size: 16),
          label: Text(
            (hasLatestReport || localReportIndex != null)
                ? 'Deschide ultimul raport'
                : 'Raport lucrare (lipseste)',
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerSummaryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('Parteneri', _partners.length.toString()),
        _chip(
          'Total personal partener',
          '${_partnerWorkersTotal.toStringAsFixed(2)} $_partnerWorkersCurrency',
        ),
        _chip(
          'Total autovehicule partener',
          '${_partnerVehiclesTotal.toStringAsFixed(2)} $_partnerVehiclesCurrency',
        ),
        _chip(
          'Total general parteneri',
          '${_partnersTotal.toStringAsFixed(2)} $_partnersCurrency',
        ),
      ],
    );
  }

  Widget _buildPartnerResourcesSection() {
    if (_partners.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPartnerSummaryChips(),
          const SizedBox(height: 10),
          const Text('Nu exista parteneri asociati acestei lucrari.'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPartnerSummaryChips(),
        const SizedBox(height: 10),
        ..._partners.map((partner) {
          final workers = _partnerWorkersFor(partner.id);
          final vehicles = _partnerVehiclesFor(partner.id);
          final workerCurrency = _partnerWorkerCurrencyFor(partner.id);
          final vehicleCurrency = _partnerVehicleCurrencyFor(partner.id);
          final totalCurrency = _partnerCurrencyFor(partner.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partner.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (partner.contactPerson.isNotEmpty)
                                  _chip('Contact', partner.contactPerson),
                                if (partner.phone.isNotEmpty)
                                  _chip('Telefon', partner.phone),
                                if (partner.email.isNotEmpty)
                                  _chip('Email', partner.email),
                                _chip(
                                  'Total personal',
                                  '${_partnerWorkersTotalFor(partner.id).toStringAsFixed(2)} $workerCurrency',
                                ),
                                _chip(
                                  'Total autovehicule',
                                  '${_partnerVehiclesTotalFor(partner.id).toStringAsFixed(2)} $vehicleCurrency',
                                ),
                                _chip(
                                  'Total partener',
                                  '${_partnerTotalFor(partner.id).toStringAsFixed(2)} $totalCurrency',
                                ),
                              ],
                            ),
                            if (partner.notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Observatii: ${partner.notes}'),
                            ],
                          ],
                        ),
                      ),
                      if (!_isTechnician)
                        Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Editeaza partener',
                              onPressed: () => _onEditPartner(partner),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Sterge partener',
                              onPressed: () => _onDeletePartner(partner),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Personal partener',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _onAddPartnerWorker(partner),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Adauga personal'),
                      ),
                    ],
                  ),
                  if (workers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Nu exista personal partener adaugat.'),
                    )
                  else
                    ...workers.map((worker) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(worker.fullName),
                          subtitle: Text(
                            [
                              if (worker.role.isNotEmpty) 'Rol: ${worker.role}',
                              'Ore: ${worker.workedHours.toStringAsFixed(2)}',
                              'Tarif: ${worker.hourlyRate.toStringAsFixed(2)} ${worker.currency}',
                              'Total: ${worker.total.toStringAsFixed(2)} ${worker.currency}',
                              if (worker.notes.isNotEmpty)
                                'Observatii: ${worker.notes}',
                            ].join(' • '),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editeaza',
                                onPressed: () =>
                                    _onEditPartnerWorker(partner, worker),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Sterge',
                                onPressed: () => _onDeletePartnerWorker(worker),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        )),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(
                        'Autovehicule partener',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _onAddPartnerVehicle(partner),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Adauga autovehicul'),
                      ),
                    ],
                  ),
                  if (vehicles.isEmpty)
                    const Text('Nu exista autovehicule partener adaugate.')
                  else
                    ...vehicles.map((vehicle) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(vehicle.vehicleName),
                          subtitle: Text(
                            [
                              if (vehicle.registrationNumber.isNotEmpty)
                                'Nr: ${vehicle.registrationNumber}',
                              'Km: ${vehicle.km.toStringAsFixed(2)}',
                              'Consum: ${vehicle.fuelConsumptionPer100Km.toStringAsFixed(2)} L/100 km',
                              'Pret combustibil: ${vehicle.fuelPricePerLiter.toStringAsFixed(2)} ${vehicle.currency}',
                              'Combustibil calculat: ${vehicle.fuelLiters.toStringAsFixed(2)} L',
                              'Total: ${vehicle.total.toStringAsFixed(2)} ${vehicle.currency}',
                              if (vehicle.notes.isNotEmpty)
                                'Observatii: ${vehicle.notes}',
                            ].join(' • '),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editeaza',
                                onPressed: () =>
                                    _onEditPartnerVehicle(partner, vehicle),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Sterge',
                                onPressed: () =>
                                    _onDeletePartnerVehicle(vehicle),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOwnVehiclesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_ownVehicles.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                'Total autoturisme proprii',
                '${_ownVehiclesTotal.toStringAsFixed(2)} $_ownVehiclesCurrency',
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_ownVehicles.isEmpty)
          const Text('Nu exista autoturisme proprii adaugate.')
        else
          ..._ownVehicles.map((vehicle) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(vehicle.vehicleName),
                subtitle: Text(
                  [
                    if (vehicle.plateNumber.isNotEmpty)
                      'Nr: ${vehicle.plateNumber}',
                    'Km: ${vehicle.km.toStringAsFixed(2)}',
                    'Consum: ${vehicle.fuelConsumptionPer100Km.toStringAsFixed(2)} L/100 km',
                    'Pret combustibil: ${vehicle.fuelPricePerLiter.toStringAsFixed(2)} ${vehicle.currency}',
                    'Combustibil calculat: ${vehicle.fuelLiters.toStringAsFixed(2)} L',
                    'Total: ${vehicle.total.toStringAsFixed(2)} ${vehicle.currency}',
                    if (vehicle.notes.isNotEmpty)
                      'Observatii: ${vehicle.notes}',
                  ].join(' • '),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Editeaza',
                      onPressed: () => _onEditOwnVehicle(vehicle),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Sterge',
                      onPressed: () => _onDeleteOwnVehicle(vehicle),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // ── Helpers pentru liniiPlanificate ─────────────────────────────────────────

  Future<void> _saveLiniiPlanificate(List<JobLine> linii) async {
    final updated = _jobSnapshot.copyWith(liniiPlanificate: linii);
    try {
      _jobSnapshot = await widget.repository.saveJob(updated);
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    } catch (e) {
      debugPrint('[Situatie] _saveLiniiPlanificate error: $e');
    }
    if (mounted) setState(() {});
  }

  void _updateLinieObservatii(String lineId, String value) {
    final linii = List<JobLine>.from(_jobSnapshot.liniiPlanificate);
    final idx = linii.indexWhere((l) => l.id == lineId);
    if (idx < 0) return;
    linii[idx] = linii[idx].copyWith(observatii: value);
    _saveLiniiPlanificate(linii);
  }

  void _updateLinieCantitateReala(String lineId, double value) {
    final linii = List<JobLine>.from(_jobSnapshot.liniiPlanificate);
    final idx = linii.indexWhere((l) => l.id == lineId);
    if (idx < 0) return;
    linii[idx] = linii[idx].copyWith(cantitateReala: value);
    _saveLiniiPlanificate(linii);
  }

  Future<void> _applyProgresGlobal(double percent) async {
    final linii = _jobSnapshot.liniiPlanificate.map((l) {
      final qty = double.parse(
          (l.cantitateOferta * percent / 100).toStringAsFixed(4));
      return l.copyWith(cantitateReala: qty);
    }).toList();
    final updated = _jobSnapshot.copyWith(
      liniiPlanificate: linii,
      progresGlobalPercent: percent,
    );
    try {
      _jobSnapshot = await widget.repository.saveJob(updated);
      await OfflineSyncRuntime.instance.queueJob(_jobSnapshot);
    } catch (e) {
      debugPrint('[Executie] _applyProgresGlobal error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLiniaBifata(String lineId, bool checked) async {
    final linii = List<JobLine>.from(_jobSnapshot.liniiPlanificate);
    final idx = linii.indexWhere((l) => l.id == lineId);
    if (idx < 0) return;
    final l = linii[idx];
    linii[idx] = l.copyWith(
      cantitateReala: checked ? l.cantitateOferta : 0.0,
    );
    _saveLiniiPlanificate(linii);
  }

  Widget _buildRepopulareCard(BuildContext context) {
    final ofertaRef = _jobSnapshot.sourceOfferNumber.isNotEmpty
        ? _jobSnapshot.sourceOfferNumber
        : _jobSnapshot.sourceOfferId;
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Linii planificate neimportate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Această lucrare a fost convertită din oferta $ofertaRef, '
              'dar liniile planificate nu au fost importate încă. '
              'Importă liniile pentru a folosi tracking-ul de execuție.',
              style: TextStyle(fontSize: 13, color: Colors.orange[900]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text('Re-populează din $ofertaRef'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              onPressed: _repopulateFromOffer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiniiTracking(BuildContext context) {
    final linii = _jobSnapshot.liniiPlanificate;
    final totalExecutat = linii.fold(0.0, (s, l) => s + l.cantitateReala);
    final totalPlanificat = linii.fold(0.0, (s, l) => s + l.cantitateOferta);
    final liniiFinalizate = linii.where((l) => l.cantitateReala > 0).length;
    final progresController = TextEditingController(
      text: _jobSnapshot.progresGlobalPercent != null
          ? _jobSnapshot.progresGlobalPercent!.toStringAsFixed(0)
          : '',
    );
    return StatefulBuilder(builder: (ctx, setLocal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card sumar progres ──────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.track_changes_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Tracking execuție',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(
                          '$liniiFinalizate/${linii.length} linii completate',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalPlanificat > 0
                        ? (totalExecutat / totalPlanificat).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  // ── Override progres global ─────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: progresController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: false),
                          decoration: const InputDecoration(
                            labelText: 'Override progres global (%)',
                            hintText: '0 – 100',
                            isDense: true,
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final val = double.tryParse(
                              progresController.text.trim());
                          if (val == null || val < 0 || val > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Valoare invalidă. Introdu 0–100.')));
                            return;
                          }
                          _applyProgresGlobal(val);
                        },
                        child: const Text('Aplică'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Carduri per linie ──────────────────────────────────────────
          ...linii.map((linie) {
            final isBifata = linie.cantitateReala > 0;
            final qtyCtrl = TextEditingController(
              text: linie.cantitateReala > 0
                  ? linie.cantitateReala.toStringAsFixed(2)
                  : '',
            );
            final categorieIcon = switch (linie.categorie) {
              'manopera' => Icons.engineering_outlined,
              'transport' => Icons.local_shipping_outlined,
              'utilaj' => Icons.construction_outlined,
              _ => Icons.inventory_2_outlined,
            };
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isBifata
                      ? Colors.green.withValues(alpha: 0.5)
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                ),
              ),
              color: isBifata
                  ? Colors.green.withValues(alpha: 0.05)
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(categorieIcon,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            linie.denumire,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Checkbox(
                          value: isBifata,
                          onChanged: (checked) =>
                              _toggleLiniaBifata(linie.id, checked ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Planificat: ${linie.cantitateOferta.toStringAsFixed(2)} ${linie.um}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textCapitalization: TextCapitalization.none,
                            decoration: InputDecoration(
                              labelText: 'Executat',
                              suffixText: linie.um,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (v) {
                              final val = double.tryParse(
                                  v.trim().replaceAll(',', '.'));
                              if (val != null && val >= 0) {
                                _updateLinieCantitateReala(linie.id, val);
                              }
                            },
                            onEditingComplete: () {
                              final val = double.tryParse(qtyCtrl.text
                                  .trim()
                                  .replaceAll(',', '.'));
                              if (val != null && val >= 0) {
                                _updateLinieCantitateReala(linie.id, val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (linie.observatii.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Obs: ${linie.observatii.trim()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  Future<void> _repopulateFromOffer() async {
    final sourceId = _jobSnapshot.sourceOfferId.trim();
    final sourceNumber = _jobSnapshot.sourceOfferNumber.trim();
    final sourceDocType = _jobSnapshot.sourceDocumentType.trim();

    // Încarcă ambele surse în paralel (local cache pentru viteză și offline-safe)
    final results = await Future.wait([
      LocalOferteRepository().listOffers(),
      DevizTehnicRepository().listLocal(),
    ]);
    final offers = results[0] as List<OfferRecord>;
    final devize = results[1] as List<DevizTehnicRecord>;

    OfferRecord? foundOffer;
    DevizTehnicRecord? foundDeviz;

    if (sourceId.isNotEmpty || sourceNumber.isNotEmpty) {
      if (sourceDocType == 'deviz_tehnic') {
        // Sursa e din Devize tehnice — caută acolo primul
        foundDeviz = devize.where((d) =>
            (sourceId.isNotEmpty && d.id == sourceId) ||
            (sourceId.isEmpty && d.numar == sourceNumber)).firstOrNull;
        // Fallback la oferte (edge case: doc vechi cu tip incorect salvat)
        if (foundDeviz == null) {
          foundOffer = offers.where((o) =>
              (sourceId.isNotEmpty && o.id == sourceId) ||
              (sourceId.isEmpty && o.offerNumber == sourceNumber)).firstOrNull;
        }
      } else {
        // Sursa e din Oferte simple — caută acolo primul
        foundOffer = offers.where((o) =>
            (sourceId.isNotEmpty && o.id == sourceId) ||
            (sourceId.isEmpty && o.offerNumber == sourceNumber)).firstOrNull;
        // Fallback la devize tehnice
        if (foundOffer == null) {
          foundDeviz = devize.where((d) =>
              (sourceId.isNotEmpty && d.id == sourceId) ||
              (sourceId.isEmpty && d.numar == sourceNumber)).firstOrNull;
        }
      }
    }

    // Dacă documentul sursă nu a fost găsit automat → picker combinat
    if (foundOffer == null && foundDeviz == null) {
      if (!mounted) return;
      if (offers.isEmpty && devize.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu există documente sursă salvate local.')),
        );
        return;
      }
      final picked = await showDialog<LucrareSourceDocument>(
        context: context,
        builder: (ctx) =>
            LucrareSourcePickerDialog(offers: offers, devize: devize),
      );
      if (picked == null || !mounted) return;
      foundOffer = picked.offer;
      foundDeviz = picked.deviz;
    }

    // Mapează documentul sursă la linii JobLine
    List<JobLine> newLinii;
    String sourceLabel;
    String previewLines;

    if (foundDeviz != null) {
      final d = foundDeviz;
      sourceLabel = d.numar;
      newLinii = [];
      final previewParts = <String>[];
      for (final a in d.articole) {
        if (a.pretMat > 0) {
          newLinii.add(JobLine.fromOfertaLine(
            id: '', ofertaLineId: a.id,
            denumire: '${a.denumire} — materiale',
            um: a.um, cantitate: a.cantitate,
            pretUnitar: a.pretMat, categorie: 'material',
          ));
          previewParts.add('• ${a.denumire} — materiale: ${a.cantitate} ${a.um} × ${a.pretMat.toStringAsFixed(2)} RON');
        }
        if (a.pretMan > 0) {
          newLinii.add(JobLine.fromOfertaLine(
            id: '', ofertaLineId: a.id,
            denumire: '${a.denumire} — manoperă',
            um: a.um, cantitate: a.cantitate,
            pretUnitar: a.pretMan, categorie: 'manopera',
          ));
          previewParts.add('• ${a.denumire} — manoperă: ${a.cantitate} ${a.um} × ${a.pretMan.toStringAsFixed(2)} RON');
        }
        if (a.pretUtilaj > 0) {
          newLinii.add(JobLine.fromOfertaLine(
            id: '', ofertaLineId: a.id,
            denumire: '${a.denumire} — utilaj',
            um: a.um, cantitate: a.cantitate,
            pretUnitar: a.pretUtilaj, categorie: 'utilaj',
          ));
          previewParts.add('• ${a.denumire} — utilaj: ${a.cantitate} ${a.um} × ${a.pretUtilaj.toStringAsFixed(2)} RON');
        }
        if (a.pretTransport > 0) {
          newLinii.add(JobLine.fromOfertaLine(
            id: '', ofertaLineId: a.id,
            denumire: '${a.denumire} — transport',
            um: a.um, cantitate: a.cantitate,
            pretUnitar: a.pretTransport, categorie: 'transport',
          ));
          previewParts.add('• ${a.denumire} — transport: ${a.cantitate} ${a.um} × ${a.pretTransport.toStringAsFixed(2)} RON');
        }
      }
      previewLines = previewParts.join('\n');
    } else {
      final offer = foundOffer!;
      sourceLabel = offer.offerNumber;
      final candidateLinii = offer.lines
          .where((l) => l.lineType != OfferLineType.text)
          .toList();
      newLinii = candidateLinii.map((l) => JobLine.fromOfertaLine(
            id: '', ofertaLineId: l.id,
            denumire: l.name, um: l.unit,
            cantitate: l.quantity, pretUnitar: l.unitPrice,
            categorie: l.lineType == OfferLineType.manopera ? 'manopera' : 'material',
          )).toList(growable: false);
      previewLines = candidateLinii.map((l) =>
          '• ${l.name} — ${l.quantity} ${l.unit} × ${l.unitPrice.toStringAsFixed(2)} RON'
          ' [${l.lineType == OfferLineType.manopera ? "manoperă" : "material"}]').join('\n');
    }

    if (newLinii.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documentul sursă nu are articole cu valoare > 0.')),
      );
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Re-populare din $sourceLabel'),
        ]),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Acțiunea va importa liniile de mai jos în câmpul '
                    '"Linii planificate" al lucrării. Cantitățile reale vor fi '
                    'inițializate la valorile din document.'),
                const SizedBox(height: 12),
                Text('Linii de importat (${newLinii.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(previewLines, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmă import'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _saveLiniiPlanificate(newLinii);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newLinii.length} linii importate din $sourceLabel.')),
    );
  }

  // ── TAB: SITUAȚIE LUCRARE (comparativ ofertă vs realizat) ──────────────────
  Widget _buildSituatieTab(BuildContext context) {
    final job = _jobSnapshot;
    final linii = job.liniiPlanificate;
    String fmtCurr(double v) => '${v.toStringAsFixed(2)} RON';

    // Dacă lucrarea nu are linii planificate — arată buton de import indiferent de câmpurile sursă.
    // Acoperă și cazul JOB-uri vechi cu sourceOfferId/sourceOfferNumber gol în cache.
    if (linii.isEmpty) {
      final hasKnownOffer = job.sourceOfferId.isNotEmpty || job.sourceOfferNumber.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              hasKnownOffer
                  ? 'Oferta sursă (${job.sourceOfferNumber.isNotEmpty ? job.sourceOfferNumber : "asociată"}) nu are linii importate încă.'
                  : 'Liniile planificate nu au fost importate.\nPoți importa din orice ofertă disponibilă.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(hasKnownOffer
                  ? 'Re-populează din ${job.sourceOfferNumber.isNotEmpty ? job.sourceOfferNumber : "oferta sursă"}'
                  : 'Importă linii din ofertă'),
              onPressed: _repopulateFromOffer,
            ),
            const SizedBox(height: 8),
            Text(
              'Importă articolele din oferta originală în situația de lucrări.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final totalOfertaFaraTva = job.totalOferta;
    final totalReal = job.totalReal;
    final diferenta = job.diferenta;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header comparativ ───────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('OFERTĂ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700])),
                      const SizedBox(height: 4),
                      Text(
                        fmtCurr(totalOfertaFaraTva),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700]),
                      ),
                      Text('fără TVA',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Text('REALIZAT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700])),
                      const SizedBox(height: 4),
                      Text(
                        fmtCurr(totalReal),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700]),
                      ),
                      Text('la prețuri actuale',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Text('DIFERENȚĂ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diferenta >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700])),
                      const SizedBox(height: 4),
                      Text(
                        '${diferenta >= 0 ? '+' : ''}${fmtCurr(diferenta)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: diferenta >= 0
                                ? Colors.green[700]
                                : Colors.red[700]),
                      ),
                      Text(
                        diferenta >= 0 ? 'economii' : 'depășire',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Linii detaliu ───────────────────────────────────────────────────
        Text('Detaliu articole',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...linii.map((linie) {
          final dif = linie.diferenta;
          final difColor = dif == 0
              ? Colors.grey
              : (dif > 0 ? Colors.orange[700]! : Colors.green[700]!);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(linie.denumire,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: difColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${dif >= 0 ? '+' : ''}${fmtCurr(dif)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: difColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ofertă:',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.blue[600])),
                            Text(
                              '${linie.cantitateOferta} ${linie.um} × ${linie.pretUnitarOferta.toStringAsFixed(2)} = ${fmtCurr(linie.totalOferta)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Realizat:',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[600])),
                            Text(
                              '${linie.cantitateReala} ${linie.um} × ${linie.pretUnitarReal.toStringAsFixed(2)} = ${fmtCurr(linie.totalReal)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LineObservationsField(
                    key: ValueKey('obs-${linie.id}'),
                    initial: linie.observatii,
                    onSave: (val) => _updateLinieObservatii(linie.id, val),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Butoane PDF deviz / situație
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Deviz planificat'),
                onPressed: () => _onGenerateDevizPdf(planificat: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Situație reală'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828)),
                onPressed: () => _onGenerateDevizPdf(planificat: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _onGenerateDevizPdf({required bool planificat}) async {
    try {
      final profile = await widget.repository.loadCompanyProfile();
      final branding = DocumentBrandingData.fromCompanyProfile(profile);
      final path = planificat
          ? await DevizLucrarePdfService.instance
              .generateDevizPlanificat(widget.job, branding)
          : await DevizLucrarePdfService.instance
              .generateSituatieLucrari(widget.job, branding);
      if (!mounted) return;
      await PdfActionsHelper.showPdfActions(
        context,
        filePath: path,
        title: planificat
            ? 'Deviz planificat ${widget.job.jobCode}'
            : 'Situație lucrări ${widget.job.jobCode}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.clientName.trim().isEmpty ? '-' : widget.clientName;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Fişă lucrare'),
              Text(
                '${widget.job.jobCode} · $client',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Sumar'),
              Tab(icon: Icon(Icons.build_outlined), text: 'Execuție'),
              Tab(icon: Icon(Icons.euro_outlined), text: 'Economic'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Documente'),
              Tab(icon: Icon(Icons.compare_arrows_outlined), text: 'Situație'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _isRunningAi ? null : _openJobAiAssistant,
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: 'Asistent AI',
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop('edit'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editează',
            ),
            PopupMenuButton<String>(
              tooltip: 'Mai mult',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'raport':
                    _openReport();
                  case 'situatie':
                    _onGenerateSituatieLucrari();
                  case 'certificat':
                    _openWarrantyCertificateFlow();
                  case 'poze':
                    _openFieldPhotosForJob();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'raport',
                  child: ListTile(
                    leading: Icon(Icons.preview_outlined),
                    title: Text('Raport'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'situatie',
                  child: ListTile(
                    leading: Icon(Icons.assignment_outlined),
                    title: Text('Situație lucrări'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'certificat',
                  child: ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(
                      _jobWarrantyCertificates.isEmpty
                          ? 'Generează certificat'
                          : 'Certificat garanție',
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'poze',
                  child: ListTile(
                    leading: Icon(Icons.photo_camera_outlined),
                    title: Text('Poze teren'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildSumarTab(context),
                  _buildExecutieTab(context),
                  _buildEconomicTab(context),
                  _buildDocumenteTab(context),
                  _buildSituatieTab(context),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _onAddWorkTask,
          icon: const Icon(Icons.add_task),
          label: const Text('Task lucru'),
          tooltip: 'Adaugă etapă / task lucrat',
        ),
      ),
    );
  }

  Widget _buildSumarTab(BuildContext context) {
    final client = widget.clientName.trim().isEmpty ? '-' : widget.clientName;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
                context,
                'Header lucrare',
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('Cod', widget.job.jobCode),
                  _chip('Titlu', widget.job.title),
                  _chip('Client', client),
                  _chip(
                      'Locație',
                      widget.job.location.trim().isEmpty
                          ? '-'
                          : widget.job.location.trim()),
                ])),
            if (widget.job.clientDepartmentName.trim().isNotEmpty ||
                widget.job.contactPerson.trim().isNotEmpty ||
                widget.job.contactPersonEmail.trim().isNotEmpty ||
                widget.job.contactPhone.trim().isNotEmpty)
              _section(
                context,
                'Contact comercial',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.job.clientDepartmentName
                        .trim()
                        .isNotEmpty)
                      _chip(
                        'Departament',
                        widget.job.clientDepartmentName.trim(),
                      ),
                    if (widget.job.contactPerson.trim().isNotEmpty)
                      _chip(
                        'Persoana de contact',
                        widget.job.contactPerson.trim(),
                      ),
                    if (widget.job.contactPersonEmail.trim().isNotEmpty)
                      _chip(
                        'Email',
                        widget.job.contactPersonEmail.trim(),
                      ),
                    if (widget.job.contactPhone.trim().isNotEmpty)
                      _chip(
                        'Telefon',
                        widget.job.contactPhone.trim(),
                      ),
                  ],
                ),
              ),
            _section(
              context,
              'Echipă alocată',
              _assignedTeam == null
                  ? const Text('Nu există date.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_assignedTeam!.label),
                        if (_assignedTeamMembersLabel.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Membri: $_assignedTeamMembersLabel'),
                          ),
                      ],
                    ),
              action: _isTechnician
                  ? null
                  : TextButton.icon(
                      onPressed: _onAssignTeam,
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(_assignedTeam == null
                          ? 'Alocă echipă'
                          : 'Schimbă echipa'),
                    ),
            ),
            _section(
              context,
              'Etape operative',
              Column(
                children: _checklistDefs
                    .map(
                      (entry) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _checklist[entry.key] ?? false,
                        title: Text(entry.value),
                        onChanged: (value) {
                          if (value == null) return;
                          _onToggleChecklist(entry.key, value);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutieTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              context,
              'Programări asociate',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Programari asociate',
                      _appointments.length.toString()),
                  _chip(
                      'Numar materiale', _materials.length.toString()),
                  _chip('Numar inregistrari ore',
                      _labor.length.toString()),
                  _chip('Total ore persoane',
                      _personHoursTotal.toStringAsFixed(2)),
                  _chip('Total ore echipe',
                      _teamHoursTotal.toStringAsFixed(2)),
                ],
              ),
            ),
            _section(
              context,
              'Programari asociate',
              _appointments.isEmpty
                  ? const Text('Nu există date.')
                  : Builder(
                      builder: (context) {
                        Map<String, dynamic>? selectedAppointment;
                        final selectedId = _selectedAppointmentFilterId;
                        if (selectedId != null) {
                          for (final row in _appointments) {
                            if (_appointmentIdOf(row) == selectedId) {
                              selectedAppointment = row;
                              break;
                            }
                          }
                        }
                        final linkedDocs = selectedAppointment == null
                            ? const <Map<String, dynamic>>[]
                            : _documentsLinkedToAppointment(
                                _appointmentIdOf(selectedAppointment),
                              );
                        return Column(
                          children: [
                            ...List<Widget>.generate(
                                _appointments.length, (index) {
                              final e = _appointments[index];
                              final appointmentId =
                                  '${e['id'] ?? e['appointmentId'] ?? ''}'
                                      .trim();
                              final linkedDocumentsCount =
                                  appointmentId.isEmpty
                                      ? 0
                                      : _documents
                                          .where(
                                            (doc) =>
                                                _linkedAppointmentIdOfDocument(
                                                  doc,
                                                ) ==
                                                appointmentId,
                                          )
                                          .length;
                              final isFilterActive =
                                  _selectedAppointmentFilterId ==
                                      appointmentId;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    (e['title'] ?? '-').toString()),
                                subtitle: Text(
                                  '${e['date'] ?? '-'} • ${e['location'] ?? '-'}',
                                ),
                                onTap: () => _onOpenAppointment(index),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: isFilterActive
                                          ? 'Anuleaza filtru documente'
                                          : 'Filtreaza documente dupa aceasta programare',
                                      icon: const Icon(
                                        Icons.filter_alt_outlined,
                                      ),
                                      color: isFilterActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      onPressed: () =>
                                          _toggleAppointmentDocumentFilter(
                                        Map<String, dynamic>.from(e),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Genereaza PV',
                                      icon: const Icon(
                                        Icons.assignment_outlined,
                                      ),
                                      onPressed: () =>
                                          _onGenerateProcesVerbal(
                                        appointment:
                                            Map<String, dynamic>.from(
                                                e),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Genereaza PIF',
                                      icon: const Icon(
                                        Icons.settings_suggest_outlined,
                                      ),
                                      onPressed: () => _onGeneratePif(
                                        appointment:
                                            Map<String, dynamic>.from(
                                                e),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Deschide documentul legat ($linkedDocumentsCount)',
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      onPressed: linkedDocumentsCount ==
                                              0
                                          ? null
                                          : () =>
                                              _onOpenLatestLinkedDocumentFromAppointment(
                                                Map<String,
                                                    dynamic>.from(e),
                                              ),
                                    ),
                                    IconButton(
                                      tooltip: 'Deschide',
                                      icon:
                                          const Icon(Icons.open_in_new),
                                      onPressed: () =>
                                          _onOpenAppointment(index),
                                    ),
                                    IconButton(
                                      tooltip: 'Editează',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                      ),
                                      onPressed: () =>
                                          _onEditAppointment(index),
                                    ),
                                    if (!_isTechnician)
                                      IconButton(
                                        tooltip: 'Șterge',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                        onPressed: () =>
                                            _onDeleteAppointment(index),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (selectedAppointment != null) ...[
                              const Divider(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Documente legate de programarea selectata: ${selectedAppointment['title'] ?? '-'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (linkedDocs.isEmpty)
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Nu exista documente legate de aceasta programare.',
                                  ),
                                )
                              else
                                Column(
                                  children: linkedDocs.map((doc) {
                                    final type =
                                        _documentListTypeLabel(doc)
                                            .trim();
                                    final title =
                                        '${doc['titlu'] ?? doc['title'] ?? '-'}';
                                    final number =
                                        '${doc['numarDocument'] ?? doc['number'] ?? ''}'
                                            .trim();
                                    final date =
                                        '${doc['dataDocument'] ?? doc['date'] ?? ''}'
                                            .trim();
                                    final rawIndex =
                                        _documentIndexInRawList(doc);
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(title),
                                      subtitle: Text(
                                        <String>[
                                          if (type.isNotEmpty) type,
                                          if (number.isNotEmpty)
                                            'Nr: $number',
                                          if (date.isNotEmpty) date,
                                        ].join(' • '),
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Deschide document',
                                        icon: const Icon(
                                          Icons.open_in_new,
                                        ),
                                        onPressed: rawIndex < 0
                                            ? null
                                            : () =>
                                                _onViewDocumentFixed(
                                                  rawIndex,
                                                ),
                                      ),
                                    );
                                  }).toList(growable: false),
                                ),
                            ],
                          ],
                        );
                      },
                    ),
              action: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _onAddAppointment,
                    icon: const Icon(Icons.add),
                    label: const Text(
                        'Adaugă programare pentru această lucrare'),
                  ),
                  if (_selectedAppointmentFilterId != null)
                    OutlinedButton.icon(
                      onPressed: () => setState(
                          () => _selectedAppointmentFilterId = null),
                      icon: const Icon(Icons.clear_outlined),
                      label: const Text('Reseteaza filtru documente'),
                    ),
                ],
              ),
            ),
            // ── Tracking execuție: nou (ofertă sursă) vs vechi (manual) ─
            if (_jobSnapshot.liniiPlanificate.isNotEmpty)
              _buildLiniiTracking(context)
            else if (_jobSnapshot.sourceOfferId.isNotEmpty ||
                _jobSnapshot.sourceOfferNumber.isNotEmpty)
              // Lucrare convertită din ofertă, dar liniile nu au fost importate încă
              _buildRepopulareCard(context)
            else ...[
              _section(
                context,
                'Materiale asociate',
                _materials.isEmpty
                    ? const Text('Nu există date.')
                    : Column(
                        children: List<Widget>.generate(_materials.length,
                            (index) {
                          final e = _materials[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text((e['name'] ?? '-').toString()),
                            subtitle: Text(
                              _isTechnician
                                  ? 'UM: ${e['um'] ?? '-'} • Cantitate: ${e['qty'] ?? 0}'
                                  : 'UM: ${e['um'] ?? '-'} • Cantitate: ${e['qty'] ?? 0} • Preț unitar: ${e['price'] ?? 0} • Total: ${_asDouble(e['total']).toStringAsFixed(2)}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editează',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _onEditMaterial(index),
                                ),
                                if (!_isTechnician)
                                  IconButton(
                                    tooltip: 'Șterge',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _onDeleteMaterial(index),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                action: TextButton.icon(
                  onPressed: _onAddMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Adaugă material'),
                ),
              ),
              _section(
                context,
                'Manoperă / ore',
                _labor.isEmpty
                    ? const Text('Nu există date.')
                    : Column(
                        children:
                            List<Widget>.generate(_labor.length, (index) {
                          final e = _labor[index];
                          final dateLabel = '${e['date'] ?? '-'}';
                          final hoursLabel =
                              _asDouble(e['hours']).toStringAsFixed(2);
                          final rateValue = _laborRateForRow(e);
                          final rateLabel = rateValue > 0
                              ? rateValue.toStringAsFixed(2)
                              : '0.00 (fallback)';
                          final costOreLabel =
                              _laborOreCost(e).toStringAsFixed(2);
                          final costDiurnaLabel =
                              _laborPerDiemCost(e).toStringAsFixed(2);
                          final costCazareLabel =
                              _laborLodgingCost(e).toStringAsFixed(2);
                          final costTotalLabel =
                              _laborTotalLineCost(e).toStringAsFixed(2);
                          final notesLabel = '${e['notes'] ?? ''}'.trim();
                          final tripDaysLabel =
                              _formatDecimal(_laborTripDays(e));
                          final periodLabel = _laborPeriodLabel(e);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text((e['who'] ?? '-').toString()),
                            subtitle: Text(
                              _isTechnician
                                  ? (notesLabel.isEmpty
                                      ? '$dateLabel • Perioadă: $periodLabel • Zile: $tripDaysLabel • Ore: $hoursLabel'
                                      : '$dateLabel • Perioadă: $periodLabel • Zile: $tripDaysLabel • Ore: $hoursLabel\nObservații: $notesLabel')
                                  : (notesLabel.isEmpty
                                      ? '$dateLabel • Perioadă: $periodLabel • Zile: $tripDaysLabel • Ore: $hoursLabel • Tarif: $rateLabel • Cost ore: $costOreLabel • Cost diurnă: $costDiurnaLabel • Cost cazare: $costCazareLabel • Cost total: $costTotalLabel'
                                      : '$dateLabel • Perioadă: $periodLabel • Zile: $tripDaysLabel • Ore: $hoursLabel • Tarif: $rateLabel • Cost ore: $costOreLabel • Cost diurnă: $costDiurnaLabel • Cost cazare: $costCazareLabel • Cost total: $costTotalLabel\nObservații: $notesLabel'),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editează',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _onEditLabor(index),
                                ),
                                if (!_isTechnician)
                                  IconButton(
                                    tooltip: 'Șterge',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _onDeleteLabor(index),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                action: TextButton.icon(
                  onPressed: _onAddLabor,
                  icon: const Icon(Icons.add),
                  label: const Text('Adaugă ore'),
                ),
              ),
            ],
            _section(
              context,
              'Echipamente furnizate de beneficiar',
              _beneficiarySuppliedEquipment.isEmpty
                  ? const Text('Nu exista date.')
                  : Column(
                      children: List<Widget>.generate(
                        _beneficiarySuppliedEquipment.length,
                        (index) {
                          final item =
                              _beneficiarySuppliedEquipment[index];
                          final subtitle = <String>[
                            if (item.equipmentType.trim().isNotEmpty)
                              'Tip: ${item.equipmentType}',
                            if (item.brand.trim().isNotEmpty)
                              'Brand: ${item.brand}',
                            if (item.model.trim().isNotEmpty)
                              'Model: ${item.model}',
                            if (item.serialNumber.trim().isNotEmpty)
                              'Serie: ${item.serialNumber}',
                            'Cantitate: ${item.quantity.toStringAsFixed(2)}',
                          ].join(' • ');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.precision_manufacturing_outlined,
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              item.notes.trim().isEmpty
                                  ? subtitle
                                  : '$subtitle\nObservatii: ${item.notes}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editeaza',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _onEditBeneficiaryEquipment(
                                          index),
                                ),
                                IconButton(
                                  tooltip: 'Sterge',
                                  icon:
                                      const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _onDeleteBeneficiaryEquipment(
                                          index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              action: TextButton.icon(
                onPressed: _onAddBeneficiaryEquipment,
                icon: const Icon(Icons.add),
                label: const Text('Adauga echipament'),
              ),
            ),
            _section(
              context,
              'Materiale furnizate de beneficiar',
              _beneficiarySuppliedMaterials.isEmpty
                  ? const Text('Nu exista date.')
                  : Column(
                      children: List<Widget>.generate(
                        _beneficiarySuppliedMaterials.length,
                        (index) {
                          final item =
                              _beneficiarySuppliedMaterials[index];
                          final subtitle =
                              'UM: ${item.unit.isEmpty ? '-' : item.unit} • Cantitate: ${item.quantity.toStringAsFixed(2)}';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              item.notes.trim().isEmpty
                                  ? subtitle
                                  : '$subtitle\nObservatii: ${item.notes}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editeaza',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () =>
                                      _onEditBeneficiaryMaterial(index),
                                ),
                                IconButton(
                                  tooltip: 'Sterge',
                                  icon:
                                      const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _onDeleteBeneficiaryMaterial(
                                          index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              action: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _onAddBeneficiaryMaterial,
                    icon: const Icon(Icons.add),
                    label: const Text('Adauga material'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _onImportBeneficiaryMaterials,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Importa lista'),
                  ),
                ],
              ),
            ),
            _section(
              context,
              'Resurse partener',
              _buildPartnerResourcesSection(),
              action: TextButton.icon(
                onPressed: _onAddPartner,
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Adaugă partener'),
              ),
            ),
            _section(
              context,
              'Autoturisme proprii',
              _buildOwnVehiclesSection(),
              action: TextButton.icon(
                onPressed: _onAddOwnVehicle,
                icon: const Icon(Icons.directions_car_outlined),
                label: const Text('Adauga autoturism'),
              ),
            ),
            _section(
              context,
              'Timeline taskuri / volum zilnic',
              _workTaskEntries.isEmpty
                  ? const Text(
                      'Nu exista inca taskuri. Adauga etape cu ora inceput/final, oameni alocati si status.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _workloadSummaryByDay().map((entry) {
                            final payload = entry.value;
                            final minutes = payload['minutes'] as int;
                            final hours = minutes / 60.0;
                            final taskCount = payload['tasks'] as int;
                            final people =
                                payload['people'] as Set<String>;
                            return _chip(
                              _dayKeyToLabel(entry.key),
                              '${hours.toStringAsFixed(2)}h | $taskCount task | ${people.length} pers',
                            );
                          }).toList(growable: false),
                        ),
                        const SizedBox(height: 10),
                        ...List<Widget>.generate(
                            _workTaskEntries.length, (index) {
                          final row = _workTaskEntries[index];
                          final title = '${row['title'] ?? '-'}'.trim();
                          final workers = _workTaskWorkers(row);
                          final startAt = _workTaskStartAt(row);
                          final endAt = _workTaskEndAt(row);
                          final completed = row['completed'] == true;
                          final notes = '${row['notes'] ?? ''}'.trim();
                          final interval =
                              '${startAt == null ? '-' : _formatDateTime(startAt.toIso8601String())} - ${endAt == null ? '-' : _formatDateTime(endAt.toIso8601String())}';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Checkbox(
                              value: completed,
                              onChanged: (value) {
                                if (value == null) return;
                                _onToggleWorkTaskCompleted(
                                    index, value);
                              },
                            ),
                            title: Text(title.isEmpty ? '-' : title),
                            subtitle: Text(
                              notes.isEmpty
                                  ? '$interval • Durata: ${_workTaskDurationLabel(row)} • Oameni: ${workers.isEmpty ? '-' : workers.join(', ')}'
                                  : '$interval • Durata: ${_workTaskDurationLabel(row)} • Oameni: ${workers.isEmpty ? '-' : workers.join(', ')}\nObs: $notes',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editeaza task',
                                  onPressed: () =>
                                      _onEditWorkTask(index),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Sterge task',
                                  onPressed: () =>
                                      _onDeleteWorkTask(index),
                                  icon:
                                      const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
              action: TextButton.icon(
                onPressed: _onAddWorkTask,
                icon: const Icon(
                    Icons.playlist_add_check_circle_outlined),
                label: const Text('Adauga task'),
              ),
            ),
            _section(
              context,
              'Pontaj teren',
              _buildTimeTrackingSection(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEmiteFacturaSmartBill() async {
    final job = widget.job;
    if (job.liniiPlanificate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Nu există linii realizate. Completează situația de lucrări mai întâi.'),
      ));
      return;
    }
    final profile = await widget.repository.loadCompanyProfile();
    if (!mounted) return;
    final settings = profile.smartBillSettings;
    if (!settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('SmartBill nu este configurat. Mergi la Setări → SmartBill.'),
      ));
      return;
    }
    setState(() {});
    final linii = job.liniiPlanificate
        .map((l) => <String, dynamic>{
              'name': l.denumire,
              'quantity': l.cantitateReala,
              'price': l.pretUnitarReal,
              'measuringUnitName': l.um,
              'taxName': 'Normala',
              'taxPercentage': 21,
              'isService': l.categorie == 'manopera',
            })
        .toList();
    final result = await SmartBillService.instance.genereazaFacturadinLucrare(
      settings: settings,
      clientName: widget.clientName,
      jobCode: job.jobCode,
      sourceOfferNumber: job.sourceOfferNumber,
      linii: linii,
    );
    if (!mounted) return;
    if (result.success) {
      final updated = job.copyWith(
        smartbillFacturaNumar: result.numarFactura,
        smartbillFacturaSerie: result.serieFactura,
      );
      await widget.repository.saveJob(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Factură emisă: ${result.serieFactura} ${result.numarFactura} ✓'),
          backgroundColor: Colors.green,
        ));
        setState(() {});
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Eroare SmartBill: ${result.eroare}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildEconomicTab(BuildContext context) {
    final client = widget.clientName.trim().isEmpty ? '-' : widget.clientName;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── SmartBill facturare ─────────────────────────────────────────
            if (widget.job.smartbillFacturaNumar.isNotEmpty)
              Card(
                color: Colors.green[50],
                child: ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                      'Facturat SmartBill: ${widget.job.smartbillFacturaSerie}${widget.job.smartbillFacturaNumar}'),
                  subtitle: const Text('Factură deja emisă'),
                ),
              )
            else if (widget.job.status == JobStatus.finalizata)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Emite factură SmartBill'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  onPressed: _onEmiteFacturaSmartBill,
                ),
              ),
            Builder(
              builder: (context) {
                final documentRows = _documents;
                String normalizeDocType(Map<String, dynamic> row) {
                  final rawType = ((row['type'] ??
                              row['tipDocument'] ??
                              row['documentType'] ??
                              _extractDocumentTypeLabel(row)) ??
                          '')
                      .toString()
                      .trim()
                      .toLowerCase()
                      .replaceAll('ă', 'a')
                      .replaceAll('â', 'a')
                      .replaceAll('î', 'i')
                      .replaceAll('ș', 's')
                      .replaceAll('ş', 's')
                      .replaceAll('ț', 't')
                      .replaceAll('ţ', 't');
                  if (rawType.contains('oferta')) return 'Oferta';
                  if (rawType.contains('deviz')) return 'Deviz';
                  if (rawType.contains('contract')) return 'Contract';
                  if (rawType.contains('proces') ||
                      rawType == 'pv' ||
                      rawType.contains('proces_verbal')) {
                    return 'PV';
                  }
                  if (rawType == 'pif' || rawType.contains('punere')) {
                    return 'PIF';
                  }
                  return '';
                }

                final docCounts = <String, int>{
                  'Oferta': 0,
                  'Deviz': 0,
                  'Contract': 0,
                  'PV': 0,
                  'PIF': 0,
                };
                for (final row in documentRows) {
                  final key = normalizeDocType(row);
                  if (key.isEmpty) continue;
                  docCounts[key] = (docCounts[key] ?? 0) + 1;
                }

                final recentDocs = documentRows
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(growable: false)
                  ..sort((a, b) {
                    final aDate =
                        '${a['updatedAt'] ?? a['createdAt'] ?? a['dataDocument'] ?? ''}';
                    final bDate =
                        '${b['updatedAt'] ?? b['createdAt'] ?? b['dataDocument'] ?? ''}';
                    return bDate.compareTo(aDate);
                  });
                final statusLabel = '${widget.job.status.label}'
                    .replaceAll('\uFFFD', '')
                    .replaceAll('', '');
                final assignedTeamLabel = _assignedTeam?.label ?? '-';
                final relevantAppointments = _appointments
                    .where((row) =>
                        '${row['status'] ?? ''}'.trim().isEmpty ||
                        _normalizeAppointmentStatusLabel(
                                row['status']) !=
                            'Anulata')
                    .length;
                final registryLabel = _latestReportRegistryRow == null
                    ? 'fara raport inregistrat'
                    : '${_latestReportRegistryRow?['number'] ?? _latestReportRegistryRow?['registryNumber'] ?? '-'}';

                return _section(
                  context,
                  'Dashboard comercial / operativ',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sumar lucrare',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Client', client),
                          _chip('Status lucrare', statusLabel),
                          _chip('Echipa', assignedTeamLabel),
                          if (widget.job.clientDepartmentName
                              .trim()
                              .isNotEmpty)
                            _chip('Departament',
                                widget.job.clientDepartmentName.trim()),
                          if (widget.job.contactPerson
                              .trim()
                              .isNotEmpty)
                            _chip(
                              'Contact',
                              widget.job.contactPerson.trim(),
                            ),
                          _chip(
                            'Programari relevante',
                            '$relevantAppointments',
                          ),
                          _chip(
                            'Documente asociate',
                            '${documentRows.length}',
                          ),
                          _chip('Registratura raport', registryLabel),
                          _chip(
                            'Resurse interne',
                            _realTotalCost.toStringAsFixed(2),
                          ),
                          _chip(
                            'Total parteneri',
                            '${_partnersTotal.toStringAsFixed(2)} $_partnersCurrency',
                          ),
                          if (_ownVehiclesTotal > 0)
                            _chip(
                              'Autoturisme proprii',
                              '${_ownVehiclesTotal.toStringAsFixed(2)} $_ownVehiclesCurrency',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Economic',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Valoare estimata',
                              _estimatedValue.toStringAsFixed(2)),
                          _chip('Cost real total',
                              _realTotalCost.toStringAsFixed(2)),
                          _chip(
                            'Diferenta estimat vs real',
                            _estimatedVsRealDifference
                                .toStringAsFixed(2),
                          ),
                          _chip('Total materiale',
                              _materialsTotal.toStringAsFixed(2)),
                          _chip('Total manopera',
                              _laborTotalCost.toStringAsFixed(2)),
                          _chip('Total diurna',
                              _laborDiurnaTotal.toStringAsFixed(2)),
                          _chip('Total cazare',
                              _laborCazareTotal.toStringAsFixed(2)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Parteneri',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      _buildPartnerSummaryChips(),
                      const SizedBox(height: 12),
                      Text(
                        'Operativ',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('Numar materiale',
                              _materials.length.toString()),
                          _chip('Numar inregistrari ore',
                              _labor.length.toString()),
                          _chip('Numar programari',
                              _appointments.length.toString()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Documente',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: docCounts.entries.map((entry) {
                          final count = entry.value;
                          final status =
                              count > 0 ? 'exista' : 'lipseste';
                          return _chip(
                              entry.key, '$status (${entry.value})');
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ultimele documente utile',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      if (recentDocs.isEmpty)
                        _emptyStateText('Nu exista documente asociate.')
                      else
                        Column(
                          children: recentDocs.take(3).map((doc) {
                            final docType = normalizeDocType(doc);
                            final title =
                                '${doc['titlu'] ?? doc['title'] ?? '-'}';
                            final number =
                                '${doc['numarDocument'] ?? doc['number'] ?? ''}'
                                    .trim();
                            final status = '${doc['status'] ?? '-'}';
                            final date =
                                '${doc['dataDocument'] ?? doc['date'] ?? ''}'
                                    .trim();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              subtitle: Text(
                                <String>[
                                  if (docType.isNotEmpty) docType,
                                  if (number.isNotEmpty) 'Nr: $number',
                                  if (status.trim().isNotEmpty)
                                    'Status: $status',
                                  if (date.isNotEmpty) date,
                                ].join(' • '),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                    ],
                  ),
                );
              },
            ),
            _section(
              context,
              'Cost real lucrare',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Total materiale',
                      _materialsTotal.toStringAsFixed(2)),
                  _chip('Total manoperă ore',
                      _laborOreTotal.toStringAsFixed(2)),
                  _chip('Total diurnă',
                      _laborDiurnaTotal.toStringAsFixed(2)),
                  _chip('Total cazare',
                      _laborCazareTotal.toStringAsFixed(2)),
                  _chip('Total manoperă completă',
                      _laborTotalCost.toStringAsFixed(2)),
                  _chip('Cost real total',
                      _realTotalCost.toStringAsFixed(2)),
                  _chip(
                    'Valoare estimată',
                    _estimatedValue.toStringAsFixed(2),
                  ),
                  _chip(
                    'Diferență estimat vs real',
                    _estimatedVsRealDifference.toStringAsFixed(2),
                  ),
                  _chip(
                      'Număr materiale', _materials.length.toString()),
                  _chip('Total înregistrări ore',
                      _labor.length.toString()),
                  _chip('Total ore persoane',
                      _personHoursTotal.toStringAsFixed(2)),
                  _chip('Total ore echipe',
                      _teamHoursTotal.toStringAsFixed(2)),
                  _chip(
                    'Total parteneri (separat)',
                    '${_partnersTotal.toStringAsFixed(2)} $_partnersCurrency',
                  ),
                  _chip('Programări asociate',
                      _appointments.length.toString()),
                  _chip('Echipa curentă', _assignedTeam?.label ?? '-'),
                  _chip('Număr intrări jurnal',
                      _journal.length.toString()),
                  _chip(
                    'Etape bifate',
                    '${_checklist.values.where((value) => value).length}/${_checklistDefs.length}',
                  ),
                  _chip('Taskuri zilnice',
                      _workTaskEntries.length.toString()),
                  _chip(
                    'Taskuri finalizate',
                    _workTaskEntries
                        .where((row) => row['completed'] == true)
                        .length
                        .toString(),
                  ),
                ],
              ),
            ),
            if (!_isTechnician)
              _section(
                context,
                'Rentabilitate lucrare',
                _buildProfitabilitySection(),
              ),
            if (!_isTechnician)
              _section(
                context,
                'Profit și Partener',
                _buildPartnerProfitSection(),
              ),
            if (!_isTechnician)
              _section(
                context,
                'Setări comerciale globale',
                _buildCommercialSettingsSummary(),
                action: OutlinedButton.icon(
                  onPressed: _openCommercialSettingsDialog,
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Editează'),
                ),
              ),
            _section(
              context,
              'Acces rapid documente',
              _buildQuickDocumentActions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumenteTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              context,
              'Procese-verbale lucrari',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Familia noua de PV / PIF este gestionata distinct si cloud-first pentru aceasta lucrare.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tipuri disponibile: PV montaj / executie lucrari, PV PIF ventilatie / recuperator, PV PIF VRF / climatizare.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La creare se pregatesc automat anexele relevante din materialele, echipamentele si datele deja existente in lucrare.',
                  ),
                ],
              ),
              action: FilledButton.icon(
                onPressed: _openJobSiteDocumentsPage,
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Deschide PV / PIF'),
              ),
            ),
            _section(
              context,
              'Certificate de garantie',
              _jobWarrantyCertificates.isEmpty
                  ? const Text(
                      'Nu exista inca certificate emise pentru aceasta lucrare.',
                    )
                  : Column(
                      children: _jobWarrantyCertificates.map((item) {
                        final coverage = _productCatalogService
                            .coverageStatusForCertificate(
                          item,
                        );
                        final subtitleParts = <String>[
                          if (item.sourceEquipmentLabel
                              .trim()
                              .isNotEmpty)
                            item.sourceEquipmentLabel.trim(),
                          if (item.jobTitle.trim().isNotEmpty)
                            item.jobTitle.trim(),
                          item.fullCertificateNumber.trim().isEmpty
                              ? 'Draft'
                              : item.fullCertificateNumber.trim(),
                          coverage.label,
                        ];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.verified_user_outlined,
                          ),
                          title: Text(
                            item.buyerName.trim().isEmpty
                                ? 'Certificat garantie'
                                : item.buyerName.trim(),
                          ),
                          subtitle: Text(subtitleParts.join(' | ')),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Deschide certificat',
                                onPressed: () async {
                                  final equipment =
                                      _beneficiarySuppliedEquipment
                                          .where(
                                            (entry) =>
                                                entry.id ==
                                                item.sourceEquipmentId,
                                          )
                                          .fold<
                                              BeneficiarySuppliedEquipment?>(
                                            null,
                                            (previous, entry) => entry,
                                          );
                                  final initial =
                                      await _buildJobWarrantyCertificate(
                                    equipment: equipment,
                                    existing: item,
                                  );
                                  if (!mounted) return;
                                  final saved = await showDialog<
                                      WarrantyCertificateRecord>(
                                    context: this.context,
                                    builder: (context) =>
                                        WarrantyCertificateEditorDialog(
                                      initial: initial,
                                    ),
                                  );
                                  if (saved == null) return;
                                  await _productCatalogService
                                      .saveWarrantyCertificate(saved);
                                  await _loadData();
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Genereaza PDF',
                                onPressed: () =>
                                    _generateJobWarrantyCertificatePdf(
                                  item,
                                  share: false,
                                ),
                                icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Save As',
                                onPressed: () =>
                                    _generateJobWarrantyCertificatePdf(
                                  item,
                                  share: false,
                                  saveAs: true,
                                ),
                                icon:
                                    const Icon(Icons.save_as_outlined),
                              ),
                              IconButton(
                                tooltip: 'Share',
                                onPressed: () =>
                                    _generateJobWarrantyCertificatePdf(
                                  item,
                                  share: true,
                                ),
                                icon: const Icon(Icons.share_outlined),
                              ),
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    ),
              action: FilledButton.icon(
                onPressed: _openWarrantyCertificateFlow,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_jobWarrantyCertificates.isEmpty
                    ? 'Genereaza certificat garantie'
                    : 'Deschide certificat garantie'),
              ),
            ),
            _section(
              context,
              'Documente asociate',
              _documentsForDisplay(_documents).isEmpty
                  ? const Text('Nu există date.')
                  : Column(
                      children: List<Widget>.generate(
                          _documentsForDisplay(_documents).length,
                          (index) {
                        final e =
                            _documentsForDisplay(_documents)[index];
                        final type = _documentListTypeLabel(e);
                        final title =
                            '${e['titlu'] ?? e['title'] ?? '-'}';
                        final number =
                            '${e['numarDocument'] ?? e['number'] ?? ''}'
                                .trim();
                        final date =
                            '${e['dataDocument'] ?? e['date'] ?? ''}'
                                .trim();
                        final status = _normalizeAppointmentStatusLabel(
                            e['status']);
                        final filePath =
                            '${e['filePath'] ?? e['pdfPath'] ?? ''}'
                                .trim();
                        final registryNumber =
                            '${e['registryNumber'] ?? ''}'.trim();
                        final registeredAt =
                            '${e['registeredAt'] ?? ''}'.trim();
                        final subtitle = <String>[
                          if (type.trim().isNotEmpty) type,
                          if (number.isNotEmpty) 'Nr: $number',
                          if (date.isNotEmpty) date,
                          if (status.trim().isNotEmpty)
                            'Status: $status',
                        ].join(' • ');
                        final notes =
                            '${e['observatii'] ?? e['notes'] ?? ''}'
                                .trim();
                        final registrySuffix = <String>[
                          registryNumber.isNotEmpty
                              ? 'Registratura: $registryNumber'
                              : 'Registratura: neinregistrat',
                          if (registeredAt.isNotEmpty)
                            'Inregistrat: $registeredAt',
                        ].join(' • ');
                        final linkedAppointmentId =
                            _linkedAppointmentIdOfDocument(e);
                        final linkedAppointmentTitle =
                            '${e['sourceAppointmentTitle'] ?? ''}'
                                .trim();
                        final linkedAppointmentDate =
                            '${e['sourceAppointmentDate'] ?? ''}'
                                .trim();
                        final linkedAppointmentSuffix = linkedAppointmentId
                                .isEmpty
                            ? ''
                            : 'Programare: ${linkedAppointmentTitle.isEmpty ? linkedAppointmentId : linkedAppointmentTitle}${linkedAppointmentDate.isEmpty ? '' : ' ($linkedAppointmentDate)'}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(title),
                          subtitle: Text(notes.isEmpty
                              ? (linkedAppointmentSuffix.isEmpty
                                  ? '$subtitle • $registrySuffix'
                                  : '$subtitle • $registrySuffix\n$linkedAppointmentSuffix')
                              : (linkedAppointmentSuffix.isEmpty
                                  ? '$subtitle • $registrySuffix\n$notes'
                                  : '$subtitle • $registrySuffix\n$linkedAppointmentSuffix\n$notes')),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Acțiuni document',
                            itemBuilder: (_) => [
                              if (linkedAppointmentId.isNotEmpty)
                                const PopupMenuItem(
                                  value: 'appointment',
                                  child: ListTile(
                                    leading: Icon(Icons.event_note_outlined),
                                    title: Text('Deschide programarea'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'open',
                                child: ListTile(
                                  leading: Icon(Icons.open_in_new),
                                  title: Text('Deschide'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Editează'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'pdf',
                                child: ListTile(
                                  leading: Icon(Icons.picture_as_pdf_outlined),
                                  title: Text('Export PDF'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'save_as',
                                child: ListTile(
                                  leading: Icon(Icons.save_as_outlined),
                                  title: Text('Salvează PDF ca...'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'open_pdf',
                                child: ListTile(
                                  leading: Icon(Icons.file_open_outlined),
                                  title: Text('Deschide PDF'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'photos',
                                child: ListTile(
                                  leading: Icon(Icons.photo_camera_outlined),
                                  title: Text('Poze teren'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              if (!_isTechnician)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Șterge'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'appointment':
                                  _onOpenLinkedAppointmentFromDocument(e);
                                case 'open':
                                  _onViewDocumentFixed(index);
                                case 'edit':
                                  _onEditDocumentSmart(index);
                                case 'pdf':
                                  _onExportDocumentPdf(index);
                                case 'save_as':
                                  _onExportDocumentPdf(index,
                                      saveAs: true);
                                case 'open_pdf':
                                  _onOpenDocumentPdf(index);
                                case 'photos':
                                  _openFieldPhotosForDocument(index);
                                case 'delete':
                                  _onDeleteDocument(index);
                              }
                            },
                          ),
                        );
                      }),
                    ),
              action: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _onGenerateProcesVerbal,
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Genereaza PV'),
                  ),
                  TextButton.icon(
                    onPressed: _onGeneratePif,
                    icon: const Icon(Icons.settings_suggest_outlined),
                    label: const Text('Genereaza PIF'),
                  ),
                  if (!_isTechnician) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _onGenerateOferta,
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Genereaza Ofertă'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _onGenerateDeviz,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Genereaza Deviz'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _onGenerateContract,
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('Genereaza Contract'),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: _onAddDocument,
                    icon: const Icon(Icons.add),
                    label: const Text('Adaugă document'),
                  ),
                ],
              ),
            ),
            _section(
              context,
              'Istoric lucrare',
              _journal.isEmpty
                  ? const Text('Nu există date.')
                  : Column(
                      children: List<Widget>.generate(_journal.length,
                          (index) {
                        final e = _journal[index];
                        final action = '${e['action'] ?? '-'}';
                        final message = '${e['message'] ?? '-'}';
                        final at = _formatDateTime('${e['at'] ?? ''}');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(message),
                          subtitle: Text('$action • $at'),
                        );
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

const Set<String> _collapsibleSectionTitles = <String>{
  'Programari asociate',
  'Programări asociate',
  'Materiale asociate',
  'Echipamente furnizate de beneficiar',
  'Materiale furnizate de beneficiar',
  'Manopera / ore',
  'Manoperă / ore',
  'Resurse partener',
  'Autoturisme proprii',
  'Documente asociate',
  'Istoric lucrare',
};

const Set<String> _collapsedByDefaultTitles = <String>{
  'Documente asociate',
  'Istoric lucrare',
};

const List<String> _appointmentStatuses = <String>[
  'Planificată',
  'În curs',
  'Finalizată',
  'Amânată',
  'Anulată',
];

String _normalizeAppointmentStatusLabel(dynamic rawStatus) {
  String norm(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't');

  final value = norm('${rawStatus ?? ''}');

  if (value.isEmpty) return '-';
  if (value == 'planificata' || value == 'planned' || value == 'noua') {
    return 'Planificată';
  }
  if (value == 'in curs' || value == 'incurs' || value == 'in_progress') {
    return 'În curs';
  }
  if (value == 'finalizata' || value == 'finalizataa' || value == 'done') {
    return 'Finalizată';
  }
  if (value == 'amanata' || value == 'amânata' || value == 'postponed') {
    return 'Amânată';
  }
  if (value == 'anulata' || value == 'cancelled' || value == 'canceled') {
    return 'Anulată';
  }

  for (final status in _appointmentStatuses) {
    if (norm(status) == value) {
      return status;
    }
  }
  final fallback = '${rawStatus ?? ''}'.trim();
  return fallback.isEmpty ? '-' : fallback;
}

bool _isCollapsibleSection(String title) {
  final normalized = title.trim();
  return _collapsibleSectionTitles.contains(normalized);
}

bool _isInitiallyExpandedSection(String title) {
  final normalized = title.trim();
  if (_collapsedByDefaultTitles.contains(normalized)) {
    return false;
  }
  return true;
}

Widget _section(BuildContext context, String title, Widget child,
    {Widget? action}) {
  final titleStyle = Theme.of(context).textTheme.titleMedium;
  if (!_isCollapsibleSection(title)) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: titleStyle)),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      key: PageStorageKey<String>('section_$title'),
      initiallyExpanded: _isInitiallyExpandedSection(title),
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: titleStyle),
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
      children: [
        child,
      ],
    ),
  );
}

Widget _chip(String label, String value) => Chip(label: Text('$label: $value'));

Widget _emptyStateText(String text) => Text(
      text,
      style: const TextStyle(color: Colors.black54),
    );

String _documentListTypeLabel(dynamic rawDocument) {
  final document = rawDocument is Map
      ? Map<String, dynamic>.from(rawDocument)
      : <String, dynamic>{};

  final canonicalFromMap = normalizeDocumentTypeCanonical(document);
  if (canonicalFromMap.isNotEmpty) {
    return documentTypeLabelFromCanonical(canonicalFromMap);
  }

  final subtype = '${document['documentSubtype'] ?? document['subtype'] ?? ''}'
      .trim()
      .toLowerCase();
  if (subtype == 'oferta_client') {
    return 'Ofertă client';
  }

  final rawNumber = '${document['numarDocument'] ?? document['number'] ?? ''}'
      .trim()
      .toUpperCase();
  if (rawNumber.startsWith('CT-')) return 'Contract';
  if (rawNumber.startsWith('DV-')) return 'Deviz';
  if (rawNumber.startsWith('OF-')) return 'Ofertă';
  if (rawNumber.startsWith('PV-')) return 'Proces verbal';
  if (rawNumber.startsWith('PIF-')) return 'PIF';
  if (rawNumber.startsWith('RAP-')) return 'Raport lucrare';

  return 'Alt document';
}

List<String> _dedupeDropdownValues(Iterable<dynamic> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in values) {
    final value = raw.toString().trim();
    if (value.isEmpty) continue;
    final normalized = value
        .toLowerCase()
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final canonicalKey = normalized.startsWith('oferta client')
        ? 'oferta_client'
        : (normalized == 'oferta' ? 'oferta' : normalized);

    if (seen.add(canonicalKey)) {
      if (canonicalKey == 'oferta_client') {
        out.add('Oferta client');
      } else if (canonicalKey == 'oferta') {
        out.add('Oferta');
      } else {
        out.add(value);
      }
    }
  }

  final hasOffer = seen.contains('oferta');
  final hasOfferClient = seen.contains('oferta_client');
  if (hasOffer && !hasOfferClient) {
    final offerIndex =
        out.indexWhere((e) => normalizeDocumentTypeCanonical(e) == 'oferta');
    if (offerIndex >= 0) {
      out.insert(offerIndex + 1, 'Oferta client');
    } else {
      out.add('Oferta client');
    }
  }

  return out;
}

String _documentSubtypeFromSelectedType(String? rawType) {
  final value = (rawType ?? '')
      .toLowerCase()
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value.startsWith('oferta client')) return 'oferta_client';
  return '';
}

List<Map<String, dynamic>> _documentsForDisplay(
  List<Map<String, dynamic>> documents,
) {
  final byStableKey = <String, Map<String, dynamic>>{};

  for (final raw in documents) {
    final doc = Map<String, dynamic>.from(raw);
    final id = '${doc['id'] ?? doc['localId'] ?? ''}'.trim();
    final job = '${doc['jobId'] ?? doc['jobCode'] ?? ''}'.trim();
    final number =
        '${doc['numarDocument'] ?? doc['number'] ?? ''}'.trim().toUpperCase();
    final title = '${doc['titlu'] ?? doc['title'] ?? ''}'.trim().toLowerCase();
    final date = '${doc['dataDocument'] ?? doc['date'] ?? ''}'.trim();
    final type = normalizeDocumentTypeCanonical(doc);
    final subtype = '${doc['documentSubtype'] ?? doc['subtype'] ?? ''}'
        .trim()
        .toLowerCase();

    final stableType = subtype.isNotEmpty ? subtype : type;
    final key = id.isNotEmpty ? 'id:$id' : '$job|$stableType|$title|$date';

    final existing = byStableKey[key];
    if (existing == null) {
      byStableKey[key] = doc;
      continue;
    }

    final existingNumber =
        '${existing['numarDocument'] ?? existing['number'] ?? ''}'
            .trim()
            .toUpperCase();
    final existingIsOther = existingNumber.startsWith('OTHER-');
    final currentIsOther = number.startsWith('OTHER-');

    // Keep the non-generic numbered document when duplicate logical entries exist.
    if (existingIsOther && !currentIsOther) {
      byStableKey[key] = doc;
    }
  }

  return byStableKey.values.toList(growable: false);
}

String? _safeDropdownValue(Iterable<dynamic> options, String? selectedValue) {
  if (selectedValue == null) return null;
  final trimmed = selectedValue.trim();
  final normalized = options.map((e) => e.toString().trim());
  final matches = normalized
      .where((e) => e.toLowerCase() == trimmed.toLowerCase())
      .toList();
  return matches.length == 1 ? matches.first : null;
}

// ── Helper pentru _buildSituatieTab ──────────────────────────────────────────
String _fileNameFromPath(String path) {
  final normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return '';
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

