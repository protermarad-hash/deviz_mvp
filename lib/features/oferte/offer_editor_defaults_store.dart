import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/company_profile.dart';
import 'offer_models.dart';

class OfferEditorDefaults {
  const OfferEditorDefaults({
    this.vatPercent = 21,
    this.regiePercent = 0,
    this.profitPercent = 0,
    this.currency = 'RON',
    this.exchangeRateSource = OfferExchangeRateSource.manual,
    this.exchangeCommissionPercent = 0,
  });

  final double vatPercent;
  final double regiePercent;
  final double profitPercent;
  final String currency;
  final OfferExchangeRateSource exchangeRateSource;
  final double exchangeCommissionPercent;

  OfferEditorDefaults copyWith({
    double? vatPercent,
    double? regiePercent,
    double? profitPercent,
    String? currency,
    OfferExchangeRateSource? exchangeRateSource,
    double? exchangeCommissionPercent,
  }) {
    return OfferEditorDefaults(
      vatPercent: vatPercent ?? this.vatPercent,
      regiePercent: regiePercent ?? this.regiePercent,
      profitPercent: profitPercent ?? this.profitPercent,
      currency: currency ?? this.currency,
      exchangeRateSource: exchangeRateSource ?? this.exchangeRateSource,
      exchangeCommissionPercent:
          exchangeCommissionPercent ?? this.exchangeCommissionPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'vat_percent': vatPercent,
      'regie_percent': regiePercent,
      'profit_percent': profitPercent,
      'currency': currency,
      'exchange_rate_source': exchangeRateSource.value,
      'exchange_commission_percent': exchangeCommissionPercent,
    };
  }

  factory OfferEditorDefaults.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw, double fallback) {
      if (raw == null) return fallback;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ??
          fallback;
    }

    final normalizedCurrency =
        (map['currency'] ?? 'RON').toString().trim().toUpperCase() == 'EUR'
            ? 'EUR'
            : 'RON';
    return OfferEditorDefaults(
      vatPercent: asDouble(map['vat_percent'] ?? map['vatPercent'], 21),
      regiePercent: asDouble(map['regie_percent'] ?? map['regiePercent'], 0),
      profitPercent: asDouble(map['profit_percent'] ?? map['profitPercent'], 0),
      currency: normalizedCurrency,
      exchangeRateSource: OfferExchangeRateSource.fromValue(
        (map['exchange_rate_source'] ?? map['exchangeRateSource'] ?? 'manual')
            .toString(),
      ),
      exchangeCommissionPercent: asDouble(
        map['exchange_commission_percent'] ?? map['exchangeCommissionPercent'],
        0,
      ),
    );
  }
}

class OfferEditorDefaultsStore {
  static const String _prefsKey = 'offer_editor_defaults_v1';

  Future<OfferEditorDefaults> load({CompanyProfile? profileFallback}) async {
    // Taxele (TVA, profit, regie) vin ÎNTOTDEAUNA din Setările firmei.
    // Cache-ul păstrează doar preferințele de monedă și curs de schimb.
    final vatPercent = profileFallback?.defaultVatPercent ?? 21.0;
    final profitPercent = profileFallback?.defaultProfitPercent ?? 0.0;
    final regiePercent = profileFallback?.defaultOverheadPercent ?? 0.0;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return OfferEditorDefaults(
        vatPercent: vatPercent,
        profitPercent: profitPercent,
        regiePercent: regiePercent,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : null;
      if (map != null) {
        // Aplică preferințele de monedă din cache,
        // dar suprascrie taxele cu valorile din Setările firmei.
        final cached = OfferEditorDefaults.fromMap(map);
        return cached.copyWith(
          vatPercent: vatPercent,
          profitPercent: profitPercent,
          regiePercent: regiePercent,
        );
      }
    } catch (e) {
      debugPrint('[OfferEditorDefaults] parsare cache eșuată, folosesc default: $e');
    }
    return OfferEditorDefaults(
      vatPercent: vatPercent,
      profitPercent: profitPercent,
      regiePercent: regiePercent,
    );
  }

  Future<void> save(OfferEditorDefaults defaults) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(defaults.toMap()));
  }
}
