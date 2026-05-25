import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'deviz_articol_template_models.dart';

class DevizArticolTemplateRepository {
  static const String _localKey = 'deviz_articole_template_v1';

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.devizArticoleTemplate);

  // ── Composite upsert/delete (CLAUDE.md: local → queue → Firebase fire-and-forget) ──

  Future<void> upsert(DevizArticolTemplate template) async {
    await upsertLocal(template);
    unawaited(OfflineSyncRuntime.instance
        .queueDevizArticolTemplateUpsert(template.toMap()));
    if (_isCloudAvailable) {
      _col.doc(template.id)
          .set(template.toMap(), SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  Future<void> delete(String id) async {
    await deleteLocal(id);
    unawaited(OfflineSyncRuntime.instance.queueDevizArticolTemplateDelete(id));
    if (_isCloudAvailable) {
      _col.doc(id).delete().catchError((_) {});
    }
  }

  // ── Local ─────────────────────────────────────────────────────────────────

  Future<List<DevizArticolTemplate>> listLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) =>
              DevizArticolTemplate.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertLocal(DevizArticolTemplate template) async {
    final current = await listLocal();
    final next = <DevizArticolTemplate>[];
    var found = false;
    for (final item in current) {
      if (item.id == template.id) {
        next.add(template);
        found = true;
      } else {
        next.add(item);
      }
    }
    if (!found) next.add(template);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(next.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> deleteLocal(String id) async {
    final current = await listLocal();
    final next =
        current.where((t) => t.id != id).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(next.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> replaceAll(List<DevizArticolTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(templates.map((t) => t.toMap()).toList()),
    );
  }

  // ── Firebase ───────────────────────────────────────────────────────────────

  Future<List<DevizArticolTemplate>> listFromFirebase() async {
    final snap = await FirebaseFirestore.instance
        .collection(FirebaseCollections.devizArticoleTemplate)
        .get();
    return snap.docs
        .map((doc) => DevizArticolTemplate.fromMap(
            Map<String, dynamic>.from(doc.data())))
        .toList(growable: false);
  }

  Future<void> upsertToFirebase(DevizArticolTemplate template) async {
    await FirebaseFirestore.instance
        .collection(FirebaseCollections.devizArticoleTemplate)
        .doc(template.id)
        .set(template.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteFromFirebase(String id) async {
    await FirebaseFirestore.instance
        .collection(FirebaseCollections.devizArticoleTemplate)
        .doc(id)
        .delete();
  }

  // ── Statics diagnostice (CLAUDE.md CHECKLIST) ─────────────────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  // ── Sync forțat: publică toate documentele locale în Firestore ─────────────
  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await listLocal();
    if (locals.isEmpty) return 0;
    int synced = 0;
    for (final t in locals) {
      try {
        await _col.doc(t.id).set(t.toMap(), SetOptions(merge: true));
        unawaited(OfflineSyncRuntime.instance.queueDevizArticolTemplateUpsert(t.toMap()));
        synced++;
      } catch (e) {
        lastFirestoreError = e.toString();
      }
    }
    return synced;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Caută template după denumire exactă (case-insensitive).
  DevizArticolTemplate? findByName(
    String name,
    List<DevizArticolTemplate> templates,
  ) {
    final normalized = name.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final t in templates) {
      if (t.denumireNormalizata == normalized) return t;
    }
    return null;
  }

  /// Caută template-uri care conțin query (pentru management page).
  List<DevizArticolTemplate> searchTemplates(
    String query,
    List<DevizArticolTemplate> templates,
  ) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return templates;
    return templates
        .where((t) =>
            t.denumireNormalizata.contains(q) ||
            t.um.toUpperCase().contains(q))
        .toList(growable: false);
  }
}
