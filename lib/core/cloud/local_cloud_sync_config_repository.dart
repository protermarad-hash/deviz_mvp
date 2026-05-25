import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_config.dart';

class LocalCloudSyncConfigRepository {
  static const _key = 'cloud_sync_config_v1';

  Future<CloudSyncConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const CloudSyncConfig();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const CloudSyncConfig();
    return CloudSyncConfig.fromMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> save(CloudSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toMap()));
  }
}

