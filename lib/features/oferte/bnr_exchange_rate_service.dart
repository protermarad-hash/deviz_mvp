import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Serviciu de curs valutar BNR (nbrfxrates.xml).
///
/// Tratează corect atributul `multiplier` din XML: unele valute (ex. HUF, JPY)
/// sunt publicate ca `<Rate currency="HUF" multiplier="100">1.2494</Rate>`,
/// unde valoarea este cursul pentru 100 de unități. Cursul normalizat (RON per
/// 1 unitate) = valoare / multiplier. EUR nu are `multiplier` → implicit 1.
class BnrExchangeRateService {
  const BnrExchangeRateService();

  static const String _bnrFeedUrl = 'https://www.bnr.ro/nbrfxrates.xml';

  /// Cheia de cache per valută (ex. `ultra_offer_bnr_rate_EUR_v1`).
  static String _cacheKeyFor(String currencyCode) =>
      'ultra_offer_bnr_rate_${currencyCode.trim().toUpperCase()}_v1';

  /// Extrage cursul normalizat pentru o valută din corpul XML BNR.
  /// Returnează `valoare / multiplier` sau null dacă nu găsește / e invalid.
  static double? parseRateFromXml(String body, String currencyCode) {
    final code = currencyCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final escaped = RegExp.escape(code);
    // Extrage întreg elementul <Rate ...>valoare</Rate> pentru codul căutat,
    // indiferent de ordinea atributelor.
    final tagMatch = RegExp(
      '<Rate[^>]*currency="$escaped"[^>]*>[^<]+</Rate>',
      caseSensitive: false,
    ).firstMatch(body);
    final tag = tagMatch?.group(0);
    if (tag == null) return null;

    final valueRaw =
        RegExp(r'>([^<]+)</Rate>', caseSensitive: false).firstMatch(tag)?.group(1)?.trim() ??
            '';
    final value = double.tryParse(valueRaw.replaceAll(',', '.'));
    if (value == null || value <= 0) return null;

    final multiplierRaw = RegExp(
      r'multiplier="(\d+)"',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1);
    final multiplier =
        multiplierRaw == null ? 1 : (int.tryParse(multiplierRaw) ?? 1);
    final safeMultiplier = multiplier > 0 ? multiplier : 1;

    return value / safeMultiplier;
  }

  Future<double?> getCachedRate(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyFor(currencyCode));
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.').trim());
  }

  Future<void> _cacheRate(String currencyCode, double value) async {
    if (value <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKeyFor(currencyCode), value.toStringAsFixed(6));
  }

  /// Preia cursul normalizat (RON per 1 unitate) pentru orice valută din feed-ul
  /// BNR, aplicând corect `multiplier`.
  Future<double?> fetchRate(
    String currencyCode, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = timeout;
      final request = await client.getUrl(Uri.parse(_bnrFeedUrl));
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await utf8.decodeStream(response);
      final value = parseRateFromXml(body, currencyCode);
      if (value == null || value <= 0) {
        return null;
      }
      await _cacheRate(currencyCode, value);
      return value;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Preia cursul proaspăt; dacă eșuează, cade pe cache-ul salvat.
  Future<double?> fetchOrCachedRate(String currencyCode) async {
    final fresh = await fetchRate(currencyCode);
    if (fresh != null && fresh > 0) return fresh;
    return getCachedRate(currencyCode);
  }

  // --- Wrappere de compatibilitate (EUR) peste API-ul generic ---

  Future<double?> getCachedEurRate() => getCachedRate('EUR');

  Future<double?> fetchEurRate({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      fetchRate('EUR', timeout: timeout);

  Future<double?> fetchOrCachedEurRate() => fetchOrCachedRate('EUR');
}
