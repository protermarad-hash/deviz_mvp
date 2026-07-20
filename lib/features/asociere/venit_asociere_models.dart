/// Venit (factură emisă) pe o Asociere. Intră în `veniturIncasatTotal` al
/// unui decont lunar DOAR dacă `dataIncasare` e setată și cade în luna
/// respectivă — o factură emisă dar neîncasată nu contează ca venit
/// recunoscut (numele câmpului pe DecontLunarAsociere e explicit
/// "încasat", nu "facturat").
class VenitAsociereRecord {
  const VenitAsociereRecord({
    required this.id,
    required this.asociereId,
    required this.nrFactura,
    required this.dataFactura,
    required this.valoareFaraTva,
    this.situatieLucrariAferenta = '',
    this.dataIncasare,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String asociereId;
  final String nrFactura;
  final DateTime dataFactura;
  final double valoareFaraTva;

  /// Referință text la situația de lucrări care a generat factura (nu FK
  /// strict — situațiile de lucrări nu au încă id-uri stabile expuse aici).
  final String situatieLucrariAferenta;
  final DateTime? dataIncasare;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get esteIncasat => dataIncasare != null;

  VenitAsociereRecord copyWith({
    String? nrFactura,
    DateTime? dataFactura,
    double? valoareFaraTva,
    String? situatieLucrariAferenta,
    Object? dataIncasare = _unset,
    DateTime? updatedAt,
  }) {
    return VenitAsociereRecord(
      id: id,
      asociereId: asociereId,
      nrFactura: nrFactura ?? this.nrFactura,
      dataFactura: dataFactura ?? this.dataFactura,
      valoareFaraTva: valoareFaraTva ?? this.valoareFaraTva,
      situatieLucrariAferenta:
          situatieLucrariAferenta ?? this.situatieLucrariAferenta,
      dataIncasare: identical(dataIncasare, _unset)
          ? this.dataIncasare
          : dataIncasare as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'asociere_id': asociereId,
      'nr_factura': nrFactura,
      'data_factura': dataFactura.toIso8601String(),
      'valoare_fara_tva': valoareFaraTva,
      'situatie_lucrari_aferenta': situatieLucrariAferenta,
      'data_incasare': dataIncasare?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VenitAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return VenitAsociereRecord(
      id: pick(const <String>['id']),
      asociereId: pick(const <String>['asociere_id', 'asociereId']),
      nrFactura: pick(const <String>['nr_factura', 'nrFactura']),
      dataFactura:
          DateTime.tryParse((map['data_factura'] ?? '').toString()) ?? now,
      valoareFaraTva:
          parseDouble(map['valoare_fara_tva'] ?? map['valoareFaraTva']),
      situatieLucrariAferenta: pick(
        const <String>['situatie_lucrari_aferenta', 'situatieLucrariAferenta'],
      ),
      dataIncasare:
          DateTime.tryParse((map['data_incasare'] ?? '').toString()),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

const Object _unset = Object();
