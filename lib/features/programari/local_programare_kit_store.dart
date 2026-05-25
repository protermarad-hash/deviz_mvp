import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'programare_kit_models.dart';

class LocalProgramareKitStore {
  static const String _templatesKey = 'appointment_material_kit_templates_v1';

  Future<List<AppointmentMaterialKitTemplate>> listTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templatesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <AppointmentMaterialKitTemplate>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AppointmentMaterialKitTemplate>[];
      }
      return decoded
          .map((item) {
            if (item is Map<String, dynamic>) {
              return AppointmentMaterialKitTemplate.fromMap(item);
            }
            if (item is Map) {
              return AppointmentMaterialKitTemplate.fromMap(
                Map<String, dynamic>.from(item),
              );
            }
            return null;
          })
          .whereType<AppointmentMaterialKitTemplate>()
          .toList(growable: false);
    } catch (_) {
      return const <AppointmentMaterialKitTemplate>[];
    }
  }

  Future<void> saveTemplates(List<AppointmentMaterialKitTemplate> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _templatesKey,
      jsonEncode(items.map((item) => item.toMap()).toList(growable: false)),
    );
  }
}
