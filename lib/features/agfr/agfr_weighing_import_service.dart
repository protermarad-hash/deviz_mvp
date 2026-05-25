import 'dart:convert';

import 'agfr_models.dart';

class AgfrWeighingImportResult {
  const AgfrWeighingImportResult({
    required this.record,
    required this.detectedHeaders,
    required this.warnings,
  });

  final AgfrWeighingReportRecord record;
  final List<String> detectedHeaders;
  final List<String> warnings;
}

class AgfrWeighingImportService {
  const AgfrWeighingImportService._();

  static AgfrWeighingImportResult importTestoCsv({
    required String csvText,
    required String filePath,
    required String fileName,
    required AgfrWeighingReportRecord seed,
  }) {
    final warnings = <String>[];
    final lines = const LineSplitter()
        .convert(csvText)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2) {
      warnings.add('CSV-ul nu contine suficiente randuri pentru mapare.');
      return AgfrWeighingImportResult(
        record: seed.copyWith(
          sourceType: AgfrWeighingSourceType.testoCsv,
          sourceFilePath: filePath,
          sourceFileName: fileName,
          sourceImportedAt: DateTime.now(),
          sourceRawPayload: csvText,
          updatedAt: DateTime.now(),
        ),
        detectedHeaders: const <String>[],
        warnings: warnings,
      );
    }

    final delimiter = _detectDelimiter(lines);
    final headerCells = _parseCsvLine(lines.first, delimiter)
        .map(_normalizeHeader)
        .toList(growable: false);
    final dataCells = _parseCsvLine(lines[1], delimiter);
    final valuesByHeader = <String, String>{};
    for (var i = 0; i < headerCells.length; i++) {
      final header = headerCells[i];
      if (header.isEmpty) {
        continue;
      }
      valuesByHeader[header] = i < dataCells.length ? dataCells[i].trim() : '';
    }

    DateTime? measurementTimestamp = _parseDateTimeCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'datetime',
          'date',
          'timestamp',
          'measurementdate',
          'ora',
          'data',
          'time',
        ],
      ),
    );
    if (measurementTimestamp == null) {
      final dateOnly = _readMappedValue(
        valuesByHeader,
        const <String>['date', 'data', 'measurementdate'],
      );
      final timeOnly = _readMappedValue(
        valuesByHeader,
        const <String>['time', 'ora'],
      );
      measurementTimestamp = _combineDateAndTime(dateOnly, timeOnly);
    }

    final initialWeight = _parseDoubleCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'initialweight',
          'startweight',
          'grossweightstart',
          'greutateinitiala',
          'greutatestart',
        ],
      ),
    );
    final finalWeight = _parseDoubleCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'finalweight',
          'endweight',
          'grossweightend',
          'greutatefinala',
          'greutatefinal',
        ],
      ),
    );
    final charged = _parseDoubleCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'chargedkg',
          'charged',
          'charge',
          'quantitycharged',
          'incarcat',
          'cantitateincarcata',
        ],
      ),
    );
    final recovered = _parseDoubleCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'recoveredkg',
          'recovered',
          'quantityrecovered',
          'recuperat',
          'cantitaterecuperata',
        ],
      ),
    );
    final netQuantity = _parseDoubleCandidate(
      _readMappedValue(
        valuesByHeader,
        const <String>[
          'netquantity',
          'netquantitykg',
          'netkg',
          'net',
          'quantity',
          'delta',
          'difference',
          'cantitateneta',
        ],
      ),
    );
    final scaleIdentifier = _readMappedValue(
      valuesByHeader,
      const <String>[
        'scale',
        'scaleid',
        'device',
        'devicename',
        'scaleidentifier',
        'cantar',
        'balanta',
      ],
    );
    final cylinderIdentifier = _readMappedValue(
      valuesByHeader,
      const <String>[
        'cylinder',
        'container',
        'recipient',
        'tank',
        'butelie',
        'recipientid',
      ],
    );
    final sourceDeviceInfo = _readMappedValue(
      valuesByHeader,
      const <String>[
        'device',
        'devicename',
        'instrument',
        'instrumentname',
        'scale',
      ],
    );

    if (headerCells.isEmpty) {
      warnings.add('Header-ele CSV nu au putut fi detectate clar.');
    }
    if (measurementTimestamp == null) {
      warnings.add('Data/ora masuratorii nu a putut fi extrasa sigur din CSV.');
    }
    if (initialWeight == null && finalWeight == null) {
      warnings.add('Greutatile initiala/finala nu au putut fi mapate automat.');
    }
    if (charged == null && recovered == null && netQuantity == null) {
      warnings.add('Cantitatile incarcata/recuperata/net nu au putut fi mapate automat.');
    }

    final record = seed.copyWith(
      sourceType: AgfrWeighingSourceType.testoCsv,
      sourceFilePath: filePath,
      sourceFileName: fileName,
      sourceImportedAt: DateTime.now(),
      sourceDeviceInfo: sourceDeviceInfo,
      sourceRawPayload: csvText,
      measurementTimestamp: measurementTimestamp,
      clearMeasurementTimestamp: measurementTimestamp == null,
      initialWeightKg: initialWeight ?? seed.initialWeightKg,
      finalWeightKg: finalWeight ?? seed.finalWeightKg,
      chargedKg: charged ?? seed.chargedKg,
      recoveredKg: recovered ?? seed.recoveredKg,
      netQuantityKg: netQuantity ?? seed.netQuantityKg,
      scaleIdentifier: scaleIdentifier.isEmpty
          ? seed.scaleIdentifier
          : scaleIdentifier,
      cylinderIdentifier: cylinderIdentifier.isEmpty
          ? seed.cylinderIdentifier
          : cylinderIdentifier,
      updatedAt: DateTime.now(),
    );

    return AgfrWeighingImportResult(
      record: record,
      detectedHeaders: headerCells.where((item) => item.isNotEmpty).toList(growable: false),
      warnings: warnings,
    );
  }

  static List<String> _parseCsvLine(String line, String delimiter) {
    final values = <String>[];
    var buffer = StringBuffer();
    var insideQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
        if (insideQuotes && nextIsQuote) {
          buffer.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
        continue;
      }
      if (!insideQuotes && char == delimiter) {
        values.add(buffer.toString().trim());
        buffer = StringBuffer();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString().trim());
    return values;
  }

  static String _detectDelimiter(List<String> lines) {
    final sample = lines.take(3).join('\n');
    final candidates = <String>[',', ';', '\t'];
    var best = ',';
    var bestScore = -1;
    for (final delimiter in candidates) {
      final score = delimiter.allMatches(sample).length;
      if (score > bestScore) {
        best = delimiter;
        bestScore = score;
      }
    }
    return best;
  }

  static String _normalizeHeader(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static String _readMappedValue(
    Map<String, String> valuesByHeader,
    List<String> candidates,
  ) {
    for (final candidate in candidates) {
      final value = valuesByHeader[candidate];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final entry in valuesByHeader.entries) {
      for (final candidate in candidates) {
        if (entry.key.contains(candidate) && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  static double? _parseDoubleCandidate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final normalized = value
        .replaceAll(RegExp(r'[^0-9,.\-]+'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static DateTime? _parseDateTimeCandidate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return iso;
    }
    final cleaned = value.replaceAll('/', '.').replaceAll('-', '.');
    final dateTimeMatch = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(cleaned);
    if (dateTimeMatch == null) {
      return null;
    }
    final day = int.tryParse(dateTimeMatch.group(1) ?? '');
    final month = int.tryParse(dateTimeMatch.group(2) ?? '');
    final yearRaw = int.tryParse(dateTimeMatch.group(3) ?? '');
    if (day == null || month == null || yearRaw == null) {
      return null;
    }
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    final hour = int.tryParse(dateTimeMatch.group(4) ?? '') ?? 0;
    final minute = int.tryParse(dateTimeMatch.group(5) ?? '') ?? 0;
    final second = int.tryParse(dateTimeMatch.group(6) ?? '') ?? 0;
    return DateTime(year, month, day, hour, minute, second);
  }

  static DateTime? _combineDateAndTime(String dateRaw, String timeRaw) {
    final date = _parseDateTimeCandidate(dateRaw);
    if (date == null) {
      return null;
    }
    final time = timeRaw.trim();
    if (time.isEmpty) {
      return DateTime(date.year, date.month, date.day);
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(time);
    if (match == null) {
      return DateTime(date.year, date.month, date.day);
    }
    final hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final second = int.tryParse(match.group(3) ?? '') ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }
}
