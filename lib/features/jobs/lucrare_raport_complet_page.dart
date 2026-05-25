import 'package:flutter/material.dart';

import 'job_document_type_utils.dart';

/// Pagina de raport complet al unei lucrări — afișează toate datele agregate
/// (materiale, manoperă, programări, documente) într-o singură pagină de vizualizare.
class LucrareRaportCompletPage extends StatelessWidget {
  const LucrareRaportCompletPage({
    super.key,
    required this.data,
    this.onExportPdf,
  });

  final dynamic data;
  final Future<void> Function(Map<String, dynamic> payload)? onExportPdf;

  dynamic _tryReadDataField(List<String> keys) {
    if (data is Map) {
      final map = data as Map;
      for (final key in keys) {
        if (map.containsKey(key)) {
          return map[key];
        }
      }
    }

    for (final key in keys) {
      try {
        switch (key) {
          case 'jobCode':
            return (data as dynamic).jobCode;
          case 'jobTitle':
            return (data as dynamic).jobTitle;
          case 'clientName':
            return (data as dynamic).clientName;
          case 'location':
            return (data as dynamic).location;
          case 'statusLabel':
            return (data as dynamic).statusLabel;
          case 'estimatedValue':
            return (data as dynamic).estimatedValue;
          case 'realTotalCost':
            return (data as dynamic).realTotalCost;
          case 'differenceVsEstimate':
            return (data as dynamic).differenceVsEstimate;
          case 'materialTotal':
            return (data as dynamic).materialTotal;
          case 'laborFullTotal':
            return (data as dynamic).laborFullTotal;
          case 'laborPerDiemTotal':
            return (data as dynamic).laborPerDiemTotal;
          case 'laborLodgingTotal':
            return (data as dynamic).laborLodgingTotal;
          case 'materialsCount':
            return (data as dynamic).materialsCount;
          case 'laborEntriesCount':
            return (data as dynamic).laborEntriesCount;
          case 'appointmentsCount':
            return (data as dynamic).appointmentsCount;
          case 'personHoursTotal':
            return (data as dynamic).personHoursTotal;
          case 'teamHoursTotal':
            return (data as dynamic).teamHoursTotal;
          case 'currentTeamLabel':
            return (data as dynamic).currentTeamLabel;
          case 'appointments':
            return (data as dynamic).appointments;
          case 'materials':
            return (data as dynamic).materials;
          case 'labor':
            return (data as dynamic).labor;
          case 'documents':
            return (data as dynamic).documents;
          case 'generatedAt':
            return (data as dynamic).generatedAt;
          case 'generatedOn':
            return (data as dynamic).generatedOn;
          case 'generatedDate':
            return (data as dynamic).generatedDate;
        }
      } catch (_) {
        // try next key safely
      }
    }
    return null;
  }

  String _readDataString(List<String> keys, {String fallback = '-'}) {
    final value = _tryReadDataField(keys);
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  double _readDataNum(List<String> keys, {double fallback = 0}) {
    final value = _tryReadDataField(keys);
    if (value is num) return value.toDouble();
    final parsed = double.tryParse('${value ?? ''}'.replaceAll(',', '.'));
    return parsed ?? fallback;
  }

  int _readDataInt(List<String> keys, {int fallback = 0}) {
    final value = _tryReadDataField(keys);
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse('${value ?? ''}');
    return parsed ?? fallback;
  }

  List<Map<String, dynamic>> _readDataRows(List<String> keys) {
    final value = _tryReadDataField(keys);
    if (value is List) {
      return value.map((e) => _asMap(e)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _read(dynamic rowRaw, List<String> keys) {
    final row = _asMap(rowRaw);
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '-';
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
  }

  String _normalizeDocType(dynamic rowRaw) {
    final row = _asMap(rowRaw);
    final candidates = <String>[
      '${row['type'] ?? ''}',
      '${row['tipDocument'] ?? ''}',
      '${row['documentSubtype'] ?? ''}',
      '${row['documentType'] ?? ''}',
      '${row['typeLegacy'] ?? ''}',
    ];
    for (final candidate in candidates) {
      final normalized = normalizeDocumentTypeCanonical(candidate);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  Map<String, int> _documentCounts() {
    final counts = <String, int>{
      'oferta': 0,
      'deviz': 0,
      'contract': 0,
      'pv': 0,
      'pif': 0,
    };
    final docs = _readDataRows(const ['documents']);
    for (final row in docs) {
      final type = _normalizeDocType(row);
      if (counts.containsKey(type)) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    return counts;
  }

  String _money(double value) => value.toStringAsFixed(2);

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDocStatusChips(Map<String, int> counts) {
    Widget chip(String label, int value) {
      final exists = value > 0;
      return Chip(
        avatar: Icon(
          exists ? Icons.check_circle_outline : Icons.remove_circle_outline,
          size: 16,
          color: exists ? Colors.green.shade700 : Colors.grey.shade600,
        ),
        label: Text('$label: ${exists ? 'exista' : 'lipseste'}'),
      );
    }

    return [
      chip('Oferta', counts['oferta'] ?? 0),
      chip('Deviz', counts['deviz'] ?? 0),
      chip('Contract', counts['contract'] ?? 0),
      chip('PV', counts['pv'] ?? 0),
      chip('PIF', counts['pif'] ?? 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final counts = _documentCounts();
    final jobCode = _readDataString(const ['jobCode']);
    final jobTitle = _readDataString(const ['jobTitle']);
    final clientName = _readDataString(const ['clientName']);
    final location = _readDataString(const ['location']);
    final statusLabel = _readDataString(const ['statusLabel']);
    final generatedAt = _readDataString(
      const ['generatedAt', 'generatedOn', 'generatedDate'],
      fallback: DateTime.now().toIso8601String(),
    );

    final estimatedValue = _readDataNum(const ['estimatedValue']);
    final realTotalCostRaw = _readDataNum(const ['realTotalCost']);
    final differenceVsEstimateRaw =
        _readDataNum(const ['differenceVsEstimate']);
    final materialTotalRaw = _readDataNum(const ['materialTotal']);
    final laborFullTotalRaw = _readDataNum(const ['laborFullTotal']);
    final laborPerDiemTotalRaw = _readDataNum(const ['laborPerDiemTotal']);
    final laborLodgingTotalRaw = _readDataNum(const ['laborLodgingTotal']);
    final materialsCountRaw = _readDataInt(const ['materialsCount']);
    final laborEntriesCountRaw = _readDataInt(const ['laborEntriesCount']);
    final appointmentsCountRaw = _readDataInt(const ['appointmentsCount']);
    final personHoursTotalRaw = _readDataNum(const ['personHoursTotal']);
    final teamHoursTotalRaw = _readDataNum(const ['teamHoursTotal']);
    final currentTeamLabel = _readDataString(const ['currentTeamLabel']);

    final appointments = _readDataRows(const ['appointments']);
    final materials = _readDataRows(const ['materials']);
    final labor = _readDataRows(const ['labor']);
    final documents = _readDataRows(const ['documents']);
    final beneficiaryEquipment =
        _readDataRows(const ['beneficiarySuppliedEquipment']);
    final beneficiaryMaterials =
        _readDataRows(const ['beneficiarySuppliedMaterials']);

    final computedMaterialTotal = materials.fold<double>(0, (sum, row) {
      final total = _asDouble(row['total']);
      if (total > 0) return sum + total;
      final qty = _asDouble(row['qty']);
      final price = _asDouble(row['price']);
      return sum + (qty * price);
    });
    final computedLaborPerDiem = labor.fold<double>(
      0,
      (sum, row) =>
          sum + _asDouble(row['costDiurna']) + _asDouble(row['cost_diurna']),
    );
    final computedLaborLodging = labor.fold<double>(
      0,
      (sum, row) =>
          sum + _asDouble(row['costCazare']) + _asDouble(row['cost_cazare']),
    );
    final computedLaborFull = labor.fold<double>(0, (sum, row) {
      final full =
          _asDouble(row['costTotalLinie']) + _asDouble(row['cost_total_linie']);
      if (full > 0) return sum + full;
      final ore = _asDouble(row['costOre']) + _asDouble(row['cost_ore']);
      final diurna =
          _asDouble(row['costDiurna']) + _asDouble(row['cost_diurna']);
      final cazare =
          _asDouble(row['costCazare']) + _asDouble(row['cost_cazare']);
      final legacy = _asDouble(row['total']);
      return sum + (legacy > 0 ? legacy : ore + diurna + cazare);
    });

    var computedPersonHours = 0.0;
    var computedTeamHours = 0.0;
    for (final row in labor) {
      final type = _read(row, const ['type', 'entryType', 'tip']).toLowerCase();
      final hours = _asDouble(row['hours']) + _asDouble(row['ore']);
      if (type.contains('team') || type.contains('echipa')) {
        computedTeamHours += hours;
      } else {
        computedPersonHours += hours;
      }
    }

    final materialTotal =
        materialTotalRaw > 0 ? materialTotalRaw : computedMaterialTotal;
    final laborPerDiemTotal =
        laborPerDiemTotalRaw > 0 ? laborPerDiemTotalRaw : computedLaborPerDiem;
    final laborLodgingTotal =
        laborLodgingTotalRaw > 0 ? laborLodgingTotalRaw : computedLaborLodging;
    final laborFullTotal =
        laborFullTotalRaw > 0 ? laborFullTotalRaw : computedLaborFull;
    final realTotalCost = realTotalCostRaw > 0
        ? realTotalCostRaw
        : materialTotal + laborFullTotal;
    final differenceVsEstimate = differenceVsEstimateRaw != 0
        ? differenceVsEstimateRaw
        : estimatedValue - realTotalCost;
    final materialsCount =
        materialsCountRaw > 0 ? materialsCountRaw : materials.length;
    final laborEntriesCount =
        laborEntriesCountRaw > 0 ? laborEntriesCountRaw : labor.length;
    final appointmentsCount =
        appointmentsCountRaw > 0 ? appointmentsCountRaw : appointments.length;
    final personHoursTotal =
        personHoursTotalRaw > 0 ? personHoursTotalRaw : computedPersonHours;
    final teamHoursTotal =
        teamHoursTotalRaw > 0 ? teamHoursTotalRaw : computedTeamHours;

    final lastDocuments = [...documents]..sort((a, b) =>
        _read(b, const ['updatedAt', 'createdAt'])
            .compareTo(_read(a, const ['updatedAt', 'createdAt'])));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raport complet lucrare'),
        actions: [
          TextButton.icon(
            onPressed: onExportPdf == null
                ? null
                : () async {
                    try {
                      await onExportPdf!(_asMap(data));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Raport PDF salvat.')),
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nu am putut exporta raportul PDF.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Header lucrare',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cod: $jobCode'),
                  Text('Titlu: $jobTitle'),
                  Text('Client: $clientName'),
                  Text('Locatie: $location'),
                  Text('Status lucrare: $statusLabel'),
                  Text('Generat la: $generatedAt'),
                ],
              ),
            ),
            _section(
              'Indicatori economici si operativi',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('Valoare estimata', _money(estimatedValue)),
                  _metric('Cost real total', _money(realTotalCost)),
                  _metric('Diferenta estimat vs real',
                      _money(differenceVsEstimate)),
                  _metric('Total materiale', _money(materialTotal)),
                  _metric('Total manopera', _money(laborFullTotal)),
                  _metric('Total diurna', _money(laborPerDiemTotal)),
                  _metric('Total cazare', _money(laborLodgingTotal)),
                  _metric('Numar materiale', '$materialsCount'),
                  _metric('Numar inregistrari ore', '$laborEntriesCount'),
                  _metric('Numar programari', '$appointmentsCount'),
                  _metric('Ore persoane', personHoursTotal.toStringAsFixed(2)),
                  _metric('Ore echipe', teamHoursTotal.toStringAsFixed(2)),
                  _metric('Echipa alocata', currentTeamLabel),
                ],
              ),
            ),
            _section(
              'Situatie documente',
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildDocStatusChips(counts)),
            ),
            _section(
              'Programari asociate',
              appointments.isEmpty
                  ? const Text('Nu exista programari asociate.')
                  : Column(
                      children: appointments
                          .map(
                            (row) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_read(row, const ['title', 'titlu'])),
                              subtitle: Text(
                                'Data: ${_read(row, const [
                                      'date',
                                      'data'
                                    ])} | Locatie: ${_read(row, const [
                                      'location',
                                      'locatie'
                                    ])} | Status: ${_read(row, const [
                                      'status'
                                    ])}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            _section(
              'Materiale asociate',
              materials.isEmpty
                  ? const Text('Nu exista materiale asociate.')
                  : Column(
                      children: materials.map((row) {
                        final qty = _asDouble(row['qty']);
                        final price = _asDouble(row['price']);
                        final total = _asDouble(row['total']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_read(row, const ['name', 'denumire'])),
                          subtitle: Text(
                            'UM: ${_read(row, const [
                                  'um'
                                ])} | Cant: ${qty.toStringAsFixed(2)} | Pret: ${price.toStringAsFixed(2)} | Total: ${total.toStringAsFixed(2)}',
                          ),
                        );
                      }).toList(growable: false),
                    ),
            ),
            _section(
              'Echipamente furnizate de beneficiar',
              beneficiaryEquipment.isEmpty
                  ? const Text('Nu exista echipamente furnizate de beneficiar.')
                  : Column(
                      children: beneficiaryEquipment.map((row) {
                        final qty =
                            _asDouble(row['quantity'] ?? row['cantitate']);
                        final notes = _read(row, const ['notes', 'observatii']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_read(row, const ['name', 'denumire'])),
                          subtitle: Text(
                            notes == '-'
                                ? 'Tip: ${_read(row, const [
                                        'equipment_type',
                                        'equipmentType',
                                        'type'
                                      ])} | Brand: ${_read(row, const [
                                        'brand'
                                      ])} | Model: ${_read(row, const [
                                        'model'
                                      ])} | Serie: ${_read(row, const [
                                        'serial_number',
                                        'serialNumber',
                                        'serie'
                                      ])} | Cantitate: ${qty.toStringAsFixed(2)}'
                                : 'Tip: ${_read(row, const [
                                        'equipment_type',
                                        'equipmentType',
                                        'type'
                                      ])} | Brand: ${_read(row, const [
                                        'brand'
                                      ])} | Model: ${_read(row, const [
                                        'model'
                                      ])} | Serie: ${_read(row, const [
                                        'serial_number',
                                        'serialNumber',
                                        'serie'
                                      ])} | Cantitate: ${qty.toStringAsFixed(2)}\nObservatii: $notes',
                          ),
                        );
                      }).toList(growable: false),
                    ),
            ),
            _section(
              'Materiale furnizate de beneficiar',
              beneficiaryMaterials.isEmpty
                  ? const Text('Nu exista materiale furnizate de beneficiar.')
                  : Column(
                      children: beneficiaryMaterials.map((row) {
                        final qty =
                            _asDouble(row['quantity'] ?? row['cantitate']);
                        final notes = _read(row, const ['notes', 'observatii']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_read(row, const ['name', 'denumire'])),
                          subtitle: Text(
                            notes == '-'
                                ? 'UM: ${_read(row, const [
                                        'unit',
                                        'um'
                                      ])} | Cantitate: ${qty.toStringAsFixed(2)}'
                                : 'UM: ${_read(row, const [
                                        'unit',
                                        'um'
                                      ])} | Cantitate: ${qty.toStringAsFixed(2)}\nObservatii: $notes',
                          ),
                        );
                      }).toList(growable: false),
                    ),
            ),
            _section(
              'Manopera / ore',
              labor.isEmpty
                  ? const Text('Nu exista inregistrari de manopera.')
                  : Column(
                      children: labor.map((row) {
                        final hours = _asDouble(row['hours']);
                        final rate = _asDouble(row['hourlyRate']);
                        final total = _asDouble(row['costTotalLinie']) > 0
                            ? _asDouble(row['costTotalLinie'])
                            : _asDouble(row['total']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              _read(row, const ['whoLabel', 'who', 'label'])),
                          subtitle: Text(
                            'Data: ${_read(row, const [
                                  'date',
                                  'data'
                                ])} | Ore: ${hours.toStringAsFixed(2)} | Tarif: ${rate.toStringAsFixed(2)} | Total linie: ${total.toStringAsFixed(2)}',
                          ),
                        );
                      }).toList(growable: false),
                    ),
            ),
            _section(
              'Ultimele documente utile',
              lastDocuments.isEmpty
                  ? const Text('Nu exista documente asociate.')
                  : Column(
                      children: lastDocuments
                          .take(8)
                          .map(
                            (row) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${documentTypeLabelFromCanonical(_normalizeDocType(row))} - ${_read(row, const [
                                      'numarDocument',
                                      'number'
                                    ])}',
                              ),
                              subtitle: Text(
                                'Status: ${_read(row, const [
                                      'status'
                                    ])} | Data: ${_read(row, const [
                                      'dataDocument',
                                      'date'
                                    ])}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
