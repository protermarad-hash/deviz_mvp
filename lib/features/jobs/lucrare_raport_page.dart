import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/document_file_service.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/pdf_save_service.dart';
import '../../core/repositories/app_data_repository.dart';

class LucrareReportData {
  const LucrareReportData({
    required this.generatedAtLabel,
    required this.jobCode,
    required this.jobTitle,
    required this.clientName,
    required this.location,
    required this.statusLabel,
    required this.estimatedValue,
    required this.materialsTotal,
    required this.laborOreTotal,
    required this.laborPerDiemTotal,
    required this.laborLodgingTotal,
    required this.laborCompleteTotal,
    required this.realTotal,
    required this.estimatedVsReal,
    required this.materialsCount,
    required this.laborCount,
    required this.appointmentsCount,
    required this.personHoursTotal,
    required this.teamHoursTotal,
    required this.currentTeamLabel,
    required this.teamMembers,
    required this.appointments,
    required this.materials,
    required this.labor,
    required this.documents,
    required this.workTaskEntries,
    required this.checklist,
    required this.journal,
    required this.beneficiarySuppliedEquipment,
    required this.beneficiarySuppliedMaterials,
  });

  final String generatedAtLabel;
  final String jobCode;
  final String jobTitle;
  final String clientName;
  final String location;
  final String statusLabel;
  final double estimatedValue;

  final double materialsTotal;
  final double laborOreTotal;
  final double laborPerDiemTotal;
  final double laborLodgingTotal;
  final double laborCompleteTotal;
  final double realTotal;
  final double estimatedVsReal;

  final int materialsCount;
  final int laborCount;
  final int appointmentsCount;
  final double personHoursTotal;
  final double teamHoursTotal;
  final String currentTeamLabel;
  final List<String> teamMembers;

  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> labor;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> workTaskEntries;
  final Map<String, bool> checklist;
  final List<Map<String, dynamic>> journal;
  final List<Map<String, dynamic>> beneficiarySuppliedEquipment;
  final List<Map<String, dynamic>> beneficiarySuppliedMaterials;
}

class LucrareRaportPage extends StatelessWidget {
  const LucrareRaportPage({
    super.key,
    required this.data,
    required this.repository,
  });

  final LucrareReportData data;
  final AppDataRepository repository;

  static const List<MapEntry<String, String>> _checklistDefs = [
    MapEntry<String, String>('programare_facuta', 'Programare facuta'),
    MapEntry<String, String>('echipa_alocata', 'Echipa alocata'),
    MapEntry<String, String>('materiale_alocate', 'Materiale alocate'),
    MapEntry<String, String>('executie_inceputa', 'Executie inceputa'),
    MapEntry<String, String>('pif_realizat', 'PIF realizat'),
    MapEntry<String, String>('lucrare_finalizata', 'Lucrare finalizata'),
  ];

  String _f2(double value) => value.toStringAsFixed(2);

  String _sanitizePdfText(String raw) {
    var value = raw;
    value = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('•', ' | ')
        .replaceAll('–', ' - ')
        .replaceAll('—', ' - ')
        .replaceAll('→', ' -> ')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[\u2000-\u200F\u2028-\u202F\u2060-\u206F]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }

  Widget _chip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _latestJournal(List<Map<String, dynamic>> rows) {
    if (rows.length <= 20) return rows;
    return rows.take(20).toList(growable: false);
  }

  String _sanitizeFilePart(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'raport' : sanitized;
  }

  String _formatJournalDate(String raw) {
    if (raw.trim().isEmpty) return '-';
    try {
      final value = DateTime.parse(raw).toLocal();
      final d = value.day.toString().padLeft(2, '0');
      final m = value.month.toString().padLeft(2, '0');
      final h = value.hour.toString().padLeft(2, '0');
      final min = value.minute.toString().padLeft(2, '0');
      return '$d.$m.${value.year} $h:$min';
    } catch (_) {
      return raw;
    }
  }

  DateTime? _parseIsoDateTime(dynamic raw) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _formatDateTimeValue(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d.$m.${value.year} $h:$min';
  }

  List<String> _taskWorkers(Map<String, dynamic> row) {
    final raw = row['workers'];
    if (raw is List) {
      return raw
          .map((entry) => '$entry'.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return const <String>[];
    return text
        .split(RegExp(r'[,;\n]+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  String _taskDurationLabel(Map<String, dynamic> row) {
    final start = _parseIsoDateTime(row['startAt']);
    final end = _parseIsoDateTime(row['endAt']);
    if (start == null || end == null || end.isBefore(start)) return '-';
    final minutes = end.difference(start).inMinutes;
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (hours <= 0) return '${rem}m';
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  List<MapEntry<String, Map<String, dynamic>>> _dailyTaskSummary() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in data.workTaskEntries) {
      final start = _parseIsoDateTime(row['startAt']);
      final end = _parseIsoDateTime(row['endAt']);
      if (start == null || end == null || end.isBefore(start)) continue;
      final key =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final current = grouped[key] ??
          <String, dynamic>{
            'minutes': 0,
            'tasks': 0,
            'people': <String>{},
          };
      current['minutes'] =
          (current['minutes'] as int) + end.difference(start).inMinutes;
      current['tasks'] = (current['tasks'] as int) + 1;
      final people = current['people'] as Set<String>;
      people.addAll(_taskWorkers(row));
      grouped[key] = current;
    }
    final rows = grouped.entries.toList(growable: false)
      ..sort((a, b) => b.key.compareTo(a.key));
    return rows;
  }

  List<Map<String, dynamic>> _dailyWorkerProductivity() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in data.workTaskEntries) {
      final start = _parseIsoDateTime(row['startAt']);
      final end = _parseIsoDateTime(row['endAt']);
      if (start == null || end == null || end.isBefore(start)) {
        continue;
      }
      final dayKey =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final minutes = end.difference(start).inMinutes;
      if (minutes <= 0) {
        continue;
      }
      final workers = _taskWorkers(row);
      final effectiveWorkers = workers.isEmpty ? const <String>['-'] : workers;
      for (final worker in effectiveWorkers) {
        final normalizedWorker = worker.trim().isEmpty ? '-' : worker.trim();
        final key = '$dayKey|$normalizedWorker';
        final current = grouped[key] ??
            <String, dynamic>{
              'dayKey': dayKey,
              'worker': normalizedWorker,
              'minutes': 0,
              'tasks': 0,
            };
        current['minutes'] = (current['minutes'] as int) + minutes;
        current['tasks'] = (current['tasks'] as int) + 1;
        grouped[key] = current;
      }
    }

    final rows = grouped.values.toList(growable: false)
      ..sort((a, b) {
        final dayCompare = '${b['dayKey']}'.compareTo('${a['dayKey']}');
        if (dayCompare != 0) {
          return dayCompare;
        }
        final minuteCompare =
            (b['minutes'] as int).compareTo(a['minutes'] as int);
        if (minuteCompare != 0) {
          return minuteCompare;
        }
        return '${a['worker']}'.compareTo('${b['worker']}');
      });
    return rows;
  }

  String _dayKeyLabel(String key) {
    final parsed = DateTime.tryParse('${key}T00:00:00');
    if (parsed == null) return key;
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    return '$d.$m.${parsed.year}';
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 180,
            child: pw.Text(
              _sanitizePdfText(label),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(_sanitizePdfText(value))),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    final latestJournal = _latestJournal(data.journal);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Raport lucrare',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _pdfSection('Antet raport', [
            _pdfLine('Cod lucrare', data.jobCode),
            _pdfLine('Titlu lucrare', data.jobTitle),
            _pdfLine('Client', data.clientName),
            _pdfLine('Locatie', data.location),
            _pdfLine('Status', data.statusLabel),
            _pdfLine('Valoare estimata', _f2(data.estimatedValue)),
            _pdfLine('Data generarii', data.generatedAtLabel),
          ]),
          _pdfSection('Sumar operativ', [
            _pdfLine('Total materiale', _f2(data.materialsTotal)),
            _pdfLine('Total manopera ore', _f2(data.laborOreTotal)),
            _pdfLine('Total diurna', _f2(data.laborPerDiemTotal)),
            _pdfLine('Total cazare', _f2(data.laborLodgingTotal)),
            _pdfLine('Total manopera completa', _f2(data.laborCompleteTotal)),
            _pdfLine('Cost real total', _f2(data.realTotal)),
            _pdfLine('Diferenta estimat vs real', _f2(data.estimatedVsReal)),
            _pdfLine('Numar materiale', data.materialsCount.toString()),
            _pdfLine('Numar inregistrari ore', data.laborCount.toString()),
            _pdfLine('Numar programari', data.appointmentsCount.toString()),
            _pdfLine('Echipa curenta', data.currentTeamLabel),
          ]),
          _pdfSection(
            'Programari asociate',
            data.appointments.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.appointments.map((e) {
                    final start = '${e['startTime'] ?? ''}'.trim();
                    final end = '${e['endTime'] ?? ''}'.trim();
                    final interval = start.isNotEmpty || end.isNotEmpty
                        ? ' • $start-$end'
                        : '';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Data: ${e['date'] ?? '-'} | Interval: ${interval.replaceAll('•', '').trim().isEmpty ? '-' : interval.replaceAll('•', '').trim()} | Titlu: ${e['title'] ?? '-'} | Locatie: ${e['location'] ?? '-'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection('Echipa alocata', [
            _pdfLine('Echipa', data.currentTeamLabel),
            _pdfLine(
              'Membri',
              data.teamMembers.isEmpty ? '-' : data.teamMembers.join(', '),
            ),
          ]),
          _pdfSection(
            'Materiale asociate',
            data.materials.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.materials.map((e) {
                    final qty = (e['qty'] is num)
                        ? (e['qty'] as num).toDouble()
                        : double.tryParse(
                                '${e['qty'] ?? '0'}'.replaceAll(',', '.')) ??
                            0;
                    final price = (e['price'] is num)
                        ? (e['price'] as num).toDouble()
                        : double.tryParse(
                                '${e['price'] ?? '0'}'.replaceAll(',', '.')) ??
                            0;
                    final totalRaw = (e['total'] is num)
                        ? (e['total'] as num).toDouble()
                        : double.tryParse(
                                '${e['total'] ?? '0'}'.replaceAll(',', '.')) ??
                            0;
                    final total = totalRaw > 0 ? totalRaw : qty * price;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Material: ${e['name'] ?? '-'} | UM: ${e['um'] ?? '-'} | Cantitate: ${_f2(qty)} | Pret unitar: ${_f2(price)} | Total: ${_f2(total)}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection(
            'Echipamente furnizate de beneficiar',
            data.beneficiarySuppliedEquipment.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.beneficiarySuppliedEquipment.map((e) {
                    final qty = (e['quantity'] is num)
                        ? (e['quantity'] as num).toDouble()
                        : double.tryParse(
                                '${e['quantity'] ?? e['cantitate'] ?? '0'}'
                                    .replaceAll(',', '.')) ??
                            0;
                    final notes =
                        '${e['notes'] ?? e['observatii'] ?? ''}'.trim();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Denumire: ${e['name'] ?? e['denumire'] ?? '-'} | Tip: ${e['equipment_type'] ?? e['equipmentType'] ?? e['type'] ?? '-'} | Brand: ${e['brand'] ?? '-'} | Model: ${e['model'] ?? '-'} | Serie: ${e['serial_number'] ?? e['serialNumber'] ?? e['serie'] ?? '-'} | Cantitate: ${_f2(qty)}${notes.isEmpty ? '' : ' | Observatii: $notes'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection(
            'Materiale furnizate de beneficiar',
            data.beneficiarySuppliedMaterials.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.beneficiarySuppliedMaterials.map((e) {
                    final qty = (e['quantity'] is num)
                        ? (e['quantity'] as num).toDouble()
                        : double.tryParse(
                                '${e['quantity'] ?? e['cantitate'] ?? '0'}'
                                    .replaceAll(',', '.')) ??
                            0;
                    final notes =
                        '${e['notes'] ?? e['observatii'] ?? ''}'.trim();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Denumire: ${e['name'] ?? e['denumire'] ?? '-'} | UM: ${e['unit'] ?? e['um'] ?? '-'} | Cantitate: ${_f2(qty)}${notes.isEmpty ? '' : ' | Observatii: $notes'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection(
            'Manopera / ore',
            data.labor.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.labor.map((e) {
                    final hours = (e['hours'] is num)
                        ? (e['hours'] as num).toDouble()
                        : double.tryParse(
                                '${e['hours'] ?? '0'}'.replaceAll(',', '.')) ??
                            0;
                    final rate = (e['hourlyRate'] is num)
                        ? (e['hourlyRate'] as num).toDouble()
                        : double.tryParse('${e['hourlyRate'] ?? '0'}'
                                .replaceAll(',', '.')) ??
                            0;
                    final costOre = (e['costOre'] is num)
                        ? (e['costOre'] as num).toDouble()
                        : double.tryParse('${e['costOre'] ?? '0'}'
                                .replaceAll(',', '.')) ??
                            0;
                    final costDiurna = (e['costDiurna'] is num)
                        ? (e['costDiurna'] as num).toDouble()
                        : double.tryParse('${e['costDiurna'] ?? '0'}'
                                .replaceAll(',', '.')) ??
                            0;
                    final costCazare = (e['costCazare'] is num)
                        ? (e['costCazare'] as num).toDouble()
                        : double.tryParse('${e['costCazare'] ?? '0'}'
                                .replaceAll(',', '.')) ??
                            0;
                    final totalRaw = (e['costTotalLinie'] is num)
                        ? (e['costTotalLinie'] as num).toDouble()
                        : double.tryParse('${e['costTotalLinie'] ?? '0'}'
                                .replaceAll(',', '.')) ??
                            0;
                    final total = totalRaw > 0
                        ? totalRaw
                        : (costOre + costDiurna + costCazare);
                    final notes = '${e['notes'] ?? ''}'.trim();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Data: ${e['date'] ?? '-'} | Resursa: ${e['who'] ?? '-'} | Ore: ${_f2(hours)} | Tarif: ${_f2(rate)} | Cost ore: ${_f2(costOre)} | Cost diurna: ${_f2(costDiurna)} | Cost cazare: ${_f2(costCazare)} | Cost total: ${_f2(total)}${notes.isEmpty ? '' : ' | Observatii: $notes'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection(
            'Documente asociate',
            data.documents.isEmpty
                ? [pw.Text('Nu exista date.')]
                : data.documents.map((e) {
                    final type = '${e['tipDocument'] ?? e['type'] ?? '-'}';
                    final title = '${e['titlu'] ?? e['title'] ?? '-'}';
                    final number =
                        '${e['numarDocument'] ?? e['number'] ?? '-'}';
                    final date = '${e['dataDocument'] ?? e['date'] ?? '-'}';
                    final status = '${e['status'] ?? '-'}';
                    final notes =
                        '${e['observatii'] ?? e['notes'] ?? ''}'.trim();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Tip: $type | Titlu: $title | Numar: $number | Data: $date | Status: $status${notes.isEmpty ? '' : ' | Observatii: $notes'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
          _pdfSection(
            'Timeline taskuri / volum zilnic',
            data.workTaskEntries.isEmpty
                ? [pw.Text('Nu exista date.')]
                : [
                    ..._dailyTaskSummary().map((entry) {
                      final minutes = entry.value['minutes'] as int;
                      final tasks = entry.value['tasks'] as int;
                      final people = entry.value['people'] as Set<String>;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          _sanitizePdfText(
                            'Zi: ${_dayKeyLabel(entry.key)} | Ore totale: ${_f2(minutes / 60)} | Taskuri: $tasks | Persoane: ${people.length}',
                          ),
                        ),
                      );
                    }),
                    pw.SizedBox(height: 4),
                    ...data.workTaskEntries.map((e) {
                      final start =
                          _formatDateTimeValue(_parseIsoDateTime(e['startAt']));
                      final end =
                          _formatDateTimeValue(_parseIsoDateTime(e['endAt']));
                      final workers = _taskWorkers(e);
                      final notes = '${e['notes'] ?? ''}'.trim();
                      final completed = e['completed'] == true ? 'DA' : 'NU';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          _sanitizePdfText(
                            'Task: ${e['title'] ?? '-'} | Start: $start | Final: $end | Durata: ${_taskDurationLabel(e)} | Finalizat: $completed | Oameni: ${workers.isEmpty ? '-' : workers.join(', ')}${notes.isEmpty ? '' : ' | Obs: $notes'}',
                          ),
                        ),
                      );
                    }),
                  ],
          ),
          _pdfSection(
            'Productivitate pe persoana / zi',
            data.workTaskEntries.isEmpty
                ? [pw.Text('Nu exista date.')]
                : _dailyWorkerProductivity().isEmpty
                    ? [pw.Text('Nu exista date valide pentru calcul.')]
                    : _dailyWorkerProductivity().map((entry) {
                        final dayLabel = _dayKeyLabel('${entry['dayKey']}');
                        final worker = '${entry['worker'] ?? '-'}';
                        final minutes = (entry['minutes'] as int);
                        final tasks = (entry['tasks'] as int);
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            _sanitizePdfText(
                              'Zi: $dayLabel | Persoana: $worker | Ore: ${_f2(minutes / 60)} | Taskuri: $tasks',
                            ),
                          ),
                        );
                      }).toList(growable: false),
          ),
          _pdfSection(
            'Checklist / etape operative',
            _checklistDefs
                .map(
                  (entry) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      _sanitizePdfText(
                        '${(data.checklist[entry.key] ?? false) ? '[x]' : '[ ]'} ${entry.value}',
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          _pdfSection(
            'Jurnal / istoric',
            latestJournal.isEmpty
                ? [pw.Text('Nu exista date.')]
                : latestJournal.map((e) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        _sanitizePdfText(
                          'Data: ${_formatJournalDate('${e['at'] ?? ''}')} | Actiune: ${e['action'] ?? '-'} | Mesaj: ${e['message'] ?? '-'}',
                        ),
                      ),
                    );
                  }).toList(growable: false),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<String> _savePdfFile(Uint8List bytes, {bool saveAs = false}) async {
    final fileName =
        'raport_${_sanitizeFilePart(data.jobCode)}_${_sanitizeFilePart(data.clientName)}.pdf';
    return PdfSaveService.savePdf(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      category: PdfDocumentCategory.jobs,
      forceSaveAs: saveAs,
    );
  }

  Future<void> _onExportPdf(BuildContext context, {bool saveAs = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Se genereaza PDF...')),
    );
    try {
      final bytes = await _buildPdfBytes();
      final path = await _savePdfFile(bytes, saveAs: saveAs);
      messenger.showSnackBar(
        SnackBar(content: Text('PDF generat cu succes: $path')),
      );
      if (!context.mounted) return;
      await _showGeneratedPdfActions(context, path);
    } on PdfSaveCanceledException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Salvarea documentului a fost anulata.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nu am putut genera PDF-ul.')),
      );
    }
  }

  Future<void> _showGeneratedPdfActions(
    BuildContext context,
    String filePath,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raport PDF generat',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  filePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final result =
                            await DocumentFileService.openFile(filePath);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                        if (result.shouldOfferShare && context.mounted) {
                          await _shareGeneratedPdf(context, filePath);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareGeneratedPdf(context, filePath);
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    if (!DocumentFileService.isMobilePlatform)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final opened =
                              await DocumentFileService.openFolderForFile(
                            filePath,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? 'Folder deschis.'
                                    : 'Nu am putut deschide folderul.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareGeneratedPdf(BuildContext context, String filePath) async {
    try {
      await DocumentFileService.shareFile(
        filePath,
        subject: data.jobCode.trim().isEmpty ? 'Raport lucrare' : data.jobCode,
        text: 'Raport lucrare generat din aplicatie.',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share deschis pentru raport.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut trimite PDF-ul: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raport lucrare'),
        actions: [
          TextButton.icon(
            onPressed: () => _onExportPdf(context),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF'),
          ),
          TextButton.icon(
            onPressed: () => _onExportPdf(context, saveAs: true),
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('Save As'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            context,
            'Antet raport',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Cod lucrare', data.jobCode),
                _chip('Titlu lucrare', data.jobTitle),
                _chip('Client', data.clientName),
                _chip('Locatie', data.location),
                _chip('Status', data.statusLabel),
                _chip('Valoare estimata', _f2(data.estimatedValue)),
                _chip('Data generarii', data.generatedAtLabel),
              ],
            ),
          ),
          _section(
            context,
            'Sumar operativ',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Total materiale', _f2(data.materialsTotal)),
                _chip('Total manopera ore', _f2(data.laborOreTotal)),
                _chip('Total diurna', _f2(data.laborPerDiemTotal)),
                _chip('Total cazare', _f2(data.laborLodgingTotal)),
                _chip('Total manopera completa', _f2(data.laborCompleteTotal)),
                _chip('Cost real total', _f2(data.realTotal)),
                _chip('Diferenta estimat vs real', _f2(data.estimatedVsReal)),
                _chip('Numar materiale', data.materialsCount.toString()),
                _chip('Numar inregistrari ore', data.laborCount.toString()),
                _chip('Numar programari', data.appointmentsCount.toString()),
                _chip('Echipa curenta', data.currentTeamLabel),
              ],
            ),
          ),
          _section(
            context,
            'Programari asociate',
            data.appointments.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children: List<Widget>.generate(data.appointments.length,
                        (index) {
                      final e = data.appointments[index];
                      final start = '${e['startTime'] ?? ''}'.trim();
                      final end = '${e['endTime'] ?? ''}'.trim();
                      final interval = start.isNotEmpty || end.isNotEmpty
                          ? ' • $start - $end'
                          : '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e['title'] ?? '-'}'),
                        subtitle: Text(
                          '${e['date'] ?? '-'}$interval\n'
                          'Locatie: ${e['location'] ?? '-'} • Status: ${e['status'] ?? '-'}',
                        ),
                      );
                    }),
                  ),
          ),
          _section(
            context,
            'Echipa alocata',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.currentTeamLabel),
                const SizedBox(height: 6),
                Text(
                  data.teamMembers.isEmpty
                      ? 'Membri: -'
                      : 'Membri: ${data.teamMembers.join(', ')}',
                ),
              ],
            ),
          ),
          _section(
            context,
            'Materiale asociate',
            data.materials.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children:
                        List<Widget>.generate(data.materials.length, (index) {
                      final e = data.materials[index];
                      final qty = (e['qty'] is num)
                          ? (e['qty'] as num).toDouble()
                          : double.tryParse(
                                  '${e['qty'] ?? '0'}'.replaceAll(',', '.')) ??
                              0;
                      final price = (e['price'] is num)
                          ? (e['price'] as num).toDouble()
                          : double.tryParse('${e['price'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final totalRaw = (e['total'] is num)
                          ? (e['total'] as num).toDouble()
                          : double.tryParse('${e['total'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final total = totalRaw > 0 ? totalRaw : qty * price;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e['name'] ?? '-'}'),
                        subtitle: Text(
                          'UM: ${e['um'] ?? '-'} • Cantitate: ${_f2(qty)} • Pret unitar: ${_f2(price)} • Total: ${_f2(total)}',
                        ),
                      );
                    }),
                  ),
          ),
          _section(
            context,
            'Echipamente furnizate de beneficiar',
            data.beneficiarySuppliedEquipment.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children: List<Widget>.generate(
                      data.beneficiarySuppliedEquipment.length,
                      (index) {
                        final e = data.beneficiarySuppliedEquipment[index];
                        final qty = (e['quantity'] is num)
                            ? (e['quantity'] as num).toDouble()
                            : double.tryParse(
                                    '${e['quantity'] ?? e['cantitate'] ?? '0'}'
                                        .replaceAll(',', '.')) ??
                                0;
                        final notes =
                            '${e['notes'] ?? e['observatii'] ?? ''}'.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${e['name'] ?? e['denumire'] ?? '-'}'),
                          subtitle: Text(
                            notes.isEmpty
                                ? 'Tip: ${e['equipment_type'] ?? e['equipmentType'] ?? e['type'] ?? '-'} • Brand: ${e['brand'] ?? '-'} • Model: ${e['model'] ?? '-'} • Serie: ${e['serial_number'] ?? e['serialNumber'] ?? e['serie'] ?? '-'} • Cantitate: ${_f2(qty)}'
                                : 'Tip: ${e['equipment_type'] ?? e['equipmentType'] ?? e['type'] ?? '-'} • Brand: ${e['brand'] ?? '-'} • Model: ${e['model'] ?? '-'} • Serie: ${e['serial_number'] ?? e['serialNumber'] ?? e['serie'] ?? '-'} • Cantitate: ${_f2(qty)}\nObservatii: $notes',
                          ),
                        );
                      },
                    ),
                  ),
          ),
          _section(
            context,
            'Materiale furnizate de beneficiar',
            data.beneficiarySuppliedMaterials.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children: List<Widget>.generate(
                      data.beneficiarySuppliedMaterials.length,
                      (index) {
                        final e = data.beneficiarySuppliedMaterials[index];
                        final qty = (e['quantity'] is num)
                            ? (e['quantity'] as num).toDouble()
                            : double.tryParse(
                                    '${e['quantity'] ?? e['cantitate'] ?? '0'}'
                                        .replaceAll(',', '.')) ??
                                0;
                        final notes =
                            '${e['notes'] ?? e['observatii'] ?? ''}'.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${e['name'] ?? e['denumire'] ?? '-'}'),
                          subtitle: Text(
                            notes.isEmpty
                                ? 'UM: ${e['unit'] ?? e['um'] ?? '-'} • Cantitate: ${_f2(qty)}'
                                : 'UM: ${e['unit'] ?? e['um'] ?? '-'} • Cantitate: ${_f2(qty)}\nObservatii: $notes',
                          ),
                        );
                      },
                    ),
                  ),
          ),
          _section(
            context,
            'Manopera / ore',
            data.labor.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children: List<Widget>.generate(data.labor.length, (index) {
                      final e = data.labor[index];
                      final hours = (e['hours'] is num)
                          ? (e['hours'] as num).toDouble()
                          : double.tryParse('${e['hours'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final rate = (e['hourlyRate'] is num)
                          ? (e['hourlyRate'] as num).toDouble()
                          : double.tryParse('${e['hourlyRate'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final costOre = (e['costOre'] is num)
                          ? (e['costOre'] as num).toDouble()
                          : double.tryParse('${e['costOre'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final costDiurna = (e['costDiurna'] is num)
                          ? (e['costDiurna'] as num).toDouble()
                          : double.tryParse('${e['costDiurna'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final costCazare = (e['costCazare'] is num)
                          ? (e['costCazare'] as num).toDouble()
                          : double.tryParse('${e['costCazare'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final totalRaw = (e['costTotalLinie'] is num)
                          ? (e['costTotalLinie'] as num).toDouble()
                          : double.tryParse('${e['costTotalLinie'] ?? '0'}'
                                  .replaceAll(',', '.')) ??
                              0;
                      final total = totalRaw > 0
                          ? totalRaw
                          : (costOre + costDiurna + costCazare);
                      final notes = '${e['notes'] ?? ''}'.trim();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e['who'] ?? '-'}'),
                        subtitle: Text(
                          notes.isEmpty
                              ? '${e['date'] ?? '-'} • Ore: ${_f2(hours)} • Tarif: ${_f2(rate)} • Cost ore: ${_f2(costOre)} • Cost diurna: ${_f2(costDiurna)} • Cost cazare: ${_f2(costCazare)} • Cost total: ${_f2(total)}'
                              : '${e['date'] ?? '-'} • Ore: ${_f2(hours)} • Tarif: ${_f2(rate)} • Cost ore: ${_f2(costOre)} • Cost diurna: ${_f2(costDiurna)} • Cost cazare: ${_f2(costCazare)} • Cost total: ${_f2(total)}\nObservatii: $notes',
                        ),
                      );
                    }),
                  ),
          ),
          _section(
            context,
            'Documente asociate',
            data.documents.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children:
                        List<Widget>.generate(data.documents.length, (index) {
                      final e = data.documents[index];
                      final type = '${e['tipDocument'] ?? e['type'] ?? '-'}';
                      final title = '${e['titlu'] ?? e['title'] ?? '-'}';
                      final number =
                          '${e['numarDocument'] ?? e['number'] ?? '-'}';
                      final date = '${e['dataDocument'] ?? e['date'] ?? '-'}';
                      final status = '${e['status'] ?? '-'}';
                      final notes =
                          '${e['observatii'] ?? e['notes'] ?? ''}'.trim();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(title),
                        subtitle: Text(
                          notes.isEmpty
                              ? '$type • Nr: $number • $date • Status: $status'
                              : '$type • Nr: $number • $date • Status: $status\n$notes',
                        ),
                      );
                    }),
                  ),
          ),
          _section(
            context,
            'Timeline taskuri / volum zilnic',
            data.workTaskEntries.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dailyTaskSummary().map((entry) {
                          final minutes = entry.value['minutes'] as int;
                          final tasks = entry.value['tasks'] as int;
                          final people = entry.value['people'] as Set<String>;
                          return _chip(
                            _dayKeyLabel(entry.key),
                            '${_f2(minutes / 60)}h | $tasks task | ${people.length} pers',
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      ...List<Widget>.generate(data.workTaskEntries.length,
                          (index) {
                        final e = data.workTaskEntries[index];
                        final workers = _taskWorkers(e);
                        final notes = '${e['notes'] ?? ''}'.trim();
                        final completed = e['completed'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text('${e['title'] ?? '-'}'),
                          subtitle: Text(
                            notes.isEmpty
                                ? '${_formatDateTimeValue(_parseIsoDateTime(e['startAt']))} - ${_formatDateTimeValue(_parseIsoDateTime(e['endAt']))} • Durata: ${_taskDurationLabel(e)} • Oameni: ${workers.isEmpty ? '-' : workers.join(', ')}'
                                : '${_formatDateTimeValue(_parseIsoDateTime(e['startAt']))} - ${_formatDateTimeValue(_parseIsoDateTime(e['endAt']))} • Durata: ${_taskDurationLabel(e)} • Oameni: ${workers.isEmpty ? '-' : workers.join(', ')}\nObs: $notes',
                          ),
                        );
                      }),
                    ],
                  ),
          ),
          _section(
            context,
            'Productivitate pe persoana / zi',
            data.workTaskEntries.isEmpty
                ? const Text('Nu exista date.')
                : _dailyWorkerProductivity().isEmpty
                    ? const Text('Nu exista date valide pentru calcul.')
                    : Column(
                        children: List<Widget>.generate(
                          _dailyWorkerProductivity().length,
                          (index) {
                            final entry = _dailyWorkerProductivity()[index];
                            final dayLabel =
                                _dayKeyLabel('${entry['dayKey'] ?? ''}');
                            final worker = '${entry['worker'] ?? '-'}';
                            final minutes = (entry['minutes'] as int);
                            final tasks = (entry['tasks'] as int);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(worker),
                              subtitle: Text(
                                '$dayLabel • Ore: ${_f2(minutes / 60)} • Taskuri: $tasks',
                              ),
                            );
                          },
                        ),
                      ),
          ),
          _section(
            context,
            'Checklist / etape operative',
            Column(
              children: _checklistDefs
                  .map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        (data.checklist[entry.key] ?? false)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(entry.value),
                      subtitle: Text((data.checklist[entry.key] ?? false)
                          ? 'Bifat'
                          : 'Nebifat'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          _section(
            context,
            'Jurnal / istoric',
            data.journal.isEmpty
                ? const Text('Nu exista date.')
                : Column(
                    children: List<Widget>.generate(
                        _latestJournal(data.journal).length, (index) {
                      final e = _latestJournal(data.journal)[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e['message'] ?? '-'}'),
                        subtitle:
                            Text('${e['action'] ?? '-'} • ${e['at'] ?? '-'}'),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}
