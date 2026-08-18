import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/firebase_bootstrap.dart';
import '../cloud/firebase_collections.dart';

/// Repository pentru ordinea custom a grupurilor de status (Oferte, Devize
/// Tehnice etc.), salvată PER UTILIZATOR și sincronizată cross-device.
///
/// Document Firestore: `user_status_order/{uid}`, câmp `status_order` = mapă
/// `{ moduleId: [chei status în ordinea aleasă de user] }`, ex:
/// `{ "oferte": ["accepted", "sent", ...], "deviz_tehnic": [...] }`.
///
/// Diferă INTENȚIONAT de precedentul `app_settings/deviz_tehnic_settings`
/// (`deviz_tehnic_repository.dart:318-320`) — acela e un document GLOBAL, unic
/// pentru toată firma. Aici fiecare utilizator are documentul lui propriu,
/// identificat după Firebase Auth UID (`FirebaseAuth.instance.currentUser.uid`,
/// aceeași sursă de UID ca `field_firebase_auth_repository.dart:89` etc.).
///
/// Pattern local-first, la fel ca `saveDefaultTipDocument()`/
/// `loadDefaultTipDocument()`: local (SharedPreferences) întâi — funcționează
/// offline — apoi Firestore best-effort pentru sincronizare cross-device.
class UserStatusOrderRepository {
  static const _prefKeyPrefix = 'status_order_';

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection(FirebaseCollections.userStatusOrder);

  /// Salvează ordinea de statusuri pentru un modul (ex: `'oferte'`,
  /// `'deviz_tehnic'`). Local întâi (persistă și offline), apoi Firestore
  /// best-effort — dacă scrierea cloud eșuează, ordinea rămâne salvată local.
  Future<void> saveOrder({
    required String moduleId,
    required List<String> order,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefKeyPrefix$moduleId', jsonEncode(order));

    final uid = _uid;
    if (uid == null || uid.isEmpty || !_isCloudAvailable) {
      return;
    }
    try {
      // Cheie cu punct ("status_order.$moduleId") = merge țintit doar pe
      // sub-câmpul modulului curent; nu suprascrie ordinea salvată pentru
      // celelalte module din același document.
      await _col.doc(uid).set(
        {
          'status_order.$moduleId': order,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        '[UserStatusOrderRepo] salvare cloud best-effort eșuată pentru '
        '"$moduleId" (ordinea locală rămâne persistă): $e',
      );
    }
  }

  /// Citește ordinea salvată pentru un modul. Întoarce `null` dacă userul nu
  /// a salvat încă nicio ordine — apelantul aplică fallback-ul implicit
  /// (vezi `resolveStatusOrder()` din `status_order_utils.dart`).
  Future<List<String>?> loadOrder(String moduleId) async {
    final uid = _uid;
    if (uid != null && uid.isNotEmpty && _isCloudAvailable) {
      try {
        final doc = await _col.doc(uid).get();
        if (doc.exists) {
          final statusOrderRaw = doc.data()?['status_order'];
          if (statusOrderRaw is Map && statusOrderRaw[moduleId] is List) {
            final order = (statusOrderRaw[moduleId] as List)
                .map((e) => e.toString())
                .toList(growable: false);
            // Sincronizează și local, ca fallback-ul offline să fie la zi.
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
                '$_prefKeyPrefix$moduleId', jsonEncode(order));
            return order;
          }
        }
      } catch (e) {
        debugPrint(
          '[UserStatusOrderRepo] citire cloud eșuată pentru "$moduleId", '
          'folosesc ordinea locală: $e',
        );
      }
    }

    // Fallback: local (offline sau eroare cloud).
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefKeyPrefix$moduleId');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
