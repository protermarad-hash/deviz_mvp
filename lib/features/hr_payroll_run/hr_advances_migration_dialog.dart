import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../hr_variable_payroll/hr_variable_payroll_catalog_service.dart';
import '../hr_variable_payroll/hr_variable_payroll_models.dart';
import '../master/master_local_store.dart';

// ── Dialog one-time migrare avansuri single_month mai 2026 ───────────────────
// Marchează ca 'recovered' avansurile cu recoveryMode='single_month',
// status='active', effectiveMonth=2026-05. Apelat din Tab Setări HR.
// De șters după confirmare migrare.

Future<void> showHrAdvancesMay2026MigrationDialog(
  BuildContext context, {
  required HrVariablePayrollCatalogService service,
  required List<MasterEmployee> employees,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MigrationDialog(service: service, employees: employees),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

enum _Step { loading, confirm, migrating, done, error }

class _MigrationDialog extends StatefulWidget {
  const _MigrationDialog({
    required this.service,
    required this.employees,
  });

  final HrVariablePayrollCatalogService service;
  final List<MasterEmployee> employees;

  @override
  State<_MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<_MigrationDialog> {
  _Step _step = _Step.loading;
  List<HrAdvance> _candidates = const [];
  String _backupPath = '';
  int _migratedCount = 0;
  String _errorMsg = '';
  String _verifyResult = '';

  static const _expectedNames = {
    'Dreghiciu Gheorghe',
    'Heczel Eduard',
    'Herman Margareta',
    'Herman Sebastian',
    'Ilie Marcel',
    'Nechifor Cristian',
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  String _empName(String employeeId) {
    for (final e in widget.employees) {
      if (e.id.trim() == employeeId.trim()) return e.name;
    }
    return 'ID: $employeeId';
  }

  Future<void> _load() async {
    try {
      final all = await widget.service.listAdvances();
      final candidates = all.where((a) {
        final isSingleMonth = a.recoveryMode.trim() == 'single_month';
        final isActive = a.status.trim().toLowerCase() == 'active';
        final isMay2026 =
            a.effectiveMonth.year == 2026 && a.effectiveMonth.month == 5;
        return isSingleMonth && isActive && isMay2026;
      }).toList();
      if (mounted) setState(() { _candidates = candidates; _step = _Step.confirm; });
    } catch (e) {
      if (mounted) setState(() { _errorMsg = e.toString(); _step = _Step.error; });
    }
  }

  Future<void> _migrate() async {
    setState(() => _step = _Step.migrating);
    try {
      // 1. Backup JSON local
      final backupData = _candidates.map((a) => {
        ...a.toMap(),
        '_employee_name': _empName(a.employeeId),
        '_backup_timestamp': DateTime.now().toIso8601String(),
      }).toList();

      try {
        Directory? dir;
        if (Platform.isWindows) {
          dir = await getDownloadsDirectory();
        }
        dir ??= await getTemporaryDirectory();
        final file = File('${dir.path}\\backup_avansuri_mai_2026.json');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(backupData),
          encoding: utf8,
        );
        _backupPath = file.path;
      } catch (_) {
        _backupPath = '(backup local indisponibil)';
      }

      // 2. Marchează fiecare ca 'recovered'
      final now = DateTime.now();
      int count = 0;
      for (final adv in _candidates) {
        await widget.service.upsertAdvance(HrAdvance(
          id: adv.id,
          employeeId: adv.employeeId,
          hrEmployeeProfileId: adv.hrEmployeeProfileId,
          amount: adv.amount,
          currency: adv.currency,
          grantedAt: adv.grantedAt,
          recoveryMode: adv.recoveryMode,
          effectiveMonth: adv.effectiveMonth,
          status: 'recovered',
          notes: adv.notes,
          createdAt: adv.createdAt,
          updatedAt: now,
        ));
        count++;
      }
      _migratedCount = count;

      // 3. Verificare: re-citește și confirmă status
      final allAfter = await widget.service.listAdvances();
      final migratedIds = _candidates.map((a) => a.id).toSet();
      final afterMigration = allAfter.where((a) => migratedIds.contains(a.id)).toList();
      final allRecovered = afterMigration.every(
        (a) => a.status.trim().toLowerCase() == 'recovered',
      );
      _verifyResult = allRecovered
          ? 'Toate $count avansuri confirmate status=recovered.'
          : 'ATENTIE: ${afterMigration.where((a) => a.status != "recovered").length} avans(uri) inca nu au status=recovered!';

      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      if (mounted) setState(() { _errorMsg = e.toString(); _step = _Step.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.published_with_changes_outlined, color: cs.primary),
        const SizedBox(width: 8),
        const Expanded(child: Text('Migrare avansuri mai 2026')),
      ]),
      content: SizedBox(
        width: 520,
        child: _buildContent(cs),
      ),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return switch (_step) {
      _Step.loading => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      _Step.confirm => _buildConfirmContent(cs),
      _Step.migrating => SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Actualizare ${_candidates.length} avansuri...',
                  style: TextStyle(color: cs.onSurface)),
            ],
          ),
        ),
      _Step.done => _buildDoneContent(cs),
      _Step.error => Text('Eroare: $_errorMsg',
          style: TextStyle(color: cs.error)),
    };
  }

  Widget _buildConfirmContent(ColorScheme cs) {
    final count = _candidates.length;
    final names = _candidates.map((a) => _empName(a.employeeId)).toSet();
    final expected = _expectedNames;
    final foundNotExpected = names.difference(expected);
    final expectedNotFound = expected.difference(names);
    final isExact = count == 6 && foundNotExpected.isEmpty && expectedNotFound.isEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status validare
          if (isExact)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text('Lista corespunde exact: $count avansuri de migrat.',
                    style: const TextStyle(color: Colors.green)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text('STOP — lista NU corespunde. Găsite: $count.',
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ]),
                  if (foundNotExpected.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Găsite în plus față de așteptat: ${foundNotExpected.join(", ")}',
                        style: const TextStyle(color: Colors.red)),
                  ],
                  if (expectedNotFound.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Așteptate dar negăsite: ${expectedNotFound.join(", ")}',
                        style: const TextStyle(color: Colors.orange)),
                  ],
                  const SizedBox(height: 8),
                  const Text('Confirmarea este blocată. Verifică manual.',
                      style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Lista candidaților
          Text('Avansuri găsite (${_candidates.length}):',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_candidates.isEmpty)
            const Text('Niciun avans eligibil găsit.')
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('Angajat', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('Sumă', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('ID doc.', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ..._candidates.map((a) => TableRow(children: [
                  Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(_empName(a.employeeId))),
                  Padding(
                      padding: const EdgeInsets.all(4),
                      child:
                          Text('${a.amount.toStringAsFixed(2)} ${a.currency}')),
                  Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(a.id.length > 8 ? '${a.id.substring(0, 8)}…' : a.id,
                          style: const TextStyle(fontSize: 11))),
                ])),
              ],
            ),
          const SizedBox(height: 12),
          Text('Se vor marca ca "recovered". Backup JSON se salvează înainte de modificare.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDoneContent(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text('Migrare completă: $_migratedCount avansuri actualizate.',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_verifyResult, style: const TextStyle(color: Colors.green)),
        ),
        const SizedBox(height: 8),
        Text('Backup salvat la:\n$_backupPath',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        const Text(
          'Verificare finală: regenerarea salarizării lunii iunie 2026 '
          'nu va mai include aceste avansuri.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return switch (_step) {
      _Step.confirm => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: _candidates.length == 6 ? _migrate : null,
            child: const Text('Confirmă și marchează recovered'),
          ),
        ],
      _Step.done || _Step.error => [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Închide'),
          ),
        ],
      _ => [],
    };
  }
}
