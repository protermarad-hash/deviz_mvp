import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'company_cost_profile_models.dart';

class CompanyCostProfileService {
  static const String _storageKey = 'company_cost_profile_v1';
  static const String _defaultDocId = 'default';

  String dataSourceLabel = 'local_cache';
  String? fallbackReason;

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) {
      return 'necunoscuta';
    }
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  void _markCloudPrimary() {
    dataSourceLabel = 'cloud';
    fallbackReason = null;
  }

  void _markLocalFallback(String? reason) {
    dataSourceLabel = 'local_cache';
    final normalized = (reason ?? '').trim();
    fallbackReason = normalized.isEmpty ? null : normalized;
  }

  Future<CompanyCostProfile> load() async {
    final local = await _readLocal();
    if (!FirebaseBootstrap.isInitialized) {
      _markLocalFallback(FirebaseBootstrap.lastErrorMessage);
      return local;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirebaseCollections.companyCostProfiles)
          .doc(_defaultDocId)
          .get();
      if (!snapshot.exists || snapshot.data() == null) {
        _markCloudPrimary();
        await _writeLocal(local);
        return local;
      }
      final cloudProfile = CompanyCostProfile.fromMap(snapshot.data()!);
      _markCloudPrimary();
      await _writeLocal(cloudProfile);
      return cloudProfile;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(_shortCloudError(error));
      return local;
    }
  }

  Future<void> save(CompanyCostProfile profile) async {
    final normalized = profile.copyWith(updatedAt: DateTime.now());
    if (FirebaseBootstrap.isInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection(FirebaseCollections.companyCostProfiles)
            .doc(_defaultDocId)
            .set(normalized.toMap(), SetOptions(merge: true));
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(_shortCloudError(error));
      }
    } else {
      _markLocalFallback(FirebaseBootstrap.lastErrorMessage);
    }
    await _writeLocal(normalized);
  }

  Future<CompanyCostProfile> _readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const CompanyCostProfile();
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return CompanyCostProfile.fromMap(decoded);
    }
    if (decoded is Map) {
      return CompanyCostProfile.fromMap(Map<String, dynamic>.from(decoded));
    }
    return const CompanyCostProfile();
  }

  Future<void> _writeLocal(CompanyCostProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(profile.toMap()));
  }
}
