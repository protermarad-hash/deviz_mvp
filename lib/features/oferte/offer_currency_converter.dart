class OfferCurrencyConverter {
  const OfferCurrencyConverter._();

  static String normalizeCurrency(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == 'EUR') return 'EUR';
    return 'RON';
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
    final normalizedCurrency = normalizeCurrency(currency);
    if (normalizedCurrency == 'EUR') {
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
    final converted = convertRonToOfferCurrency(
      ronAmount: ronAmount,
      currency: currency,
      effectiveRate: effectiveRate,
    );
    return '${converted.toStringAsFixed(2)} ${normalizeCurrency(currency)}';
  }
}
