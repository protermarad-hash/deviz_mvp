import 'package:flutter/material.dart';

import '../../partners/partner_models.dart';
import '../job_partner_models.dart';
import '../lucrare_format_utils.dart';
import 'multi_day_picker_dialog.dart';
import 'partner_worker_autocomplete.dart';

/// Dialog "Personal partener" — paritate cu manopera proprie
/// (`_buildOwnResourcesSection` / dialogul din `lucrare_detalii_page.dart`
/// liniile 4180-4480): selectare Interval SAU Zile individuale, ore/zi cu
/// ore totale auto-calculate, tarif orar, diurnă și cazare.
///
/// Extras separat din `partner_dialogs.dart` (Faza 1, paritate pontaj
/// partener) ca să nu depășească limita de dimensiune a fișierului.
///
/// La ADĂUGARE: poate genera MAI MULTE rânduri `JobPartnerWorker` dintr-o
/// singură operațiune (un rând per zi selectată la "Zile individuale"),
/// la fel ca `buildMultiDayLaborEntries()` pentru manopera proprie.
/// La EDITARE unui rând existent: un singur rând, câmpuri directe (fără
/// selector de interval/zile multiple).
Future<List<JobPartnerWorker>?> showPartnerWorkerDialog(
  BuildContext context, {
  required JobPartner partner,
  required List<PartnerWorkerRecord> masterWorkers,
  required String jobId,
  required void Function(String message) onValidationError,
  JobPartnerWorker? existing,
}) async {
  final isEdit = existing != null;
  final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
  final roleCtrl = TextEditingController(text: existing?.role ?? '');
  final hoursPerDayCtrl = TextEditingController(
    text: _fmtNum(existing == null || existing.hoursPerDay <= 0
        ? 8
        : existing.hoursPerDay),
  );
  final hoursTotalCtrl = TextEditingController(
    text: (existing?.workedHours ?? 0) > 0
        ? _fmtNum(existing!.workedHours)
        : '',
  );
  final rateCtrl =
      TextEditingController(text: (existing?.hourlyRate ?? 0).toString());
  final currencyCtrl = TextEditingController(
      text: existing?.currency.trim().isNotEmpty == true
          ? existing!.currency
          : 'RON');
  final diurnaValCtrl = TextEditingController(
    text: (existing?.perDiemPerDay ?? 0) > 0
        ? _fmtNum(existing!.perDiemPerDay)
        : '',
  );
  final cazareValCtrl = TextEditingController(
    text: (existing?.lodgingPerNight ?? 0) > 0
        ? _fmtNum(existing!.lodgingPerNight)
        : '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  String? selectedMasterWorkerId =
      existing?.masterWorkerId.trim().isNotEmpty == true
          ? existing!.masterWorkerId.trim()
          : null;
  var multiDayMode = false;
  var includeDiurna = (existing?.perDiemDays ?? 0) > 0;
  var includeCazare = (existing?.lodgingNights ?? 0) > 0;
  var periodStart = existing?.workPeriodStart ?? DateTime.now();
  var periodEnd = existing?.workPeriodEnd ?? periodStart;
  periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
  periodEnd = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
  var selectedDays = <DateTime>{};

  List<JobPartnerWorker>? result;
  try {
    result = await showDialog<List<JobPartnerWorker>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void syncTotal() {
            final perDay = double.tryParse(
                    hoursPerDayCtrl.text.replaceAll(',', '.')) ??
                8;
            if (!isEdit) {
              final days = multiDayMode
                  ? (selectedDays.isEmpty ? 1 : selectedDays.length)
                  : (periodEnd.difference(periodStart).inDays + 1).clamp(
                      1, 100000);
              hoursTotalCtrl.text = _fmtNum(perDay * days);
            }
          }

          return AlertDialog(
            title: Text(isEdit
                ? 'Editează personal partener'
                : 'Adaugă personal partener'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    PartnerWorkerAutocomplete(
                      controller: nameCtrl,
                      options: masterWorkers,
                      onSelected: (selected) => setDialogState(() {
                        selectedMasterWorkerId = selected.id;
                        nameCtrl.text = selected.fullName;
                        roleCtrl.text = selected.role;
                        rateCtrl.text = selected.hourlyRate.toStringAsFixed(2);
                        currencyCtrl.text = selected.currency;
                        notesCtrl.text = selected.notes;
                      }),
                      onChanged: (_) => setDialogState(
                        () => selectedMasterWorkerId = null,
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: roleCtrl,
                      decoration: const InputDecoration(labelText: 'Rol'),
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Interval'),
                            icon: Icon(Icons.date_range_outlined),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Zile individuale'),
                            icon: Icon(Icons.event_repeat_outlined),
                          ),
                        ],
                        selected: {multiDayMode},
                        onSelectionChanged: (value) => setDialogState(() {
                          multiDayMode = value.first;
                          syncTotal();
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (!multiDayMode)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: periodStart,
                                    firstDate:
                                        DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime(DateTime.now().year + 5),
                                  );
                                  if (picked == null) return;
                                  setDialogState(() {
                                    periodStart = picked;
                                    if (periodEnd.isBefore(periodStart)) {
                                      periodEnd = periodStart;
                                    }
                                    syncTotal();
                                  });
                                },
                                icon: const Icon(Icons.calendar_today),
                                label:
                                    Text('Start: ${lucrareFormatDate(periodStart)}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: periodEnd,
                                    firstDate:
                                        DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime(DateTime.now().year + 5),
                                  );
                                  if (picked == null) return;
                                  setDialogState(() {
                                    periodEnd = picked;
                                    if (periodEnd.isBefore(periodStart)) {
                                      periodEnd = periodStart;
                                    }
                                    syncTotal();
                                  });
                                },
                                icon: const Icon(Icons.event_available_outlined),
                                label:
                                    Text('Sfârșit: ${lucrareFormatDate(periodEnd)}'),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showMultiDayPickerDialog(
                                  context,
                                  initialSelection: selectedDays,
                                  firstDate: DateTime(DateTime.now().year - 5),
                                  lastDate: DateTime(DateTime.now().year + 5),
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  selectedDays = picked;
                                  syncTotal();
                                });
                              },
                              icon: const Icon(Icons.event_repeat_outlined),
                              label: Text(selectedDays.isEmpty
                                  ? 'Selectează zile'
                                  : '${selectedDays.length} zile selectate'),
                            ),
                            if (selectedDays.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: (selectedDays.toList()..sort())
                                    .map((d) => Chip(
                                          label: Text(lucrareFormatDate(d)),
                                          visualDensity: VisualDensity.compact,
                                          onDeleted: () => setDialogState(() {
                                            selectedDays = {...selectedDays}
                                              ..remove(d);
                                            syncTotal();
                                          }),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
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
                              periodEnd = picked;
                            });
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Data: ${lucrareFormatDate(periodStart)}'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursPerDayCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Ore/zi'),
                            onChanged: (_) => setDialogState(syncTotal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hoursTotalCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Ore totale',
                              helperText: isEdit
                                  ? null
                                  : 'Se recalculează din perioadă x ore/zi',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tarif negociat / ora',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Moneda'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeDiurna,
                      title: const Text('Include diurnă'),
                      onChanged: (v) => setDialogState(() => includeDiurna = v),
                    ),
                    if (includeDiurna)
                      TextField(
                        controller: diurnaValCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Diurnă / zi (RON)'),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeCazare,
                      title: const Text('Include cazare'),
                      onChanged: (v) => setDialogState(() => includeCazare = v),
                    ),
                    if (includeCazare)
                      TextField(
                        controller: cazareValCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Cazare / noapte (RON)'),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Observatii'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Renunta'),
              ),
              FilledButton(
                onPressed: () {
                  final fullName = nameCtrl.text.trim();
                  if (fullName.isEmpty) {
                    onValidationError('Completeaza numele persoanei.');
                    return;
                  }
                  if (!isEdit && multiDayMode && selectedDays.isEmpty) {
                    onValidationError('Selecteaza cel putin o zi.');
                    return;
                  }
                  final role = roleCtrl.text.trim();
                  final rate = lucrareAsDouble(rateCtrl.text);
                  final currency = currencyCtrl.text.trim().isEmpty
                      ? 'RON'
                      : currencyCtrl.text.trim().toUpperCase();
                  final diurnaVal = lucrareAsDouble(diurnaValCtrl.text);
                  final cazareVal = lucrareAsDouble(cazareValCtrl.text);
                  final notes = notesCtrl.text.trim();
                  final masterId = selectedMasterWorkerId ?? '';
                  final now = DateTime.now();

                  JobPartnerWorker buildRow({
                    required String id,
                    required DateTime dayStart,
                    required DateTime dayEnd,
                    required double hoursPerDay,
                    required double workedHours,
                    required int workDays,
                  }) {
                    return JobPartnerWorker(
                      id: id,
                      jobId: jobId,
                      partnerId: partner.id,
                      fullName: fullName,
                      masterWorkerId: masterId,
                      role: role,
                      workedHours: workedHours,
                      hoursPerDay: hoursPerDay,
                      workPeriodStart: dayStart,
                      workPeriodEnd: dayEnd,
                      workDays: workDays,
                      hourlyRate: rate,
                      perDiemDays: includeDiurna ? workDays : 0,
                      perDiemPerDay: diurnaVal,
                      lodgingNights: includeCazare ? workDays : 0,
                      lodgingPerNight: cazareVal,
                      currency: currency,
                      notes: notes,
                    );
                  }

                  if (isEdit) {
                    Navigator.of(context).pop([
                      buildRow(
                        id: existing.id,
                        dayStart: periodStart,
                        dayEnd: periodStart,
                        hoursPerDay:
                            lucrareAsDouble(hoursPerDayCtrl.text) <= 0
                                ? 8.0
                                : lucrareAsDouble(hoursPerDayCtrl.text),
                        workedHours: lucrareAsDouble(hoursTotalCtrl.text),
                        workDays: 1,
                      ),
                    ]);
                    return;
                  }

                  final hoursPerDay =
                      lucrareAsDouble(hoursPerDayCtrl.text) <= 0
                          ? 8.0
                          : lucrareAsDouble(hoursPerDayCtrl.text);

                  if (multiDayMode) {
                    final sortedDays = selectedDays.toList()
                      ..sort((a, b) => a.compareTo(b));
                    final rows = List<JobPartnerWorker>.generate(
                      sortedDays.length,
                      (index) => buildRow(
                        id: 'job-partner-worker-'
                            '${sortedDays[index].millisecondsSinceEpoch}-$index',
                        dayStart: sortedDays[index],
                        dayEnd: sortedDays[index],
                        hoursPerDay: hoursPerDay,
                        workedHours: hoursPerDay,
                        workDays: 1,
                      ),
                    );
                    Navigator.of(context).pop(rows);
                    return;
                  }

                  final workDays =
                      periodEnd.difference(periodStart).inDays + 1;
                  Navigator.of(context).pop([
                    buildRow(
                      id: 'job-partner-worker-${now.microsecondsSinceEpoch}',
                      dayStart: periodStart,
                      dayEnd: periodEnd,
                      hoursPerDay: hoursPerDay,
                      workedHours: hoursPerDay * workDays,
                      workDays: workDays,
                    ),
                  ]);
                },
                child: const Text('Salveaza'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    // Dispose amânat pe frame-ul următor (nu imediat) — dialogul (AlertDialog
    // cu tranziție fade) mai există în arbore o scurtă perioadă după ce
    // showDialog() se rezolvă (Navigator.pop rulează tranziția de ieșire);
    // dispose imediat pe un TextField încă focusat poate crapa la
    // caret-blink ("TextEditingController was used after being disposed"),
    // reprodus real prin test widget (nu doar teoretic).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      roleCtrl.dispose();
      hoursPerDayCtrl.dispose();
      hoursTotalCtrl.dispose();
      rateCtrl.dispose();
      currencyCtrl.dispose();
      diurnaValCtrl.dispose();
      cazareValCtrl.dispose();
      notesCtrl.dispose();
    });
  }
  return result;
}

String _fmtNum(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

