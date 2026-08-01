part of '../programari_page.dart';

/// Panoul de detalii/actiuni al unei programari (AlertDialog cu tot
/// continutul detaliat) extras din `_ProgramariPageState` FARA nicio
/// schimbare de logica. Extension (nu mixin) pentru a evita circularitatea
/// "on ClassItself"; `part of` pastreaza accesul complet la starea
/// privata a paginii.
extension _ProgramariAppointmentDetailsPanelX on _ProgramariPageState {
  Future<void> _openDetails(Appointment item) async {
    final clientLabel = _resolvedClientName(item.clientId, item.clientName);
    final contractingLabel = _resolvedClientName(
      item.contractingClientId,
      item.contractingClientName,
    );
    final teamLabels = _teamNamesFromIds(_appointmentTeamIds(item));
    final assignedEmployeeLabels =
        _employeeNamesFromIds(_appointmentEmployeeIds(item));
    final teamLabel = _summarizeLabels(teamLabels);
    final assignedEmployeeLabel = _summarizeLabels(assignedEmployeeLabels);
    final contactPerson = _detailContactPerson(item);
    final phone = _detailPhone(item);
    final email = _detailEmail(item);
    final intervalLabel =
        '${_formatDateTime(item.effectiveStartDateTime)} - ${_formatDateTime(item.effectiveEndDateTime)}';
    // Compute client address from client record (not just from appointment location)
    final clientRec = _clientRecordById(item.clientId);
    final clientAddrParts = <String>[
      if ((clientRec?.address ?? '').trim().isNotEmpty)
        clientRec!.address.trim(),
      if ((clientRec?.city ?? '').trim().isNotEmpty) clientRec!.city.trim(),
      if ((clientRec?.county ?? '').trim().isNotEmpty) clientRec!.county.trim(),
    ];
    final clientAddrFromRecord = clientAddrParts.join(', ');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            item.title.trim().isEmpty
                ? 'Detaliu programare'
                : item.title.trim(),
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusChip(item.status),
                      if (!_isEmployeeRole) _appointmentColorChip(item),
                      if (!_isEmployeeRole) _linkedDocumentsChip(item),
                      _buildQuickDocumentMenu(item),
                      Chip(
                        avatar: const Icon(Icons.timelapse, size: 16),
                        label: Text(_durationLabel(item.effectiveDuration)),
                      ),
                      if (!_isEmployeeRole)
                        Chip(
                          avatar: const Icon(Icons.group_outlined, size: 16),
                          label: Text(teamLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  // Quick status action buttons - shown inline as Wrap
                  Builder(builder: (ctx) {
                    final statusBtns =
                        _buildQuickStatusDialogActions(item, dialogContext);
                    if (statusBtns.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: statusBtns,
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  _formSection(
                    dialogContext,
                    title: 'Contact si locatie',
                    children: [
                      // Tappable client chip + buton editare date client (vizibil pt toți)
                      Row(
                        children: [
                          if (item.clientId.trim().isNotEmpty)
                            ActionChip(
                              avatar: const Icon(Icons.person_outlined, size: 16),
                              label: Text(clientLabel),
                              onPressed: () => _showClientInfoDialog(
                                dialogContext,
                                item.clientId,
                                clientLabel,
                              ),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Editează'),
                            onPressed: () => _showClientDataEditDialog(dialogContext, item),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _detailLine('Beneficiar real', clientLabel),
                      if (!_isEmployeeRole &&
                          (item.contractingClientId.trim().isNotEmpty ||
                              item.contractingClientName.trim().isNotEmpty))
                        _detailLine('Societate contractanta', contractingLabel),
                      _detailLine('Adresa / locatie', _detailAddress(item)),
                      // Address from client record (always shown if available)
                      if (clientAddrFromRecord.isNotEmpty)
                        _detailLine(
                            'Adresa din fisa client', clientAddrFromRecord),
                      _detailLine('Persoana de contact', contactPerson),
                      // Afișare multiple telefoane
                      if (item.clientPhoneNumbers.isNotEmpty)
                        ...item.clientPhoneNumbers.map((p) => _detailLine(
                          item.clientPhoneNumbers.length == 1
                              ? 'Telefon client'
                              : 'Telefon ${item.clientPhoneNumbers.indexOf(p) + 1}',
                          p,
                          onTap: p.trim().isEmpty
                              ? null
                              : () => _launchExternalUri(
                                    dialogContext,
                                    Uri(scheme: 'tel', path: _phoneUriValue(p)),
                                    failureLabel: 'dialerul',
                                  ),
                        ))
                      else
                        _detailLine(
                          'Telefon client',
                          phone,
                          onTap: phone.trim().isEmpty
                              ? null
                              : () => _launchExternalUri(
                                    dialogContext,
                                    Uri(
                                      scheme: 'tel',
                                      path: _phoneUriValue(phone),
                                    ),
                                    failureLabel: 'dialerul',
                                  ),
                        ),
                      _detailLine(
                        'Email client',
                        email,
                        onTap: email.trim().isEmpty
                            ? null
                            : () => _launchExternalUri(
                                  dialogContext,
                                  Uri(
                                    scheme: 'mailto',
                                    path: email.trim(),
                                  ),
                                  failureLabel: 'clientul de email',
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isEmployeeRole)
                    _formSection(
                      dialogContext,
                      title: 'Detalii interventie',
                      children: [
                        _detailLine('Data / interval', intervalLabel),
                        _detailLine('Status', _statusLabel(item.status)),
                        if (item.equipmentDescription.trim().isNotEmpty)
                          _detailLine(
                            'Echipament / instalatie',
                            item.equipmentDescription.trim(),
                          ),
                        if (item.interventionPrice > 0)
                          _detailLine(
                            'Pret interventie',
                            '${item.interventionPrice.toStringAsFixed(2)} ${item.interventionPriceCurrency}',
                          ),
                        if (item.materialUsage.kitTemplateName.trim().isNotEmpty)
                          _detailLine(
                            'Kit materiale',
                            item.materialUsage.kitTemplateName.trim(),
                          ),
                        if (item.materialUsage.linearMetersUsed > 0)
                          _detailLine(
                            'Cantitate folosita',
                            '${item.materialUsage.linearMetersUsed.toStringAsFixed(2)} ml',
                          ),
                        if (item.materialUsage.lines.isNotEmpty)
                          _detailLine(
                            'Materiale consumate',
                            item.materialUsage.lines
                                .map(
                                  (line) =>
                                      '${line.name} (${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} ${line.unit})',
                                )
                                .join(', '),
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _openEmployeeMaterialUsageDialog(item);
                            },
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('Completeaza materiale'),
                          ),
                        ),
                      ],
                    )
                  else
                    _formSection(
                      dialogContext,
                      title: 'Programare si alocare',
                      children: [
                        _detailLine('Data / interval', intervalLabel),
                        _detailLine('Status', _statusLabel(item.status)),
                        _detailLine(
                            'Prioritate', _priorityLabel(item.priority)),
                        _detailLine(
                          'Culoare planner',
                          _appointmentColorLabel(item.colorCode),
                        ),
                        if (_isComplaintAppointment(item))
                          _detailLine(
                            'Tip vizita',
                            _complaintVisitTypeLabel(item.complaintVisitType),
                          ),
                        if (_isComplaintAppointment(item))
                          _detailLine(
                            'Rezultat vizita',
                            _complaintVisitOutcomeLabel(
                                item.complaintVisitOutcome),
                          ),
                        _detailLine('Echipe alocate', teamLabel),
                        if (teamLabels.length > 1)
                          _detailLine('Toate echipele', teamLabels.join(', ')),
                        _detailLine(
                          'Persoane alocate',
                          assignedEmployeeLabel,
                        ),
                        if (assignedEmployeeLabels.length > 1)
                          _detailLine(
                            'Toate persoanele',
                            assignedEmployeeLabels.join(', '),
                          ),
                        _detailLine(
                            'Utilizator alocat', item.assignedUserEmail.trim()),
                        _detailLine('Lucrare asociata', _jobLabel(item.jobId)),
                        _detailLine(
                          'Documente atasate',
                          item.linkedDocuments.isEmpty
                              ? '-'
                              : item.linkedDocuments
                                  .map((entry) => entry.label.trim())
                                  .join(', '),
                        ),
                        if (item.complaintId.trim().isNotEmpty ||
                            item.complaintNumber.trim().isNotEmpty)
                          _detailLine(
                            'Reclamatie sursa',
                            item.complaintNumber.trim().isNotEmpty
                                ? item.complaintNumber.trim()
                                : item.complaintId.trim(),
                          ),
                        if (item.postponementReason.trim().isNotEmpty)
                          _detailLine(
                            'Motiv amanare / reprogramare',
                            item.postponementReason.trim(),
                          ),
                        if (item.rescheduledFromStartDateTime != null &&
                            item.rescheduledFromEndDateTime != null)
                          _detailLine(
                            'Interval anterior',
                            '${_formatDateTime(item.rescheduledFromStartDateTime!)} - ${_formatDateTime(item.rescheduledFromEndDateTime!)}',
                          ),
                        _detailLine('Observatii / note', item.notes.trim()),
                        if (item.forPartnerName.trim().isNotEmpty)
                          _detailLine(
                            'Montez pentru partener',
                            item.forPartnerName.trim(),
                          ),
                        if (item.executingPartnerName.trim().isNotEmpty)
                          _detailLine(
                            'Partener executant trimis',
                            item.executingPartnerName.trim(),
                          ),
                        if (item.equipmentDescription.trim().isNotEmpty)
                          _detailLine(
                            'Echipament / instalatie',
                            item.equipmentDescription.trim(),
                          ),
                        if (item.interventionPrice > 0)
                          _detailLine(
                            'Pret interventie',
                            '${item.interventionPrice.toStringAsFixed(2)} ${item.interventionPriceCurrency}',
                          ),
                        if (item.materialUsage.kitTemplateName.trim().isNotEmpty)
                          _detailLine(
                            'Kit materiale',
                            item.materialUsage.kitTemplateName.trim(),
                          ),
                        if (item.materialUsage.linearMetersUsed > 0)
                          _detailLine(
                            'Cantitate folosita',
                            '${item.materialUsage.linearMetersUsed.toStringAsFixed(2)} ml',
                          ),
                        if (item.materialUsage.lines.isNotEmpty)
                          _detailLine(
                            'Materiale consumate',
                            item.materialUsage.lines
                                .map(
                                  (line) =>
                                      '${line.name} (${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} ${line.unit})',
                                )
                                .join(', '),
                          ),
                        if (_canManageAppointmentFinancials &&
                            item.adminCollectedAmount > 0)
                          _detailLine(
                            'Incasare / valoare interna',
                            '${item.adminCollectedAmount.toStringAsFixed(2)} ${item.adminCollectedCurrency}',
                          ),
                        if (_canManageAppointmentFinancials)
                          _detailLine(
                            'Status financiar',
                            item.adminFinancialStatus.label,
                          ),
                        if (_canManageAppointmentFinancials &&
                            item.adminDueDate != null)
                          _detailLine(
                            'Scadenta / data incasare',
                            _formatDate(item.adminDueDate!),
                          ),
                        if (_canManageAppointmentFinancials &&
                            item.estimatedMaterialsCost > 0)
                          _detailLine(
                            'Cost materiale estimat',
                            '${item.estimatedMaterialsCost.toStringAsFixed(2)} RON',
                          ),
                        if (_canManageAppointmentFinancials &&
                            item.adminCollectedAmount > 0)
                          _detailLine(
                            'Profit estimat',
                            '${item.estimatedProfit.toStringAsFixed(2)} ${item.adminCollectedCurrency}',
                          ),
                        if (_canManageAppointmentFinancials &&
                            item.adminFinancialNotes.trim().isNotEmpty)
                          _detailLine(
                            'Observatii financiare',
                            item.adminFinancialNotes.trim(),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  _formSection(
                    dialogContext,
                    title: 'Documente rapide incarcate',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _linkedDocumentsChip(item),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _openFieldPhotosForAppointment(item);
                            },
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Poze teren'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _openLinkedDocumentsManagerForAppointment(
                                item,
                              );
                            },
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Gestioneaza documente'),
                          ),
                          if (_canManageAppointmentFinancials &&
                              item.materialUsage.lines.isNotEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _openBonConsumDialog(context, item);
                              },
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Bon consum SmartBill'),
                            ),
                          if (_canManageAppointmentFinancials &&
                              _normalizeStatusValue(item.status) ==
                                  'finalizata')
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _showQuickCollectionDialog(item);
                              },
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Încasează'),
                            ),
                          if (_canManageAppointmentFinancials &&
                              item.executingPartnerId.trim().isNotEmpty &&
                              _normalizeStatusValue(item.status) ==
                                  'finalizata')
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _showQuickPartnerPaymentDialog(item);
                              },
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Plătește partener'),
                            ),
                          if (_canManageAppointmentFinancials)
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _openCatalogMaterialsDialog(item);
                              },
                              icon: const Icon(Icons.shopping_cart_outlined),
                              label: const Text('Catalog materiale'),
                            ),
                          if (_canManageAppointmentFinancials)
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _openEmployeePayDialog(item);
                              },
                              icon: const Icon(Icons.people_outlined),
                              label: const Text('Plată angajați'),
                            ),
                        ],
                      ),
                      if (item.linkedDocuments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final document in item.linkedDocuments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.insert_drive_file_outlined),
                            title: Text(document.label.trim()),
                            subtitle: Text(
                              document.fileName.trim().isEmpty
                                  ? _fileNameFromPath(document.filePath)
                                  : document.fileName.trim(),
                            ),
                            trailing: IconButton(
                              tooltip: 'Deschide',
                              onPressed: () async {
                                final result =
                                    await DocumentFileService.openFile(
                                  document.filePath,
                                );
                                if (!dialogContext.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              },
                              icon: const Icon(Icons.open_in_new_outlined),
                            ),
                          ),
                      ],
                    ],
                  ),
                  if (phone.trim().isNotEmpty || email.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (phone.trim().isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.call_outlined, size: 16),
                            label: Text(phone.trim()),
                            onPressed: () => _launchExternalUri(
                              dialogContext,
                              Uri(scheme: 'tel', path: _phoneUriValue(phone)),
                              failureLabel: 'dialerul',
                            ),
                          ),
                        if (phone.trim().isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('Confirmare WA'),
                            onPressed: () async {
                              final msg = CommunicationService.instance
                                  .mesajConfirmareProgramare(
                                numeClient: item.clientName.trim().isNotEmpty
                                    ? item.clientName
                                    : item.title,
                                dataOra: _formatDateTime(
                                    item.effectiveStartDateTime),
                                titluLucrare: item.title,
                                numeTechnician:
                                    item.assignedUserEmail.isNotEmpty
                                        ? item.assignedUserEmail
                                        : item.teamId,
                                adresaLocatie: item.location.trim().isNotEmpty
                                    ? item.location
                                    : null,
                              );
                              final ok = await CommunicationService.instance
                                  .sendWhatsApp(
                                phone: phone.trim(),
                                message: msg,
                              );
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'WhatsApp nu a putut fi deschis. '
                                      'Verificați că aplicația este instalată.',
                                    ),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                          ),
                        if (phone.trim().isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.schedule_outlined,
                                size: 16),
                            label: const Text('Reminder WA'),
                            onPressed: () async {
                              final start =
                                  item.effectiveStartDateTime;
                              final oraStr =
                                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                              final msg = CommunicationService.instance
                                  .mesajReminderZiUrmatoare(
                                numeClient: item.clientName.trim().isNotEmpty
                                    ? item.clientName
                                    : item.title,
                                ora: oraStr,
                                titluLucrare: item.title,
                                numeTechnician:
                                    item.assignedUserEmail.isNotEmpty
                                        ? item.assignedUserEmail
                                        : item.teamId,
                              );
                              final ok = await CommunicationService.instance
                                  .sendWhatsApp(
                                phone: phone.trim(),
                                message: msg,
                              );
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'WhatsApp nu a putut fi deschis. '
                                      'Verificați că aplicația este instalată.',
                                    ),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                          ),
                        if (email.trim().isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.email_outlined, size: 16),
                            label: Text(email.trim()),
                            onPressed: () => _launchExternalUri(
                              dialogContext,
                              Uri(
                                scheme: 'mailto',
                                path: email.trim(),
                              ),
                              failureLabel: 'clientul de email',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Grid compact doar cu iconițe (tooltip pe fiecare) în locul
          // OverflowBar-ului implicit, care cu 5-8 butoane icon+text
          // trecea pe layout vertical și acoperea cardul de informații.
          // Lățime fixă ~210px → maxim 4 iconițe/rând (grid 2 rânduri).
          // „Închide" rămâne buton text separat, sub grid, ca acțiune de
          // închidere distinctă și clară.
          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: SizedBox(
                      width: 210,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          if (item.complaintId.trim().isNotEmpty)
                            IconButton(
                              tooltip: 'Proces verbal',
                              icon: const Icon(Icons.description_outlined),
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _openRepairReportForAppointment(item);
                              },
                            ),
                          IconButton(
                            tooltip: 'Materiale',
                            icon: const Icon(Icons.inventory_2_outlined),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _openEmployeeMaterialUsageDialog(item);
                            },
                          ),
                          IconButton(
                            tooltip: 'Poze teren',
                            icon: const Icon(Icons.photo_camera_outlined),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _openFieldPhotosForAppointment(item);
                            },
                          ),
                          IconButton(
                            tooltip: 'GPS',
                            icon: const Icon(Icons.location_on_outlined),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _handleGpsCheckin(item);
                            },
                          ),
                          IconButton(
                            tooltip: 'Export fișă (PDF)',
                            icon: const Icon(Icons.print_outlined),
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _exportAppointmentSheet(item);
                            },
                          ),
                          if (_canCreateAdministrativeAppointments)
                            IconButton(
                              tooltip: 'Editează',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _openEditor(appointment: item);
                              },
                            ),
                          IconButton(
                            tooltip: 'Istoric',
                            icon: const Icon(Icons.history_outlined),
                            onPressed: () => _openAppointmentHistoryDialog(
                              dialogContext,
                              item,
                            ),
                          ),
                          if (_canCreateAdministrativeAppointments)
                            IconButton(
                              tooltip: 'Șterge',
                              icon: Icon(
                                Icons.delete_outline,
                                color:
                                    Theme.of(dialogContext).colorScheme.error,
                              ),
                              onPressed: () async {
                                Navigator.of(dialogContext).pop();
                                await _confirmAndDeleteAppointment(item);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Închide'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
