import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'scule_models.dart';

class LocalSculeStore {
  static const String _toolsKey = 'ultra_tools_inventory_v1';
  static const String _handoverDocsKey = 'ultra_tools_handover_docs_v1';
  static const String _movementEventsKey = 'ultra_tools_movement_events_v1';
  static const String _toolCategoriesKey = 'ultra_tools_categories_v1';
  static const String _transferRequestsKey = 'ultra_tools_transfer_requests_v1';
  static const String _transferNotificationsKey =
      'ultra_tools_transfer_notifications_v1';

  static const List<String> _defaultToolCategories = <String>[
    'Electric',
    'Mecanic',
    'Masurare',
    'Protectie',
    'Consumabile',
  ];

  Future<List<ToolInventoryItem>> listTools() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_toolsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolInventoryItem>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolInventoryItem>[];
    }
    return decoded
        .whereType<Map>()
        .map((row) => ToolInventoryItem.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveTools(List<ToolInventoryItem> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _toolsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<ToolHandoverDocument>> listHandoverDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_handoverDocsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolHandoverDocument>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolHandoverDocument>[];
    }
    return decoded
        .whereType<Map>()
        .map((row) =>
            ToolHandoverDocument.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.documentDate.compareTo(a.documentDate));
  }

  Future<void> saveHandoverDocuments(List<ToolHandoverDocument> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _handoverDocsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<ToolMovementEvent>> listMovementEvents(String toolId) async {
    final target = toolId.trim();
    if (target.isEmpty) return const <ToolMovementEvent>[];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementEventsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolMovementEvent>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolMovementEvent>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map((row) => ToolMovementEvent.fromMap(Map<String, dynamic>.from(row)))
        .where((item) => item.id.trim().isNotEmpty && item.toolId == target)
        .toList(growable: false);
    rows.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return rows;
  }

  Future<void> appendMovementEvent(ToolMovementEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_movementEventsKey);
    final existing = <ToolMovementEvent>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        existing.addAll(
          decoded
              .whereType<Map>()
              .map(
                (row) => ToolMovementEvent.fromMap(
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

  Future<List<String>> listToolCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_toolCategoriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return _defaultToolCategories;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return _defaultToolCategories;
    }
    final values = decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values.isEmpty ? _defaultToolCategories : values;
  }

  Future<void> saveToolCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final values = categories
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (values.isEmpty) {
      values.addAll(_defaultToolCategories);
    }
    await prefs.setString(_toolCategoriesKey, jsonEncode(values));
  }

  Future<List<ToolTransferRequest>> listTransferRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transferRequestsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolTransferRequest>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolTransferRequest>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) => ToolTransferRequest.fromMap(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> saveTransferRequests(List<ToolTransferRequest> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _transferRequestsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }

  Future<List<ToolTransferNotification>> listTransferNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transferNotificationsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolTransferNotification>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <ToolTransferNotification>[];
    }
    final rows = decoded
        .whereType<Map>()
        .map(
          (row) =>
              ToolTransferNotification.fromMap(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> saveTransferNotifications(
    List<ToolTransferNotification> rows,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _transferNotificationsKey,
      jsonEncode(rows.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
