import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'pontaj_zi_lucrare_models.dart';

/// Card sumar: total general + total per persoană (expandabil) + acțiuni.
class PontajSummaryCard extends StatelessWidget {
  const PontajSummaryCard({
    super.key,
    required this.totalGeneral,
    required this.totalPerPersoana,
    required this.itemCount,
    required this.expanded,
    required this.syncing,
    required this.onToggleExpanded,
    required this.onForceSync,
    required this.onCopyPreviousDay,
  });

  final double totalGeneral;
  final Map<String, double> totalPerPersoana;
  final int itemCount;
  final bool expanded;
  final bool syncing;
  final VoidCallback onToggleExpanded;
  final VoidCallback onForceSync;
  final VoidCallback onCopyPreviousDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perPersoana = totalPerPersoana.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.summarize_outlined),
            title: Text(
              'Total pontaj: ${totalGeneral.toStringAsFixed(2)} RON',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle:
                Text('$itemCount pontaje · ${perPersoana.length} persoane'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync_outlined),
                  tooltip: 'Sincronizează la cloud',
                  onPressed: syncing ? null : onForceSync,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: 'Copiază ziua precedentă',
                  onPressed: onCopyPreviousDay,
                ),
                IconButton(
                  icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: 'Total per persoană',
                  onPressed: onToggleExpanded,
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  for (final entry in perPersoana)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(
                            '${entry.value.toStringAsFixed(2)} RON',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Antet de zi calendaristică cu totalul zilei.
class PontajDayHeader extends StatelessWidget {
  const PontajDayHeader({
    super.key,
    required this.day,
    required this.items,
  });

  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static final _dayLabelFormat = DateFormat('EEEE, dd.MM.yyyy', 'ro_RO');

  final DateTime day;
  final List<PontajZiLucrare> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayTotal = items.fold(0.0, (sum, r) => sum + r.costZi);
    String label;
    try {
      label = _dayLabelFormat.format(day);
    } catch (_) {
      label = _dateFormat.format(day);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label[0].toUpperCase() + label.substring(1),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${dayTotal.toStringAsFixed(2)} RON',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Rând de pontaj: nume, chip sursă, detalii tarif/diurnă/cazare, cost zi.
class PontajRow extends StatelessWidget {
  const PontajRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final PontajZiLucrare item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPartener = item.sursaPersoana == SursaPersoanaPontaj.partener;
    final isLiber = item.sursaPersoana == SursaPersoanaPontaj.liber;
    final details = <String>[
      'Tarif ${item.tarifZilnicSnapshot.toStringAsFixed(0)}',
      if (item.includeDiurna)
        'Diurnă ${item.diurnaSnapshot.toStringAsFixed(0)}',
      if (item.includeCazare)
        'Cazare ${item.cazareSnapshot.toStringAsFixed(0)}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            isPartener
                ? Icons.handshake_outlined
                : isLiber
                    ? Icons.person_outline
                    : Icons.badge_outlined,
            size: 14,
          ),
          label: Text(
            item.sursaPersoana.label,
            style: theme.textTheme.labelSmall,
          ),
        ),
        title: Text(
          isPartener && (item.partenerNume ?? '').isNotEmpty
              ? '${item.persoanaNume} · ${item.partenerNume}'
              : item.persoanaNume,
        ),
        subtitle: Text(
          [
            details.join(' + '),
            if (item.observatii.isNotEmpty) item.observatii,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.costZi.toStringAsFixed(2)} RON',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              tooltip: 'Acțiuni',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editează'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Șterge'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
