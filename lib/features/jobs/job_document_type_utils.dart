// Funcții utilitare pentru normalizarea și afișarea tipurilor de documente
// asociate lucrărilor. Folosite în lucrare_detalii_page.dart și
// lucrare_raport_complet_page.dart.

String normalizeDocumentTypeCanonical(dynamic rawValue) {
  if (rawValue is Map) {
    final map = Map<String, dynamic>.from(rawValue);
    final subtype = '${map['documentSubtype'] ?? map['subtype'] ?? ''}'
        .trim()
        .toLowerCase();
    if (subtype == 'oferta_client') {
      return 'oferta_client';
    }
    rawValue = map['type'] ??
        map['tipDocument'] ??
        map['documentType'] ??
        map['source'] ??
        map['numarDocument'] ??
        map['number'] ??
        map['titlu'] ??
        map['title'] ??
        '';
  }
  final raw = '${rawValue ?? ''}'.trim().toLowerCase();
  if (raw.isEmpty) return '';
  final compact = raw
      .replaceAll(RegExp(r'[\s_\-]+'), ' ')
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't')
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't')
      .trim();

  if (compact == 'of' ||
      compact == 'oferta' ||
      compact == 'oferta client' ||
      compact == 'oferta_client' ||
      compact.startsWith('oferta ')) {
    // Pentru tipuri string brute (ex: dropdown add-document), oferta client
    // folosește numerotarea ofertei. Diferențierea vizuală rămâne pe subtype.
    return 'oferta';
  }
  if (compact == 'dv' || compact == 'deviz' || compact.startsWith('deviz ')) {
    return 'deviz';
  }
  if (compact == 'ct' ||
      compact == 'contract' ||
      compact.startsWith('contract ')) {
    return 'contract';
  }
  if (compact == 'pv' ||
      compact == 'proces verbal' ||
      compact == 'proces-verbal' ||
      compact == 'proces_verbal' ||
      // 'process_verbal' (valoarea reala din row['type']) devine, dupa
      // compactare underscore->spatiu, 'process verbal' (ortografie EN cu
      // dublu 's'). Fara aceasta varianta, PV-ul nu se potrivea niciodata.
      compact == 'process verbal' ||
      compact == 'processverbal' ||
      compact.startsWith('pv ') ||
      compact.startsWith('process verbal') ||
      compact.startsWith('proces verbal')) {
    return 'pv';
  }
  if (compact == 'pif' || compact.startsWith('pif ')) {
    return 'pif';
  }
  if (compact == 'raport' ||
      compact == 'raport lucrare' ||
      compact == 'raport_lucrare' ||
      compact.startsWith('raport ')) {
    return 'raport_lucrare';
  }
  return '';
}

String documentTypeLabelFromCanonical(String canonicalType) {
  switch (canonicalType) {
    case 'oferta_client':
      return 'Ofertă client';
    case 'oferta':
      return 'Ofertă';
    case 'deviz':
      return 'Deviz';
    case 'contract':
      return 'Contract';
    case 'pv':
      return 'Proces verbal';
    case 'pif':
      return 'PIF';
    case 'raport_lucrare':
      return 'Raport lucrare';
    default:
      return 'Alt document';
  }
}
