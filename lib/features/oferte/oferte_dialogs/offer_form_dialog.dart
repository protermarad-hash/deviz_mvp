import 'package:flutter/material.dart';

import '../../../core/design_system/app_tokens.dart';
import '../../../core/repositories/app_data_repository.dart';
import '../../../core/widgets/client_autocomplete_field.dart';
import '../../clients/client_models.dart';
import '../../jobs/job_models.dart';
import '../bnr_exchange_rate_service.dart';
import '../offer_commercial_package_models.dart';
import '../offer_currency_converter.dart';
import '../offer_editor_defaults_store.dart';
import '../offer_models.dart';
import '../offer_standard_catalog_models.dart';
import 'offer_commercial_clause_dialog.dart';

class OfferFormDialog extends StatefulWidget {
  const OfferFormDialog({
    required this.clients,
    required this.jobs,
    required this.onSave,
    required this.defaults,
    required this.laborTemplates,
    required this.clauseTemplates,
    required this.packageTemplates,
    this.existing,
    this.initialDraft,
    this.nextOfferNumber,
    this.currentUserId,
    this.currentUserEmail,
    this.defaultTipDocument,
    this.repository,
  });

  final OfferRecord? existing;
  final OfferRecord? initialDraft;
  final List<ClientRecord> clients;
  final AppDataRepository? repository;
  final List<JobRecord> jobs;
  final Future<void> Function(OfferRecord offer) onSave;
  final OfferEditorDefaults defaults;
  final List<OfferLaborTemplate> laborTemplates;
  final List<OfferCommercialClauseTemplate> clauseTemplates;
  final List<OfferCommercialPackageTemplate> packageTemplates;
  final String? nextOfferNumber;
  final String? currentUserId;
  final String? currentUserEmail;
  final TipDocumentDeviz? defaultTipDocument;

  @override
  State<OfferFormDialog> createState() => OfferFormDialogState();
}

class OfferFormDialogState extends State<OfferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _vatPercentController = TextEditingController();
  final _regiePercentController = TextEditingController();
  final _profitPercentController = TextEditingController();
  final _manualRateController = TextEditingController();
  final _exchangeCommissionController = TextEditingController();
  final _notesController = TextEditingController();
  final ScrollController _dialogScrollController = ScrollController();
  final BnrExchangeRateService _bnrService = const BnrExchangeRateService();

  // Lista locală de clienți — extinsă când utilizatorul adaugă unul nou inline
  List<ClientRecord> _localClients = const [];

  bool _saving = false;
  bool _loadingBnrRate = false;
  bool _manualClientSelection = false;
  String? _selectedClientId;
  String? _selectedDepartmentId;
  String? _selectedContactPersonId;
  String? _selectedJobId;
  OfferStatus _selectedStatus = OfferStatus.draft;
  OfferPriceDisplayMode _priceDisplayMode = OfferPriceDisplayMode.both;
  String _selectedCurrency = 'RON';
  OfferExchangeRateSource _exchangeRateSource = OfferExchangeRateSource.manual;
  double _bnrRateValue = 0;
  DateTime _issueDate = DateTime.now();
  DateTime? _validUntil;
  String _offerNumber = '';
  List<OfferCommercialClause> _commercialClauses = <OfferCommercialClause>[];
  bool _priceDisplayModeTouched = false;

  @override
  void initState() {
    super.initState();
    _localClients = [...widget.clients];
    final seed = widget.existing ?? widget.initialDraft;
    if (seed != null) {
      _offerNumber = widget.existing == null && seed.offerNumber.trim().isEmpty
          ? (widget.nextOfferNumber ?? '').trim()
          : seed.offerNumber;
      _titleController.text = seed.title;
      _selectedClientId = _normalizeClientId(seed.clientId);
      _selectedDepartmentId =
          _normalizeDepartmentId(_selectedClientId, seed.departmentId);
      _selectedContactPersonId =
          _normalizeContactPersonId(_selectedClientId, seed.contactPersonId);
      _selectedJobId = _normalizeJobId(seed.jobId);
      _selectedStatus = seed.status;
      _priceDisplayMode = seed.priceDisplayMode;
      _issueDate = seed.issueDate;
      _validUntil = seed.validUntil;
      _selectedCurrency = OfferCurrencyConverter.normalizeCurrency(
        seed.currency,
      );
      _exchangeRateSource = seed.exchangeRateSource;
      _bnrRateValue = seed.bnrRate;
      _manualRateController.text =
          seed.manualRate > 0 ? seed.manualRate.toStringAsFixed(4) : '';
      _exchangeCommissionController.text =
          seed.exchangeCommissionPercent.toStringAsFixed(2);
      _vatPercentController.text = seed.vatPercent.toStringAsFixed(2);
      _regiePercentController.text = seed.regiePercent.toStringAsFixed(2);
      _profitPercentController.text = seed.profitPercent.toStringAsFixed(2);
      _notesController.text = seed.notes;
      _commercialClauses = seed.commercialClauses
          .map((item) => item.copyWith())
          .toList(growable: true);
      _manualClientSelection = _selectedClientId != null;
      _priceDisplayModeTouched = true;
    } else {
      _offerNumber = (widget.nextOfferNumber ?? '').trim();
      _selectedCurrency = widget.defaults.currency;
      _exchangeRateSource = widget.defaults.exchangeRateSource;
      _manualRateController.text = '5.0000';
      _exchangeCommissionController.text =
          widget.defaults.exchangeCommissionPercent.toStringAsFixed(2);
      _vatPercentController.text =
          widget.defaults.vatPercent.toStringAsFixed(2);
      _regiePercentController.text =
          widget.defaults.regiePercent.toStringAsFixed(2);
      _profitPercentController.text =
          widget.defaults.profitPercent.toStringAsFixed(2);
      _selectedStatus = OfferStatus.draft;
      _priceDisplayMode = OfferPriceDisplayMode.withoutVat;
      _validUntil = _issueDate.add(const Duration(days: 30));
      _manualClientSelection = false;
      _priceDisplayModeTouched = false;
      _commercialClauses = <OfferCommercialClause>[];
      final preselectedClient = _clientById(_selectedClientId);
      if (preselectedClient != null) {
        _applyClientDependentDefaults(preselectedClient);
      }
    }
    if (_exchangeRateSource == OfferExchangeRateSource.bnr) {
      _refreshBnrRate();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vatPercentController.dispose();
    _regiePercentController.dispose();
    _profitPercentController.dispose();
    _manualRateController.dispose();
    _exchangeCommissionController.dispose();
    _notesController.dispose();
    _dialogScrollController.dispose();
    super.dispose();
  }

  double _asDouble(String raw, [double fallback = 0]) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;
  }

  OfferTotals get _computedTotals {
    final lines = (widget.existing ?? widget.initialDraft)?.lines ??
        const <OfferLineItem>[];
    final vat = _asDouble(_vatPercentController.text, 21);
    final regie = _asDouble(_regiePercentController.text, 0);
    final profit = _asDouble(_profitPercentController.text, 0);
    return OfferRecord.computeTotals(
      lines: lines,
      vatPercent: vat,
      regiePercent: regie,
      profitPercent: profit,
    );
  }

  double get _manualRateValue => _asDouble(_manualRateController.text, 0);
  double get _exchangeCommissionPercent =>
      _asDouble(_exchangeCommissionController.text, 0);

  double get _baseExchangeRate {
    if (!OfferCurrencyConverter.requiresRate(_selectedCurrency)) return 0;
    if (_exchangeRateSource == OfferExchangeRateSource.bnr) {
      return _bnrRateValue > 0 ? _bnrRateValue : _manualRateValue;
    }
    return _manualRateValue;
  }

  double get _effectiveExchangeRate {
    if (!OfferCurrencyConverter.requiresRate(_selectedCurrency)) return 1;
    return OfferCurrencyConverter.computeEffectiveRate(
      baseRate: _baseExchangeRate,
      commissionPercent: _exchangeCommissionPercent,
    );
  }

  Future<void> _refreshBnrRate() async {
    if (_loadingBnrRate) return;
    setState(() => _loadingBnrRate = true);
    try {
      final fetched = await _bnrService.fetchOrCachedRate(_selectedCurrency);
      if (!mounted) return;
      if (fetched != null && fetched > 0) {
        setState(() => _bnrRateValue = fetched);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingBnrRate = false);
      }
    }
  }

  String? _normalizeClientId(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final exists = widget.clients.any((item) => item.id == value);
    return exists ? value : null;
  }

  String? _normalizeJobId(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final exists = widget.jobs.any((item) => item.id == value);
    return exists ? value : null;
  }

  JobRecord? _jobById(String? id) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in widget.jobs) {
      if (item.id == value) return item;
    }
    return null;
  }

  ClientRecord? _clientById(String? id) {
    final value = (id ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in _localClients) {
      if (item.id == value) return item;
    }
    return null;
  }

  List<ClientDepartment> _departmentsForClient(String? clientId) {
    final client = _clientById(clientId);
    return client?.departments ?? const <ClientDepartment>[];
  }

  List<ClientContactPerson> _contactsForClient(String? clientId) {
    final client = _clientById(clientId);
    return client?.contactPeople ?? const <ClientContactPerson>[];
  }

  String? _normalizeDepartmentId(String? clientId, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final exists =
        _departmentsForClient(clientId).any((item) => item.id == value);
    return exists ? value : null;
  }

  String? _normalizeContactPersonId(String? clientId, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final exists = _contactsForClient(clientId).any((item) => item.id == value);
    return exists ? value : null;
  }

  ClientDepartment? _departmentById(String? clientId, String? departmentId) {
    final value = (departmentId ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in _departmentsForClient(clientId)) {
      if (item.id == value) return item;
    }
    return null;
  }

  ClientContactPerson? _contactById(String? clientId, String? contactId) {
    final value = (contactId ?? '').trim();
    if (value.isEmpty) return null;
    for (final item in _contactsForClient(clientId)) {
      if (item.id == value) return item;
    }
    return null;
  }

  List<ClientContactPerson> _filteredContactsForSelection() {
    final contacts = _contactsForClient(_selectedClientId);
    final departmentId = (_selectedDepartmentId ?? '').trim();
    if (departmentId.isEmpty) return contacts;
    final filtered = contacts
        .where(
          (item) =>
              item.departmentId.trim().isEmpty ||
              item.departmentId.trim() == departmentId,
        )
        .toList(growable: false);
    return filtered.isEmpty ? contacts : filtered;
  }

  OfferPriceDisplayMode _defaultPriceDisplayModeForClient(
      ClientRecord? client) {
    if (client == null) return OfferPriceDisplayMode.withoutVat;
    return client.type == ClientType.persoanaJuridica
        ? OfferPriceDisplayMode.withoutVat
        : OfferPriceDisplayMode.withVat;
  }

  void _applyClientDependentDefaults(ClientRecord? client) {
    final departments = client?.departments ?? const <ClientDepartment>[];
    final contacts = client?.contactPeople ?? const <ClientContactPerson>[];
    _selectedDepartmentId =
        _normalizeDepartmentId(client?.id, _selectedDepartmentId);
    _selectedContactPersonId =
        _normalizeContactPersonId(client?.id, _selectedContactPersonId);

    if (_selectedDepartmentId == null && departments.length == 1) {
      _selectedDepartmentId = departments.first.id;
    }

    final selectedContact = _contactById(client?.id, _selectedContactPersonId);
    if (selectedContact != null &&
        selectedContact.departmentId.trim().isNotEmpty) {
      _selectedDepartmentId = _normalizeDepartmentId(
        client?.id,
        selectedContact.departmentId,
      );
    }

    final selectableContacts = _filteredContactsForSelection();
    if (_selectedContactPersonId == null && selectableContacts.length == 1) {
      _selectedContactPersonId = selectableContacts.first.id;
      final onlyContact = selectableContacts.first;
      if (onlyContact.departmentId.trim().isNotEmpty) {
        _selectedDepartmentId = _normalizeDepartmentId(
          client?.id,
          onlyContact.departmentId,
        );
      }
    }

    if (_selectedContactPersonId != null &&
        !_filteredContactsForSelection()
            .any((item) => item.id == _selectedContactPersonId)) {
      _selectedContactPersonId = null;
    }

    if (_selectedContactPersonId == null &&
        _selectedDepartmentId == null &&
        contacts.length == 1 &&
        contacts.first.departmentId.trim().isNotEmpty) {
      _selectedDepartmentId = _normalizeDepartmentId(
        client?.id,
        contacts.first.departmentId,
      );
      _selectedContactPersonId = contacts.first.id;
    }

    if (!_priceDisplayModeTouched && widget.existing == null) {
      _priceDisplayMode = _defaultPriceDisplayModeForClient(client);
    }
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _issueDate = picked);
  }

  Future<void> _pickValidUntil() async {
    final initial = _validUntil ?? _issueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _validUntil = picked);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  List<OfferCommercialClauseTemplate> get _activeClauseTemplates =>
      widget.clauseTemplates
          .where((item) => item.isActive)
          .toList(growable: false);

  Future<void> _addCommercialClause() async {
    final saved = await showDialog<OfferCommercialClause>(
      context: context,
      builder: (context) => OfferCommercialClauseDialog(
        templates: _activeClauseTemplates,
        initialSortOrder: _commercialClauses.length + 1,
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      _commercialClauses = [
        ..._commercialClauses,
        saved.copyWith(sortOrder: _commercialClauses.length + 1),
      ];
    });
  }

  Future<void> _editCommercialClause(OfferCommercialClause clause) async {
    final saved = await showDialog<OfferCommercialClause>(
      context: context,
      builder: (context) => OfferCommercialClauseDialog(
        templates: widget.clauseTemplates,
        initialSortOrder: clause.sortOrder,
        existing: clause,
      ),
    );
    if (saved == null) {
      return;
    }
    setState(() {
      _commercialClauses = _commercialClauses
          .map((item) => item.id == clause.id ? saved : item)
          .toList(growable: false);
    });
  }

  void _deleteCommercialClause(OfferCommercialClause clause) {
    setState(() {
      final remaining = _commercialClauses
          .where((item) => item.id != clause.id)
          .toList(growable: false);
      _commercialClauses = [
        for (var i = 0; i < remaining.length; i++)
          remaining[i].copyWith(sortOrder: i + 1),
      ];
    });
  }

  void _onClientChanged(String? value) {
    setState(() {
      _selectedClientId = value;
      _manualClientSelection = true;
      _selectedDepartmentId = null;
      _selectedContactPersonId = null;
      _applyClientDependentDefaults(_clientById(value));
    });
  }

  void _onDepartmentChanged(String? value) {
    setState(() {
      _selectedDepartmentId = _normalizeDepartmentId(_selectedClientId, value);
      final currentContact = _contactById(
        _selectedClientId,
        _selectedContactPersonId,
      );
      if (currentContact != null &&
          currentContact.departmentId.trim().isNotEmpty &&
          currentContact.departmentId.trim() !=
              (_selectedDepartmentId ?? '').trim()) {
        _selectedContactPersonId = null;
      }
      final filteredContacts = _filteredContactsForSelection();
      if (_selectedContactPersonId == null && filteredContacts.length == 1) {
        _selectedContactPersonId = filteredContacts.first.id;
      }
    });
  }

  void _onContactChanged(String? value) {
    setState(() {
      _selectedContactPersonId =
          _normalizeContactPersonId(_selectedClientId, value);
      final selectedContact = _contactById(
        _selectedClientId,
        _selectedContactPersonId,
      );
      if (selectedContact != null &&
          selectedContact.departmentId.trim().isNotEmpty) {
        _selectedDepartmentId = _normalizeDepartmentId(
          _selectedClientId,
          selectedContact.departmentId,
        );
      }
    });
  }

  void _onJobChanged(String? value) {
    setState(() {
      _selectedJobId = value;
      if (_manualClientSelection) return;
      final job = _jobById(value);
      if (job == null) return;
      final jobClient = _normalizeClientId(job.clientId);
      if (jobClient != null) {
        _selectedClientId = jobClient;
        _selectedDepartmentId = null;
        _selectedContactPersonId = null;
        _applyClientDependentDefaults(_clientById(jobClient));
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.existing;
    final seed = existing ?? widget.initialDraft;
    final selectedJob = _jobById(_selectedJobId);
    final selectedClient = _clientById(_selectedClientId);
    final selectedDepartment =
        _departmentById(_selectedClientId, _selectedDepartmentId);
    final selectedContact =
        _contactById(_selectedClientId, _selectedContactPersonId);
    final vatPercent = _asDouble(_vatPercentController.text, 21);
    final regiePercent = _asDouble(_regiePercentController.text, 0);
    final profitPercent = _asDouble(_profitPercentController.text, 0);
    final exchangeCommissionPercent = _exchangeCommissionPercent;
    final manualRate = _manualRateValue;
    final bnrRate = _bnrRateValue;
    final effectiveExchangeRate = _effectiveExchangeRate;
    if (OfferCurrencyConverter.requiresRate(_selectedCurrency) &&
        effectiveExchangeRate <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Completeaza un curs $_selectedCurrency valid (manual sau BNR).',
            ),
          ),
        );
      }
      setState(() => _saving = false);
      return;
    }
    final lines = seed?.lines ?? const <OfferLineItem>[];
    final normalizedClauses = [
      for (var i = 0; i < _commercialClauses.length; i++)
        _commercialClauses[i].copyWith(sortOrder: i + 1),
    ];
    final totals = OfferRecord.computeTotals(
      lines: lines,
      vatPercent: vatPercent,
      regiePercent: regiePercent,
      profitPercent: profitPercent,
    );

    String resolvedClientId = _selectedClientId ?? '';
    String resolvedClientName =
        selectedClient?.name ?? (seed?.clientName ?? '');
    if (resolvedClientId.isEmpty && selectedJob != null) {
      final jobClient = _clientById(selectedJob.clientId);
      if (jobClient != null) {
        resolvedClientId = jobClient.id;
        resolvedClientName = jobClient.name;
      }
    }

    final offer = OfferRecord(
      id: seed?.id ?? 'offer-${now.microsecondsSinceEpoch}',
      offerNumber: _offerNumber,
      title: _titleController.text.trim(),
      clientId: resolvedClientId,
      clientName: resolvedClientName,
      clientCui: selectedClient?.cui ?? (seed?.clientCui ?? ''),
      clientAddress: selectedClient?.address ?? (seed?.clientAddress ?? ''),
      clientPhone: selectedClient?.allPhoneNumbers.firstOrNull ?? selectedClient?.phone ?? (seed?.clientPhone ?? ''),
      clientEmail: selectedClient?.email ?? (seed?.clientEmail ?? ''),
      departmentId: selectedDepartment?.id ?? '',
      departmentName: selectedDepartment?.name ?? '',
      contactPersonId: selectedContact?.id ?? '',
      contactPersonName:
          selectedContact?.fullName ?? (seed?.contactPersonName ?? ''),
      contactPersonEmail:
          selectedContact?.email ?? (seed?.contactPersonEmail ?? ''),
      contactPersonPhone:
          selectedContact?.phone ?? (seed?.contactPersonPhone ?? ''),
      beneficiaryClientId: seed?.beneficiaryClientId ?? '',
      beneficiaryName: seed?.beneficiaryName ?? '',
      commercialRecipientClientId:
          seed?.commercialRecipientClientId ?? resolvedClientId,
      commercialRecipientName:
          seed?.commercialRecipientName ?? resolvedClientName,
      complaintId: seed?.complaintId ?? '',
      complaintNumber: seed?.complaintNumber ?? '',
      appointmentId: seed?.appointmentId ?? '',
      equipmentType: seed?.equipmentType ?? '',
      equipmentBrand: seed?.equipmentBrand ?? '',
      equipmentModel: seed?.equipmentModel ?? '',
      outdoorUnitSerial: seed?.outdoorUnitSerial ?? '',
      indoorUnitSerials: seed?.indoorUnitSerials ?? '',
      equipmentDetails: seed?.equipmentDetails ?? '',
      jobId: selectedJob?.id ?? '',
      jobCode: selectedJob?.jobCode ?? (seed?.jobCode ?? ''),
      jobTitle: selectedJob?.title ?? (seed?.jobTitle ?? ''),
      status: _selectedStatus,
      priceDisplayMode: _priceDisplayMode,
      issueDate: _issueDate,
      validUntil: _validUntil,
      currency: _selectedCurrency,
      exchangeRateSource: _exchangeRateSource,
      bnrRate: bnrRate,
      manualRate: manualRate,
      exchangeCommissionPercent: exchangeCommissionPercent,
      effectiveExchangeRate: effectiveExchangeRate,
      notes: _notesController.text.trim(),
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
      lines: lines,
      commercialClauses: normalizedClauses,
      createdAt: seed?.createdAt ?? now,
      updatedAt: now,
      createdByUserId:
          seed?.createdByUserId ?? (widget.currentUserId ?? '').trim(),
      createdByUserEmail:
          seed?.createdByUserEmail ?? (widget.currentUserEmail ?? '').trim(),
      convertedToJobId: seed?.convertedToJobId ?? '',
      convertedAt: seed?.convertedAt,
      convertedByUserId: seed?.convertedByUserId ?? '',
      tipDocument: seed?.tipDocument ??
          widget.defaultTipDocument ??
          TipDocumentDeviz.devizLucrari,
    );

    try {
      await widget.onSave(offer);
      if (!mounted) return;
      Navigator.of(context).pop(offer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la salvare: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipDoc = widget.existing?.tipDocument ??
        widget.initialDraft?.tipDocument ??
        widget.defaultTipDocument ??
        TipDocumentDeviz.devizLucrari;
    final docLabel = tipDoc == TipDocumentDeviz.ofertaLucrari
        ? 'ofertă'
        : tipDoc == TipDocumentDeviz.situatieLucrari
            ? 'situație de lucrări'
            : 'deviz';
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Adaugă $docLabel'
          : 'Editează $docLabel'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          controller: _dialogScrollController,
          primary: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  initialValue: _offerNumber,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Număr ofertă'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titlu ofertă'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Completează titlul ofertei.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedJobId,
                  decoration:
                      const InputDecoration(labelText: 'Lucrare asociată'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Fără lucrare asociată'),
                    ),
                    ...widget.jobs.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.jobCode.trim().isEmpty
                            ? item.title
                            : '${item.jobCode} - ${item.title}'),
                      ),
                    ),
                  ],
                  onChanged: _onJobChanged,
                ),
                const SizedBox(height: 8),
                ClientAutocompleteField(
                  key: ValueKey('offer-client-${_selectedClientId ?? 'none'}'),
                  clients: _localClients,
                  initialClient: _clientById(_selectedClientId),
                  labelText: 'Client',
                  onClientSelected: (c) => _onClientChanged(c?.id),
                  repository: widget.repository,
                  tipEntitate: 'Client',
                  onClientAdded: (c) => setState(() {
                    _localClients = [..._localClients, c];
                    _selectedClientId = c.id;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _normalizeDepartmentId(
                    _selectedClientId,
                    _selectedDepartmentId,
                  ),
                  decoration:
                      const InputDecoration(labelText: 'Departament client'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Fara departament'),
                    ),
                    ..._departmentsForClient(_selectedClientId).map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (_selectedClientId ?? '').trim().isEmpty
                      ? null
                      : _onDepartmentChanged,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _normalizeContactPersonId(
                    _selectedClientId,
                    _selectedContactPersonId,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Persoana de contact',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Fara persoana de contact'),
                    ),
                    ..._filteredContactsForSelection().map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(
                          item.role.trim().isEmpty
                              ? item.fullName
                              : '${item.fullName} - ${item.role.trim()}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (_selectedClientId ?? '').trim().isEmpty
                      ? null
                      : _onContactChanged,
                ),
                if (_contactById(_selectedClientId, _selectedContactPersonId) !=
                    null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      [
                        if ((_contactById(
                                  _selectedClientId,
                                  _selectedContactPersonId,
                                )?.email ??
                                '')
                            .trim()
                            .isNotEmpty)
                          'Email: ${_contactById(_selectedClientId, _selectedContactPersonId)!.email.trim()}',
                        if ((_contactById(
                                  _selectedClientId,
                                  _selectedContactPersonId,
                                )?.phone ??
                                '')
                            .trim()
                            .isNotEmpty)
                          'Tel: ${_contactById(_selectedClientId, _selectedContactPersonId)!.phone.trim()}',
                      ].join(' | '),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<OfferStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: OfferStatus.values
                      .map(
                        (item) => DropdownMenuItem<OfferStatus>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedStatus = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<OfferPriceDisplayMode>(
                  initialValue: _priceDisplayMode,
                  decoration: const InputDecoration(
                    labelText: 'Afișare prețuri',
                  ),
                  items: OfferPriceDisplayMode.values
                      .map(
                        (item) => DropdownMenuItem<OfferPriceDisplayMode>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _priceDisplayMode = value;
                      _priceDisplayModeTouched = true;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickIssueDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Data emitere: ${_formatDate(_issueDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickValidUntil,
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          'Valabil până la: ${_formatDate(_validUntil)}',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_validUntil != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _validUntil = null),
                      icon: const Icon(Icons.clear),
                      label: const Text('Șterge valabilitatea'),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'RON',
                            child: Text('RON'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'EUR',
                            child: Text('EUR'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'HUF',
                            child: Text('HUF'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedCurrency = value);
                          // Cursul BNR este per-valută: la schimbarea monedei,
                          // reîmprospătează dacă sursa e BNR (altfel s-ar folosi
                          // cursul valutei anterioare).
                          if (OfferCurrencyConverter.requiresRate(value) &&
                              _exchangeRateSource ==
                                  OfferExchangeRateSource.bnr) {
                            _refreshBnrRate();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<OfferExchangeRateSource>(
                        initialValue: _exchangeRateSource,
                        decoration:
                            const InputDecoration(labelText: 'Sursa curs'),
                        items: OfferExchangeRateSource.values
                            .map(
                              (item) =>
                                  DropdownMenuItem<OfferExchangeRateSource>(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _exchangeRateSource = value);
                          if (value == OfferExchangeRateSource.bnr) {
                            _refreshBnrRate();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (OfferCurrencyConverter.requiresRate(_selectedCurrency)) ...[
                  const SizedBox(height: 8),
                  if (_exchangeRateSource == OfferExchangeRateSource.manual)
                    TextFormField(
                      controller: _manualRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Curs manual RON/$_selectedCurrency',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (!OfferCurrencyConverter.requiresRate(
                            _selectedCurrency)) {
                          return null;
                        }
                        if (_exchangeRateSource !=
                            OfferExchangeRateSource.manual) {
                          return null;
                        }
                        final rate = _asDouble(value ?? '', -1);
                        if (rate <= 0) return 'Introdu un curs manual valid.';
                        return null;
                      },
                    ),
                  if (_exchangeRateSource == OfferExchangeRateSource.bnr)
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Curs BNR RON/$_selectedCurrency',
                            ),
                            child: Text(
                              _bnrRateValue > 0
                                  ? _bnrRateValue.toStringAsFixed(4)
                                  : '-',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _loadingBnrRate ? null : _refreshBnrRate,
                          icon: const Icon(Icons.refresh),
                          label: Text(_loadingBnrRate ? '...' : 'Refresh BNR'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _exchangeCommissionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Comision curs %',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (!OfferCurrencyConverter.requiresRate(
                          _selectedCurrency)) {
                        return null;
                      }
                      final commission = _asDouble(value ?? '', -1);
                      if (commission < 0) {
                        return 'Comisionul trebuie să fie >= 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Curs baza: ${_baseExchangeRate > 0 ? _baseExchangeRate.toStringAsFixed(4) : '-'} | '
                      'Curs efectiv: ${_effectiveExchangeRate > 0 ? _effectiveExchangeRate.toStringAsFixed(4) : '-'}',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vatPercentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'TVA %'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final vat = _asDouble(value ?? '', -1);
                    if (vat < 0) return 'TVA trebuie să fie >= 0.';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _regiePercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Regie %'),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final regie = _asDouble(value ?? '', -1);
                          if (regie < 0) return 'Regia trebuie sa fie >= 0.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _profitPercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Profit %'),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final profit = _asDouble(value ?? '', -1);
                          if (profit < 0) {
                            return 'Profitul trebuie sa fie >= 0.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Subtotal materiale: ${_computedTotals.materialSubtotal.toStringAsFixed(2)}'
                    ' • Subtotal manopera: ${_computedTotals.laborSubtotal.toStringAsFixed(2)}\n'
                    'Subtotal direct: ${_computedTotals.subtotalDirect.toStringAsFixed(2)}'
                    ' • Regie: ${_computedTotals.regieValue.toStringAsFixed(2)}'
                    ' • Profit: ${_computedTotals.profitValue.toStringAsFixed(2)}\n'
                    '${_priceDisplayMode == OfferPriceDisplayMode.withoutVat ? 'Subtotal comercial / total fără TVA: ${_computedTotals.subtotalComercial.toStringAsFixed(2)}' : _priceDisplayMode == OfferPriceDisplayMode.withVat ? 'Preț ofertat / total: ${_computedTotals.totalValue.toStringAsFixed(2)}' : 'Subtotal comercial: ${_computedTotals.subtotalComercial.toStringAsFixed(2)} • TVA: ${_computedTotals.vatValue.toStringAsFixed(2)} • Total: ${_computedTotals.totalValue.toStringAsFixed(2)}'}',
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Servicii incluse / Condiții comerciale',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _addCommercialClause,
                              icon: const Icon(Icons.add),
                              label: const Text('Adaugă din șablon'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_commercialClauses.isEmpty)
                          const Text(
                            'Nu există condiții comerciale selectate pentru această ofertă.',
                          )
                        else
                          Column(
                            children: _commercialClauses
                                .toList(growable: false)
                                .map(
                                  (item) => Card(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: ListTile(
                                      title: Text(item.title.trim().isEmpty
                                          ? 'Condiție comercială'
                                          : item.title.trim()),
                                      subtitle: Text(
                                        item.content.trim().isEmpty
                                            ? '-'
                                            : item.content.trim(),
                                      ),
                                      trailing: Wrap(
                                        spacing: 8,
                                        children: [
                                          IconButton(
                                            tooltip: 'Editează',
                                            onPressed: () =>
                                                _editCommercialClause(item),
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'Șterge',
                                            onPressed: () =>
                                                _deleteCommercialClause(item),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Observații'),
                ),
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvare...' : 'Salvează'),
        ),
      ],
    );
  }
}

