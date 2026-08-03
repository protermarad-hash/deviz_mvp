part of '../programari_page.dart';

/// Dialogul de creare/editare programare (tab-uri General/Executie/Financiar)
/// extras din `_ProgramariPageState` FARA nicio schimbare de logica.
/// Extension (nu mixin) pentru a evita circularitatea "on ClassItself";
/// `part of` pastreaza accesul complet la starea privata a paginii.
extension _ProgramariAppointmentFormDialogX on _ProgramariPageState {
  Future<void> _openEditor({
    Appointment? appointment,
    Appointment? draftAppointment,
    DateTime? initialStartDateTime,
    DateTime? initialEndDateTime,
    bool closePageOnSave = false,
  }) async {
    final editorStopwatch = Stopwatch()..start();
    _programariLog('open editor tapped');
    _programariLog('editor preload start');
    await _ensureSecondaryDataReadyForEditor();
    final seedAppointment = appointment ?? draftAppointment;
    final isEditingExisting = appointment != null;
    final titleController =
        TextEditingController(text: seedAppointment?.title ?? '');
    final locationController =
        TextEditingController(text: seedAppointment?.location ?? '');
    final clientController =
        TextEditingController(text: seedAppointment?.clientId ?? '');
    final contractingClientController = TextEditingController(
      text: seedAppointment?.contractingClientId ?? '',
    );
    final notesController =
        TextEditingController(text: seedAppointment?.notes ?? '');
    final typeController =
        TextEditingController(text: seedAppointment?.type ?? 'interventie');
    final priorityController =
        TextEditingController(text: seedAppointment?.priority ?? 'medie');
    final postponementReasonController = TextEditingController(
      text: seedAppointment?.postponementReason ?? '',
    );
    final dialogScrollController = ScrollController();
    String? formError;
    final now = DateTime.now();
    final initialStart = seedAppointment?.effectiveStartDateTime ??
        initialStartDateTime ??
        DateTime(now.year, now.month, now.day, now.hour);
    DateTime selectedStart = initialStart;
    DateTime selectedEnd = seedAppointment?.effectiveEndDateTime ??
        initialEndDateTime ??
        initialStart.add(_ProgramariPageState._defaultCalendarCreateDuration);
    String selectedStatus =
        _normalizeStatusValue(seedAppointment?.status ?? '');
    String selectedRecurrenceRule =
        (seedAppointment?.recurrenceRule.trim().isNotEmpty ?? false)
            ? seedAppointment!.recurrenceRule.trim()
            : 'none';
    List<String> selectedAssignedTeamIds = seedAppointment != null
        ? _appointmentTeamIds(seedAppointment)
        : <String>[];
    // IDs angajaților adăugați automat la selectarea echipei (se pot elimina manual)
    final Set<String> autoAddedEmployeeIds = <String>{};
    String selectedJobId = seedAppointment?.jobId ?? '';
    String selectedClientId = seedAppointment?.clientId ?? '';
    String selectedContractingClientId =
        seedAppointment?.contractingClientId.trim() ?? '';
    String selectedAssignedUserId =
        seedAppointment?.assignedUserId.trim() ?? '';
    String selectedAssignedUserEmail =
        seedAppointment?.assignedUserEmail.trim() ?? '';
    String selectedColorCode = seedAppointment?.colorCode.trim() ?? '';
    List<String> selectedAssignedEmployeeIds = seedAppointment != null
        ? _appointmentEmployeeIds(seedAppointment)
        : <String>[];
    ComplaintVisitType? selectedComplaintVisitType =
        seedAppointment?.complaintVisitType;
    ComplaintVisitOutcome? selectedComplaintVisitOutcome =
        seedAppointment?.complaintVisitOutcome;
    final bool isComplaintAppointment =
        (seedAppointment?.complaintId.trim().isNotEmpty ?? false);
    bool clientManuallyChanged = selectedClientId.trim().isNotEmpty;
    bool teamManuallyChanged = selectedAssignedTeamIds.isNotEmpty;

    final authUserId = (widget.fieldAuthUserId ?? '').trim();
    final authUserEmail = (widget.fieldAuthUserEmail ?? '').trim();
    final userTeamId = (_currentAuthUser?.teamId.trim().isNotEmpty ?? false)
        ? _currentAuthUser!.teamId.trim()
        : (widget.fieldAuthTeamId ?? '').trim();
    final currentEmployeeId = (_currentAuthUser?.employeeId ?? '').trim();
    final isRestrictedOperationalCreate =
        !isEditingExisting && !_canCreateAdministrativeAppointments;

    if (!isEditingExisting) {
      if (selectedAssignedUserId.isEmpty) {
        selectedAssignedUserId = authUserId;
      }
      if (selectedAssignedUserEmail.isEmpty) {
        selectedAssignedUserEmail = authUserEmail;
      }
      if (selectedAssignedEmployeeIds.isEmpty && currentEmployeeId.isNotEmpty) {
        selectedAssignedEmployeeIds = <String>[currentEmployeeId];
      }
      if (selectedAssignedTeamIds.isEmpty) {
        // Setarea explicită a utilizatorului are prioritate față de echipa automată
        if (_defaultAppointmentTeamIds.isNotEmpty) {
          selectedAssignedTeamIds = List<String>.of(_defaultAppointmentTeamIds);
        } else if (userTeamId.isNotEmpty) {
          selectedAssignedTeamIds = <String>[userTeamId];
        } else {
          selectedAssignedTeamIds = _normalizeIdList(
            selectedAssignedEmployeeIds.map(_teamIdFromEmployee),
          );
        }
      }
      if (isRestrictedOperationalCreate) {
        selectedAssignedUserId = authUserId;
        selectedAssignedUserEmail = authUserEmail;
        if (currentEmployeeId.isNotEmpty) {
          selectedAssignedEmployeeIds = <String>[currentEmployeeId];
        }
        final restrictedTeamIds = userTeamId.isNotEmpty
            ? <String>[userTeamId]
            : _normalizeIdList(
                selectedAssignedEmployeeIds.map(_teamIdFromEmployee),
              );
        if (restrictedTeamIds.isNotEmpty) {
          selectedAssignedTeamIds = restrictedTeamIds;
        }
      }
      // Auto-adaugă membrii echipelor pre-selectate la programare nouă
      for (final teamId in selectedAssignedTeamIds) {
        final team =
            _masterTeams.where((t) => t.id == teamId).firstOrNull;
        if (team == null) continue;
        for (final memberId in team.memberIds) {
          if (!selectedAssignedEmployeeIds.contains(memberId)) {
            selectedAssignedEmployeeIds = [
              ...selectedAssignedEmployeeIds,
              memberId,
            ];
            autoAddedEmployeeIds.add(memberId);
          }
        }
      }
    }
    if (isComplaintAppointment && selectedComplaintVisitType == null) {
      selectedComplaintVisitType = ComplaintVisitType.constatare;
    }

    Future<void> pickStartDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedStart,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setDialogState(() {
        selectedStart = DateTime(
          picked.year,
          picked.month,
          picked.day,
          selectedStart.hour,
          selectedStart.minute,
        );
        if (selectedEnd.isBefore(selectedStart)) {
          selectedEnd = selectedStart;
        }
      });
    }

    Future<void> pickEndDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedEnd,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setDialogState(() {
        selectedEnd = DateTime(
          picked.year,
          picked.month,
          picked.day,
          selectedEnd.hour,
          selectedEnd.minute,
        );
        if (selectedEnd.isBefore(selectedStart)) {
          selectedStart = selectedEnd;
        }
      });
    }

    Future<void> pickStartTime(StateSetter setDialogState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: _timeOfDayFromDateTime(selectedStart),
      );
      if (picked == null) return;
      setDialogState(() {
        selectedStart = _withDateAndTime(selectedStart, picked);
        if (selectedEnd.isBefore(selectedStart)) {
          selectedEnd = selectedStart;
        }
      });
    }

    Future<void> pickEndTime(StateSetter setDialogState) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: _timeOfDayFromDateTime(selectedEnd),
      );
      if (picked == null) return;
      setDialogState(() {
        selectedEnd = _withDateAndTime(selectedEnd, picked);
        if (selectedEnd.isBefore(selectedStart)) {
          selectedEnd = selectedStart;
        }
      });
    }

    void applyDurationPreset(StateSetter setDialogState, Duration duration) {
      setDialogState(() {
        selectedEnd = selectedStart.add(duration);
      });
    }

    // Selector rapid de slot: precompletează intervalul COMPLET al slotului
    // (ex: 09:00–12:00 pentru slotul 09-12, deci 3 ore). Utilizatorul poate
    // micșora apoi manual durata din câmpurile de oră — selectorul doar
    // precompletează, NU restricționează ora sau durata.
    void applySlotQuickSelect(StateSetter setDialogState, ProgramareSlot slot) {
      setDialogState(() {
        selectedStart = DateTime(
          selectedStart.year,
          selectedStart.month,
          selectedStart.day,
          slot.startHour,
        );
        selectedEnd = DateTime(
          selectedStart.year,
          selectedStart.month,
          selectedStart.day,
          slot.endHour,
        );
      });
    }

    final teamEntries = <MapEntry<String, String>>[
      ..._teams.map((team) => MapEntry<String, String>(team.id, team.name)),
      ..._masterTeams
          .map((team) => MapEntry<String, String>(team.id, team.name)),
    ];
    final teamMap = <String, String>{};
    for (final entry in teamEntries) {
      final id = entry.key.trim();
      if (id.isEmpty) continue;
      teamMap[id] = entry.value.trim().isEmpty ? id : entry.value;
    }
    final teamOptions = teamMap.entries
        .map((entry) => MapEntry<String, String>(entry.key, entry.value))
        .toList(growable: false);

    // ─── new fields state ────────────────────────────────────────────────────
    String selectedForPartnerId = seedAppointment?.forPartnerId.trim() ?? '';
    String selectedExecutingPartnerId =
        seedAppointment?.executingPartnerId.trim() ?? '';

    // Keys pentru autocomplete — se schimbă când se creează un client/partener nou
    // pentru a forța rebuild-ul cu valoarea inițială actualizată.
    var beneficiarKey = ValueKey('benef_$selectedClientId');
    var contractantKey = ValueKey('contract_$selectedContractingClientId');
    var forPartnerKey = ValueKey('forp_$selectedForPartnerId');
    var execPartnerKey = ValueKey('exepart_$selectedExecutingPartnerId');
    _programariLog('clients count=${_clientRecords.length}');
    _programariLog('partners count=${_partnerRecords.length}');
    _programariLog('jobs count=${_jobRecords.length}');
    final anySyncStartedBeforeDialog = OfflineSyncRuntime.instance.isSyncing;
    _programariLog(
      'editor preload end duration_ms=${editorStopwatch.elapsedMilliseconds}',
    );
    _programariLog(
      'any sync started before dialog? ${anySyncStartedBeforeDialog ? 'true' : 'false'}',
    );
    var dialogShownLogged = false;
    if (!mounted) return;
    final equipmentController = TextEditingController(
      text: seedAppointment?.equipmentDescription ?? '',
    );
    final interventionPriceController = TextEditingController(
      text: (seedAppointment?.interventionPrice ?? 0) > 0
          ? seedAppointment!.interventionPrice.toStringAsFixed(2)
          : '',
    );
    String selectedInterventionPriceCurrency =
        seedAppointment?.interventionPriceCurrency.trim().isEmpty ?? true
            ? 'RON'
            : (seedAppointment?.interventionPriceCurrency ?? 'RON');
    final adminCollectedAmountController = TextEditingController(
      text: (seedAppointment?.adminCollectedAmount ?? 0) > 0
          ? seedAppointment!.adminCollectedAmount.toStringAsFixed(2)
          : '',
    );
    String selectedAdminCollectedCurrency =
        seedAppointment?.adminCollectedCurrency.trim().isEmpty ?? true
            ? 'RON'
            : (seedAppointment?.adminCollectedCurrency ?? 'RON');
    AppointmentFinancialStatus selectedAdminFinancialStatus =
        seedAppointment?.adminFinancialStatus ??
            AppointmentFinancialStatus.neincasata;
    DateTime? selectedAdminDueDate = seedAppointment?.adminDueDate;
    final adminFinancialNotesController = TextEditingController(
      text: seedAppointment?.adminFinancialNotes ?? '',
    );
    // ─── parteneri — câmpuri financiare ──────────────────────────────────────
    final forPartnerInvoiceController = TextEditingController(
      text: (seedAppointment?.forPartnerInvoiceAmount ?? 0) > 0
          ? seedAppointment!.forPartnerInvoiceAmount.toStringAsFixed(2)
          : '',
    );
    String selectedForPartnerInvoiceCurrency =
        (seedAppointment?.forPartnerInvoiceCurrency.trim().isEmpty ?? true)
            ? 'RON'
            : (seedAppointment?.forPartnerInvoiceCurrency ?? 'RON');
    PartnerPaymentStatus selectedForPartnerReceiveStatus =
        seedAppointment?.forPartnerReceiveStatus ??
            PartnerPaymentStatus.neplatit;
    DateTime? selectedForPartnerReceiveDate =
        seedAppointment?.forPartnerReceiveDate;
    final forPartnerReceiveNotesController = TextEditingController(
      text: seedAppointment?.forPartnerReceiveNotes ?? '',
    );
    final executingPartnerCommissionController = TextEditingController(
      text: (seedAppointment?.executingPartnerCommission ?? 0) > 0
          ? seedAppointment!.executingPartnerCommission.toStringAsFixed(2)
          : '',
    );
    String selectedExecutingPartnerCommissionCurrency =
        (seedAppointment?.executingPartnerCommissionCurrency.trim().isEmpty ??
                true)
            ? 'RON'
            : (seedAppointment?.executingPartnerCommissionCurrency ?? 'RON');
    PartnerPaymentStatus selectedExecutingPartnerPaymentStatus =
        seedAppointment?.executingPartnerPaymentStatus ??
            PartnerPaymentStatus.neplatit;
    DateTime? selectedExecutingPartnerPaymentDate =
        seedAppointment?.executingPartnerPaymentDate;
    final executingPartnerPaymentNotesController = TextEditingController(
      text: seedAppointment?.executingPartnerPaymentNotes ?? '',
    );
    final materialUsageNotesController = TextEditingController(
      text: seedAppointment?.materialUsage.notes ?? '',
    );
    String selectedMaterialKitTemplateId =
        seedAppointment?.materialUsage.kitTemplateId.trim() ?? '';
    final materialKitLinearMetersController = TextEditingController(
      text: (seedAppointment?.materialUsage.linearMetersUsed ?? 0) > 0
          ? seedAppointment!.materialUsage.linearMetersUsed.toStringAsFixed(2)
          : '',
    );

    List<AppointmentMaterialKitTemplate> availableMaterialKits() {
      final selectedId = selectedMaterialKitTemplateId.trim();
      return _materialKitTemplates.where((template) {
        if (template.isActive) {
          return true;
        }
        return selectedId.isNotEmpty && template.id == selectedId;
      }).toList(growable: false);
    }

    AppointmentMaterialKitTemplate? findSelectedMaterialKit() {
      final selectedId = selectedMaterialKitTemplateId.trim();
      for (final template in _materialKitTemplates) {
        if (template.id == selectedId) {
          return template;
        }
      }
      return null;
    }

    AppointmentMaterialUsage buildMaterialUsage() {
      final template = findSelectedMaterialKit();
      if (template == null) {
        if (seedAppointment != null &&
            seedAppointment.materialUsage.kitTemplateId.trim() ==
                selectedMaterialKitTemplateId.trim()) {
          return seedAppointment.materialUsage.copyWith(
            linearMetersUsed: asDouble(materialKitLinearMetersController.text),
            notes: materialUsageNotesController.text.trim(),
          );
        }
        return AppointmentMaterialUsage(
          kitTemplateId: selectedMaterialKitTemplateId.trim(),
          kitTemplateName: '',
          linearMetersUsed: asDouble(materialKitLinearMetersController.text),
          notes: materialUsageNotesController.text.trim(),
        );
      }
      final meters = asDouble(materialKitLinearMetersController.text);
      final lines = template.components
          .map((component) {
            final quantity = component.resolvedQuantity(meters);
            if (quantity <= 0) {
              return null;
            }
            return AppointmentMaterialUsageLine(
              id: component.id,
              materialId: component.materialId,
              name: component.name,
              unit: component.unit,
              quantity: quantity,
              unitCost: component.unitCost,
              isVariableLength: component.isVariableLength,
              quantityPerLinearMeter: component.quantityPerLinearMeter,
            );
          })
          .whereType<AppointmentMaterialUsageLine>()
          .toList(growable: false);
      return AppointmentMaterialUsage(
        kitTemplateId: template.id,
        kitTemplateName: template.name,
        linearMetersUsed: meters,
        lines: lines,
        notes: materialUsageNotesController.text.trim(),
      );
    }

    Future<void> pickAdminDueDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedAdminDueDate ?? selectedStart,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      setDialogState(() => selectedAdminDueDate = picked);
    }

    // ── Employee pay — pre-populate controllers ───────────────────────────────
    final employeePayControllers = <String, TextEditingController>{};
    var employeePayEntriesLoadConclusive = !isEditingExisting;
    if (isEditingExisting) {
      List<EmployeePayEntry> existingPayEntries = const [];
      try {
        final payLoad = await EmployeeFinancialRepository.instance
            .loadPayEntriesForAppointmentWithSyncStatus(appointment.id);
        existingPayEntries = payLoad.entries;
        employeePayEntriesLoadConclusive = payLoad.isConclusive;
        if (!employeePayEntriesLoadConclusive) {
          _programariLog(
            'employee pay preload inconclusive appointment=${appointment.id}',
          );
        }
      } catch (error) {
        employeePayEntriesLoadConclusive = false;
        _programariLog(
          'employee pay preload error appointment=${appointment.id} error=$error',
        );
      }
      for (final e in existingPayEntries) {
        if (e.amountDue > 0) {
          employeePayControllers[e.employeeId] = TextEditingController(
            text: e.amountDue.toStringAsFixed(2),
          );
          // NU adăugăm automat în selectedAssignedEmployeeIds — un angajat
          // cu PayEntry vechi dar dezalocat trebuie să apară ca "dezalocat"
          // în UI și PayEntry-ul lui să se șteargă la salvare.
        }
      }
    } else {
      // Programare nouă: pre-completăm cu tarifele prestabilite din Firestore
      final defaultSettings = await EmployeeFinancialRepository.instance
          .loadAllEmployeeSettings();
      for (final empId in selectedAssignedEmployeeIds) {
        final defaultRate =
            defaultSettings[empId]?.defaultPayPerAppointment;
        if (defaultRate != null && defaultRate > 0) {
          employeePayControllers[empId] = TextEditingController(
            text: defaultRate.toStringAsFixed(2),
          );
        }
      }
    }
    if (!mounted) return;

    // Capturate la salvare pentru dialogul de confirmare WhatsApp
    String clientNameForWhatsApp = '';
    String phoneForWhatsApp = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        if (!dialogShownLogged) {
          dialogShownLogged = true;
          _programariLog(
            'dialog shown after ${editorStopwatch.elapsedMilliseconds} ms',
          );
        }
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewMaterialUsage = buildMaterialUsage();
            final previewMaterialKit = findSelectedMaterialKit();
            final kitOptions = availableMaterialKits();
            return AlertDialog(
              title: Text(
                isEditingExisting ? 'Editeaza programarea' : 'Programare noua',
              ),
              content: SizedBox(
                width: 620,
                height: MediaQuery.of(dialogContext).size.height * 0.8,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.event_note_outlined),
                            text: 'General',
                          ),
                          Tab(
                            icon: Icon(Icons.build_outlined),
                            text: 'Execuție',
                          ),
                          Tab(
                            icon: Icon(Icons.euro_outlined),
                            text: 'Financiar',
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // TAB 0: General
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.sm),
                      _formSection(
                        context,
                        title: 'Programare',
                        helper: 'Datele principale ale interventiei.',
                        children: [
                          ValueListenableBuilder<List<ServiciuPrestat>>(
                            valueListenable: _serviciiPrestateNotifier,
                            builder: (context, serviciiList, _) {
                              return ServiciuAutocompleteField(
                                controller: titleController,
                                servicii: serviciiList,
                                labelText: 'Titlu programare',
                                helperText:
                                    'Scrie liber sau alege un serviciu din catalog (cu pret).',
                                onServiceSelected: (serviciu) {
                                  // Titlul e setat automat de Autocomplete (= denumire).
                                  if (serviciu.pretSugerat <= 0) {
                                    return;
                                  }
                                  setDialogState(() {
                                    // ÎNTOTDEAUNA în „Suma incasata / de incasat"
                                    // (tab Financiar, admin-only).
                                    if (_canManageAppointmentFinancials) {
                                      adminCollectedAmountController.text =
                                          serviciu.pretSugerat.toStringAsFixed(2);
                                    }
                                    // DOAR dacă serviciul e marcat „Vizibil la
                                    // Execuție" → și în „Preț intervenție", ca
                                    // echipa de teren să vadă prețul. Altfel câmpul
                                    // rămâne neschimbat.
                                    if (serviciu.vizibilLaExecutie) {
                                      interventionPriceController.text =
                                          serviciu.pretSugerat.toStringAsFixed(2);
                                      selectedInterventionPriceCurrency =
                                          serviciu.moneda;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Slot rapid (optional)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final slot in kProgramareSloturi)
                                ChoiceChip(
                                  label: Text(slot.rangeLabel),
                                  selected:
                                      slot.containsHour(selectedStart.hour),
                                  backgroundColor: slot.backgroundColor,
                                  onSelected: (_) => applySlotQuickSelect(
                                    setDialogState,
                                    slot,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickStartDate(setDialogState),
                                  icon: const Icon(Icons.event_outlined),
                                  label: Text(
                                    'Data inceput: ${_formatDate(selectedStart)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      pickStartTime(setDialogState),
                                  icon: const Icon(Icons.schedule_outlined),
                                  label: Text(
                                    'Ora inceput: ${_formatTime(selectedStart)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickEndDate(setDialogState),
                                  icon: const Icon(
                                      Icons.event_available_outlined),
                                  label: Text(
                                    'Data final: ${_formatDate(selectedEnd)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => pickEndTime(setDialogState),
                                  icon: const Icon(Icons.timer_outlined),
                                  label: Text(
                                    'Ora final: ${_formatTime(selectedEnd)}',
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
                              AppStatusChip(
                                label:
                                    'Durata: ${_durationLabel(selectedEnd.difference(selectedStart))}',
                                status: AppStatusKind.neutral,
                                icon: Icons.timelapse,
                              ),
                              ActionChip(
                                label: const Text('1 ora'),
                                onPressed: () => applyDurationPreset(
                                  setDialogState,
                                  const Duration(hours: 1),
                                ),
                              ),
                              ActionChip(
                                label: const Text('2 ore'),
                                onPressed: () => applyDurationPreset(
                                  setDialogState,
                                  const Duration(hours: 2),
                                ),
                              ),
                              ActionChip(
                                label: const Text('3 ore'),
                                onPressed: () => applyDurationPreset(
                                  setDialogState,
                                  const Duration(hours: 3),
                                ),
                              ),
                              ActionChip(
                                label: const Text('4 ore'),
                                onPressed: () => applyDurationPreset(
                                  setDialogState,
                                  const Duration(hours: 4),
                                ),
                              ),
                              ActionChip(
                                label: const Text('1 zi'),
                                onPressed: () => applyDurationPreset(
                                  setDialogState,
                                  const Duration(days: 1),
                                ),
                              ),
                              if (selectedEnd.isBefore(selectedStart))
                                const AppStatusChip(
                                  label: 'Interval invalid',
                                  status: AppStatusKind.anulata,
                                  icon: Icons.error_outline,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: _ProgramariPageState._statusOptions
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status.key,
                                    child: Text(status.value),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) => setDialogState(
                              () => selectedStatus = value ?? 'planificata',
                            ),
                          ),
                        ],
                      ),
                                  const SizedBox(height: 12),
                      _formSection(
                        context,
                        title: 'Client si context',
                        helper:
                            'Beneficiarul ramane separat de societatea pentru care executi lucrarea.',
                        children: [
                          if (_clients.isEmpty)
                            Column(
                              children: [
                                TextField(
                                  textCapitalization: TextCapitalization.sentences,
                                  controller: clientController,
                                  decoration: const InputDecoration(
                                    labelText: 'Beneficiar (ID)',
                                  ),
                                  onChanged: (value) {
                                    selectedClientId = value.trim();
                                    clientManuallyChanged = true;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  textCapitalization: TextCapitalization.sentences,
                                  controller: contractingClientController,
                                  decoration: const InputDecoration(
                                    labelText: 'Societate contractanta (ID)',
                                  ),
                                  onChanged: (value) {
                                    selectedContractingClientId = value.trim();
                                  },
                                ),
                              ],
                            )
                          else ...[
                            ClientAutocompleteField(
                              key: beneficiarKey,
                              clients: _clientRecords,
                              initialClient:
                                  _clientRecordByIdMap[selectedClientId],
                              labelText: 'Beneficiar',
                              helperText: 'Clientul real al lucrarii',
                              onClientSelected: (client) {
                                setDialogState(() {
                                  selectedClientId =
                                      (client?.id ?? '').trim();
                                  clientManuallyChanged = true;
                                  // Auto-populare locație din adresa clientului
                                  if (client != null &&
                                      locationController.text.trim().isEmpty) {
                                    if (client.address.trim().isNotEmpty) {
                                      locationController.text =
                                          client.address.trim();
                                    }
                                  }
                                });
                              },
                              repository: widget.repository,
                              tipEntitate: 'Beneficiar',
                              onClientAdded: (newClient) {
                                // Actualizează page state
                                // ignore: invalid_use_of_protected_member
                                setState(() {
                                  _clientRecords = <ClientRecord>[
                                    ..._clientRecords.where(
                                      (item) => item.id != newClient.id,
                                    ),
                                    newClient,
                                  ];
                                  _clientRecordByIdMap = {
                                    for (final c in _clientRecords)
                                      if (c.id.trim().isNotEmpty) c.id: c,
                                  };
                                });
                                // Actualizează dialog state
                                setDialogState(() {
                                  selectedClientId = newClient.id;
                                  clientManuallyChanged = true;
                                  beneficiarKey = ValueKey(
                                    'benef_${newClient.id}',
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            ClientAutocompleteField(
                              key: contractantKey,
                              clients: _clientRecords,
                              initialClient: _clientRecordByIdMap[
                                  selectedContractingClientId],
                              labelText: 'Societate contractantă',
                              helperText: 'Firma pentru care execuți lucrarea',
                              onClientSelected: (client) {
                                setDialogState(() {
                                  selectedContractingClientId =
                                      (client?.id ?? '').trim();
                                  contractantKey = ValueKey(
                                    'contract_${client?.id ?? 'none'}',
                                  );
                                });
                              },
                              repository: widget.repository,
                              tipEntitate: 'Client',
                              onClientAdded: (newClient) {
                                // Actualizează page state
                                // ignore: invalid_use_of_protected_member
                                setState(() {
                                  _clientRecords = [
                                    ..._clientRecords,
                                    newClient,
                                  ];
                                  _clientRecordByIdMap = {
                                    for (final c in _clientRecords)
                                      if (c.id.trim().isNotEmpty) c.id: c,
                                  };
                                });
                                // Actualizează dialog state
                                setDialogState(() {
                                  selectedContractingClientId = newClient.id;
                                  contractantKey =
                                      ValueKey('contract_${newClient.id}');
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: locationController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Adresa / locatie',
                              helperText:
                                  'Locatia exacta in care se va merge la interventie.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _jobs.any((j) => j.id == selectedJobId)
                                    ? selectedJobId
                                    : null,
                            decoration: const InputDecoration(
                              labelText: 'Lucrare asociata / cod lucrare',
                            ),
                            items: _jobs
                                .map(
                                  (job) => DropdownMenuItem<String>(
                                    value: job.id,
                                    child: Text(job.name),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) => setDialogState(() {
                              selectedJobId = (value ?? '').trim();
                              final linkedClientId =
                                  _jobClientById[selectedJobId]?.trim() ?? '';
                              if (!clientManuallyChanged &&
                                  linkedClientId.isNotEmpty) {
                                selectedClientId = linkedClientId;
                              }
                            }),
                          ),
                        ],
                      ),
                                  if (!isComplaintAppointment) ...[
                                    const SizedBox(height: 12),
                        _formSection(
                          context,
                          title: 'Recurență',
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: selectedRecurrenceRule,
                              decoration: const InputDecoration(
                                labelText: 'Repetare automată',
                                helperText:
                                    'La salvare se creează automat programări pentru anii următori.',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Fără recurență'),
                                ),
                                DropdownMenuItem(
                                  value: 'annual',
                                  child: Text('Anual (service / mentenanță)'),
                                ),
                              ],
                              onChanged: isEditingExisting
                                  ? null
                                  : (v) => setDialogState(
                                        () => selectedRecurrenceRule =
                                            v ?? 'none',
                                      ),
                            ),
                            if (selectedRecurrenceRule == 'annual' &&
                                !isEditingExisting)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Se vor crea automat 3 programări: cea curentă + 1 an + 2 ani.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                                  ],
                                  const SizedBox(height: 12),
                      _formSection(
                        context,
                        title: 'Note si detalii',
                        children: [
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Observatii',
                            ),
                          ),
                          const SizedBox(height: 12),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: const Text('Detalii suplimentare'),
                            children: [
                              TextField(
                                textCapitalization: TextCapitalization.sentences,
                                controller: typeController,
                                decoration: const InputDecoration(
                                  labelText: 'Tip',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                textCapitalization: TextCapitalization.sentences,
                                controller: priorityController,
                                decoration: const InputDecoration(
                                  labelText: 'Prioritate',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Culoare in programari',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label:
                                        const Text('Auto dupa echipa / status'),
                                    selected: selectedColorCode.isEmpty,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setDialogState(
                                      () => selectedColorCode = '',
                                    ),
                                  ),
                                  for (final preset in _ProgramariPageState._appointmentColorPresets)
                                    ChoiceChip(
                                      avatar: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: preset.color,
                                      ),
                                      label: Text(preset.label),
                                      selected: selectedColorCode ==
                                          _colorCodeFromColor(preset.color),
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setDialogState(
                                        () => selectedColorCode =
                                            _colorCodeFromColor(preset.color),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Builder(builder: (context) {
                                // Derive the preview color the same way
                                // _appointmentAccentColor does at runtime.
                                Color previewColor;
                                String previewLabel;
                                if (selectedColorCode.isNotEmpty) {
                                  previewColor =
                                      _colorFromCode(selectedColorCode) ??
                                          _statusAccentColor(selectedStatus);
                                  previewLabel =
                                      _appointmentColorLabel(selectedColorCode);
                                } else {
                                  // Check if any selected team has a color.
                                  Color? teamColor;
                                  for (final teamId
                                      in selectedAssignedTeamIds) {
                                    for (final team in _masterTeams) {
                                      if (team.id == teamId &&
                                          team.colorValue != 0) {
                                        teamColor = Color(team.colorValue);
                                        break;
                                      }
                                    }
                                    if (teamColor != null) break;
                                  }
                                  if (teamColor != null) {
                                    previewColor = teamColor;
                                    previewLabel = 'Culoare echipa';
                                  } else {
                                    previewColor =
                                        _statusAccentColor(selectedStatus);
                                    previewLabel =
                                        'Status: ${_statusLabel(selectedStatus)}';
                                  }
                                }
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color.alphaBlend(
                                      previewColor.withValues(alpha: 0.12),
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          previewColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: previewColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Preview: $previewLabel',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
                                  const SizedBox(height: AppSpacing.md),
                                ],
                              ),
                            ),
                            // TAB 1: Execuție
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.sm),
                      _formSection(
                        context,
                        title: 'Alocare',
                        helper: isRestrictedOperationalCreate
                            ? 'Programarea noua se creeaza pe propria persoana si propria echipa.'
                            : 'Poti aloca mai multe echipe si mai multe persoane pe aceeasi programare.',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isRestrictedOperationalCreate
                                      ? null
                                      : () async {
                                          final nextSelection =
                                              await _openMultiSelectDialog(
                                            title: 'Echipe alocate',
                                            emptyLabel:
                                                'Nu exista echipe disponibile.',
                                            options: teamOptions,
                                            initialSelectedIds:
                                                selectedAssignedTeamIds,
                                          );
                                          if (nextSelection == null) {
                                            return;
                                          }
                                          setDialogState(() {
                                            final prevTeams =
                                                Set<String>.from(
                                              selectedAssignedTeamIds,
                                            );
                                            final nextTeams =
                                                Set<String>.from(nextSelection);
                                            selectedAssignedTeamIds =
                                                nextSelection;
                                            teamManuallyChanged = true;
                                            // Elimină angajații auto din echipele scoase
                                            final removedTeams =
                                                prevTeams.difference(nextTeams);
                                            for (final tid in removedTeams) {
                                              final t = _masterTeams
                                                  .where((x) => x.id == tid)
                                                  .firstOrNull;
                                              if (t == null) {
                                                continue;
                                              }
                                              for (final mid
                                                  in t.memberIds) {
                                                if (autoAddedEmployeeIds
                                                    .contains(mid)) {
                                                  selectedAssignedEmployeeIds =
                                                      selectedAssignedEmployeeIds
                                                          .where(
                                                            (id) => id != mid,
                                                          )
                                                          .toList();
                                                  autoAddedEmployeeIds
                                                      .remove(mid);
                                                }
                                              }
                                            }
                                            // Adaugă angajații din echipele noi
                                            final addedTeams =
                                                nextTeams.difference(prevTeams);
                                            for (final tid in addedTeams) {
                                              final t = _masterTeams
                                                  .where((x) => x.id == tid)
                                                  .firstOrNull;
                                              if (t == null) {
                                                continue;
                                              }
                                              for (final mid
                                                  in t.memberIds) {
                                                if (!selectedAssignedEmployeeIds
                                                    .contains(mid)) {
                                                  selectedAssignedEmployeeIds =
                                                      [
                                                    ...selectedAssignedEmployeeIds,
                                                    mid,
                                                  ];
                                                  autoAddedEmployeeIds
                                                      .add(mid);
                                                }
                                              }
                                            }
                                          });
                                        },
                                  icon: const Icon(Icons.groups_outlined),
                                  label: Text(
                                    selectedAssignedTeamIds.isEmpty
                                        ? 'Selecteaza echipe'
                                        : 'Echipe alocate (${selectedAssignedTeamIds.length})',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _selectionSummaryWrap(
                            labels: _teamNamesFromIds(selectedAssignedTeamIds),
                            icon: Icons.groups_outlined,
                            emptyLabel: 'Nicio echipa selectata.',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isRestrictedOperationalCreate
                                      ? null
                                      : () async {
                                          final nextSelection =
                                              await _openMultiSelectDialog(
                                            title: 'Persoane alocate',
                                            emptyLabel:
                                                'Nu exista persoane disponibile.',
                                            options: _masterEmployees
                                                .map(
                                                  (employee) =>
                                                      MapEntry<String, String>(
                                                    employee.id,
                                                    employee.role.trim().isEmpty
                                                        ? employee.name
                                                        : '${employee.name} (${employee.role})',
                                                  ),
                                                )
                                                .toList(growable: false),
                                            initialSelectedIds:
                                                selectedAssignedEmployeeIds,
                                          );
                                          if (nextSelection == null) {
                                            return;
                                          }
                                          setDialogState(() {
                                            // Angajații eliminați manual → scot flag-ul auto
                                            final removed =
                                                selectedAssignedEmployeeIds
                                                    .where(
                                                      (id) => !nextSelection
                                                          .contains(id),
                                                    )
                                                    .toSet();
                                            autoAddedEmployeeIds
                                                .removeAll(removed);
                                            selectedAssignedEmployeeIds =
                                                nextSelection;
                                            if (!teamManuallyChanged) {
                                              selectedAssignedTeamIds =
                                                  _normalizeIdList(
                                                selectedAssignedEmployeeIds
                                                    .map(_teamIdFromEmployee),
                                              );
                                            }
                                          });
                                        },
                                  icon:
                                      const Icon(Icons.person_search_outlined),
                                  label: Text(
                                    selectedAssignedEmployeeIds.isEmpty
                                        ? 'Selecteaza persoane'
                                        : 'Persoane alocate (${selectedAssignedEmployeeIds.length})',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _selectionSummaryWrap(
                            labels: _employeeNamesFromIds(
                              selectedAssignedEmployeeIds,
                            ),
                            icon: Icons.person_outline,
                            emptyLabel: 'Nicio persoana selectata.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Utilizator alocat: ${selectedAssignedUserEmail.trim().isEmpty ? '-' : selectedAssignedUserEmail.trim()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                                  const SizedBox(height: 12),
                      // ── Overlap warning ──────────────────────────────────
                      Builder(builder: (ctx) {
                        final currentId =
                            isEditingExisting ? appointment.id : '';
                        final conflicting = _items.where((a) {
                          if (a.id == currentId) return false;
                          if (_normalizeStatusValue(a.status) == 'anulata') {
                            return false;
                          }
                          final aStart = a.effectiveStartDateTime;
                          final aEnd = a.effectiveEndDateTime;
                          if (!aEnd.isAfter(selectedStart) ||
                              !aStart.isBefore(selectedEnd)) {
                            return false;
                          }
                          final aTeams = _appointmentTeamIds(a).toSet();
                          return selectedAssignedTeamIds.any(aTeams.contains);
                        }).toList(growable: false);
                        if (conflicting.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final duration = selectedEnd.difference(selectedStart);
                        final suggested = _findFirstFreeSlotForTeams(
                          teamIds: selectedAssignedTeamIds,
                          fromTime: selectedStart,
                          duration: duration.isNegative
                              ? const Duration(hours: 1)
                              : duration,
                          excludeId: currentId.isEmpty ? null : currentId,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Suprapunere cu ${conflicting.length} programare(i) ale aceleiasi echipe:\n'
                                      '${conflicting.map((a) => '• ${a.title.trim().isEmpty ? a.id : a.title.trim()}  '
                                          '(${_formatTime(a.effectiveStartDateTime)}-${_formatTime(a.effectiveEndDateTime)})').join('\n')}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (suggested != null &&
                                  suggested != selectedStart) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Text(
                                      'Primul interval liber: '
                                      '${_formatDate(suggested)} '
                                      '${_formatTime(suggested)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    ActionChip(
                                      label: const Text('Adopta intervalul'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => setDialogState(() {
                                        final dur = selectedEnd
                                            .difference(selectedStart);
                                        selectedStart = suggested;
                                        selectedEnd = suggested.add(
                                          dur.isNegative
                                              ? const Duration(hours: 1)
                                              : dur,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Poti continua si programa in paralel.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        );
                      }),
                                  if (isComplaintAppointment) ...[
                                    const SizedBox(height: 12),
                        _formSection(
                          context,
                          title: 'Vizita pe reclamatie',
                          helper:
                              'Aceste campuri descriu vizita in contextul cazului, fara sa schimbe statusul general al reclamatiei.',
                          children: [
                            DropdownButtonFormField<ComplaintVisitType>(
                              initialValue: selectedComplaintVisitType,
                              decoration: const InputDecoration(
                                labelText: 'Tip vizita',
                              ),
                              items: _ProgramariPageState._complaintVisitTypes
                                  .map(
                                    (entry) =>
                                        DropdownMenuItem<ComplaintVisitType>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) => setDialogState(
                                () => selectedComplaintVisitType = value,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ComplaintVisitOutcome?>(
                              initialValue: selectedComplaintVisitOutcome,
                              decoration: const InputDecoration(
                                labelText: 'Rezultat vizita',
                              ),
                              items: <DropdownMenuItem<ComplaintVisitOutcome?>>[
                                const DropdownMenuItem<ComplaintVisitOutcome?>(
                                  value: null,
                                  child: Text('Neselectat'),
                                ),
                                ..._ProgramariPageState._complaintVisitOutcomes.map(
                                  (entry) =>
                                      DropdownMenuItem<ComplaintVisitOutcome?>(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setDialogState(
                                () => selectedComplaintVisitOutcome = value,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              textCapitalization: TextCapitalization.sentences,
                              controller: postponementReasonController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Motiv amanare / reprogramare',
                                helperText:
                                    'Se foloseste doar cand vizita a fost amanata sau reprogramata.',
                              ),
                            ),
                          ],
                        ),
                                  ],
                                  const SizedBox(height: 12),
                                  _formSection(
                                    context,
                                    title: 'Intervenție și echipament',
                                    helper:
                                        'Echipamentul, prețul intervenției și materialele folosite.',
                                    children: [
                          TextField(
                            controller: equipmentController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Echipament / instalatie',
                              helperText:
                                  'Descrie echipamentul la care se intervine sau se monteaza.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: interventionPriceController,
                                  enabled: _canEditInterventionPrice,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Preț intervenție',
                                    helperText: _canEditInterventionPrice
                                        ? 'Vizibil și pentru angajați pe teren.'
                                        : 'Setat de administrator.',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedInterventionPriceCurrency,
                                  decoration: const InputDecoration(
                                    labelText: 'Monedă',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'RON',
                                      child: Text('RON'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'EUR',
                                      child: Text('EUR'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'USD',
                                      child: Text('USD'),
                                    ),
                                  ],
                                  onChanged: _canEditInterventionPrice
                                      ? (v) => setDialogState(
                                            () => selectedInterventionPriceCurrency =
                                                v ?? 'RON',
                                          )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _formSection(
                            context,
                            title: 'Materiale folosite',
                            helper:
                                'Angajatul selecteaza doar kitul si cantitatea de ml folosita. Materialele fixe raman conform retetei definite de administrator.',
                            children: [
                              if (_canManageAppointmentMaterialKits)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () async {
                                      await _openKitTemplatesAdminPage();
                                      if (!context.mounted) return;
                                      setDialogState(() {});
                                    },
                                    icon: const Icon(Icons.settings_outlined),
                                    label: const Text('Administreaza kituri'),
                                  ),
                                ),
                              DropdownButtonFormField<String>(
                                initialValue: kitOptions.any(
                                  (template) =>
                                      template.id == selectedMaterialKitTemplateId,
                                )
                                    ? selectedMaterialKitTemplateId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Kit materiale',
                                ),
                                items: <DropdownMenuItem<String>>[
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('Fara kit'),
                                  ),
                                  ...kitOptions.map(
                                    (template) => DropdownMenuItem<String>(
                                      value: template.id,
                                      child: Text(template.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setDialogState(() {
                                  selectedMaterialKitTemplateId =
                                      (value ?? '').trim();
                                  final selectedTemplate =
                                      findSelectedMaterialKit();
                                  if (selectedTemplate != null &&
                                      asDouble(materialKitLinearMetersController.text) <=
                                          0 &&
                                      selectedTemplate.defaultLinearMeters > 0) {
                                    materialKitLinearMetersController.text =
                                        selectedTemplate.defaultLinearMeters
                                            .toStringAsFixed(2);
                                  }
                                }),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: materialKitLinearMetersController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Cantitate folosita (ml)',
                                  helperText:
                                      'Aceasta valoare recalculeaza doar componentele variabile din reteta.',
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                              if (previewMaterialKit != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  previewMaterialKit.description.trim().isEmpty
                                      ? 'Reteta selectata: ${previewMaterialKit.name}'
                                      : previewMaterialKit.description.trim(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextField(
                                textCapitalization: TextCapitalization.sentences,
                                controller: materialUsageNotesController,
                                minLines: 2,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Observatii materiale',
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                              if (previewMaterialUsage.lines.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                for (final line in previewMaterialUsage.lines)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(line.name),
                                    subtitle: Text(
                                      '${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} ${line.unit}${line.isVariableLength ? ' | variabil' : ' | fix'}',
                                    ),
                                    trailing: _canManageAppointmentFinancials
                                        ? Text(
                                            '${line.totalCost.toStringAsFixed(2)} RON',
                                          )
                                        : null,
                                  ),
                              ],
                            ],
                          ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                              ),
                            ),
                            // TAB 2: Financiar
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.sm),
                                  if (_canManageAppointmentFinancials) ...[
                            _formSection(
                              context,
                              title: 'Evidenta administrator',
                              helper:
                                  'Zona interna pentru incasari, termene si profitabilitate. Angajatii nu vad aceste campuri.',
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: adminCollectedAmountController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Suma incasata / de incasat',
                                        ),
                                        onChanged: (_) => setDialogState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue:
                                            selectedAdminCollectedCurrency,
                                        decoration: const InputDecoration(
                                          labelText: 'Moneda',
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'RON',
                                            child: Text('RON'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'EUR',
                                            child: Text('EUR'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'USD',
                                            child: Text('USD'),
                                          ),
                                        ],
                                        onChanged: (value) => setDialogState(
                                          () => selectedAdminCollectedCurrency =
                                              value ?? 'RON',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<AppointmentFinancialStatus>(
                                  initialValue: selectedAdminFinancialStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Status financiar',
                                  ),
                                  items: AppointmentFinancialStatus.values
                                      .map(
                                        (status) => DropdownMenuItem<
                                            AppointmentFinancialStatus>(
                                          value: status,
                                          child: Text(status.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) => setDialogState(
                                    () => selectedAdminFinancialStatus =
                                        value ??
                                        AppointmentFinancialStatus.neincasata,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          pickAdminDueDate(setDialogState),
                                      icon: const Icon(Icons.event_outlined),
                                      label: Text(
                                        selectedAdminDueDate == null
                                            ? 'Scadenta / data incasare'
                                            : 'Scadenta: ${_formatDate(selectedAdminDueDate!)}',
                                      ),
                                    ),
                                    if (selectedAdminDueDate != null)
                                      TextButton(
                                        onPressed: () => setDialogState(
                                          () => selectedAdminDueDate = null,
                                        ),
                                        child: const Text('Sterge data'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  textCapitalization: TextCapitalization.sentences,
                                  controller: adminFinancialNotesController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Observatii financiare',
                                    helperText:
                                        'Exemplu: contract lunar, plata la 30 zile, diferenta de incasat etc.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Builder(builder: (_) {
                                  final costMat =
                                      previewMaterialUsage.totalCost;
                                  final costAng =
                                      selectedAssignedEmployeeIds.fold<double>(
                                    0.0,
                                    (s, empId) {
                                      final ctrl =
                                          employeePayControllers[empId];
                                      if (ctrl == null) return s;
                                      return s +
                                          (double.tryParse(
                                                ctrl.text.replaceAll(
                                                  ',',
                                                  '.',
                                                ),
                                              ) ??
                                              0.0);
                                    },
                                  );
                                  final totalCosturi = costMat + costAng;
                                  final incasare = asDouble(
                                    adminCollectedAmountController.text,
                                  );
                                  final profit = incasare - totalCosturi;
                                  final hasAngajati = costAng > 0;

                                  Widget profRow(
                                    String label,
                                    String value, {
                                    bool bold = false,
                                  }) =>
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              label,
                                              style: bold
                                                  ? const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    )
                                                  : TextStyle(
                                                      color:
                                                          Colors.grey[600],
                                                    ),
                                            ),
                                            Text(
                                              value,
                                              style: bold
                                                  ? const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      );

                                  return AppCard(
                                    elevated: true,
                                    accentColor: profit >= 0
                                        ? Colors.green.shade800
                                        : Colors.red.shade700,
                                    margin: EdgeInsets.zero,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Profitabilitate estimată',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          profRow(
                                            'Cost materiale:',
                                            '${costMat.toStringAsFixed(2)} RON',
                                          ),
                                          if (hasAngajati)
                                            profRow(
                                              'Cost angajați:',
                                              '${costAng.toStringAsFixed(2)} RON',
                                            ),
                                          if (hasAngajati) ...[
                                            const Divider(height: 12),
                                            profRow(
                                              'Total costuri:',
                                              '${totalCosturi.toStringAsFixed(2)} RON',
                                            ),
                                          ],
                                          profRow(
                                            'Încasare:',
                                            '${incasare.toStringAsFixed(2)} $selectedAdminCollectedCurrency',
                                          ),
                                          const Divider(height: 12),
                                          Padding(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Profit estimat:',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${profit.toStringAsFixed(2)} $selectedAdminCollectedCurrency',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: profit >= 0
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  );
                                }),
                              ],
                            ),
                                    const SizedBox(height: 12),
                                  ],
                                  _formSection(
                                    context,
                                    title: 'Partener beneficiar',
                                    helper:
                                        'Partenerul în numele căruia execuți lucrarea.',
                                    children: [
                          PartnerAutocompleteField(
                            key: forPartnerKey,
                            partners: _partnerRecords,
                            initialPartner: _partnerRecords.where(
                              (p) => p.id == selectedForPartnerId,
                            ).firstOrNull,
                            labelText: 'Montez pentru partener',
                            helperText:
                                'Partenerul în numele căruia execuți lucrarea',
                            onPartnerSelected: (partner) {
                              setDialogState(() {
                                selectedForPartnerId =
                                    (partner?.id ?? '').trim();
                              });
                            },
                            onCreateNew: () async {
                              final created =
                                  await _openQuickCreatePartnerDialog();
                              if (created == null || !mounted) {
                                return;
                              }
                              final nextPartners =
                                  await widget.repository.listPartners();
                              if (!mounted) return;
                              // ignore: invalid_use_of_protected_member
                              setState(() {
                                _partnerRecords = <PartnerRecord>[
                                  ...nextPartners.where(
                                    (p) => p.id != created.id,
                                  ),
                                  created,
                                ];
                              });
                              setDialogState(() {
                                selectedForPartnerId = created.id;
                                forPartnerKey =
                                    ValueKey('forp_${created.id}');
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Partener creat și selectat: ${created.name.trim().isEmpty ? created.id : created.name.trim()}',
                                  ),
                                ),
                              );
                            },
                          ),
                          // Câmpuri financiare partener contractant (admin only)
                          if (_canManageAppointmentFinancials) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: forPartnerInvoiceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Valoare de încasat de la partener',
                                      helperText: 'Suma pe care o facturezi partenerului contractant.',
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedForPartnerInvoiceCurrency,
                                    decoration: const InputDecoration(
                                      labelText: 'Monedă',
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'RON', child: Text('RON')),
                                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    ],
                                    onChanged: (v) => setDialogState(
                                      () => selectedForPartnerInvoiceCurrency = v ?? 'RON',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PartnerPaymentStatus>(
                              initialValue: selectedForPartnerReceiveStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status încasare partener',
                              ),
                              items: PartnerPaymentStatus.values
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s.label),
                                      ))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                () => selectedForPartnerReceiveStatus =
                                    v ?? PartnerPaymentStatus.neplatit,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedForPartnerReceiveDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => selectedForPartnerReceiveDate = picked);
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                    label: Text(
                                      selectedForPartnerReceiveDate != null
                                          ? 'Încasat pe: ${selectedForPartnerReceiveDate!.day.toString().padLeft(2, '0')}.${selectedForPartnerReceiveDate!.month.toString().padLeft(2, '0')}.${selectedForPartnerReceiveDate!.year}'
                                          : 'Data încasare partener',
                                    ),
                                  ),
                                ),
                                if (selectedForPartnerReceiveDate != null)
                                  IconButton(
                                    onPressed: () => setDialogState(() => selectedForPartnerReceiveDate = null),
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Șterge data',
                                  ),
                              ],
                            ),
                          ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _formSection(
                                    context,
                                    title: 'Partener executant',
                                    helper:
                                        'Partenerul pe care l-ai trimis să facă lucrarea.',
                                    children: [
                          PartnerAutocompleteField(
                            key: execPartnerKey,
                            partners: _partnerRecords,
                            initialPartner: _partnerRecords.where(
                              (p) => p.id == selectedExecutingPartnerId,
                            ).firstOrNull,
                            labelText: 'Partener trimis să execute',
                            helperText:
                                'Partenerul pe care l-ai trimis să facă lucrarea',
                            onPartnerSelected: (partner) {
                              setDialogState(() {
                                selectedExecutingPartnerId =
                                    (partner?.id ?? '').trim();
                              });
                            },
                            onCreateNew: () async {
                              final created =
                                  await _openQuickCreatePartnerDialog();
                              if (created == null || !mounted) {
                                return;
                              }
                              final nextPartners =
                                  await widget.repository.listPartners();
                              if (!mounted) return;
                              // ignore: invalid_use_of_protected_member
                              setState(() {
                                _partnerRecords = <PartnerRecord>[
                                  ...nextPartners.where(
                                    (p) => p.id != created.id,
                                  ),
                                  created,
                                ];
                              });
                              setDialogState(() {
                                selectedExecutingPartnerId = created.id;
                                execPartnerKey =
                                    ValueKey('exepart_${created.id}');
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Partener creat și selectat: ${created.name.trim().isEmpty ? created.id : created.name.trim()}',
                                  ),
                                ),
                              );
                            },
                          ),
                          // Câmpuri financiare partener executant (admin only)
                          if (_canManageAppointmentFinancials) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: executingPartnerCommissionController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Comision partener executant',
                                      helperText: 'Suma pe care o datorezi partenerului care execută.',
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedExecutingPartnerCommissionCurrency,
                                    decoration: const InputDecoration(
                                      labelText: 'Monedă',
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'RON', child: Text('RON')),
                                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    ],
                                    onChanged: (v) => setDialogState(
                                      () => selectedExecutingPartnerCommissionCurrency = v ?? 'RON',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<PartnerPaymentStatus>(
                              initialValue: selectedExecutingPartnerPaymentStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status plată partener executant',
                              ),
                              items: PartnerPaymentStatus.values
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s.label),
                                      ))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                () => selectedExecutingPartnerPaymentStatus =
                                    v ?? PartnerPaymentStatus.neplatit,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedExecutingPartnerPaymentDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => selectedExecutingPartnerPaymentDate = picked);
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                    label: Text(
                                      selectedExecutingPartnerPaymentDate != null
                                          ? 'Plătit pe: ${selectedExecutingPartnerPaymentDate!.day.toString().padLeft(2, '0')}.${selectedExecutingPartnerPaymentDate!.month.toString().padLeft(2, '0')}.${selectedExecutingPartnerPaymentDate!.year}'
                                          : 'Data plată partener',
                                    ),
                                  ),
                                ),
                                if (selectedExecutingPartnerPaymentDate != null)
                                  IconButton(
                                    onPressed: () => setDialogState(() => selectedExecutingPartnerPaymentDate = null),
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Șterge data',
                                  ),
                              ],
                            ),
                          ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _formSection(
                                    context,
                                    title: 'Plată angajați',
                                    helper:
                                        'Sumele datorate fiecărui angajat alocat pe această programare.',
                                    children: [
                                      Builder(builder: (_) {
                                        final deallocatedIds =
                                            employeePayControllers.keys
                                                .where(
                                                  (id) =>
                                                      !selectedAssignedEmployeeIds
                                                          .contains(id),
                                                )
                                                .toList();
                                        final hasAny =
                                            selectedAssignedEmployeeIds
                                                    .isNotEmpty ||
                                                deallocatedIds.isNotEmpty;
                                        if (!hasAny) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'Alocați mai întâi persoane în tab-ul Execuție.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ── Angajați alocați — editabili ──
                                            for (final empId
                                                in selectedAssignedEmployeeIds)
                                              Builder(builder: (ctx) {
                                                final emp =
                                                    _masterEmployees.firstWhere(
                                                  (e) => e.id == empId,
                                                  orElse: () => MasterEmployee(
                                                    id: empId,
                                                    name: empId,
                                                    role: '',
                                                    active: true,
                                                  ),
                                                );
                                                final ctrl =
                                                    employeePayControllers
                                                        .putIfAbsent(
                                                  empId,
                                                  () => TextEditingController(),
                                                );
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          emp.name
                                                                  .trim()
                                                                  .isEmpty
                                                              ? empId
                                                              : emp.name,
                                                        ),
                                                      ),
                                                      const SizedBox(width: AppSpacing.sm),
                                                      SizedBox(
                                                        width: 130,
                                                        child: TextField(
                                                          controller: ctrl,
                                                          keyboardType:
                                                              const TextInputType
                                                                  .numberWithOptions(
                                                                  decimal: true),
                                                          textAlign:
                                                              TextAlign.end,
                                                          decoration:
                                                              const InputDecoration(
                                                            labelText: 'Sumă',
                                                            suffixText: 'RON',
                                                            isDense: true,
                                                          ),
                                                          onChanged: (_) =>
                                                              setDialogState(
                                                                  () {}),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            // ── Angajați dezalocați — read-only,
                                            //    excluși din Total, șterși la save ──
                                            for (final empId in deallocatedIds)
                                              Builder(builder: (ctx) {
                                                final emp =
                                                    _masterEmployees.firstWhere(
                                                  (e) => e.id == empId,
                                                  orElse: () => MasterEmployee(
                                                    id: empId,
                                                    name: empId,
                                                    role: '',
                                                    active: true,
                                                  ),
                                                );
                                                final oldAmount = asDouble(
                                                  employeePayControllers[empId]
                                                          ?.text ??
                                                      '',
                                                );
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              emp.name
                                                                      .trim()
                                                                      .isEmpty
                                                                  ? empId
                                                                  : emp.name,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .outline,
                                                              ),
                                                            ),
                                                            Text(
                                                              'dezalocat — nu se plătește',
                                                              style: Theme.of(
                                                                context,
                                                              )
                                                                  .textTheme
                                                                  .labelSmall
                                                                  ?.copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .outline,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: AppSpacing.sm),
                                                      SizedBox(
                                                        width: 130,
                                                        child: Text(
                                                          '${oldAmount.toStringAsFixed(2)} RON',
                                                          textAlign:
                                                              TextAlign.end,
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .outline,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            if (selectedAssignedEmployeeIds
                                                .isNotEmpty) ...[
                                              const Divider(height: 16),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Total angajați: ${selectedAssignedEmployeeIds.fold<double>(0, (acc, empId) { final ctrl = employeePayControllers[empId]; return acc + asDouble(ctrl?.text ?? ''); }).toStringAsFixed(2)} RON',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    final saveStopwatch = Stopwatch()..start();
                    _programariLog('save tapped');
                    if (selectedEnd.isBefore(selectedStart)) {
                      setDialogState(() {
                        formError =
                            'Intervalul este invalid. Finalul trebuie sa fie dupa inceput.';
                      });
                      return;
                    }
                    final seedStart = seedAppointment?.effectiveStartDateTime;
                    final seedEnd = seedAppointment?.effectiveEndDateTime;
                    final scheduleChanged = seedStart != null &&
                        seedEnd != null &&
                        (seedStart != selectedStart || seedEnd != selectedEnd);
                    final enforcedAssignedEmployeeIds =
                        isRestrictedOperationalCreate &&
                                currentEmployeeId.isNotEmpty
                            ? <String>[currentEmployeeId]
                            : _normalizeIdList(selectedAssignedEmployeeIds);
                    final enforcedAssignedTeamIds =
                        isRestrictedOperationalCreate
                            ? (userTeamId.isNotEmpty
                                ? <String>[userTeamId]
                                : _normalizeIdList(
                                    enforcedAssignedEmployeeIds
                                        .map(_teamIdFromEmployee),
                                  ))
                            : _normalizeIdList(selectedAssignedTeamIds);
                    final enforcedAssignedUserId = isRestrictedOperationalCreate
                        ? authUserId
                        : selectedAssignedUserId.trim();
                    final enforcedAssignedUserEmail =
                        isRestrictedOperationalCreate
                            ? authUserEmail
                            : selectedAssignedUserEmail.trim();
                    final resolvedLocation = _resolvedLocationForSelection(
                      selectedClientId: selectedClientId,
                      selectedJobId: selectedJobId,
                      preferredValue: locationController.text,
                    );
                    final resolvedContactPerson =
                        _resolvedContactPersonForSelection(
                      selectedClientId: selectedClientId,
                      selectedJobId: selectedJobId,
                      preferredValue: seedAppointment?.contactPerson ?? '',
                    );
                    final resolvedContactPhone = _resolvedPhoneForSelection(
                      selectedClientId: selectedClientId,
                      selectedJobId: selectedJobId,
                      preferredValue: seedAppointment?.contactPhone ?? '',
                    );
                    final resolvedContactEmail = _resolvedEmailForSelection(
                      selectedClientId: selectedClientId,
                      selectedJobId: selectedJobId,
                      preferredValue: seedAppointment?.contactEmail ?? '',
                    );
                    final item = Appointment(
                      id: isEditingExisting
                          ? appointment.id
                          : DateTime.now().microsecondsSinceEpoch.toString(),
                      clientId: selectedClientId.trim(),
                      clientName: _resolvedClientName(
                        selectedClientId,
                        seedAppointment?.clientName ?? '',
                      ),
                      contractingClientId: selectedContractingClientId.trim(),
                      contractingClientName: _resolvedClientName(
                        selectedContractingClientId,
                        seedAppointment?.contractingClientName ?? '',
                      ),
                      contactPerson: resolvedContactPerson,
                      contactPhone: resolvedContactPhone,
                      contactEmail: resolvedContactEmail,
                      title: titleController.text.trim(),
                      location: resolvedLocation,
                      scheduledDate: _dateOnly(selectedStart),
                      startTime: _formatTime(selectedStart),
                      endTime: _formatTime(selectedEnd),
                      startDateTime: selectedStart,
                      endDateTime: selectedEnd,
                      teamId: enforcedAssignedTeamIds.isNotEmpty
                          ? enforcedAssignedTeamIds.first
                          : '',
                      assignedTeamIds: enforcedAssignedTeamIds,
                      assignedUserId: enforcedAssignedUserId,
                      assignedUserEmail: enforcedAssignedUserEmail,
                      assignedEmployeeIds: enforcedAssignedEmployeeIds,
                      vehicleId: seedAppointment?.vehicleId ?? '',
                      complaintVisitType: isComplaintAppointment
                          ? selectedComplaintVisitType
                          : null,
                      complaintVisitOutcome: isComplaintAppointment
                          ? selectedComplaintVisitOutcome
                          : null,
                      postponementReason: isComplaintAppointment
                          ? postponementReasonController.text.trim()
                          : '',
                      rescheduledFromStartDateTime: isComplaintAppointment &&
                              scheduleChanged &&
                              postponementReasonController.text
                                  .trim()
                                  .isNotEmpty
                          ? seedStart
                          : seedAppointment?.rescheduledFromStartDateTime,
                      rescheduledFromEndDateTime: isComplaintAppointment &&
                              scheduleChanged &&
                              postponementReasonController.text
                                  .trim()
                                  .isNotEmpty
                          ? seedEnd
                          : seedAppointment?.rescheduledFromEndDateTime,
                      type: typeController.text.trim(),
                      priority: priorityController.text.trim(),
                      colorCode: selectedColorCode,
                      status: selectedStatus,
                      jobId: selectedJobId.trim(),
                      complaintId: seedAppointment?.complaintId ?? '',
                      complaintNumber: seedAppointment?.complaintNumber ?? '',
                      notes: notesController.text.trim(),
                      linkedDocuments: seedAppointment?.linkedDocuments ??
                          const <AppointmentLinkedDocument>[],
                      recurrenceRule: selectedRecurrenceRule,
                      recurringGroupId: isEditingExisting
                          ? (seedAppointment?.recurringGroupId ?? '')
                          : (selectedRecurrenceRule != 'none'
                              ? DateTime.now().microsecondsSinceEpoch.toString()
                              : ''),
                      forPartnerId: selectedForPartnerId,
                      forPartnerName: _partnerRecords
                              .where((p) => p.id == selectedForPartnerId)
                              .map((p) => p.name)
                              .firstOrNull ??
                          '',
                      executingPartnerId: selectedExecutingPartnerId,
                      executingPartnerName: _partnerRecords
                              .where((p) => p.id == selectedExecutingPartnerId)
                              .map((p) => p.name)
                              .firstOrNull ??
                          '',
                      equipmentDescription: equipmentController.text.trim(),
                      interventionPrice: double.tryParse(
                            interventionPriceController.text
                                .trim()
                                .replaceAll(',', '.'),
                          ) ??
                          0,
                      interventionPriceCurrency:
                          selectedInterventionPriceCurrency,
                      adminCollectedAmount:
                          asDouble(adminCollectedAmountController.text),
                      adminCollectedCurrency: selectedAdminCollectedCurrency,
                      adminFinancialStatus: selectedAdminFinancialStatus,
                      adminDueDate: selectedAdminDueDate,
                      adminFinancialNotes:
                          adminFinancialNotesController.text.trim(),
                      materialUsage: buildMaterialUsage(),
                      executingPartnerCommission: asDouble(
                        executingPartnerCommissionController.text,
                      ),
                      executingPartnerCommissionCurrency:
                          selectedExecutingPartnerCommissionCurrency,
                      executingPartnerPaymentStatus:
                          selectedExecutingPartnerPaymentStatus,
                      executingPartnerPaymentDate:
                          selectedExecutingPartnerPaymentDate,
                      executingPartnerPaymentNotes:
                          executingPartnerPaymentNotesController.text.trim(),
                      forPartnerInvoiceAmount:
                          asDouble(forPartnerInvoiceController.text),
                      forPartnerInvoiceCurrency:
                          selectedForPartnerInvoiceCurrency,
                      forPartnerReceiveStatus: selectedForPartnerReceiveStatus,
                      forPartnerReceiveDate: selectedForPartnerReceiveDate,
                      forPartnerReceiveNotes:
                          forPartnerReceiveNotesController.text.trim(),
                    );
                    // Build employee pay data from controllers
                    final employeePayData = <String, double>{};
                    for (final empId in enforcedAssignedEmployeeIds) {
                      final ctrl = employeePayControllers[empId];
                      if (ctrl != null) {
                        final amount = asDouble(ctrl.text);
                        if (amount > 0) employeePayData[empId] = amount;
                      }
                    }
                    _programariLog('local save start');
                    // 1. Salvare locală — instant (cu mem cache)
                    await _saveAppointmentResolved(item);
                    _programariLog(
                      'local save end duration_ms=${saveStopwatch.elapsedMilliseconds}',
                    );
                    // Capturare date WhatsApp pentru confirmarea post-save
                    if (!isEditingExisting) {
                      clientNameForWhatsApp = item.clientName.trim();
                      phoneForWhatsApp = item.contactPhone.trim().isNotEmpty
                          ? item.contactPhone.trim()
                          : (item.clientPhoneNumbers.isNotEmpty
                              ? item.clientPhoneNumbers.first.trim()
                              : '');
                    }
                    // 2. Închide dialogul IMEDIAT — UI răspunde instant
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                    _programariLog(
                      'dialog closed after ${saveStopwatch.elapsedMilliseconds} ms',
                    );
                    // 3. Operații secundare în BACKGROUND — nu blochează UI
                    // (fiecare poate dura 1-10s pe Firestore lent)
                    _startBackgroundTask(
                      'history background',
                      () => _writeAppointmentHistory(
                        item: item,
                        action: isEditingExisting ? 'update' : 'create',
                        previous: isEditingExisting ? appointment : null,
                      ),
                    );
                    _startBackgroundTask(
                      'partner financial sync',
                      () => _syncPartnerFinancialFromAppointment(
                        item,
                        previous: isEditingExisting ? appointment : null,
                      ),
                    );
                    // Copii recurente în background
                    if (!isEditingExisting &&
                        selectedRecurrenceRule == 'annual') {
                      _startBackgroundTask('recurrence background', () async {
                        for (var yearOffset = 1;
                            yearOffset <= 2;
                            yearOffset++) {
                          final futureStart = selectedStart.copyWith(
                            year: selectedStart.year + yearOffset,
                          );
                          final futureEnd = selectedEnd.copyWith(
                            year: selectedEnd.year + yearOffset,
                          );
                          final copy = item.copyWith(
                            id: '${item.id}_r$yearOffset',
                            scheduledDate: _dateOnly(futureStart),
                            startDateTime: futureStart,
                            endDateTime: futureEnd,
                            status: 'planificata',
                          );
                          await _saveAppointmentResolved(copy);
                        }
                      });
                    }
                    _startBackgroundTask(
                      'notification background',
                      () => _notifyAppointmentSaved(
                        item: item,
                        previous: isEditingExisting ? appointment : null,
                      ),
                    );
                    if (widget.onAppointmentSaved != null) {
                      _startBackgroundTask(
                        'onAppointmentSaved callback',
                        () => widget.onAppointmentSaved!(item),
                      );
                    }
                    // Rulăm background task dacă avem sume de salvat SAU dacă
                    // editam o programare existentă (pentru a șterge PayEntry-urile
                    // angajaților dezalocați din Firestore).
                    if (employeePayData.isNotEmpty || isEditingExisting) {
                      final savedItem = item;
                      final savedAuthUserId = authUserId;
                      final savedIsEditing = isEditingExisting;
                      final savedCanDeleteMissingPayEntries =
                          canDeleteMissingEmployeePayEntries(
                        isEditingExisting: savedIsEditing,
                        payEntriesLoadConclusive:
                            employeePayEntriesLoadConclusive,
                      );
                      final savedPayData =
                          Map<String, double>.from(employeePayData);
                      _startBackgroundTask('employee pay save', () async {
                        final payRepo = EmployeeFinancialRepository.instance;
                        // Sync din Firestore înainte de INSERT/UPDATE previne
                        // duplicate dacă local cache e gol (cross-device sau
                        // după reinstall). Query doar când localul e gol.
                        final existing = await payRepo
                            .listPayEntriesForAppointmentWithSync(savedItem.id);
                        // 1. Salvare/actualizare pentru angajații alocați
                        for (final entry in savedPayData.entries) {
                          final empId = entry.key;
                          final amount = entry.value;
                          final emp = _masterEmployees.firstWhere(
                            (e) => e.id == empId,
                            orElse: () => MasterEmployee(
                              id: empId,
                              name: empId,
                              role: '',
                              active: true,
                            ),
                          );
                          final existingEntry = existing
                              .where((e) => e.employeeId == empId)
                              .firstOrNull;
                          if (existingEntry != null) {
                            await payRepo.savePayEntry(
                              existingEntry.copyWith(amountDue: amount),
                            );
                          } else {
                            await payRepo.savePayEntry(
                              EmployeePayEntry.create(
                                appointmentId: savedItem.id,
                                appointmentTitle: savedItem.title,
                                appointmentDate: savedItem.effectiveStartDateTime
                                    .toIso8601String()
                                    .substring(0, 10),
                                employeeId: empId,
                                employeeName: emp.name,
                                amountDue: amount,
                                currency: 'RON',
                                notes: '',
                                createdBy: savedAuthUserId,
                              ),
                            );
                          }
                        }
                        // 2. Ștergere PayEntry pentru angajați dezalocați sau
                        // cu sumă 0. Previne reapariția sumelor vechi după
                        // dezalocare + curăță istoricul la prima salvare.
                        if (savedCanDeleteMissingPayEntries &&
                            existing.isNotEmpty) {
                          final allocatedIds = savedPayData.keys.toSet();
                          for (final oldEntry in existing) {
                            if (!allocatedIds
                                .contains(oldEntry.employeeId)) {
                              await payRepo.deletePayEntry(oldEntry.id);
                            }
                          }
                        }
                      });
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

    dialogScrollController.dispose();
    if (!mounted) return;
    if (saved == true) {
      // Reîncarcă NUMAI programările (nu și clienți/echipe/lucrări) — mult mai rapid
      await _reloadAppointmentsOnly();
      // Confirmare WhatsApp pentru programări noi cu telefon disponibil
      if (!isEditingExisting && mounted) {
        _maybeOfferWhatsAppConfirmation(
          clientName: clientNameForWhatsApp,
          phone: phoneForWhatsApp,
          titlu: titleController.text.trim(),
          start: selectedStart,
          location: locationController.text.trim(),
        );
      }
      if (closePageOnSave && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
    }

    titleController.dispose();
    locationController.dispose();
    clientController.dispose();
    contractingClientController.dispose();
    notesController.dispose();
    typeController.dispose();
    priorityController.dispose();
    postponementReasonController.dispose();
    equipmentController.dispose();
    interventionPriceController.dispose();
    adminCollectedAmountController.dispose();
    adminFinancialNotesController.dispose();
    materialUsageNotesController.dispose();
    materialKitLinearMetersController.dispose();
    for (final ctrl in employeePayControllers.values) {
      ctrl.dispose();
    }
  }

  Future<void> _handleGpsCheckin(Appointment item) async {
    final activeCheckin =
        await GpsCheckinService.instance.getActiveCheckin(item.id);
    if (!mounted) return;
    final isCheckedIn = activeCheckin != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCheckedIn ? 'Check-out GPS' : 'Check-in GPS'),
        content: Text(isCheckedIn
            ? 'Confirmati check-out (ati terminat la locatie)?'
            : 'Confirmati ca sunteti la locatia: ${item.location.isEmpty ? item.title : item.location}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuleaza')),
          FilledButton.icon(
            icon: Icon(isCheckedIn
                ? Icons.logout_outlined
                : Icons.location_on_outlined),
            label: Text(isCheckedIn ? 'Check-out' : 'Check-in'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final GpsCheckinResult result;
    if (isCheckedIn) {
      result = await GpsCheckinService.instance.checkOut(
        appointmentId: item.id,
        adresaLocatie: item.location,
      );
    } else {
      result = await GpsCheckinService.instance.checkIn(
        appointmentId: item.id,
        adresaLocatie: item.location,
      );
    }
    if (!mounted) return;
    if (!result.success) {
      messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? 'Eroare GPS')));
      return;
    }
    if (!result.inRaza && !isCheckedIn) {
      final dist = result.distanta?.toStringAsFixed(0) ?? '?';
      final continua = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Esti departe de locatie'),
          content: Text('Distanta fata de adresa programarii: $dist m.\n'
              'Doriti sa inregistrati oricum prezenta?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuleaza')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Inregistreaza')),
          ],
        ),
      );
      if (continua != true) return;
    }
    final tip = isCheckedIn ? 'Check-out' : 'Check-in';
    final razaMsg = result.inRaza ? ' ✅' : ' ⚠️ (departe de locatie)';
    messenger.showSnackBar(
      SnackBar(
        content: Text('$tip inregistrat$razaMsg'),
        backgroundColor: result.inRaza ? Colors.green : Colors.orange,
      ),
    );
  }
}
