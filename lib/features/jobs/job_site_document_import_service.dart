import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'job_site_document_models.dart';

class JobSiteDocumentImportResult {
  const JobSiteDocumentImportResult({
    required this.sourceName,
    required this.extractedText,
    required this.items,
    this.warnings = const <String>[],
  });

  final String sourceName;
  final String extractedText;
  final List<JobSiteDocumentAnnexItem> items;
  final List<String> warnings;
}

class JobSiteDocumentImportService {
  const JobSiteDocumentImportService._();

  static Future<JobSiteDocumentImportResult> importFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final warnings = <String>[];
    final extractedText = _extractText(
      fileName: fileName,
      bytes: bytes,
      warnings: warnings,
    );
    final items = _parseItems(
      extractedText,
      sourceName: fileName,
      warnings: warnings,
    );
    return JobSiteDocumentImportResult(
      sourceName: fileName,
      extractedText: extractedText,
      items: items,
      warnings: warnings,
    );
  }

  static String _extractText({
    required String fileName,
    required Uint8List bytes,
    required List<String> warnings,
  }) {
    final lowerName = fileName.trim().toLowerCase();
    if (lowerName.endsWith('.docx')) {
      return _extractDocxText(bytes, warnings);
    }
    if (lowerName.endsWith('.xlsx')) {
      return _extractXlsxText(bytes, warnings);
    }
    if (lowerName.endsWith('.pdf')) {
      return _extractPdfText(bytes, warnings);
    }
    return _decodeText(bytes, warnings);
  }

  static String _decodeText(Uint8List bytes, List<String> warnings) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      warnings.add(
          'Fișierul nu a putut fi decodat complet ca text; s-a folosit fallback brut.');
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String _extractDocxText(Uint8List bytes, List<String> warnings) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final documentFile = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () => ArchiveFile('', 0, <int>[]),
      );
      if (documentFile.name.isEmpty) {
        warnings.add(
            'DOCX fără word/document.xml; s-a folosit fallback text brut.');
        return _decodeText(bytes, warnings);
      }
      final xml =
          utf8.decode(documentFile.content as List<int>, allowMalformed: true);
      return _stripXml(xml)
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll('  ', ' ')
          .trim();
    } catch (_) {
      warnings.add(
          'DOCX-ul nu a putut fi citit structurat; s-a folosit fallback text brut.');
      return _decodeText(bytes, warnings);
    }
  }

  static String _extractXlsxText(Uint8List bytes, List<String> warnings) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final sharedStrings = _readSharedStrings(archive);
      final buffer = StringBuffer();
      final worksheets = archive.files
          .where((file) => file.name.startsWith('xl/worksheets/sheet'))
          .toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final sheet in worksheets) {
        final xml =
            utf8.decode(sheet.content as List<int>, allowMalformed: true);
        final rows = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true)
            .allMatches(xml)
            .map((match) => match.group(1) ?? '')
            .toList(growable: false);
        for (final row in rows) {
          final values = <String>[];
          final cellMatches =
              RegExp(r'<c([^>]*)>(.*?)</c>', dotAll: true).allMatches(row);
          for (final cell in cellMatches) {
            final attrs = cell.group(1) ?? '';
            final body = cell.group(2) ?? '';
            final rawValue = RegExp(r'<v>(.*?)</v>', dotAll: true)
                    .firstMatch(body)
                    ?.group(1) ??
                RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
                    .firstMatch(body)
                    ?.group(1) ??
                '';
            if (rawValue.trim().isEmpty) {
              values.add('');
              continue;
            }
            if (attrs.contains(' t="s"')) {
              final index = int.tryParse(rawValue.trim());
              values.add(
                  index != null && index >= 0 && index < sharedStrings.length
                      ? sharedStrings[index]
                      : rawValue.trim());
            } else {
              values.add(rawValue.trim());
            }
          }
          final line = values
              .where((value) => value.trim().isNotEmpty)
              .join(' | ')
              .trim();
          if (line.isNotEmpty) {
            buffer.writeln(line);
          }
        }
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) {
        warnings.add('XLSX fără text util; s-a folosit fallback text brut.');
        return _decodeText(bytes, warnings);
      }
      return text;
    } catch (_) {
      warnings.add(
          'XLSX-ul nu a putut fi citit structurat; s-a folosit fallback text brut.');
      return _decodeText(bytes, warnings);
    }
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.files
        .where((item) => item.name == 'xl/sharedStrings.xml')
        .firstWhere(
          (_) => true,
          orElse: () => ArchiveFile('', 0, <int>[]),
        );
    if (file.name.isEmpty) {
      return const <String>[];
    }
    final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
    return RegExp(r'<si>(.*?)</si>', dotAll: true)
        .allMatches(xml)
        .map((match) => _stripXml(match.group(1) ?? '').trim())
        .toList(growable: false);
  }

  static String _extractPdfText(Uint8List bytes, List<String> warnings) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final matches = RegExp(r'\(([^()]*)\)').allMatches(raw);
    final buffer = StringBuffer();
    for (final match in matches) {
      final value = (match.group(1) ?? '')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\r', ' ')
          .replaceAll(r'\t', ' ')
          .replaceAll(r'\(', '(')
          .replaceAll(r'\)', ')')
          .replaceAll(r'\\', r'\')
          .trim();
      if (value.length >= 3 &&
          RegExp(r'[A-Za-z0-9ĂÂÎȘŞȚŢăâîșşțţ]').hasMatch(value)) {
        buffer.writeln(value);
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      warnings.add(
          'PDF-ul nu a putut fi citit complet; pentru PDF-uri scanate poate fi necesar OCR extern.');
      return _decodeText(bytes, warnings);
    }
    warnings.add(
        'Textul PDF a fost extras best-effort; verifică rezultatul înainte de salvare.');
    return text;
  }

  static String _stripXml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static List<JobSiteDocumentAnnexItem> _parseItems(
    String text, {
    required String sourceName,
    required List<String> warnings,
  }) {
    final items = <JobSiteDocumentAnnexItem>[];
    final seen = <String>{};
    final lines = const LineSplitter().convert(text.replaceAll('\r\n', '\n'));
    Map<String, int>? headerMap;
    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index].trim();
      if (rawLine.isEmpty) continue;
      var normalized = rawLine
          .replaceAll(RegExp(r'^[\-•*\u2022\s]+'), '')
          .replaceAll(RegExp(r'^[0-9]+[\.)]\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (normalized.length < 3) continue;
      final cells = _splitCells(normalized);
      final detectedHeaderMap = _detectHeaderMap(cells);
      if (detectedHeaderMap != null) {
        headerMap = detectedHeaderMap;
        continue;
      }
      if (_looksLikeHeader(normalized)) continue;

      final parsed = headerMap != null && cells.length > 1
          ? _parseStructuredRow(cells, headerMap)
          : _parseLooseRow(normalized, cells);
      if (parsed == null) {
        continue;
      }
      final label = parsed.label;
      final quantity = parsed.quantity;
      final unit = parsed.unit;
      final details = parsed.details;

      if (label.length < 3) continue;
      final dedupeKey =
          '${label.toLowerCase()}|$quantity|${unit.toLowerCase()}|${details.join(' ').toLowerCase()}';
      if (!seen.add(dedupeKey)) continue;

      items.add(
        JobSiteDocumentAnnexItem(
          id: 'import-${index + 1}',
          label: label,
          quantity: quantity,
          unit: unit,
          details: details.join(' | '),
          source: sourceName,
        ),
      );
    }

    if (items.isEmpty) {
      warnings.add(
          'Nu am extras poziții structurate; verifică fișierul sau completează manual.');
    }
    return items;
  }

  static List<String> _splitCells(String normalized) {
    final cells = normalized
        .split(RegExp(r'\s*[;|\t]+\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return cells.isEmpty ? <String>[normalized] : cells;
  }

  static Map<String, int>? _detectHeaderMap(List<String> cells) {
    if (cells.length < 2) {
      return null;
    }
    final map = <String, int>{};
    for (var index = 0; index < cells.length; index++) {
      final key = _headerKeyFor(cells[index]);
      if (key != null) {
        map[key] = index;
      }
    }
    return map.containsKey('label') ? map : null;
  }

  static String? _headerKeyFor(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.isEmpty) {
      return null;
    }
    if (RegExp(
            r'^(denumire|material|echipament|produs|articol|pozitie|poziție|descriere)$')
        .hasMatch(lower)) {
      return 'label';
    }
    if (RegExp(r'^(cantitate|cant\.?|qty|quantity)$').hasMatch(lower)) {
      return 'quantity';
    }
    if (RegExp(
            r'^(um|u\.?m\.?|unitate|unitate\s+masura|unitate\s+de\s+masura|uom)$')
        .hasMatch(lower)) {
      return 'unit';
    }
    if (RegExp(
            r'^(detalii|observatii|observații|mentiuni|mențiuni|specificatii|specificații|note)$')
        .hasMatch(lower)) {
      return 'details';
    }
    if (RegExp(r'^(cod|cod\s+produs|sku|part\s*number)$').hasMatch(lower)) {
      return 'code';
    }
    return null;
  }

  static _ParsedImportRow? _parseStructuredRow(
    List<String> cells,
    Map<String, int> headerMap,
  ) {
    final label = _cellAt(cells, headerMap['label']);
    if (label.length < 3) {
      return null;
    }
    var quantity = _normalizeQuantity(_cellAt(cells, headerMap['quantity']));
    var unit = _normalizeUnit(_cellAt(cells, headerMap['unit']));
    final details = <String>[];
    final code = _cellAt(cells, headerMap['code']);
    final extra = _cellAt(cells, headerMap['details']);
    if (code.isNotEmpty) {
      details.add('Cod: $code');
    }
    if (extra.isNotEmpty && extra.toLowerCase() != label.toLowerCase()) {
      details.add(extra);
    }
    for (var index = 0; index < cells.length; index++) {
      if (headerMap.values.contains(index)) {
        continue;
      }
      final value = cells[index].trim();
      if (value.isNotEmpty) {
        details.add(value);
      }
    }
    if (quantity.isEmpty || unit.isEmpty) {
      final enriched = _extractQuantityAndUnit('$label ${details.join(' ')}');
      quantity = quantity.isEmpty ? enriched.quantity : quantity;
      unit = unit.isEmpty ? enriched.unit : unit;
    }
    return _ParsedImportRow(
      label: _cleanLabel(label),
      quantity: quantity,
      unit: unit,
      details: details,
    );
  }

  static _ParsedImportRow? _parseLooseRow(
      String normalized, List<String> parts) {
    var label = parts.first;
    var quantity = '';
    var unit = '';
    final details = <String>[];

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      final qtyMatch = RegExp(
        r'^([0-9]+(?:[\.,][0-9]+)?)\s*(buc|set|m|ml|kg|g|mp|m2|mc|m3|l|role|perechi|kit)?$',
        caseSensitive: false,
      ).firstMatch(part);
      if (qtyMatch != null && quantity.isEmpty) {
        quantity = qtyMatch.group(1)?.replaceAll(',', '.') ?? '';
        unit = _normalizeUnit(qtyMatch.group(2) ?? '');
        continue;
      }
      details.add(part);
    }

    if (quantity.isEmpty || unit.isEmpty) {
      final trailingMatch = RegExp(
        r'^(.*?)(?:\s+|\s*[,xX-]\s*)([0-9]+(?:[\.,][0-9]+)?)\s*(buc|set|m|ml|kg|g|mp|m2|mc|m3|l|role|perechi|kit)?$',
        caseSensitive: false,
      ).firstMatch(label);
      if (trailingMatch != null) {
        label = trailingMatch.group(1)?.trim() ?? label;
        quantity = trailingMatch.group(2)?.replaceAll(',', '.') ?? quantity;
        unit = _normalizeUnit(trailingMatch.group(3) ?? unit);
      }
    }

    if (quantity.isEmpty || unit.isEmpty) {
      final enriched =
          _extractQuantityAndUnit('$normalized ${details.join(' ')}');
      quantity = quantity.isEmpty ? enriched.quantity : quantity;
      unit = unit.isEmpty ? enriched.unit : unit;
    }

    final cleanLabel = _cleanLabel(label);
    if (cleanLabel.length < 3) {
      return null;
    }
    return _ParsedImportRow(
      label: cleanLabel,
      quantity: quantity,
      unit: unit,
      details: details,
    );
  }

  static String _cellAt(List<String> cells, int? index) {
    if (index == null || index < 0 || index >= cells.length) {
      return '';
    }
    return cells[index].trim();
  }

  static _ParsedQuantity _extractQuantityAndUnit(String value) {
    final match = RegExp(
      r'([0-9]+(?:[\.,][0-9]+)?)\s*(buc|set|m|ml|kg|g|mp|m2|mc|m3|l|role|perechi|kit)',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) {
      return const _ParsedQuantity();
    }
    return _ParsedQuantity(
      quantity: _normalizeQuantity(match.group(1) ?? ''),
      unit: _normalizeUnit(match.group(2) ?? ''),
    );
  }

  static String _normalizeQuantity(String value) {
    return value.trim().replaceAll(',', '.');
  }

  static String _normalizeUnit(String value) {
    final lower = value.trim().toLowerCase();
    switch (lower) {
      case 'm2':
      case 'mp':
        return 'mp';
      case 'm3':
      case 'mc':
        return 'mc';
      case 'u.m.':
      case 'u.m':
      case 'um':
        return '';
      default:
        return lower;
    }
  }

  static String _cleanLabel(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-•*\u2022\s]+'), '')
        .trim();
  }

  static bool _looksLikeHeader(String value) {
    final lower = value.toLowerCase();
    return lower == 'denumire' ||
        lower == 'material' ||
        lower == 'echipament' ||
        lower == 'cantitate' ||
        lower == 'um' ||
        lower == 'unitate' ||
        lower == 'descriere' ||
        lower.startsWith('lista material') ||
        lower.startsWith('lista echip') ||
        lower.startsWith('anexa');
  }
}

class _ParsedImportRow {
  const _ParsedImportRow({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.details,
  });

  final String label;
  final String quantity;
  final String unit;
  final List<String> details;
}

class _ParsedQuantity {
  const _ParsedQuantity({
    this.quantity = '',
    this.unit = '',
  });

  final String quantity;
  final String unit;
}
