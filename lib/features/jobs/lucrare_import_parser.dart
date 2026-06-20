import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'job_models.dart';

/// Parsere pure pentru importul materialelor puse la dispoziție de beneficiar
/// (din text simplu / DOCX / XLSX). Toate funcțiile sunt fără stare — primesc
/// bytes/string și returnează date. Extrase din `lucrare_detalii_page.dart`.

String lucrareDecodeImportBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

String lucrareDecodeXmlText(String raw) {
  return raw
      .replaceAllMapped(RegExp(r'<[^>]+>'), (_) => ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String lucrareExtractDocxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);
  for (final file in archive) {
    if (file.name == 'word/document.xml' && file.isFile) {
      final content = file.content;
      final xml = content is List<int>
          ? lucrareDecodeImportBytes(Uint8List.fromList(content))
          : '$content';
      return lucrareDecodeXmlText(xml);
    }
  }
  return '';
}

String lucrareExtractXlsxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);
  final sharedStrings = <String>[];
  for (final file in archive) {
    if (file.name == 'xl/sharedStrings.xml' && file.isFile) {
      final content = file.content;
      final xml = content is List<int>
          ? lucrareDecodeImportBytes(Uint8List.fromList(content))
          : '$content';
      for (final match in RegExp(r'<t[^>]*>([\s\S]*?)</t>').allMatches(xml)) {
        sharedStrings.add(lucrareDecodeXmlText(match.group(1) ?? ''));
      }
    }
  }

  final rows = <String>[];
  final worksheetFiles = archive
      .where((file) =>
          file.isFile && file.name.startsWith('xl/worksheets/sheet'))
      .toList(growable: false)
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final file in worksheetFiles) {
    final content = file.content;
    final xml = content is List<int>
        ? lucrareDecodeImportBytes(Uint8List.fromList(content))
        : '$content';
    for (final rowMatch
        in RegExp(r'<row[^>]*>([\s\S]*?)</row>').allMatches(xml)) {
      final rowBody = rowMatch.group(1) ?? '';
      final values = <String>[];
      for (final cellMatch
          in RegExp(r'<c([^>]*)>([\s\S]*?)</c>').allMatches(rowBody)) {
        final attrs = cellMatch.group(1) ?? '';
        final body = cellMatch.group(2) ?? '';
        String value = '';
        final shared = attrs.contains('t="s"') || attrs.contains("t='s'");
        if (shared) {
          final rawIndex =
              RegExp(r'<v>(.*?)</v>').firstMatch(body)?.group(1) ?? '';
          final index = int.tryParse(rawIndex.trim());
          if (index != null && index >= 0 && index < sharedStrings.length) {
            value = sharedStrings[index];
          }
        } else {
          final inlineText =
              RegExp(r'<is>[\s\S]*?<t[^>]*>([\s\S]*?)</t>[\s\S]*?</is>')
                  .firstMatch(body)
                  ?.group(1);
          if (inlineText != null) {
            value = lucrareDecodeXmlText(inlineText);
          } else {
            value =
                RegExp(r'<v>(.*?)</v>').firstMatch(body)?.group(1)?.trim() ??
                    '';
          }
        }
        if (value.trim().isNotEmpty) {
          values.add(value.trim());
        }
      }
      if (values.isNotEmpty) {
        rows.add(values.join('\t'));
      }
    }
  }
  return rows.join('\n');
}

List<String> lucrareSplitImportedMaterialLine(String line) {
  final candidates = <String>['\t', ';', '|'];
  for (final separator in candidates) {
    if (!line.contains(separator)) continue;
    final parts = line
        .split(separator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) return parts;
  }
  if (line.split(',').length >= 3) {
    final parts = line
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) return parts;
  }
  return <String>[line.trim()];
}

bool lucrareLooksLikeImportHeader(String line) {
  final normalized = line.trim().toLowerCase();
  return normalized.contains('denumire') &&
      (normalized.contains('cant') || normalized.contains('um'));
}

BeneficiarySuppliedMaterial? lucrareParseImportedBeneficiaryMaterial(
  String rawLine,
  int index,
) {
  final cleaned = rawLine
      .replaceFirst(RegExp(r'^[-*•]+\s*'), '')
      .replaceFirst(RegExp(r'^\d+[\.)]\s*'), '')
      .trim();
  if (cleaned.isEmpty || lucrareLooksLikeImportHeader(cleaned)) {
    return null;
  }
  final parts = lucrareSplitImportedMaterialLine(cleaned);
  if (parts.isEmpty) return null;
  final name = parts.first.trim();
  if (name.isEmpty) return null;

  var unit = '';
  var quantity = 1.0;
  final notes = <String>[];
  var numericIndex = -1;
  for (var i = 1; i < parts.length; i++) {
    if (double.tryParse(parts[i].replaceAll(',', '.')) != null) {
      numericIndex = i;
      break;
    }
  }
  if (numericIndex == 1) {
    quantity = double.tryParse(parts[1].replaceAll(',', '.')) ?? 1.0;
    if (parts.length > 2) {
      notes.addAll(parts.skip(2));
    }
  } else if (numericIndex > 1) {
    unit = parts[1].trim();
    quantity =
        double.tryParse(parts[numericIndex].replaceAll(',', '.')) ?? 1.0;
    if (numericIndex > 2) {
      notes.addAll(parts.sublist(2, numericIndex));
    }
    if (numericIndex + 1 < parts.length) {
      notes.addAll(parts.sublist(numericIndex + 1));
    }
  } else {
    if (parts.length > 1) {
      unit = parts[1].trim();
    }
    if (parts.length > 2) {
      notes.addAll(parts.skip(2));
    }
  }

  return BeneficiarySuppliedMaterial(
    id: 'beneficiary-material-import-${DateTime.now().microsecondsSinceEpoch}-$index',
    name: name,
    unit: unit,
    quantity: quantity,
    notes: notes.join(' | ').trim(),
  );
}

List<BeneficiarySuppliedMaterial> lucrareMergeBeneficiaryMaterialImports(
  List<BeneficiarySuppliedMaterial> existing,
  List<BeneficiarySuppliedMaterial> imported,
) {
  final merged = <String, BeneficiarySuppliedMaterial>{
    for (final item in existing)
      '${item.name.trim().toLowerCase()}|${item.unit.trim().toLowerCase()}':
          item,
  };
  for (final item in imported) {
    final key =
        '${item.name.trim().toLowerCase()}|${item.unit.trim().toLowerCase()}';
    final previous = merged[key];
    if (previous == null) {
      merged[key] = item;
      continue;
    }
    final mergedNotes = <String>[
      if (previous.notes.trim().isNotEmpty) previous.notes.trim(),
      if (item.notes.trim().isNotEmpty && item.notes.trim() != previous.notes)
        item.notes.trim(),
    ].join(' | ');
    merged[key] = previous.copyWith(
      quantity: previous.quantity + item.quantity,
      notes: mergedNotes,
    );
  }
  return merged.values.toList(growable: false);
}
