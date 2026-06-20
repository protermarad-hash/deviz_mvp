/// Helpers pure (fără stare) folosite în fișa lucrării: conversii numerice,
/// formatare/parsare date și sanitizare nume fișiere.
///
/// Toate funcțiile sunt PURE — primesc input și returnează output, fără a
/// accesa starea widget-ului. Extrase din `lucrare_detalii_page.dart` (Faza 0).
///
/// NOTĂ: `_sanitizeDisplayText` / `_sanitizePdfText` au rămas intenționat în
/// fișierul principal — conțin literali Unicode invizibili (caractere de
/// control, U+FFFD, intervale U+2000–U+206F) care s-ar putea corupe la mutare.
library;

double lucrareAsDouble(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse((raw ?? '0').toString().replaceAll(',', '.')) ?? 0.0;
}

bool lucrareAsBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value == 'true' || value == '1' || value == 'da' || value == 'yes') {
    return true;
  }
  if (value == 'false' || value == '0' || value == 'nu' || value == 'no') {
    return false;
  }
  return false;
}

String lucrareFormatDecimal(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.0001) {
    return rounded.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

DateTime lucrareDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime? lucrareTryParseLaborDate(dynamic raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty) return null;
  final parsedIso = DateTime.tryParse(value);
  if (parsedIso != null) {
    return lucrareDateOnly(parsedIso.toLocal());
  }
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
  if (match == null) return null;
  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String lucrareEncodeLaborPeriodDate(DateTime value) {
  return lucrareDateOnly(value).toIso8601String();
}

DateTime lucrareParseDateOrNow(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(trimmed);
  if (match != null) {
    final day = int.tryParse(match.group(1) ?? '') ?? 1;
    final month = int.tryParse(match.group(2) ?? '') ?? 1;
    final year = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    return DateTime(year, month, day);
  }
  return DateTime.now();
}

String lucrareFormatDate(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d.$m.${value.year}';
}

String lucrareFormatDateTime(String raw) {
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

String lucrareSanitizeFilePart(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'doc' : sanitized;
}
