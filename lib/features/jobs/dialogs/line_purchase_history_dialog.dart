import 'package:flutter/material.dart';

import '../job_models.dart';
import '../lucrare_format_utils.dart';

/// Dialog auto-conținut pentru jurnalul de achiziții al unei linii planificate
/// (`JobLine.achizitii`) — STRICT INFORMATIV (iul 2026).
///
/// NU modifică `cantitateReala`/`pretUnitarReal` ale liniei — acelea rămân
/// editabile manual, independent, exact ca înainte. Acest dialog doar
/// afișează/adaugă/șterge intrări de tip {id, data, cantitate, pretUnitar,
/// notite}, pentru a urmări evoluția reală a prețului de achiziție în timp.
///
/// Întoarce lista actualizată dacă utilizatorul apasă „Salvează”, sau `null`
/// dacă renunță (fără nicio persistare — apelantul decide).
Future<List<Map<String, dynamic>>?> showLinePurchaseHistoryDialog(
  BuildContext context, {
  required JobLine linie,
  required void Function(String message) onValidationError,
}) async {
  final achizitii = List<Map<String, dynamic>>.from(linie.achizitii)
    ..sort((a, b) {
      final da = DateTime.tryParse('${a['data'] ?? ''}') ?? DateTime(2000);
      final db = DateTime.tryParse('${b['data'] ?? ''}') ?? DateTime(2000);
      return db.compareTo(da);
    });

  final dataCtrl = TextEditingController(text: lucrareFormatDate(DateTime.now()));
  final cantitateCtrl = TextEditingController();
  final pretCtrl = TextEditingController();
  final notiteCtrl = TextEditingController();

  try {
    return await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          void addEntry() {
            final cantitate = lucrareAsDouble(cantitateCtrl.text);
            final pretUnitar = lucrareAsDouble(pretCtrl.text);
            if (cantitate <= 0) {
              onValidationError('Completează o cantitate mai mare decât 0.');
              return;
            }
            if (pretUnitar <= 0) {
              onValidationError('Completează un preț unitar mai mare decât 0.');
              return;
            }
            final data = lucrareParseDateOrNow(dataCtrl.text);
            setModalState(() {
              achizitii.insert(0, <String, dynamic>{
                'id': 'achizitie-${DateTime.now().microsecondsSinceEpoch}',
                'data': data.toIso8601String(),
                'cantitate': cantitate,
                'pretUnitar': pretUnitar,
                'notite': notiteCtrl.text.trim(),
              });
              cantitateCtrl.clear();
              pretCtrl.clear();
              notiteCtrl.clear();
              dataCtrl.text = lucrareFormatDate(DateTime.now());
            });
          }

          void removeEntry(String id) {
            setModalState(() {
              achizitii.removeWhere((entry) => '${entry['id']}' == id);
            });
          }

          return AlertDialog(
            title: Text('Istoric achiziții — ${linie.denumire}'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jurnal informativ — nu modifică cantitatea/prețul '
                      'realizat al liniei (rămân editabile manual mai jos).',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    if (achizitii.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nu există achiziții înregistrate.'),
                      )
                    else
                      ...achizitii.map((entry) {
                        final id = '${entry['id']}';
                        final data =
                            DateTime.tryParse('${entry['data'] ?? ''}');
                        final cantitate = lucrareAsDouble(entry['cantitate']);
                        final pretUnitar = lucrareAsDouble(entry['pretUnitar']);
                        final notite = '${entry['notite'] ?? ''}'.trim();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${data == null ? '-' : lucrareFormatDate(data)}  •  '
                            '${lucrareFormatDecimal(cantitate)} ${linie.um} × '
                            '${pretUnitar.toStringAsFixed(2)} = '
                            '${(cantitate * pretUnitar).toStringAsFixed(2)}',
                          ),
                          subtitle: notite.isEmpty ? null : Text(notite),
                          trailing: IconButton(
                            tooltip: 'Șterge achiziția',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => removeEntry(id),
                          ),
                        );
                      }),
                    const Divider(height: 24),
                    Text(
                      'Adaugă achiziție',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dataCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Data (zz.ll.aaaa)',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cantitateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Cantitate (${linie.um})',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: pretCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Preț unitar',
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notiteCtrl,
                      decoration: const InputDecoration(labelText: 'Notițe'),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: addEntry,
                        icon: const Icon(Icons.add),
                        label: const Text('Adaugă achiziție'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(achizitii),
                child: const Text('Salvează'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    dataCtrl.dispose();
    cantitateCtrl.dispose();
    pretCtrl.dispose();
    notiteCtrl.dispose();
  }
}
