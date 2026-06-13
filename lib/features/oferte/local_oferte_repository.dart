import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offer_models.dart';

class LocalOferteRepository {
  static const String _offersKey = 'ultra_offers_v1';

  // Serializăm toate operațiile pentru a preveni race conditions (citire-modificare-scriere)
  Future<void>? _lock;

  Future<T> _synchronized<T>(Future<T> Function() operation) async {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      if (previous != null) await previous.catchError((_) {});
      return await operation();
    } finally {
      completer.complete();
    }
  }

  Future<List<OfferRecord>> listOffers() => _synchronized(_readOffers);

  Future<void> upsertOffer(OfferRecord offer) =>
      _synchronized(() => _upsertInternal(offer));

  Future<void> replaceOffers(List<OfferRecord> items) =>
      _synchronized(() => _writeOffers(items));

  Future<void> deleteOffer(String offerId) =>
      _synchronized(() => _deleteInternal(offerId));

  // Metode interne (fără lock — sunt apelate din _synchronized)

  Future<List<OfferRecord>> _readOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offersKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <OfferRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const <OfferRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map((row) => OfferRecord.fromMap(Map<String, dynamic>.from(row)))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      // JSON corupt în SharedPreferences — returnăm listă goală în loc să crăpăm
      return const <OfferRecord>[];
    }
  }

  Future<void> _upsertInternal(OfferRecord offer) async {
    final current = [...await _readOffers()];
    final index = current.indexWhere((item) => item.id == offer.id);
    if (index >= 0) {
      current[index] = offer;
    } else {
      current.add(offer);
    }
    await _writeOffers(current);
  }

  Future<void> _deleteInternal(String offerId) async {
    final current = [...await _readOffers()]
      ..removeWhere((item) => item.id == offerId);
    await _writeOffers(current);
  }

  Future<void> _writeOffers(List<OfferRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = items.map((item) => item.toMap()).toList(growable: false);
    await prefs.setString(_offersKey, jsonEncode(payload));
  }

  /// Returnează ofertele cu status 'sent' (trimise) care nu au primit răspuns
  /// în ultimele [dupaZile] zile și nu au fost convertite în lucrare.
  Future<List<OfferRecord>> listExpirate({required int dupaZile}) async {
    final cutoff =
        DateTime.now().subtract(Duration(days: dupaZile));
    final all = await listOffers();
    return all
        .where((o) =>
            o.status == OfferStatus.sent &&
            o.updatedAt.isBefore(cutoff) &&
            !o.isConverted)
        .toList(growable: false);
  }
}
