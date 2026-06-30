import 'package:uuid/uuid.dart';

/// Serviciu prestat din catalogul cu prețuri precompletate.
///
/// Folosit la câmpul „Titlu" din editorul de programare: utilizatorul poate
/// alege un serviciu din catalog (cu preț sugerat) sau scrie liber orice titlu.
/// Catalogul se gestionează de admin în pagina „Servicii Prestate".
class ServiciuPrestat {
  const ServiciuPrestat({
    required this.id,
    required this.denumire,
    this.pretSugerat = 0,
    this.moneda = 'RON',
    this.activ = true,
    this.vizibilLaExecutie = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String denumire;
  final double pretSugerat;
  final String moneda;
  final bool activ;

  /// Dacă true, prețul serviciului se precompletează ȘI în câmpul „Preț
  /// intervenție" (tab Execuție, vizibil echipei de teren). Default false:
  /// prețul merge doar în câmpul admin „Suma incasata / de incasat".
  final bool vizibilLaExecutie;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creează un serviciu nou cu ID generat și timestamps curente.
  factory ServiciuPrestat.nou({
    required String denumire,
    double pretSugerat = 0,
    String moneda = 'RON',
    bool vizibilLaExecutie = false,
  }) {
    final now = DateTime.now();
    return ServiciuPrestat(
      id: const Uuid().v4(),
      denumire: denumire,
      pretSugerat: pretSugerat,
      moneda: moneda,
      activ: true,
      vizibilLaExecutie: vizibilLaExecutie,
      createdAt: now,
      updatedAt: now,
    );
  }

  ServiciuPrestat copyWith({
    String? id,
    String? denumire,
    double? pretSugerat,
    String? moneda,
    bool? activ,
    bool? vizibilLaExecutie,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiciuPrestat(
      id: id ?? this.id,
      denumire: denumire ?? this.denumire,
      pretSugerat: pretSugerat ?? this.pretSugerat,
      moneda: moneda ?? this.moneda,
      activ: activ ?? this.activ,
      vizibilLaExecutie: vizibilLaExecutie ?? this.vizibilLaExecutie,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'denumire': denumire,
      'pret_sugerat': pretSugerat,
      'moneda': moneda,
      'activ': activ,
      'vizibil_la_executie': vizibilLaExecutie,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ServiciuPrestat.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return ServiciuPrestat(
      id: (map['id'] ?? '').toString(),
      denumire: (map['denumire'] ?? '').toString(),
      pretSugerat: _toDouble(map['pret_sugerat'] ?? map['pretSugerat']),
      moneda: (map['moneda'] ?? 'RON').toString().trim().isEmpty
          ? 'RON'
          : (map['moneda'] ?? 'RON').toString(),
      activ: map['activ'] is bool ? map['activ'] as bool : (map['activ'] != false),
      vizibilLaExecutie: map['vizibil_la_executie'] == true ||
          map['vizibilLaExecutie'] == true,
      createdAt: _toDate(map['created_at']) ?? now,
      updatedAt: _toDate(map['updated_at']) ?? now,
    );
  }
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
