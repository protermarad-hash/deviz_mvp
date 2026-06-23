import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/app_role_policy.dart';
import '../../core/auth_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../../core/help/help_module_button.dart';
import '../../core/widgets/client_autocomplete_field.dart';
import '../../core/widgets/partner_autocomplete_field.dart';
import '../clients/client_models.dart';
import '../partners/partner_models.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_service.dart';
import 'complaint_models.dart';
import 'complaint_detail_page.dart';
import 'repair_report_models.dart';

class ReclamatiiListPage extends StatefulWidget {
  const ReclamatiiListPage({
    super.key,
    required this.repository,
    this.fieldAuthRoleKey,
    this.fieldAuthUserLabel,
    this.fieldAuthUserId,
    this.fieldAuthTeamId,
    this.initialFocusComplaintId = '',
  });

  final AppDataRepository repository;
  final String? fieldAuthRoleKey;
  final String? fieldAuthUserLabel;
  final String? fieldAuthUserId;
  final String? fieldAuthTeamId;
  final String initialFocusComplaintId;

  @override
  State<ReclamatiiListPage> createState() => _ReclamatiiListPageState();
}

// ── Dialog creare reclamație nouă ────────────────────────────────────────────
class _NewComplaintDialog extends StatefulWidget {
  const _NewComplaintDialog({
    required this.repository,
    required this.clients,
  });

  final AppDataRepository repository;
  final List<ClientRecord> clients;

  @override
  State<_NewComplaintDialog> createState() => _NewComplaintDialogState();
}

class _NewComplaintDialogState extends State<_NewComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colaboratorRefCtrl = TextEditingController();
  final _colaboratorContactCtrl = TextEditingController();

  ComplaintType _type = ComplaintType.garantie;
  ComplaintSource _source = ComplaintSource.directa;
  String _tipSursa = 'client_direct';
  DateTime _date = DateTime.now();
  ClientRecord? _selectedClient;
  ClientRecord? _selectedClientFinal;
  PartnerRecord? _selectedColaborator;
  bool _saving = false;
  List<ClientRecord> _localClients = const [];
  List<PartnerRecord> _partners = const [];

  @override
  void initState() {
    super.initState();
    _localClients = [...widget.clients];
    // Încarcă partenerii în background pentru selectorul de colaborator
    widget.repository.listPartners().then((p) {
      if (mounted) setState(() => _partners = p);
    });
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colaboratorRefCtrl.dispose();
    _colaboratorContactCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final nextNumber = await widget.repository.nextComplaintNumber();
      final now = DateTime.now();
      // La sursă colaborator: clientul selectat devine clientFinal dacă există
      final beneficiarClient = _tipSursa == 'client_direct'
          ? _selectedClient
          : _selectedClientFinal;
      final complaint = ComplaintRecord(
        id: const Uuid().v4(),
        complaintNumber: nextNumber,
        complaintDate: _date,
        status: ComplaintStatus.noua,
        type: _type,
        source: _source,
        beneficiaryClientId: beneficiarClient?.id ?? '',
        beneficiaryName: beneficiarClient?.name ??
            (_tipSursa != 'client_direct' ? _selectedColaborator?.name ?? '' : ''),
        contractorName: '',
        contactPerson: _contactCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? (beneficiarClient?.allPhoneNumbers.firstOrNull ??
                beneficiarClient?.phone ?? '')
            : _phoneCtrl.text.trim(),
        email: beneficiarClient?.email ?? '',
        location: _locationCtrl.text.trim(),
        assignedTeamId: '',
        assignedEmployeeId: '',
        problemDescription: _descriptionCtrl.text.trim(),
        internalNotes: '',
        equipmentBrand: _brandCtrl.text.trim(),
        equipmentModel: _modelCtrl.text.trim(),
        tipSursa: _tipSursa,
        colaboratorId: _selectedColaborator?.id ?? '',
        colaboratorNume: _selectedColaborator?.name ?? '',
        colaboratorContact: _colaboratorContactCtrl.text.trim(),
        colaboratorTelefon: _selectedColaborator?.phone ?? '',
        colaboratorRefNumber: _colaboratorRefCtrl.text.trim(),
        clientFinalId: _selectedClientFinal?.id ?? '',
        clientFinalNume: _selectedClientFinal?.name ?? '',
        createdAt: now,
        updatedAt: now,
      );
      await widget.repository.saveComplaint(complaint);
      if (mounted) Navigator.of(context).pop(complaint);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reclamație nouă'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sursă reclamație ────────────────────────────────────
                const Text('Sursa reclamației',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'client_direct',
                        label: Text('Client direct'),
                        icon: Icon(Icons.person_outlined, size: 16)),
                    ButtonSegment(
                        value: 'colaborator',
                        label: Text('Via colaborator'),
                        icon: Icon(Icons.handshake_outlined, size: 16)),
                    ButtonSegment(
                        value: 'garantie_producator',
                        label: Text('Garanție prod.'),
                        icon: Icon(Icons.verified_outlined, size: 16)),
                  ],
                  selected: {_tipSursa},
                  onSelectionChanged: (s) =>
                      setState(() => _tipSursa = s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Câmpuri colaborator (afișate dacă sursa ≠ client_direct) ──
                if (_tipSursa != 'client_direct') ...[
                  PartnerAutocompleteField(
                    key: ValueKey(
                        'collab-${_selectedColaborator?.id ?? 'none'}'),
                    partners: _partners,
                    initialPartner: _selectedColaborator,
                    labelText: 'Societate / Colaborator',
                    onPartnerSelected: (p) =>
                        setState(() => _selectedColaborator = p),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _colaboratorRefCtrl,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Nr. referință / dosar colaborator',
                      prefixIcon:
                          Icon(Icons.numbers_outlined, size: 18),
                      helperText:
                          'Numărul dosarului primit de la colaborator',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _colaboratorContactCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Persoană contact colaborator',
                      prefixIcon:
                          Icon(Icons.person_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Client final — beneficiarul real al lucrării
                  ClientAutocompleteField(
                    key: ValueKey(
                        'final-client-${_selectedClientFinal?.id ?? 'none'}'),
                    clients: _localClients,
                    initialClient: _selectedClientFinal,
                    labelText: 'Client final (beneficiar)',
                    onClientSelected: (c) =>
                        setState(() => _selectedClientFinal = c),
                    repository: widget.repository,
                    tipEntitate: 'Beneficiar',
                    onClientAdded: (c) => setState(() {
                      _localClients = [..._localClients, c];
                      _selectedClientFinal = c;
                    }),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Client direct (afișat doar când sursa = client_direct) ──
                if (_tipSursa == 'client_direct') ...[
                  ClientAutocompleteField(
                    key: ValueKey(
                        'new-complaint-client-${_selectedClient?.id ?? 'none'}'),
                    clients: _localClients,
                    initialClient: _selectedClient,
                    labelText: 'Client / Beneficiar',
                    onClientSelected: (c) {
                      setState(() {
                        _selectedClient = c;
                        if (c != null && _contactCtrl.text.isEmpty) {
                          _contactCtrl.text = c.contactPerson;
                        }
                      });
                    },
                    repository: widget.repository,
                    tipEntitate: 'Beneficiar',
                    onClientAdded: (c) => setState(() {
                      _localClients = [..._localClients, c];
                      _selectedClient = c;
                      if (_contactCtrl.text.isEmpty &&
                          c.contactPerson.isNotEmpty) {
                        _contactCtrl.text = c.contactPerson;
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ComplaintType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Tip'),
                        items: ComplaintType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _type = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<ComplaintSource>(
                        initialValue: _source,
                        decoration: const InputDecoration(labelText: 'Sursă'),
                        items: ComplaintSource.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _source = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descriere problemă *',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Obligatoriu' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Brand echipament'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _modelCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Model'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Locație / Adresă',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _contactCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Persoană contact'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telefon'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, size: 18),
                  title: Text(
                    'Data: ${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Renunță'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('Salvează'),
        ),
      ],
    );
  }
}

// ── Pagina principală reclamații ──────────────────────────────────────────────
class _ReclamatiiListPageState extends State<ReclamatiiListPage> {
  final TextEditingController _searchController = TextEditingController();
  final NotificationCenterService _notificationService =
      NotificationCenterService();
  bool _loading = true;
  bool _searchVisible = false;

  List<ComplaintRecord> _items = const [];
  List<ClientRecord> _clients = const [];
  List<RepairReportRecord> _reports = const [];
  AppUser? _currentUser;

  String _searchQuery = '';
  ComplaintStatus? _statusFilter;
  List<ComplaintRecord> _filtered = const [];

  Timer? _clientsDebounce;

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    LocalAppDataRepository.clientsChangeCount.addListener(_onClientsChanged);
    _searchController.addListener(_onSearchChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    LocalAppDataRepository.clientsChangeCount.removeListener(_onClientsChanged);
    _clientsDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.onlineNotifier.value && _items.isEmpty && !_loading) {
      _load();
    }
  }

  void _onClientsChanged() {
    if (_loading) return;
    _clientsDebounce?.cancel();
    _clientsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.repository.listClients().then((clients) {
        if (!mounted) return;
        setState(() => _clients = clients);
        _rebuildFiltered();
      });
    });
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _rebuildFiltered();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await OfflineSyncRuntime.instance.syncPending();
      final results = await Future.wait<dynamic>([
        widget.repository.loadCurrentUser(),
        widget.repository.listComplaints(),
        widget.repository.listClients(),
        widget.repository.listRepairReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _currentUser = results[0] as AppUser?;
        _items = results[1] as List<ComplaintRecord>;
        _clients = results[2] as List<ClientRecord>;
        _reports = results[3] as List<RepairReportRecord>;
        _loading = false;
        _rebuildFiltered();
      });
      _handleInitialFocus();
    } catch (e) {
      FirebaseBootstrap.registerRuntimeError(e);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleInitialFocus() {
    final focusId = widget.initialFocusComplaintId.trim();
    if (focusId.isEmpty) return;
    final complaint = _items.where((c) => c.id == focusId).firstOrNull;
    if (complaint == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openDetail(complaint);
    });
  }

  UserRole? get _role => AppRolePolicy.resolve(
        appRole: _currentUser?.role,
        roleKey: widget.fieldAuthRoleKey,
      );

  bool get _canManage => AppRolePolicy.canAccessTeamLead(_role);

  bool _isVisible(ComplaintRecord item) {
    final role = _role;
    if (role == null || role == UserRole.admin || role == UserRole.birou) return true;
    final userId = (widget.fieldAuthUserId ?? _currentUser?.id ?? '').trim();
    final teamId = (widget.fieldAuthTeamId ?? '').trim();
    if (role == UserRole.sefEchipa) {
      if (teamId.isNotEmpty) {
        return item.assignedTeamId == teamId || item.fieldTeamId == teamId;
      }
      return true;
    }
    if (role == UserRole.tehnician) {
      if (userId.isNotEmpty && (item.assignedEmployeeId == userId || item.fieldTechnicianId == userId)) {
        return true;
      }
      if (teamId.isNotEmpty && (item.assignedTeamId == teamId || item.fieldTeamId == teamId)) {
        return true;
      }
      return false;
    }
    return true;
  }

  String _clientName(ComplaintRecord item) {
    if (item.beneficiaryName.trim().isNotEmpty) return item.beneficiaryName.trim();
    return _clients
        .where((c) => c.id == item.beneficiaryClientId)
        .map((c) => c.name)
        .firstOrNull ?? '';
  }

  int _pvCount(ComplaintRecord item) =>
      _reports.where((r) => r.complaintId == item.id).length;

  void _rebuildFiltered() {
    final q = _searchQuery;
    _filtered = _items.where((item) {
      if (!_isVisible(item)) return false;
      if (_statusFilter != null && item.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final hay = [
        item.complaintNumber,
        _clientName(item),
        item.equipmentBrand,
        item.equipmentModel,
        item.problemDescription,
        item.location,
        item.contactPerson,
        item.phone,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _onAdaugaReclamatie() async {
    if (!_canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Crearea reclamațiilor este disponibilă pentru admin, birou și șefi de echipă.',
          ),
        ),
      );
      return;
    }
    final result = await showDialog<ComplaintRecord>(
      context: context,
      builder: (_) => _NewComplaintDialog(
        repository: widget.repository,
        clients: _clients,
      ),
    );
    if (result != null && mounted) {
      // Notificare reclamatie noua (fire-and-forget, best-effort).
      _notifyComplaintCreated(result);
      await _load();
      if (!mounted) return;
      _openDetail(result);
    }
  }

  /// Trimite notificarea de reclamatie nou creata. Oglindeste logica din
  /// reclamatii_page.dart `_notifyComplaintSaved` (cazul previous == null).
  void _notifyComplaintCreated(ComplaintRecord saved) {
    final complaintLabel = saved.complaintNumber.trim().isEmpty
        ? 'Reclamatie'
        : saved.complaintNumber.trim();
    final message =
        '$complaintLabel | Status: ${saved.status.label} | Beneficiar: ${saved.beneficiaryName.trim().isEmpty ? '-' : saved.beneficiaryName.trim()} | Problema: ${saved.problemDescription.trim().isEmpty ? '-' : saved.problemDescription.trim()}';
    _notificationService
        .dispatchEvent(
          NotificationDispatchRequest(
            eventType: NotificationEventType.complaintCreated,
            title: 'Reclamatie noua',
            message: message,
            sourceModule: 'reclamatii',
            sourceEntityId: saved.id,
            sourceLabel: complaintLabel,
            recipientTeamIds: saved.assignedTeamId.trim().isEmpty
                ? const <String>[]
                : <String>[saved.assignedTeamId.trim()],
            recipientEmployeeIds: saved.assignedEmployeeId.trim().isEmpty
                ? const <String>[]
                : <String>[saved.assignedEmployeeId.trim()],
            recipientRoleKeys: const <String>['admin', 'office'],
            metadata: <String, dynamic>{
              'complaint_status': saved.status.value,
              'job_id': saved.jobId,
              'appointment_id': saved.appointmentId,
            },
          ),
        )
        .catchError((_) {});
  }

  void _openDetail(ComplaintRecord complaint) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintDetailPage(
          repository: widget.repository,
          complaint: complaint,
          allReports: _reports.where((r) => r.complaintId == complaint.id).toList(),
          fieldAuthRoleKey: widget.fieldAuthRoleKey,
          fieldAuthUserId: widget.fieldAuthUserId,
          fieldAuthUserLabel: widget.fieldAuthUserLabel,
          fieldAuthTeamId: widget.fieldAuthTeamId,
        ),
      ),
    ).then((_) => _load());
  }

  Color _statusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.noua:
        return Colors.blue;
      case ComplaintStatus.analizata:
        return Colors.indigo;
      case ComplaintStatus.programata:
        return Colors.purple;
      case ComplaintStatus.inLucru:
        return Colors.orange;
      case ComplaintStatus.inAsteptare:
        return Colors.amber.shade700;
      case ComplaintStatus.rezolvata:
        return Colors.green;
      case ComplaintStatus.inchisa:
        return Colors.grey;
      case ComplaintStatus.anulata:
        return Colors.red;
    }
  }

  Color _typeColor(ComplaintType type) {
    switch (type) {
      case ComplaintType.garantie:
        return Colors.green.shade700;
      case ComplaintType.postgarantie:
        return Colors.orange.shade700;
      case ComplaintType.revizie:
        return Colors.blue.shade700;
      case ComplaintType.mentenanta:
        return Colors.teal.shade700;
      case ComplaintType.alta:
        return Colors.grey.shade600;
    }
  }

  Widget _statusBadge(ComplaintStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _typeBadge(ComplaintType type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildCard(ComplaintRecord item) {
    final client = _clientName(item);
    final pvs = _pvCount(item);
    final interventions = item.interventionHistory.length;
    final hasEquip = item.equipmentBrand.isNotEmpty || item.equipmentModel.isNotEmpty;
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1),
      ),
      color: statusColor.withValues(alpha: 0.04),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statusBadge(item.status),
                  const SizedBox(width: 8),
                  Text(
                    item.complaintNumber.isEmpty ? '(fără număr)' : item.complaintNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  _typeBadge(item.type),
                ],
              ),
              const SizedBox(height: 6),
              if (client.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        client,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (item.location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.location,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (hasEquip) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.ac_unit_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      [item.equipmentBrand, item.equipmentModel]
                          .where((s) => s.isNotEmpty)
                          .join(' '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              const Divider(height: 12),
              Row(
                children: [
                  _statChip(Icons.build_outlined, '$interventions intervenții'),
                  const SizedBox(width: 12),
                  _statChip(Icons.description_outlined, '$pvs PV-uri'),
                  const Spacer(),
                  Text(
                    '${item.complaintDate.day.toString().padLeft(2, '0')}.${item.complaintDate.month.toString().padLeft(2, '0')}.${item.complaintDate.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const statusOptions = <ComplaintStatus?>[
      null,
      ComplaintStatus.noua,
      ComplaintStatus.inLucru,
      ComplaintStatus.inAsteptare,
      ComplaintStatus.rezolvata,
    ];
    final labels = ['Toate', 'Deschise', 'În lucru', 'Necesită revenire', 'Rezolvate'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: List.generate(statusOptions.length, (i) {
          final opt = statusOptions[i];
          final selected = _statusFilter == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i], style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _statusFilter = opt;
                  _rebuildFiltered();
                });
              },
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Caută reclamație...',
                  border: InputBorder.none,
                ),
              )
            : const Text('Reclamații'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            tooltip: _searchVisible ? 'Închide căutare' : 'Caută',
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                  _rebuildFiltered();
                }
              });
            },
          ),
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Reclamație nouă',
              onPressed: _onAdaugaReclamatie,
            ),
          const HelpModuleButton(moduleId: 'reclamatii'),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _onAdaugaReclamatie,
              icon: const Icon(Icons.add),
              label: const Text('Reclamație nouă'),
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            _buildFilterChips(),
            if (_loading)
              const LinearProgressIndicator(),
            Expanded(
              child: _filtered.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 60),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.support_agent_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _loading
                                    ? 'Se încarcă...'
                                    : _searchQuery.isNotEmpty || _statusFilter != null
                                        ? 'Nicio reclamație găsită pentru filtrele active.'
                                        : 'Nicio reclamație înregistrată.',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reîncarcă'),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Firebase: init=${FirebaseBootstrap.isInitialized} online=${FirebaseBootstrap.isOnline}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

