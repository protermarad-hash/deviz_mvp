import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'obiective_models.dart';

class ObiectiveRepository {
  ObiectiveRepository._();
  static final ObiectiveRepository instance = ObiectiveRepository._();

  static const String _localKey = 'obiective_lunare_v1';
  final Uuid _uuid = const Uuid();
  bool get _isCloud => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.obiectiveLunare);

  Future<void> upsert(ObiectivLunar o) async {
    await _writeLocal(o);
    await OfflineSyncRuntime.instance.queueObiectivLunarUpsert(o.toMap());
    if (_isCloud) {
      _col.doc(o.id).set(o.toMap(), SetOptions(merge: true)).catchError((_) {});
    }
  }

  Future<ObiectivLunar?> getForMonth(int an, int luna) async {
    final all = await _readAll();
    try {
      return all.firstWhere((o) => o.an == an && o.luna == luna);
    } catch (_) {
      return null;
    }
  }

  /// Returnează obiectivul curent sau unul gol cu default-uri din luna trecută.
  Future<ObiectivLunar> getOrCreateCurrent() async {
    final now = DateTime.now();
    final existing = await getForMonth(now.year, now.month);
    if (existing != null) return existing;

    // Copiază target-urile din luna trecută dacă există
    final prevLuna = now.month == 1 ? 12 : now.month - 1;
    final prevAn = now.month == 1 ? now.year - 1 : now.year;
    final prev = await getForMonth(prevAn, prevLuna);

    return ObiectivLunar(
      id: _uuid.v4(),
      an: now.year,
      luna: now.month,
      targetIncasariRON: prev?.targetIncasariRON ?? 0,
      targetLucrariNoi: prev?.targetLucrariNoi ?? 0,
      targetProgramariRON: prev?.targetProgramariRON ?? 0,
      targetOferteTrimise: prev?.targetOferteTrimise ?? 0,
      targetRataConversie: prev?.targetRataConversie ?? 0,
      createdAt: now,
    );
  }

  Future<List<ObiectivLunar>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey) ?? '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              ObiectivLunar.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[Obiective] ❌ _readAll: $e');
      return [];
    }
  }

  Future<void> _writeLocal(ObiectivLunar o) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll();
    final idx = all.indexWhere((item) => item.id == o.id);
    if (idx >= 0) {
      all[idx] = o;
    } else {
      all.add(o);
    }
    await prefs.setString(
        _localKey, jsonEncode(all.map((item) => item.toMap()).toList()));
  }
}
