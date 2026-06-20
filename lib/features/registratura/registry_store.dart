import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class RegistryStore {
  static String normalizeDocumentTypeUi(dynamic rawType) {
    final raw = '${rawType ?? ''}'.trim().toLowerCase();
    if (raw.isEmpty) return '';
    final compact = raw
        .replaceAll(RegExp(r'[\s_\-]+'), ' ')
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .trim();
    if (compact == 'of' || compact == 'oferta' || compact.startsWith('oferta ')) return 'oferta';
    if (compact == 'dv' || compact == 'deviz' || compact.startsWith('deviz ')) return 'deviz';
    if (compact == 'ct' || compact == 'contract' || compact.startsWith('contract ')) return 'contract';
    if (compact == 'pv' || compact == 'proces verbal' || compact == 'proces-verbal') return 'pv';
    if (compact == 'pif' || compact.startsWith('pif ')) return 'pif';
    if (compact == 'raport_lucrare' || compact == 'raport lucrare' || compact == 'raport') {
      return 'raport_lucrare';
    }
    return compact.replaceAll(' ', '_');
  }

  static String documentTypeLabelUi(dynamic rawType) {
    switch (normalizeDocumentTypeUi(rawType)) {
      case 'oferta':
        return 'Ofertă';
      case 'deviz':
        return 'Deviz';
      case 'contract':
        return 'Contract';
      case 'pv':
        return 'Proces verbal';
      case 'pif':
        return 'PIF';
      case 'raport_lucrare':
        return 'Raport lucrare';
      default:
        return 'Alt document';
    }
  }
  static const String _entriesKey = 'devizpro_registry_entries_v1';
  static const String _counterPrefix = 'devizpro_registry_counter_';
  static const List<Map<String, String>> _knownDocumentSources =
      <Map<String, String>>[
    {'key': 'devizpro_offers_v1', 'type': 'oferta'},
    {'key': 'offers', 'type': 'oferta'},
    {'key': 'oferte', 'type': 'oferta'},
    {'key': 'devizpro_estimates_v1', 'type': 'deviz'},
    {'key': 'estimates', 'type': 'deviz'},
    {'key': 'devize', 'type': 'deviz'},
    {'key': 'devizpro_contracts_v1', 'type': 'contract'},
    {'key': 'contracts', 'type': 'contract'},
    {'key': 'contracte', 'type': 'contract'},
    {'key': 'devizpro_job_documents_v1', 'type': 'other'},
    {'key': 'job_documents', 'type': 'other'},
  ];

  static String normalizeDocumentType(dynamic raw) {
    final value = '${raw ?? ''}'.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value == 'process_verbal' ||
        value == 'proces_verbal' ||
        value == 'proces verbal' ||
        value == 'procesverbal' ||
        value == 'pv') {
      return 'process_verbal';
    }
    if (value == 'pif') {
      return 'pif';
    }
    if (value == 'oferta' || value == 'ofertă' || value == 'offer') {
      return 'oferta';
    }
    if (value == 'deviz' || value == 'estimate' || value == 'deviz intern') {
      return 'deviz';
    }
    if (value == 'contract') {
      return 'contract';
    }
    return value.replaceAll(' ', '_');
  }

  static String prefixForType(String typeRaw) {
    final type = normalizeDocumentType(typeRaw);
    switch (type) {
      case 'oferta':
        return 'OF';
      case 'deviz':
        return 'DV';
      case 'contract':
        return 'CT';
      case 'process_verbal':
        return 'PV';
      case 'pif':
        return 'PIF';
      default:
        return type.isEmpty ? 'DOC' : type.toUpperCase();
    }
  }

  static String labelForType(String typeRaw) {
    final type = normalizeDocumentType(typeRaw);
    switch (type) {
      case 'oferta':
        return 'Ofertă';
      case 'deviz':
        return 'Deviz';
      case 'contract':
        return 'Contract';
      case 'process_verbal':
        return 'Proces verbal';
      case 'pif':
        return 'PIF';
      default:
        return type.isEmpty ? 'Document' : type.replaceAll('_', ' ');
    }
  }

  static Future<List<Map<String, dynamic>>> readEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_entriesKey) ?? const <String>[];
    final rows = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          rows.add(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('[RegistryStore] parsare intrare registratură eșuată: $e');
      }
    }
    rows.sort((a, b) {
      final aUpdated = '${a['updatedAt'] ?? a['createdAt'] ?? ''}';
      final bUpdated = '${b['updatedAt'] ?? b['createdAt'] ?? ''}';
      return bUpdated.compareTo(aUpdated);
    });
    return rows;
  }

  static Future<void> syncKnownDocumentSources({
    bool persistAllocatedNumbersBack = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final source in _knownDocumentSources) {
      final key = source['key'] ?? '';
      final defaultType = source['type'] ?? 'other';
      if (key.isEmpty) {
        continue;
      }
      final rows = _readRowsFromKey(prefs, key);
      if (rows.isEmpty) {
        continue;
      }
      var rowsChanged = false;
      for (final row in rows) {
        final normalizedType = normalizeDocumentType(
          row['type'] ?? row['tipDocument'] ?? row['documentType'] ?? defaultType,
        );
        if (normalizedType.isEmpty) {
          continue;
        }
        final existingNumber = _stringFromAny(
          row['number'] ??
              row['numarDocument'] ??
              row['offerNumber'] ??
              row['devizNumber'] ??
              row['contractNumber'],
        );
        final allocatedNumber = await allocateNumber(
          type: normalizedType,
          existingNumber: existingNumber,
        );
        if (existingNumber.trim().isEmpty && persistAllocatedNumbersBack) {
          row['numarDocument'] = allocatedNumber;
          row['number'] = allocatedNumber;
          rowsChanged = true;
        }
        final title = _stringFromAny(
          row['title'] ??
              row['titlu'] ??
              row['documentTitle'] ??
              row['titlu_oferta'] ??
              row['titluOferta'],
        );
        final date = _stringFromAny(
          row['date'] ??
              row['data'] ??
              row['documentDate'] ??
              row['dataDocument'] ??
              row['createdAt'],
        );
        final status = _stringFromAny(row['status']);
        final client = _extractClientName(row);
        final jobCode = _stringFromAny(
          row['jobCode'] ??
              row['job_code'] ??
              row['jobId'] ??
              row['job_id'] ??
              row['offerCode'] ??
              row['devizCode'],
        );
        final refId = _stringFromAny(row['id']);
        final filePath = _stringFromAny(row['pdfPath'] ?? row['filePath'] ?? row['path']);
        await upsertEntry(
          type: normalizedType,
          number: allocatedNumber,
          title: title,
          documentDate: date,
          status: status,
          clientName: client,
          jobCode: jobCode,
          jobId: jobCode,
          referenceId: refId,
          filePath: filePath,
          source: key,
        );
      }
      if (rowsChanged && persistAllocatedNumbersBack) {
        await _writeRowsToKey(prefs, key, rows);
      }
    }
  }

  static Future<String> allocateNumber({
    required String type,
    String? existingNumber,
  }) async {
    final normalizedType = normalizeDocumentType(type);
    final existing = (existingNumber ?? '').trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final prefs = await SharedPreferences.getInstance();
    final prefix = prefixForType(normalizedType);
    final counterKey = _counterPrefix + normalizedType;
    final currentCounter = prefs.getInt(counterKey) ?? 0;

    final entries = await readEntries();
    var maxFromEntries = 0;
    for (final row in entries) {
      final rowType = normalizeDocumentType(row['type']);
      if (rowType != normalizedType) continue;
      final rowNumber = '${row['number'] ?? row['numarDocument'] ?? ''}'.trim();
      final seq = _extractSequence(rowNumber, prefix: prefix);
      if (seq > maxFromEntries) {
        maxFromEntries = seq;
      }
    }

    final next = (currentCounter > maxFromEntries ? currentCounter : maxFromEntries) + 1;
    await prefs.setInt(counterKey, next);
    return '$prefix-${next.toString().padLeft(4, '0')}';
  }

  static Future<void> upsertEntry({
    required String type,
    required String number,
    required String title,
    required String documentDate,
    required String status,
    required String clientName,
    required String jobCode,
    String jobId = '',
    String referenceId = '',
    String filePath = '',
    String source = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await readEntries();
    final now = DateTime.now().toIso8601String();
    final normalizedType = normalizeDocumentType(type);
    final trimmedReference = referenceId.trim();

    final idx = rows.indexWhere((row) {
      final rowRef = '${row['referenceId'] ?? ''}'.trim();
      if (trimmedReference.isNotEmpty && rowRef == trimmedReference) {
        return true;
      }
      final rowType = normalizeDocumentType(row['type']);
      final rowNumber = '${row['number'] ?? ''}'.trim();
      return rowType == normalizedType && rowNumber == number.trim();
    });

    final nextRow = <String, dynamic>{
      'id': trimmedReference.isNotEmpty
          ? trimmedReference
          : 'reg_${normalizedType}_${number.replaceAll('-', '_')}',
      'type': normalizedType,
      'number': number.trim(),
      'title': title.trim(),
      'date': documentDate.trim(),
      'status': status.trim(),
      'client': clientName.trim(),
      'jobCode': jobCode.trim(),
      'jobId': jobId.trim(),
      'referenceId': trimmedReference,
      'filePath': filePath.trim(),
      'source': source.trim(),
      'updatedAt': now,
      'createdAt': idx >= 0 ? '${rows[idx]['createdAt'] ?? now}' : now,
    };

    if (idx >= 0) {
      rows[idx] = nextRow;
    } else {
      rows.insert(0, nextRow);
    }

    final encoded = rows.map((row) => jsonEncode(row)).toList(growable: false);
    await prefs.setStringList(_entriesKey, encoded);
  }

  static Future<void> removeByReferenceId(String referenceId) async {
    final ref = referenceId.trim();
    if (ref.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final rows = await readEntries();
    rows.removeWhere((row) => '${row['referenceId'] ?? ''}'.trim() == ref);
    final encoded = rows.map((row) => jsonEncode(row)).toList(growable: false);
    await prefs.setStringList(_entriesKey, encoded);
  }

  static Future<Map<String, dynamic>> ensureRegistered({
    required Map<String, dynamic> row,
    required String fallbackType,
    String source = '',
    String clientName = '',
    String jobCode = '',
  }) async {
    final type = normalizeDocumentType(
      row['type'] ?? row['tipDocument'] ?? row['documentType'] ?? fallbackType,
    );
    if (type.isEmpty) {
      return Map<String, dynamic>.from(row);
    }
    final number = await allocateNumber(
      type: type,
      existingNumber: _stringFromAny(
        row['number'] ?? row['numarDocument'] ?? row['documentNumber'],
      ),
    );
    final updated = <String, dynamic>{
      ...row,
      'type': type,
      'numarDocument': number,
      'number': number,
    };
    await upsertEntry(
      type: type,
      number: number,
      title: _stringFromAny(updated['title'] ?? updated['titlu']),
      documentDate: _stringFromAny(
        updated['date'] ?? updated['dataDocument'] ?? updated['data'],
      ),
      status: _stringFromAny(updated['status']),
      clientName: clientName.isNotEmpty
          ? clientName
          : _extractClientName(updated),
      jobCode: jobCode.isNotEmpty
          ? jobCode
          : _stringFromAny(updated['jobCode'] ?? updated['jobId']),
      jobId: _stringFromAny(updated['jobId']),
      referenceId: _stringFromAny(updated['id']),
      filePath: _stringFromAny(updated['filePath'] ?? updated['pdfPath']),
      source: source,
    );
    return updated;
  }

  static int _extractSequence(
    String number, {
    required String prefix,
  }) {
    final value = number.trim().toUpperCase();
    final expected = '${prefix.toUpperCase()}-';
    if (!value.startsWith(expected)) return 0;
    final raw = value.substring(expected.length);
    return int.tryParse(raw) ?? 0;
  }

  static List<Map<String, dynamic>> _readRowsFromKey(
    SharedPreferences prefs,
    String key,
  ) {
    final rows = <Map<String, dynamic>>[];

    final listRaw = prefs.getStringList(key);
    if (listRaw != null && listRaw.isNotEmpty) {
      for (final item in listRaw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            rows.add(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('[RegistryStore] parsare rând listă eșuată: $e');
        }
      }
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    final oneRaw = prefs.getString(key);
    if (oneRaw != null && oneRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(oneRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              rows.add(Map<String, dynamic>.from(item));
            }
          }
        } else if (decoded is Map) {
          rows.add(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('[RegistryStore] parsare format legacy eșuată: $e');
      }
    }

    return rows;
  }

  static Future<void> _writeRowsToKey(
    SharedPreferences prefs,
    String key,
    List<Map<String, dynamic>> rows,
  ) async {
    final encodedRows = rows.map((row) => jsonEncode(row)).toList(growable: false);
    final existingList = prefs.getStringList(key);
    if (existingList != null) {
      await prefs.setStringList(key, encodedRows);
      return;
    }
    await prefs.setString(key, jsonEncode(rows));
  }

  static String _stringFromAny(dynamic value) {
    return '${value ?? ''}'.trim();
  }

  static String _extractClientName(Map<String, dynamic> row) {
    final direct = _stringFromAny(
      row['clientName'] ??
          row['client_name'] ??
          row['client'] ??
          row['beneficiary'] ??
          row['recipient_name'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final client = row['client'];
    if (client is Map) {
      return _stringFromAny(client['name'] ?? client['companyName'] ?? client['title']);
    }
    return '';
  }
}
