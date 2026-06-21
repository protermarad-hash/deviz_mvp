import 'dart:convert';

import '../job_models.dart';
import '../lucrare_format_utils.dart';
import '../lucrare_import_parser.dart';

/// Parsare draft-uri produse de asistentul AI pentru o lucrare.
///
/// Extras din `lucrare_detalii_page.dart` (Faza 2). Conține exclusiv logica
/// PURĂ de interpretare a textului generat de AI (fence stripping, JSON sau
/// fallback pe linii) — fără UI și fără acces la stare. Orchestratorul de
/// aplicare (`_applyJobAiDraft`) și constructorul de context rămân în pagină,
/// fiindcă scriu starea și folosesc `context`/`ScaffoldMessenger`.

/// Scoate conținutul dintr-un bloc ```fenced``` dacă există; altfel întoarce
/// textul curățat de spații.
String unwrapAiDraftContent(String content) {
  final trimmed = content.trim();
  final fenced =
      RegExp(r'^```[a-zA-Z0-9_-]*\s*([\s\S]*?)\s*```$').firstMatch(trimmed);
  if (fenced != null) {
    return (fenced.group(1) ?? '').trim();
  }
  return trimmed;
}

/// Interpretează un draft AI ca listă de materiale furnizate de beneficiar.
/// Acceptă JSON array, JSON object cu `items`/`materials`/`rows`, sau linii
/// text de forma `denumire | UM | cantitate | observatii`.
List<BeneficiarySuppliedMaterial> parseAiBeneficiaryMaterials(String content) {
  final normalized = unwrapAiDraftContent(content);
  if (normalized.isEmpty) return const <BeneficiarySuppliedMaterial>[];

  try {
    final decoded = jsonDecode(normalized);
    final candidateRows = <dynamic>[];
    if (decoded is List) {
      candidateRows.addAll(decoded);
    } else if (decoded is Map) {
      final rawList =
          decoded['items'] ?? decoded['materials'] ?? decoded['rows'];
      if (rawList is List) {
        candidateRows.addAll(rawList);
      }
    }
    if (candidateRows.isNotEmpty) {
      return candidateRows
          .asMap()
          .entries
          .map((entry) {
            final row = entry.value;
            if (row is Map<String, dynamic>) {
              final material = BeneficiarySuppliedMaterial.fromMap(row);
              return material.name.trim().isEmpty ? null : material;
            }
            if (row is Map) {
              final material = BeneficiarySuppliedMaterial.fromMap(
                Map<String, dynamic>.from(row),
              );
              return material.name.trim().isEmpty ? null : material;
            }
            if (row is String) {
              return lucrareParseImportedBeneficiaryMaterial(row, entry.key);
            }
            return null;
          })
          .whereType<BeneficiarySuppliedMaterial>()
          .toList(growable: false);
    }
  } catch (_) {
    // Fallback to line parsing below.
  }

  return LineSplitter.split(normalized)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false)
      .asMap()
      .entries
      .map(
        (entry) =>
            lucrareParseImportedBeneficiaryMaterial(entry.value, entry.key),
      )
      .whereType<BeneficiarySuppliedMaterial>()
      .toList(growable: false);
}

/// Rezolvă un text liber la cheia canonică a unei etape din checklist, comparând
/// (fără diacritice) cu cheia și eticheta fiecărei intrări din `checklistDefs`.
String? checklistKeyFromAny(
  String raw,
  List<MapEntry<String, String>> checklistDefs,
) {
  final normalized = raw
      .trim()
      .toLowerCase()
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return null;
  for (final entry in checklistDefs) {
    final key = entry.key
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final label = entry.value
        .trim()
        .toLowerCase()
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ș', 's')
        .replaceAll('ş', 's')
        .replaceAll('ț', 't')
        .replaceAll('ţ', 't')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized == key || normalized == label) {
      return entry.key;
    }
  }
  return null;
}

/// Interpretează un draft AI ca set de actualizări pentru checklist-ul lucrării.
/// Acceptă JSON map cheie→bool, JSON listă de obiecte/etichete, sau linii text
/// cu markeri `[x]`/`[ ]`/`da`/`nu`/`+`/`-`.
Map<String, bool> parseAiChecklistUpdate(
  String content,
  List<MapEntry<String, String>> checklistDefs,
) {
  final normalized = unwrapAiDraftContent(content);
  final updates = <String, bool>{};
  if (normalized.isEmpty) return updates;

  try {
    final decoded = jsonDecode(normalized);
    if (decoded is Map) {
      decoded.forEach((key, value) {
        final resolvedKey = checklistKeyFromAny('$key', checklistDefs);
        if (resolvedKey != null) {
          updates[resolvedKey] = lucrareAsBool(value);
        }
      });
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          final rawKey =
              '${item['key'] ?? item['id'] ?? item['label'] ?? item['name'] ?? ''}';
          final resolvedKey = checklistKeyFromAny(rawKey, checklistDefs);
          if (resolvedKey == null) continue;
          updates[resolvedKey] = lucrareAsBool(
            item['checked'] ?? item['value'] ?? item['done'] ?? true,
          );
        } else if (item is String) {
          final resolvedKey = checklistKeyFromAny(item, checklistDefs);
          if (resolvedKey != null) {
            updates[resolvedKey] = true;
          }
        }
      }
    }
  } catch (_) {
    for (final rawLine in LineSplitter.split(normalized)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final isChecked = line.startsWith('[x]') ||
          line.startsWith('[X]') ||
          line.toLowerCase().startsWith('da ') ||
          line.toLowerCase().startsWith('true ') ||
          line.toLowerCase().startsWith('bifat ') ||
          line.startsWith('+');
      final isUnchecked = line.startsWith('[ ]') ||
          line.toLowerCase().startsWith('nu ') ||
          line.toLowerCase().startsWith('false ') ||
          line.toLowerCase().startsWith('debifat ') ||
          line.startsWith('-');
      final cleaned = line
          .replaceFirst(RegExp(r'^\[(x|X| )\]\s*'), '')
          .replaceFirst(
              RegExp(r'^(da|nu|true|false|bifat|debifat)\s+',
                  caseSensitive: false),
              '')
          .replaceFirst(RegExp(r'^[-+*•]\s*'), '')
          .trim();
      final resolvedKey = checklistKeyFromAny(cleaned, checklistDefs);
      if (resolvedKey == null) continue;
      updates[resolvedKey] = isUnchecked ? false : (isChecked ? true : true);
    }
  }

  return updates;
}

/// Sparge un draft AI de document în secțiuni după anteturi de forma
/// `Titlu:`, `Subtitlu:`, `Observații:`, `Concluzii:`, `Probe:`,
/// `Etapa următoare:`. Cheile întoarse sunt lowercase.
Map<String, String> parseAiDocumentSections(String content) {
  final matches = RegExp(
    r'^(Titlu|Subtitlu|Observații|Observatii|Concluzii|Probe|Etapa următoare|Etapa urmatoare)\s*:\s*',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(content).toList(growable: false);
  if (matches.isEmpty) {
    return const <String, String>{};
  }

  final sections = <String, String>{};
  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final rawKey = (match.group(1) ?? '').trim().toLowerCase();
    final start = match.end;
    final end =
        index + 1 < matches.length ? matches[index + 1].start : content.length;
    final value = content.substring(start, end).trim();
    if (value.isNotEmpty) {
      sections[rawKey] = value;
    }
  }
  return sections;
}
