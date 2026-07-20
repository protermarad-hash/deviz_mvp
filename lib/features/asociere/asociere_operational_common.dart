enum AsociereOperationalStatus {
  draft,
  inAsteptare,
  aprobat,
  respins,
  confirmat,
  finalizat;

  String get value => switch (this) {
        inAsteptare => 'in_asteptare',
        _ => name,
      };

  String get label => switch (this) {
        draft => 'Draft',
        inAsteptare => 'În așteptare',
        aprobat => 'Aprobat',
        respins => 'Respins',
        confirmat => 'Confirmat',
        finalizat => 'Finalizat',
      };

  static AsociereOperationalStatus fromValue(Object? raw) {
    final value = '$raw'.trim().toLowerCase();
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => AsociereOperationalStatus.draft,
    );
  }
}

enum AsociereParte { proTerm, partener, beneficiar }

extension AsociereParteX on AsociereParte {
  String get value => switch (this) {
        AsociereParte.proTerm => 'pro_term',
        AsociereParte.partener => 'partener',
        AsociereParte.beneficiar => 'beneficiar',
      };

  String get label => switch (this) {
        AsociereParte.proTerm => 'PRO TERM',
        AsociereParte.partener => 'Partener',
        AsociereParte.beneficiar => 'Beneficiar',
      };

  static AsociereParte fromValue(Object? raw) {
    return switch ('$raw'.trim().toLowerCase()) {
      'partener' => AsociereParte.partener,
      'beneficiar' => AsociereParte.beneficiar,
      _ => AsociereParte.proTerm,
    };
  }
}

String mapText(Map<String, dynamic> map, String snake, [String? camel]) =>
    (map[snake] ?? (camel == null ? null : map[camel]) ?? '').toString().trim();

double mapDouble(
  Map<String, dynamic> map,
  String snake, [
  String? camel,
  double fallback = 0,
]) {
  final raw = map[snake] ?? (camel == null ? null : map[camel]);
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.replaceAll(',', '.')) ?? fallback;
}

int mapInt(Map<String, dynamic> map, String snake,
    [String? camel, int fallback = 0]) {
  final raw = map[snake] ?? (camel == null ? null : map[camel]);
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? fallback;
}

bool mapBool(Map<String, dynamic> map, String snake,
    [String? camel, bool fallback = false]) {
  final raw = map[snake] ?? (camel == null ? null : map[camel]);
  if (raw is bool) return raw;
  if (raw == null) return fallback;
  return '$raw'.toLowerCase() == 'true' || '$raw' == '1';
}

DateTime? mapDate(Map<String, dynamic> map, String snake, [String? camel]) =>
    DateTime.tryParse(mapText(map, snake, camel));

String mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String? nullableMapString(Map<String, dynamic> map, List<String> keys) {
  final value = mapString(map, keys);
  return value.isEmpty ? null : value;
}

double valueDouble(Object? raw, {double fallback = 0}) {
  if (raw is num) return raw.toDouble();
  return double.tryParse('${raw ?? ''}'.replaceAll(',', '.')) ?? fallback;
}

int valueInt(Object? raw, {int fallback = 0}) {
  if (raw is num) return raw.toInt();
  return int.tryParse('${raw ?? ''}') ?? fallback;
}

bool valueBool(Object? raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw == null) return fallback;
  final value = '$raw'.trim().toLowerCase();
  return value == 'true' || value == '1';
}

DateTime? valueDate(Object? raw) => DateTime.tryParse('${raw ?? ''}');
