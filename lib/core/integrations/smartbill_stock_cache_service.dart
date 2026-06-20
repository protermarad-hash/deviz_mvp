import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../smartbill_settings.dart';
import 'smartbill_service.dart';

/// Serviciu care preia stocul din SmartBill și îl salvează local (cache).
/// Stocul este disponibil offline după prima sincronizare.
///
/// Cheie cache SharedPreferences: 'smartbill_stock_cache'
/// Format: JSON map { "numeProdus": { name, code, unit, quantity, unitPrice } }
class SmartBillStockCacheService {
  SmartBillStockCacheService({SmartBillService? service})
      : _service = service ?? SmartBillService();

  final SmartBillService _service;

  static const String _cacheKey = 'smartbill_stock_cache';
  static const String _cacheTimestampKey = 'smartbill_stock_cache_ts';

  /// Returnează stocul curent din cache (fără apel la SmartBill).
  /// Map cheie = denumire produs lowercase trim.
  Future<Map<String, SmartBillStockItem>> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, SmartBillStockItem>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          result[key] = SmartBillStockItem.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Data ultimei sincronizări cu SmartBill (null dacă nu s-a sincronizat niciodată).
  Future<DateTime?> lastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTimestampKey);
      if (ts == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ts);
    } catch (_) {
      return null;
    }
  }

  /// Preia stocul din SmartBill și actualizează cache-ul local.
  /// Returnează map-ul actualizat sau aruncă excepție dacă apelul eșuează.
  Future<Map<String, SmartBillStockItem>> syncFromSmartBill(
    SmartBillSettings settings,
  ) async {
    if (!settings.isConsumptionConfigured) {
      throw SmartBillApiException(
        'Gestiunea pentru bonuri de consum nu este configurată în Setări SmartBill.',
      );
    }

    final items = await _service.fetchStock(
      settings,
      warehouseName: settings.consumptionWarehouseName,
    );

    // Construiește map cheiat după denumire lowercase
    final stockMap = <String, SmartBillStockItem>{};
    for (final item in items) {
      final key = item.name.trim().toLowerCase();
      if (key.isNotEmpty) {
        stockMap[key] = item;
      }
    }

    // Salvează în cache
    await _saveToCache(stockMap);
    return stockMap;
  }

  /// Preia stocul dacă cache-ul e mai vechi de [maxAgeMinutes] minute sau e gol.
  /// În caz de eroare, returnează cache-ul existent (offline graceful).
  Future<Map<String, SmartBillStockItem>> syncIfStale(
    SmartBillSettings settings, {
    int maxAgeMinutes = 30,
  }) async {
    if (!settings.isConsumptionConfigured) return await loadCached();

    try {
      final lastSync = await lastSyncTime();
      final now = DateTime.now();
      final isStale = lastSync == null ||
          now.difference(lastSync).inMinutes >= maxAgeMinutes;

      if (isStale) {
        return await syncFromSmartBill(settings);
      } else {
        return await loadCached();
      }
    } catch (_) {
      // Offline sau eroare SmartBill — returnează cache existent
      return await loadCached();
    }
  }

  /// Caută un articol în stock după denumire (case-insensitive, potrivire parțială).
  Future<SmartBillStockItem?> findByName(
    String name, {
    Map<String, SmartBillStockItem>? stockMap,
  }) async {
    final map = stockMap ?? await loadCached();
    final key = name.trim().toLowerCase();
    // Potrivire exactă
    if (map.containsKey(key)) return map[key];
    // Potrivire parțială (primul rezultat care conține căutarea)
    for (final entry in map.entries) {
      if (entry.key.contains(key) || key.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _saveToCache(Map<String, SmartBillStockItem> stockMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, dynamic>{};
      for (final entry in stockMap.entries) {
        serialized[entry.key] = {
          'name': entry.value.name,
          'code': entry.value.code,
          'unit': entry.value.unit,
          'quantity': entry.value.quantity,
          'unitPrice': entry.value.unitPrice,
        };
      }
      await prefs.setString(_cacheKey, jsonEncode(serialized));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Nu blocăm dacă cache-ul nu se poate salva
    }
  }

  /// Șterge cache-ul (util pentru debug sau resetare).
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (_) {/* intenționat ignorat: curățare cache best-effort */}
  }
}
