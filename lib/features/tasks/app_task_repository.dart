import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'app_task_models.dart';

class AppTaskRepository {
  AppTaskRepository._();
  static final AppTaskRepository instance = AppTaskRepository._();

  static const String _prefKey = 'app_tasks_local_v1';

  // ── Diagnostice statice ────────────────────────────────────────────────────
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(FirebaseCollections.appTasks);

  bool get _isCloudAvailable => FirebaseBootstrap.isInitialized;

  // ── Stocare locală ─────────────────────────────────────────────────────────

  Future<List<AppTask>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AppTask.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('[AppTask] _readLocal error: $e');
      return const [];
    }
  }

  Future<void> _saveLocal(List<AppTask> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(tasks.map((t) => t.toMap()).toList());
      await prefs.setString(_prefKey, encoded);
    } catch (e) {
      debugPrint('[AppTask] _saveLocal error: $e');
    }
  }

  Future<void> _updateLocalCache(AppTask task) async {
    final locals = await _readLocal();
    final idx = locals.indexWhere((t) => t.id == task.id);
    final updated = List<AppTask>.from(locals);
    if (idx >= 0) {
      updated[idx] = task;
    } else {
      updated.add(task);
    }
    await _saveLocal(updated);
  }

  Future<void> _removeFromLocalCache(String taskId) async {
    final locals = await _readLocal();
    await _saveLocal(locals.where((t) => t.id != taskId).toList());
  }

  // ── LIST ───────────────────────────────────────────────────────────────────

  /// Returnează taskurile pentru utilizatorul dat.
  /// admin poate vedea toate taskurile (userId gol = toate).
  Future<List<AppTask>> listTasks({
    String? userId,
    bool isAdmin = false,
  }) async {
    final localItems = await _readLocal();
    lastLocalCount = localItems.length;

    if (!_isCloudAvailable) {
      final result = isAdmin || userId == null
          ? localItems
          : localItems.where((t) => t.createdBy == userId).toList();
      return result;
    }

    try {
      lastFirestoreCount = -1;
      lastFirestoreError = null;

      Query<Map<String, dynamic>> query = _col;
      if (!isAdmin && userId != null && userId.isNotEmpty) {
        query = _col.where('created_by', isEqualTo: userId);
      }
      final snapshot = await query.get();
      final cloudItems = snapshot.docs
          .map((d) => AppTask.fromMap({...d.data(), 'id': d.id}))
          .toList();
      lastFirestoreCount = cloudItems.length;

      // Pending IDs — items cu modificări locale nesincronizate
      final allPendingIds = await _getPendingIds();
      final cloudIds = cloudItems.map((t) => t.id).toSet();
      final localById = {for (var t in localItems) t.id: t};

      // Preferă versiunea locală pentru items cu modificări pending
      final resolvedCloud = cloudItems.map((c) {
        if (allPendingIds.contains(c.id) && localById.containsKey(c.id)) {
          return localById[c.id]!;
        }
        return c;
      }).toList();

      // Items create local dar inexistente în cloud
      final localOnly = localItems
          .where((t) => !cloudIds.contains(t.id))
          .toList();
      for (final t in localOnly) {
        await OfflineSyncRuntime.instance.queueAppTaskUpsert(t.toMap());
      }

      final merged = [...resolvedCloud, ...localOnly];
      // Salvează merge-ul în cache local
      await _saveLocal(merged);
      return merged;
    } catch (e) {
      lastFirestoreError = e.toString();
      debugPrint('[AppTask] Firestore error: $e');
      final result = isAdmin || userId == null
          ? localItems
          : localItems.where((t) => t.createdBy == userId).toList();
      return result;
    }
  }

  Future<Set<String>> _getPendingIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cloud_sync_queue_v1');
      if (raw == null || raw.isEmpty) return {};
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .where((e) {
            final m = e as Map<String, dynamic>;
            return m['entityType'] == 'appTasks' && m['deleted'] != true;
          })
          .map((e) => (e as Map<String, dynamic>)['entityId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // ── SAVE ───────────────────────────────────────────────────────────────────

  Future<AppTask> saveTask(AppTask task) async {
    // 1. Local cache
    await _updateLocalCache(task);

    // 2. Queue (obligatoriu)
    await OfflineSyncRuntime.instance.queueAppTaskUpsert(task.toMap());

    // 3. Firebase fire-and-forget
    if (_isCloudAvailable) {
      final map = task.toMap()..remove('id');
      _col
          .doc(task.id)
          .set(map, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('[AppTask] Firebase save error: $e');
      });
    }
    return task;
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────

  Future<void> deleteTask(String taskId) async {
    // 1. Local cache
    await _removeFromLocalCache(taskId);

    // 2. Queue
    await OfflineSyncRuntime.instance.queueAppTaskDelete(taskId);

    // 3. Firebase fire-and-forget
    if (_isCloudAvailable) {
      _col.doc(taskId).delete().catchError((e) {
        debugPrint('[AppTask] Firebase delete error: $e');
      });
    }
  }

  // ── COMPLETE ───────────────────────────────────────────────────────────────

  Future<AppTask> completeTask(AppTask task) async {
    final completed = task.copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );
    return saveTask(completed);
  }

  Future<AppTask> uncompleteTask(AppTask task) async {
    final uncompleted = task.copyWith(
      completed: false,
      clearCompletedAt: true,
    );
    return saveTask(uncompleted);
  }

  // ── FORCE SYNC ────────────────────────────────────────────────────────────

  Future<int> forceSyncLocalToCloud() async {
    if (!_isCloudAvailable) return 0;
    final locals = await _readLocal();
    if (locals.isEmpty) return 0;
    int synced = 0;
    final result = List<AppTask>.from(locals);
    for (int i = 0; i < result.length; i++) {
      final t = result[i];
      try {
        if (t.id.startsWith('local-') || t.id.isEmpty) {
          final map = t.toMap()..remove('id');
          final ref = await _col.add(map);
          result[i] = AppTask.fromMap({...t.toMap(), 'id': ref.id});
          await OfflineSyncRuntime.instance
              .queueAppTaskUpsert(result[i].toMap());
        } else {
          final map = t.toMap()..remove('id');
          await _col.doc(t.id).set(map, SetOptions(merge: true));
          await OfflineSyncRuntime.instance.queueAppTaskUpsert(t.toMap());
        }
        synced++;
      } catch (e) {
        debugPrint('[AppTask] forceSyncLocalToCloud error for ${t.id}: $e');
      }
    }
    final seen = <String>{};
    final deduped =
        result.where((t) => seen.add(t.id)).toList(growable: false);
    await _saveLocal(deduped);
    return synced;
  }
}
