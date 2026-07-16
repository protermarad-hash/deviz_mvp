/// Catalog de muncitori parteneri (iul 2026) — trăiește STRICT în modulul
/// Lucrări (jobs/), pentru a putea fi gestionat fără a ieși din acest modul.
///
/// NOTĂ IMPORTANTĂ: există deja un catalog similar, mai vechi, în
/// `lib/features/partners/partner_models.dart` → `PartnerWorkerRecord`,
/// complet funcțional (repository + UI de management în `partners_page.dart`,
/// colecție Firestore `partner_workers`). Acest model NOU e intenționat
/// separat de acela — decizie explicită, pentru ca tot ce ține de prezența
/// pe șantier să rămână auto-conținut în jobs/. Cele două cataloage NU sunt
/// sincronizate automat între ele.
class PartnerWorkerMaster {
  const PartnerWorkerMaster({
    required this.id,
    required this.partnerId,
    required this.fullName,
    this.role = '',
    this.active = true,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String fullName;
  final String role;
  final bool active;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerWorkerMaster copyWith({
    String? id,
    String? partnerId,
    String? fullName,
    String? role,
    bool? active,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerWorkerMaster(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'partner_id': partnerId,
      'full_name': fullName,
      'role': role,
      'active': active,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerWorkerMaster.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text.isEmpty) return fallback;
      if (text == 'true' || text == '1' || text == 'da' || text == 'yes') {
        return true;
      }
      if (text == 'false' || text == '0' || text == 'nu' || text == 'no') {
        return false;
      }
      return fallback;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return PartnerWorkerMaster(
      id: pick(const <String>['id']),
      partnerId: pick(const <String>['partner_id', 'partnerId']),
      fullName: pick(const <String>['full_name', 'fullName', 'name']),
      role: pick(const <String>['role']),
      active: parseBool(map['active'], fallback: true),
      notes: pick(const <String>['notes', 'observatii']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}
