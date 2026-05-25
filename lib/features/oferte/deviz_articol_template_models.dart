class DevizArticolTemplate {
  const DevizArticolTemplate({
    required this.id,
    required this.denumire,
    required this.um,
    this.pretUnitarMat = 0,
    this.pretUnitarMan = 0,
    this.pretUnitarUtilaj = 0,
    this.pretUnitarTransport = 0,
    required this.lastUpdated,
    this.folositDeCateOri = 0,
    this.catalogProductId = '',
  });

  final String id;
  final String denumire;
  final String um;
  final double pretUnitarMat;
  final double pretUnitarMan;
  final double pretUnitarUtilaj;
  final double pretUnitarTransport;
  final DateTime lastUpdated;
  final int folositDeCateOri;
  final String catalogProductId;

  double get pretTotalUnitar =>
      pretUnitarMat + pretUnitarMan + pretUnitarUtilaj + pretUnitarTransport;

  String get denumireNormalizata => denumire.trim().toUpperCase();

  bool hasPriceChange(double newMat, double newMan) {
    const eps = 0.005;
    if (newMat > 0 && (newMat - pretUnitarMat).abs() > eps) return true;
    if (newMan > 0 && (newMan - pretUnitarMan).abs() > eps) return true;
    return false;
  }

  DevizArticolTemplate copyWith({
    String? id,
    String? denumire,
    String? um,
    double? pretUnitarMat,
    double? pretUnitarMan,
    double? pretUnitarUtilaj,
    double? pretUnitarTransport,
    DateTime? lastUpdated,
    int? folositDeCateOri,
    String? catalogProductId,
  }) {
    return DevizArticolTemplate(
      id: id ?? this.id,
      denumire: denumire ?? this.denumire,
      um: um ?? this.um,
      pretUnitarMat: pretUnitarMat ?? this.pretUnitarMat,
      pretUnitarMan: pretUnitarMan ?? this.pretUnitarMan,
      pretUnitarUtilaj: pretUnitarUtilaj ?? this.pretUnitarUtilaj,
      pretUnitarTransport: pretUnitarTransport ?? this.pretUnitarTransport,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      folositDeCateOri: folositDeCateOri ?? this.folositDeCateOri,
      catalogProductId: catalogProductId ?? this.catalogProductId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'denumire': denumire,
      'um': um,
      'pret_unitar_mat': pretUnitarMat,
      'pret_unitar_man': pretUnitarMan,
      'pret_unitar_utilaj': pretUnitarUtilaj,
      'pret_unitar_transport': pretUnitarTransport,
      'last_updated': lastUpdated.toIso8601String(),
      'folosit_de_cate_ori': folositDeCateOri,
      'catalog_product_id': catalogProductId,
    };
  }

  factory DevizArticolTemplate.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
    }

    int asInt(dynamic raw) {
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString().trim()) ?? 0;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString().trim());
    }

    return DevizArticolTemplate(
      id: (map['id'] ?? '').toString().trim(),
      denumire: (map['denumire'] ?? '').toString(),
      um: (map['um'] ?? '').toString(),
      pretUnitarMat: asDouble(map['pret_unitar_mat'] ?? map['pretUnitarMat']),
      pretUnitarMan: asDouble(map['pret_unitar_man'] ?? map['pretUnitarMan']),
      pretUnitarUtilaj:
          asDouble(map['pret_unitar_utilaj'] ?? map['pretUnitarUtilaj']),
      pretUnitarTransport:
          asDouble(map['pret_unitar_transport'] ?? map['pretUnitarTransport']),
      lastUpdated: parseDate(map['last_updated'] ?? map['lastUpdated']) ??
          DateTime.now(),
      folositDeCateOri:
          asInt(map['folosit_de_cate_ori'] ?? map['folositDeCateOri']),
      catalogProductId:
          (map['catalog_product_id'] ?? map['catalogProductId'] ?? '')
              .toString(),
    );
  }
}
