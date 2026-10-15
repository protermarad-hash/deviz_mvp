import 'package:flutter/material.dart';

import 'cloud_sync_models.dart';
import 'revision_sync.dart';

/// Indicator minim de conflicte de sincronizare (RC 120).
///
/// Un conflict înseamnă că o modificare făcută pe acest dispozitiv NU a ajuns pe
/// server, pentru că între timp altcineva a modificat sau a șters aceeași
/// înregistrare. Ambele variante sunt păstrate (nimic nu se pierde), dar nu se
/// mai reîncearcă automat. O eroare temporară (de exemplu fără conexiune) NU
/// apare aici: aceea rămâne în coadă și se reîncearcă singură.
class SyncConflictBanner extends StatelessWidget {
  const SyncConflictBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SyncConflictStore.openCount,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return Material(
          color: Colors.red.shade700,
          child: InkWell(
            key: const Key('sync-conflict-banner'),
            onTap: () => showSyncConflictDetails(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncConflictBannerText(count),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String syncConflictBannerText(int count) {
  final what = count == 1 ? '1 modificare nu a ajuns pe server' : '$count modificări nu au ajuns pe server';
  return 'Conflict de sincronizare: $what. Datele sunt păstrate pe acest dispozitiv. '
      'Anunțați administratorul înainte de a le edita din nou.';
}

String _entityLabel(CloudEntityType type) => switch (type) {
      CloudEntityType.clients => 'Client',
      CloudEntityType.offers => 'Ofertă',
      CloudEntityType.jobs => 'Lucrare',
      _ => type.name,
    };

String _kindLabel(String kind) => switch (kind) {
      'concurrent_edit' => 'modificat între timp pe alt dispozitiv',
      'deleted_remotely' => 'șters între timp pe alt dispozitiv',
      'delete_vs_remote_edit' => 'ștergerea nu s-a aplicat: modificat pe alt dispozitiv',
      'retry_exhausted' => 'trimiterea a eșuat de prea multe ori',
      'unknown_on_upgrade' => 'nu a fost găsit pe server la actualizare',
      _ => kind,
    };

String _title(SyncConflict c) {
  final p = c.localPayload ?? c.serverPayload ?? const <String, dynamic>{};
  for (final k in const ['name', 'title', 'offer_number', 'job_code']) {
    final v = (p[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return c.entityId;
}

/// Detalii pentru suport: ce înregistrări sunt în conflict și de ce. Doar afișare.
Future<void> showSyncConflictDetails(BuildContext context) async {
  final items = await SyncConflictStore().listOpen();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Conflicte de sincronizare (${items.length})'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Aceste modificări sunt păstrate pe acest dispozitiv, dar nu au ajuns pe '
              'server. Varianta de pe server a fost păstrată și ea. Nu reinstalați '
              'aplicația și anunțați administratorul.',
            ),
            const SizedBox(height: 12),
            for (final c in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_problem_rounded),
                title: Text('${_entityLabel(c.entityType)}: ${_title(c)}'),
                subtitle: Text(
                  '${_kindLabel(c.kind)} · ${c.detectedAt.toLocal().toString().substring(0, 16)}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Închide')),
      ],
    ),
  );
}
