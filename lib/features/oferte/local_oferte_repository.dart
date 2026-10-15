import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/cloud/revision_sync.dart';
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

  /// Doar teste: furnizează entitățile protejate (altfel din OfflineSyncRuntime).
  @visibleForTesting
  static Future<Set<String>> Function()? debugProtectedIds;

  /// Îmbină lista din cloud cu stocarea locală FĂRĂ a pierde modificări locale:
  /// pentru ofertele cu modificări nesincronizate sau conflict deschis rămâne
  /// versiunea locală; ofertele doar-locale se păstrează dacă sunt protejate sau
  /// nu au fost văzute niciodată pe server (acestea intră și în coadă). Doar o
  /// ofertă văzută pe server, ștearsă acolo și fără modificare locală dispare.
  /// Înainte, `replaceOffers(cloud)` elimina orice ofertă doar-locală.
  Future<List<OfferRecord>> mergeOffersFromCloud(List<OfferRecord> cloudItems) =>
      runEntitySyncLocked(CloudEntityType.offers, () => _mergeOffersLocked(cloudItems));

  Future<List<OfferRecord>> _mergeOffersLocked(List<OfferRecord> cloudItems) async {
    return _synchronized(() async {
      // Sub blocarea comună: o salvare locală + coadă nu poate apărea între
      // citirea entităților protejate și scrierea rezultatului.
      final protectedIds = await (debugProtectedIds?.call() ??
          OfflineSyncRuntime.instance.protectedEntityIds(CloudEntityType.offers));
      final local = await _readOffers();
      final localById = {for (final o in local) o.id: o};
      final cloudIds = <String>{};
      final merged = <OfferRecord>[];
      for (final c in cloudItems) {
        cloudIds.add(c.id);
        final l = localById[c.id];
        if (protectedIds.contains(c.id)) {
          // Modificare locală în așteptare: varianta locală rămâne; dacă local
          // lipsește, e o ștergere în așteptare → NU se readuce copia din cloud.
          if (l != null) merged.add(l);
          continue;
        }
        merged.add(c);
      }
      final bases = RevisionBaseStore();
      final seenOnServer = await bases.idsWithBase(CloudEntityType.offers);
      final firstMerge = !await bases.isInitialized(CloudEntityType.offers);
      final neverSynced = <OfferRecord>[];
      for (final o in local) {
        if (cloudIds.contains(o.id)) continue;
        if (protectedIds.contains(o.id)) {
          merged.add(o); // modificare locală în așteptare
        } else if (!seenOnServer.contains(o.id)) {
          merged.add(o);
          if (firstMerge) {
            // Prima îmbinare după actualizare: netrimisă SAU ștearsă în altă parte.
            await parkUnknownOnUpgrade(CloudEntityType.offers, o.id, o.toMap());
          } else {
            neverSynced.add(o); // niciodată văzută pe server: date locale netrimise
          }
        }
        // Altfel: văzută pe server și ștearsă acolo → ștergerea se aplică local.
      }
      await _writeOffers(merged);
      if (firstMerge) await bases.markInitialized(CloudEntityType.offers);
      return (merged, neverSynced);
    }).then((r) async {
      for (final o in r.$2) {
        await OfflineSyncRuntime.instance.queueOffer(o);
      }
      return r.$1;
    });
  }

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
