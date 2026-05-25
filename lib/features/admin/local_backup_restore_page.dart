import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalBackupRestorePage extends StatefulWidget {
  const LocalBackupRestorePage({super.key});

  @override
  State<LocalBackupRestorePage> createState() => _LocalBackupRestorePageState();
}

class _LocalBackupRestorePageState extends State<LocalBackupRestorePage> {
  bool _working = false;
  String? _lastExportPath;
  String? _lastMessage;

  static const List<String> _exportCoverage = <String>[
    'Utilizatori locali auth',
    'Echipe',
    'Programări',
    'Lucrări',
    'Clienți',
    'Setări firmă',
    'Alte setări locale relevante',
  ];

  bool _isManagedKey(String key) {
    final k = key.toLowerCase();
    if (k.startsWith('field_auth_')) return true;
    if (k.startsWith('cloud_sync_')) return true;
    const tokens = <String>[
      'app_data',
      'appointment',
      'program',
      'job',
      'lucrare',
      'client',
      'team',
      'company',
      'firma',
      'registry',
      'registratura',
      'document',
      'material',
      'employee',
      'checklist',
      'journal',
      'report',
      'hr_',
    ];
    return tokens.any(k.contains);
  }

  Future<Map<String, dynamic>> _collectExportData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(_isManagedKey).toList()..sort();
    final values = <String, dynamic>{};
    for (final key in keys) {
      values[key] = prefs.get(key);
    }

    return <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'ProVentaris',
      'data': values,
    };
  }

  String _prettyJson(Object value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _lastMessage = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastMessage = 'Eroare: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _exportJsonDialog() async {
    await _run(() async {
      final payload = await _collectExportData();
      final jsonText = _prettyJson(payload);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Export JSON'),
            content: SizedBox(
              width: 700,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datele exportate pot fi copiate și mutate pe alt dispozitiv.',
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(textCapitalization: TextCapitalization.sentences, 
                      controller: TextEditingController(text: jsonText),
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Închide'),
              ),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: jsonText));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON copiat în clipboard.')),
                  );
                },
                child: const Text('Copiază JSON'),
              ),
            ],
          );
        },
      );
    });
  }

  String _fileTimestamp(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$y$m${d}_$h$min$s';
  }

  Future<void> _exportToFile() async {
    await _run(() async {
      final payload = await _collectExportData();
      final jsonText = _prettyJson(payload);
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/backup_deviz_${_fileTimestamp(DateTime.now())}.json';
      final file = File(path);
      await file.writeAsString(jsonText, flush: true);
      if (!mounted) return;
      setState(() {
        _lastExportPath = path;
        _lastMessage = 'Export finalizat: $path';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup exportat local.')),
      );
    });
  }

  Future<void> _setPrefValue(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is List) {
      final strings = value.map((e) => e.toString()).toList(growable: false);
      await prefs.setStringList(key, strings);
      return;
    }
    await prefs.setString(key, value.toString());
  }

  Future<void> _importPayload({
    required Map<String, dynamic> payload,
    required bool overwrite,
  }) async {
    final rawData = payload['data'];
    if (rawData is! Map) {
      throw Exception('Format invalid: lipsește map-ul data.');
    }
    final data = Map<String, dynamic>.from(rawData);
    final prefs = await SharedPreferences.getInstance();

    if (overwrite) {
      final keysToClear =
          prefs.getKeys().where(_isManagedKey).toList(growable: false);
      for (final key in keysToClear) {
        await prefs.remove(key);
      }
    }

    for (final entry in data.entries) {
      await _setPrefValue(prefs, entry.key, entry.value);
    }
  }

  Future<void> _confirmImport({
    required Future<Map<String, dynamic>> Function() payloadLoader,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import date'),
          content: const Text(
            'Alege modul de import:\n'
            '• Merge: adaugă/actualizează cheile din backup.\n'
            '• Suprascriere: șterge datele locale curente gestionate și aplică backup-ul.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anulează'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _run(() async {
                  final payload = await payloadLoader();
                  await _importPayload(payload: payload, overwrite: false);
                  if (!mounted) return;
                  setState(() {
                    _lastMessage = 'Import merge finalizat.';
                  });
                });
              },
              child: const Text('Import merge'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _run(() async {
                  final payload = await payloadLoader();
                  await _importPayload(payload: payload, overwrite: true);
                  if (!mounted) return;
                  setState(() {
                    _lastMessage = 'Import cu suprascriere finalizat.';
                  });
                });
              },
              child: const Text('Import cu suprascriere'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromJsonDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import din JSON'),
          content: SizedBox(
            width: 700,
            height: 360,
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Lipește aici JSON-ul exportat',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                final raw = controller.text.trim();
                if (raw.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await _confirmImport(
                  payloadLoader: () async {
                    final decoded = jsonDecode(raw);
                    if (decoded is! Map) {
                      throw Exception('JSON invalid pentru import.');
                    }
                    return Map<String, dynamic>.from(decoded);
                  },
                );
              },
              child: const Text('Continuă'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _importFromFileDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import din fișier'),
          content: SizedBox(
            width: 620,
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cale fișier JSON',
                hintText: '/storage/.../backup_deviz_*.json',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                final path = controller.text.trim();
                if (path.isEmpty) return;
                Navigator.of(dialogContext).pop();
                await _confirmImport(
                  payloadLoader: () async {
                    final file = File(path);
                    if (!await file.exists()) {
                      throw Exception('Fișierul nu există.');
                    }
                    final raw = await file.readAsString();
                    final decoded = jsonDecode(raw);
                    if (decoded is! Map) {
                      throw Exception('Format JSON invalid în fișier.');
                    }
                    return Map<String, dynamic>.from(decoded);
                  },
                );
              },
              child: const Text('Continuă'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup / Restaurare')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export date locale',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backup-ul include principalele entități locale pentru pilot intern.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _exportCoverage
                        .map((item) => Chip(label: Text(item)))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _working ? null : _exportToFile,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Exportă fișier'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _exportJsonDialog,
                        icon: const Icon(Icons.code),
                        label: const Text('Exportă JSON'),
                      ),
                    ],
                  ),
                  if ((_lastExportPath ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SelectableText('Ultimul fișier: $_lastExportPath'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import date locale',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Poți importa din fișier JSON sau din JSON lipit manual.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _working ? null : _importFromFileDialog,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Importă din fișier'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : _importFromJsonDialog,
                        icon: const Icon(Icons.content_paste),
                        label: const Text('Importă din JSON'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if ((_lastMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_lastMessage!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
