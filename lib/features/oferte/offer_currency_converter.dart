class OfferCurrencyConverter {
  const OfferCurrencyConverter._();

  /// Valutele suportate în oferte. RON este moneda de bază (fără curs).
  /// Orice altă valută (EUR, HUF) se convertește prin curs.
  static const List<String> supportedCurrencies = <String>['RON', 'EUR', 'HUF'];

  static String normalizeCurrency(String raw) {
    final value = raw.trim().toUpperCase();
    if (supportedCurrencies.contains(value)) return value;
    return 'RON';
  }

  /// True dacă valuta necesită conversie prin curs (orice ≠ RON).
  static bool requiresRate(String currency) {
    return normalizeCurrency(currency) != 'RON';
  }

  /// Numărul de zecimale la afișare pentru o valută.
  /// HUF se afișează fără zecimale (convenție de piață — Forintul nu mai are
  /// subdiviziune folosită). EUR/RON rămân cu 2 zecimale.
  static int displayDecimals(String currency) {
    return normalizeCurrency(currency) == 'HUF' ? 0 : 2;
  }

  static double sanitizeRate(double value) {
    return value > 0 ? value : 0;
  }

  static double computeEffectiveRate({
    required double baseRate,
    required double commissionPercent,
  }) {
    final safeBase = sanitizeRate(baseRate);
    if (safeBase <= 0) return 0;
    return safeBase * (1 + (commissionPercent / 100));
  }

  static double convertRonToOfferCurrency({
    required double ronAmount,
    required String currency,
    required double effectiveRate,
  }) {
    // Generic: orice valută ≠ RON cu rată validă se convertește prin împărțire
    // la curs (identic pentru EUR și HUF). RON rămâne neschimbat.
    if (requiresRate(currency)) {
      final rate = sanitizeRate(effectiveRate);
      if (rate <= 0) return ronAmount;
      return ronAmount / rate;
    }
    return ronAmount;
  }

  static String formatMoney({
    required double ronAmount,
    required String currency,
    required double effectiveRate,
  }) {
    final normalized = normalizeCurrency(currency);
    final converted = convertRonToOfferCurrency(
      ronAmount: ronAmount,
      currency: currency,
      effectiveRate: effectiveRate,
    );
    return '${converted.toStringAsFixed(displayDecimals(normalized))} $normalized';
  }
}
