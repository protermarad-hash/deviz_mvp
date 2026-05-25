import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pachete_scule_models.dart';

class LocalPacheteSculeStore {
  static const String _packagesKey = 'ultra_tool_packages_v1';
  static const String _legacyLookupKey = 'pachete_scule_v1';
  static const String _handoverDocsKey = 'ultra_tool_packages_handover_docs_v1';
  static const String _movementEventsKey = 'ultra_tool_packages_movement_v1';
  static const String _notificationsKey = 'ultra_tool_packages_notifications_v1';

  Future<List<ToolPackageRecord>> listPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_packagesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolPackageRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolPackageRecord>[];
    }
    return decoded
        .whereType<Map>()
        .map((row) => ToolPackageRecord.fromMap(Map<String, dynamic>.from(row)))
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> savePackages(List<ToolPackageRecord> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        rows.map((item) => item.toMap()).toList(growable: false);
    final encoded = jsonEncode(payload);
    await prefs.setString(_packagesKey, encoded);

    final legacyPayload = rows
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'name': item.name,
            'notes': item.notes,
            'tool_ids': item.toolIds,
            'tool_inventory_codes': item.toolInventoryCodes,
            'status': item.status.value,
            'assigned_team_id': item.assignedTeamId,
            'assigned_team_name': item.assignedTeamName,
            'assigned_at': item.assignedAt?.toIso8601String() ?? '',
          },
        )
        .toList(growable: false);
    await prefs.setString(_legacyLookupKey, jsonEncode(legacyPayload));
  }

  Future<List<ToolPackageHandoverDocument>> listHandoverDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_handoverDocsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolPackageHandoverDocument>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolPackageHandoverDocument>[];
    }
    return decoded
        .whereType<Map>()
        .map(
          (row) => ToolPackageHandoverDocument.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((row) => row.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
  }

  Future<void> saveHandoverDocuments(List<ToolPackageHandoverDocument> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _handoverDocsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<ToolPackageMovementEvent>> listMovementEvents(String packageId) async {
    final target = packageId.trim();
    if (target.isEmpty) return const <ToolPackageMovementEvent>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementEventsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolPackageMovementEvent>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolPackageMovementEvent>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => ToolPackageMovementEvent.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty && item.packageId == target)
        .toList(growable: false);
    rows.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return rows;
  }

  Future<void> appendMovementEvent(ToolPackageMovementEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementEventsKey);
    final existing = <ToolPackageMovementEvent>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        existing.addAll(
          decoded
              .whereType<Map>()
              .map(
                (row) => ToolPackageMovementEvent.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .where((item) => item.id.trim().isNotEmpty),
        );
      }
    }
    final index = existing.indexWhere((row) => row.id == event.id);
    if (index >= 0) {
      existing[index] = event;
    } else {
      existing.add(event);
    }
    await prefs.setString(
      _movementEventsKey,
      jsonEncode(existing.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<ToolPackageNotification>> listNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolPackageNotification>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolPackageNotification>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => ToolPackageNotification.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> saveNotifications(List<ToolPackageNotification> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
