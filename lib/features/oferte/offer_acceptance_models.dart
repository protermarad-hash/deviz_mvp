import 'package:uuid/uuid.dart';

class OfferAcceptanceClause {
  const OfferAcceptanceClause({
    required this.id,
    required this.title,
    required this.content,
    this.enabled = true,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String content;
  final bool enabled;
  final int sortOrder;

  OfferAcceptanceClause copyWith({
    String? id,
    String? title,
    String? content,
    bool? enabled,
    int? sortOrder,
  }) {
    return OfferAcceptanceClause(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'enabled': enabled,
      'sort_order': sortOrder,
    };
  }

  factory OfferAcceptanceClause.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    bool asBool(dynamic v, bool fallback) {
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) return v == 'true' || v == '1';
      return fallback;
    }

    return OfferAcceptanceClause(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      enabled: asBool(map['enabled'], true),
      sortOrder: asInt(map['sort_order'] ?? map['sortOrder'], 0),
    );
  }

  /// Clauze pre-setate implicite pentru firmele de construcții/instalații din România.
  /// Parametrii [totalLabel] și [currency] sunt folosiți în clauza de plată.
  static List<OfferAcceptanceClause> defaults({
    String totalLabel = '',
    String currency = 'RON',
  }) {
    const uuid = Uuid();
    final paymentContent = totalLabel.isNotEmpty
        ? 'Prețul total acceptat este de $totalLabel $currency, conform ofertei menționate. '
            'Plata se efectuează astfel: 30% avans la semnarea prezentului formular; '
            '70% din valoarea totală la finalizarea și recepția lucrărilor. '
            'Plata se poate efectua prin transfer bancar sau numerar.'
        : 'Prețul total acceptat este cel din oferta menționată. '
            'Plata se efectuează astfel: 30% avans la semnarea prezentului formular; '
            '70% la finalizarea și recepția lucrărilor. '
            'Plata se poate efectua prin transfer bancar sau numerar.';

    return [
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Durata de execuție',
        content:
            'Lucrările convenite vor fi executate în termen de _____ zile lucrătoare '
            'de la data achitării avansului sau de la data stabilită de comun acord. '
            'Termenul poate fi prelungit în cazul unor impedimente obiective '
            '(condiții meteo, întârzieri de materiale, etc.), cu notificarea prealabilă '
            'a beneficiarului.',
        sortOrder: 1,
      ),
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Condiții de plată',
        content: paymentContent,
        sortOrder: 2,
      ),
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Garanție lucrări',
        content:
            'Prestatorul acordă garanție de 24 (douăzeci și patru) luni pentru lucrările '
            'executate, calculată de la data recepției. Garanția acoperă viciile ascunse '
            'și defectele de execuție. Nu sunt acoperite deteriorările cauzate de '
            'utilizare necorespunzătoare sau intervenții neautorizate ale terților.',
        sortOrder: 3,
      ),
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Penalități de întârziere la plată',
        content:
            'În cazul neachitării la termenele convenite, beneficiarul datorează penalități '
            'de 0,1% pe zi de întârziere, calculate din suma restantă. Prestatorul are '
            'dreptul de a sista lucrările în cazul unui întârzieri mai mari de 10 zile '
            'lucrătoare.',
        sortOrder: 4,
      ),
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Acces la obiectiv',
        content:
            'Beneficiarul se obligă să asigure accesul echipei prestatoare la obiectivul '
            'de lucru în intervalul orar stabilit de comun acord și să pună la dispoziție '
            'utilitățile necesare (energie electrică, apă), fără costuri suplimentare '
            'pentru prestator.',
        sortOrder: 5,
      ),
      OfferAcceptanceClause(
        id: uuid.v4(),
        title: 'Modificări de scop',
        content:
            'Orice modificare a lucrărilor față de cele din prezentul acord se realizează '
            'numai cu acordul scris al ambelor părți (act adițional sau email confirmat). '
            'Modificările de scop pot implica ajustarea prețului și/sau a termenului '
            'de execuție.',
        sortOrder: 6,
      ),
    ];
  }
}
