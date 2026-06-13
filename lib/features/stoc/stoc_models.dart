class StocItem {
  const StocItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku = '',
    this.categorie = '',
    this.cantitate = 0.0,
    this.pragMinim = 0.0,
    this.pragComanda = 0.0,
    this.unitate = 'buc',
    this.pretUnitarAchizitie = 0.0,
    this.furnizor = '',
    this.ultimaActualizare,
    this.ultimaComanda,
  });

  final String id;
  final String productId;
  final String productName;
  final String sku;
  final String categorie;
  final double cantitate;
  final double pragMinim;
  final double pragComanda;
  final String unitate;
  final double pretUnitarAchizitie;
  final String furnizor;
  final DateTime? ultimaActualizare;
  final DateTime? ultimaComanda;

  bool get esteStocCritic => cantitate <= pragMinim;
  bool get necesitaComanda => cantitate <= pragComanda;

  StocItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? sku,
    String? categorie,
    double? cantitate,
    double? pragMinim,
    double? pragComanda,
    String? unitate,
    double? pretUnitarAchizitie,
    String? furnizor,
    DateTime? ultimaActualizare,
    DateTime? ultimaComanda,
  }) {
    return StocItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      categorie: categorie ?? this.categorie,
      cantitate: cantitate ?? this.cantitate,
      pragMinim: pragMinim ?? this.pragMinim,
      pragComanda: pragComanda ?? this.pragComanda,
      unitate: unitate ?? this.unitate,
      pretUnitarAchizitie: pretUnitarAchizitie ?? this.pretUnitarAchizitie,
      furnizor: furnizor ?? this.furnizor,
      ultimaActualizare: ultimaActualizare ?? this.ultimaActualizare,
      ultimaComanda: ultimaComanda ?? this.ultimaComanda,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'categorie': categorie,
        'cantitate': cantitate,
        'prag_minim': pragMinim,
        'prag_comanda': pragComanda,
        'unitate': unitate,
        'pret_unitar_achizitie': pretUnitarAchizitie,
        'furnizor': furnizor,
        'ultima_actualizare': ultimaActualizare?.toIso8601String(),
        'ultima_comanda': ultimaComanda?.toIso8601String(),
      };

  factory StocItem.fromMap(Map<String, dynamic> m) => StocItem(
        id: (m['id'] ?? '').toString(),
        productId: (m['product_id'] ?? '').toString(),
        productName: (m['product_name'] ?? '').toString(),
        sku: (m['sku'] ?? '').toString(),
        categorie: (m['categorie'] ?? '').toString(),
        cantitate: (m['cantitate'] as num? ?? 0).toDouble(),
        pragMinim: (m['prag_minim'] as num? ?? 0).toDouble(),
        pragComanda: (m['prag_comanda'] as num? ?? 0).toDouble(),
        unitate: (m['unitate'] ?? 'buc').toString(),
        pretUnitarAchizitie:
            (m['pret_unitar_achizitie'] as num? ?? 0).toDouble(),
        furnizor: (m['furnizor'] ?? '').toString(),
        ultimaActualizare:
            DateTime.tryParse((m['ultima_actualizare'] ?? '').toString()),
        ultimaComanda:
            DateTime.tryParse((m['ultima_comanda'] ?? '').toString()),
      );
}

class StocMiscare {
  const StocMiscare({
    required this.id,
    required this.stocItemId,
    required this.productId,
    required this.productName,
    required this.tip,
    required this.cantitate,
    required this.cantitateInainte,
    required this.cantitateAfter,
    required this.createdBy,
    required this.createdAt,
    this.referintaId = '',
    this.referintaTip = '',
    this.referintaNume = '',
    this.unitate = 'buc',
  });

  final String id;
  final String stocItemId;
  final String productId;
  final String productName;
  /// 'consum' | 'achizitie' | 'ajustare' | 'retur'
  final String tip;
  final double cantitate;
  final double cantitateInainte;
  final double cantitateAfter;
  final String referintaId;
  final String referintaTip;
  final String referintaNume;
  final String unitate;
  final String createdBy;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'stoc_item_id': stocItemId,
        'product_id': productId,
        'product_name': productName,
        'tip': tip,
        'cantitate': cantitate,
        'cantitate_inainte': cantitateInainte,
        'cantitate_after': cantitateAfter,
        'referinta_id': referintaId,
        'referinta_tip': referintaTip,
        'referinta_nume': referintaNume,
        'unitate': unitate,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory StocMiscare.fromMap(Map<String, dynamic> m) => StocMiscare(
        id: (m['id'] ?? '').toString(),
        stocItemId: (m['stoc_item_id'] ?? '').toString(),
        productId: (m['product_id'] ?? '').toString(),
        productName: (m['product_name'] ?? '').toString(),
        tip: (m['tip'] ?? 'consum').toString(),
        cantitate: (m['cantitate'] as num? ?? 0).toDouble(),
        cantitateInainte: (m['cantitate_inainte'] as num? ?? 0).toDouble(),
        cantitateAfter: (m['cantitate_after'] as num? ?? 0).toDouble(),
        referintaId: (m['referinta_id'] ?? '').toString(),
        referintaTip: (m['referinta_tip'] ?? '').toString(),
        referintaNume: (m['referinta_nume'] ?? '').toString(),
        unitate: (m['unitate'] ?? 'buc').toString(),
        createdBy: (m['created_by'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}
