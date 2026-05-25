import 'package:flutter/material.dart';

import '../../core/migrations/field_photos_migration.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pagina de migrare poze vechi din Storage → Firestore
// Disponibilă DOAR pentru admin, în secțiunea Administrare
// ─────────────────────────────────────────────────────────────────────────────

class FieldPhotosMigrationPage extends StatefulWidget {
  const FieldPhotosMigrationPage({super.key});

  @override
  State<FieldPhotosMigrationPage> createState() =>
      _FieldPhotosMigrationPageState();
}

class _FieldPhotosMigrationPageState extends State<FieldPhotosMigrationPage> {
  // ── Stare ──────────────────────────────────────────────────────────────────
  _MigrationPhase _phase = _MigrationPhase.idle;
  final List<String> _logLines = [];
  FieldPhotoMigrationResult? _dryRunResult;
  FieldPhotoMigrationResult? _migrateResult;
  int _currentItem = 0;
  int _totalItems = 0;

  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _appendLog(String line) {
    if (!mounted) return;
    setState(() => _logLines.add(line));
    // Scroll automat la final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Acțiuni ────────────────────────────────────────────────────────────────

  Future<void> _runDiagnostic() async {
    setState(() {
      _phase = _MigrationPhase.dryRunning;
      _logLines.clear();
      _dryRunResult = null;
      _migrateResult = null;
    });

    _appendLog('=== DIAGNOSTIC STORAGE ===');
    // Rulează doar listStorageFiles (include diagnosticarea completă)
    final files = await FieldPhotosMigrationService.listStorageFiles(
      onProgress: _appendLog,
    );

    if (!mounted) return;
    setState(() => _phase = _MigrationPhase.idle);

    _appendLog('');
    _appendLog('=== REZULTAT DIAGNOSTIC ===');
    if (files.isEmpty) {
      _appendLog('⚠ Nu s-au găsit fișiere. Verifică erorile de mai sus.');
    } else {
      _appendLog('✅ ${files.length} fișiere găsite. Poți rula Dry Run.');
    }
  }

  Future<void> _runDryRun() async {
    setState(() {
      _phase = _MigrationPhase.dryRunning;
      _logLines.clear();
      _dryRunResult = null;
      _migrateResult = null;
      _currentItem = 0;
      _totalItems = 0;
    });

    final result = await FieldPhotosMigrationService.dryRun(
      onProgress: _appendLog,
    );

    if (!mounted) return;
    setState(() {
      _dryRunResult = result;
      _phase = _MigrationPhase.dryRunDone;
    });
  }

  Future<void> _runMigration() async {
    // Confirmare suplimentară înainte de scriere efectivă
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmare migrare'),
        content: Text(
          'Se vor adăuga ${_dryRunResult?.migrated ?? 0} documente noi în Firestore.\n\n'
          '• NU se modifică documente existente\n'
          '• NU se șterg fișiere din Storage\n'
          '• Operațiunea NU poate fi anulată\n\n'
          'Continuați?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da, migrează'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _phase = _MigrationPhase.migrating;
      _logLines.clear();
      _migrateResult = null;
      _currentItem = 0;
      _totalItems = _dryRunResult?.migrated ?? 0;
    });

    final result = await FieldPhotosMigrationService.migrate(
      onProgress: _appendLog,
      onItemProgress: (current, total) {
        if (mounted) {
          setState(() {
            _currentItem = current;
            _totalItems = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _migrateResult = result;
      _phase = _MigrationPhase.done;
    });
  }

  void _reset() {
    setState(() {
      _phase = _MigrationPhase.idle;
      _logLines.clear();
      _dryRunResult = null;
      _migrateResult = null;
      _currentItem = 0;
      _totalItems = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migrare poze vechi'),
        actions: [
          if (_phase != _MigrationPhase.idle &&
              _phase != _MigrationPhase.dryRunning &&
              _phase != _MigrationPhase.migrating)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Resetează'),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          if (isWide) {
            // ── Desktop: log ia tot spațiul rămas (Expanded) ──
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(theme),
                  const SizedBox(height: 16),
                  _buildActionBar(theme),
                  if (_phase == _MigrationPhase.migrating) ...[
                    const SizedBox(height: 12),
                    _buildProgressBar(theme),
                  ],
                  if (_dryRunResult != null &&
                      _phase == _MigrationPhase.dryRunDone) ...[
                    const SizedBox(height: 12),
                    _buildDryRunSummary(theme),
                  ],
                  if (_migrateResult != null &&
                      _phase == _MigrationPhase.done) ...[
                    const SizedBox(height: 12),
                    _buildFinalSummary(theme),
                  ],
                  const SizedBox(height: 12),
                  Expanded(child: _buildLog(theme, fixedHeight: null)),
                ],
              ),
            );
          }

          // ── Mobile: SingleChildScrollView, log cu înălțime fixă ──
          final logHeight = constraints.maxHeight * 0.45;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(theme),
                const SizedBox(height: 16),
                _buildActionBar(theme),
                if (_phase == _MigrationPhase.migrating) ...[
                  const SizedBox(height: 12),
                  _buildProgressBar(theme),
                ],
                if (_dryRunResult != null &&
                    _phase == _MigrationPhase.dryRunDone) ...[
                  const SizedBox(height: 12),
                  _buildDryRunSummary(theme),
                ],
                if (_migrateResult != null &&
                    _phase == _MigrationPhase.done) ...[
                  const SizedBox(height: 12),
                  _buildFinalSummary(theme),
                ],
                const SizedBox(height: 12),
                _buildLog(theme, fixedHeight: logHeight.clamp(240, 420)),
                // Padding suplimentar jos pe mobile (keyboard / nav bar)
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer.withAlpha(80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Despre această migrare',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pozele din Firebase Storage (field_photos/programari/) care nu au '
              'înregistrare în Firestore vor fi adăugate automat.\n\n'
              '🟢 SAFE: Nu se șterge nimic. Nu se modifică nimic existent.\n'
              '🟢 Dacă o poză există deja în Firestore → se sare (skip).\n'
              '🟡 Pasul 1: Dry Run — verifică fără a scrie.\n'
              '🟡 Pasul 2: Migrare efectivă — după confirmare.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    final bool isDryRunning = _phase == _MigrationPhase.dryRunning;
    final bool isMigrating = _phase == _MigrationPhase.migrating;
    final bool busy = isDryRunning || isMigrating;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        // Buton Diagnostic
        OutlinedButton.icon(
          onPressed: busy || _phase == _MigrationPhase.done ? null : _runDiagnostic,
          icon: const Icon(Icons.bug_report_outlined, size: 18),
          label: const Text('0. Diagnostic Storage'),
        ),

        // Buton Dry Run
        FilledButton.tonal(
          onPressed: busy || _phase == _MigrationPhase.done ? null : _runDryRun,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDryRunning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.search, size: 18),
              const SizedBox(width: 8),
              const Text('1. Dry Run (verificare)'),
            ],
          ),
        ),

        // Buton Migrare efectivă — activ doar după dry run
        FilledButton(
          onPressed: (!busy &&
                  _dryRunResult != null &&
                  _dryRunResult!.migrated > 0 &&
                  _phase == _MigrationPhase.dryRunDone)
              ? _runMigration
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMigrating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.upload, size: 18),
              const SizedBox(width: 8),
              const Text('2. Migrează efectiv'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    final progress =
        _totalItems > 0 ? _currentItem / _totalItems : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Se migrează... $_currentItem / $_totalItems poze',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress),
      ],
    );
  }

  Widget _buildDryRunSummary(ThemeData theme) {
    final r = _dryRunResult!;
    return _SummaryCard(
      title: 'Rezultat Dry Run',
      migrated: r.migrated,
      skipped: r.skipped,
      errors: r.errors,
      total: r.total,
      isDryRun: true,
      theme: theme,
    );
  }

  Widget _buildFinalSummary(ThemeData theme) {
    final r = _migrateResult!;
    return _SummaryCard(
      title: 'Migrare finalizată',
      migrated: r.migrated,
      skipped: r.skipped,
      errors: r.errors,
      total: r.total,
      isDryRun: false,
      theme: theme,
    );
  }

  Widget _buildLog(ThemeData theme, {required double? fixedHeight}) {
    final logContainer = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _logLines.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Log-ul va apărea aici după ce pornești Diagnostic sau Dry Run.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              controller: _logScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logLines.length,
              itemBuilder: (ctx, i) {
                final line = _logLines[i];
                Color? color;
                if (line.startsWith('✅') || line.startsWith('[MIGRAT]')) {
                  color = Colors.green.shade700;
                } else if (line.startsWith('❌') ||
                    line.startsWith('[EROARE]')) {
                  color = Colors.red.shade700;
                } else if (line.startsWith('⚠') ||
                    line.startsWith('[SĂRIT]') ||
                    line.startsWith('[AR MIGRA]')) {
                  color = Colors.orange.shade700;
                } else if (line.startsWith('===')) {
                  color = theme.colorScheme.primary;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: color,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
    );

    // Containerul log cu înălțime: Expanded (desktop) sau SizedBox fix (mobile)
    final sized = fixedHeight != null
        ? SizedBox(height: fixedHeight, child: logContainer)
        : Expanded(child: logContainer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fixedHeight != null ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, size: 16),
            const SizedBox(width: 6),
            Text('Log', style: theme.textTheme.labelMedium),
            const Spacer(),
            if (_logLines.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _logLines.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Șterge log'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        sized,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget sumar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.migrated,
    required this.skipped,
    required this.errors,
    required this.total,
    required this.isDryRun,
    required this.theme,
  });

  final String title;
  final int migrated;
  final int skipped;
  final int errors;
  final int total;
  final bool isDryRun;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: errors > 0
          ? Colors.orange.shade50
          : isDryRun
              ? theme.colorScheme.secondaryContainer.withAlpha(120)
              : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: isDryRun ? 'De migrat' : 'Migrate',
                  value: migrated,
                  color: Colors.green.shade700,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Sărite',
                  value: skipped,
                  color: Colors.grey.shade600,
                  icon: Icons.skip_next_outlined,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Erori',
                  value: errors,
                  color: Colors.red.shade700,
                  icon: Icons.error_outline,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Total',
                  value: total,
                  color: theme.colorScheme.primary,
                  icon: Icons.photo_library_outlined,
                ),
              ],
            ),
            if (isDryRun && migrated > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Apasă "2. Migrează efectiv" pentru a adăuga cele $migrated poze în Firestore.',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontStyle: FontStyle.italic),
              ),
            ],
            if (isDryRun && migrated == 0) ...[
              const SizedBox(height: 10),
              const Text(
                '✅ Toate pozele sunt deja în Firestore. Nu e nimic de migrat.',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
            if (!isDryRun && errors == 0) ...[
              const SizedBox(height: 10),
              const Text(
                '✅ Migrare finalizată cu succes! Pozele sunt acum vizibile în aplicație.',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
            if (!isDryRun && errors > 0) ...[
              const SizedBox(height: 10),
              Text(
                '⚠ $errors poze nu au putut fi migrate. Verifică log-ul pentru detalii.',
                style:
                    TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum faze
// ─────────────────────────────────────────────────────────────────────────────

enum _MigrationPhase {
  idle,
  dryRunning,
  dryRunDone,
  migrating,
  done,
}
