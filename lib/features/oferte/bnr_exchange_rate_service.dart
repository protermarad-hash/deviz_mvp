import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class BnrExchangeRateService {
  const BnrExchangeRateService();

  static const String _bnrEurRateKey = 'ultra_offer_bnr_eur_rate_v1';
  static const String _bnrFeedUrl = 'https://www.bnr.ro/nbrfxrates.xml';

  Future<double?> getCachedEurRate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bnrEurRateKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.').trim());
  }

  Future<void> _cacheEurRate(double value) async {
    if (value <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bnrEurRateKey, value.toStringAsFixed(6));
  }

  Future<double?> fetchEurRate({
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
      final match = RegExp(
        r'<Rate[^>]*currency="EUR"[^>]*>([^<]+)</Rate>',
        caseSensitive: false,
      ).firstMatch(body);
      final raw = match?.group(1)?.trim() ?? '';
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value == null || value <= 0) {
        return null;
      }
      await _cacheEurRate(value);
      return value;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<double?> fetchOrCachedEurRate() async {
    final fresh = await fetchEurRate();
    if (fresh != null && fresh > 0) return fresh;
    return getCachedEurRate();
  }
}
