import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/repositories/app_data_repository.dart';
import 'appointment_models.dart';
import 'programare_kit_models.dart';

class KitPropagationResult {
  final int updatedCount;
  final int skippedCount;
  final List<String> updatedAppointmentIds;

  const KitPropagationResult({
    required this.updatedCount,
    required this.skippedCount,
    required this.updatedAppointmentIds,
  });
}

/// Propagă modificările unui kit în toate programările locale care îl folosesc.
///
/// Când un kit se modifică (componente, prețuri, nume), liniile din programările
/// existente trebuie actualizate pentru a reflecta noua rețetă.
/// linearMetersUsed din programare se PĂSTREAZĂ — se recalculează doar cantitățile.
class KitPropagationService {
  static final KitPropagationService instance = KitPropagationService._();
  KitPropagationService._();

  static const String _appointmentsKey = 'ultra_appointments_v1';

  // Guard împotriva rulărilor simultane
  bool _running = false;

  Future<KitPropagationResult> propagateKitChanges(
    AppointmentMaterialKitTemplate updatedKit,
    AppDataRepository repository,
  ) async {
    if (_running) {
      debugPrint('[KitPropagation] Deja în rulare — skip');
      return const KitPropagationResult(
        updatedCount: 0,
        skippedCount: 0,
        updatedAppointmentIds: [],
      );
    }
    _running = true;
    try {
      return await _run(updatedKit, repository);
    } finally {
      _running = false;
    }
  }

  Future<KitPropagationResult> _run(
    AppointmentMaterialKitTemplate updatedKit,
    AppDataRepository repository,
  ) async {
    final allAppointments = await _loadAllLocalAppointments();

    final affected = allAppointments
        .where((appt) =>
            appt.materialUsage.kitTemplateId.trim() == updatedKit.id.trim())
        .toList(growable: false);

    if (affected.isEmpty) {
      return const KitPropagationResult(
        updatedCount: 0,
        skippedCount: 0,
        updatedAppointmentIds: [],
      );
    }

    int updated = 0;
    int skipped = 0;
    final updatedIds = <String>[];

    for (final appt in affected) {
      try {
        // Păstrează linearMetersUsed din programare — recalculează doar cantitățile
        final linearMeters = appt.materialUsage.linearMetersUsed;

        final newLines = updatedKit.components.map((component) {
          final resolvedQty = component.resolvedQuantity(linearMeters);
          return AppointmentMaterialUsageLine(
            id: component.id,
            materialId: component.materialId,
            name: component.name,
            unit: component.unit,
            quantity: resolvedQty,
            unitCost: component.unitCost,
            isVariableLength: component.isVariableLength,
            quantityPerLinearMeter: component.quantityPerLinearMeter,
          );
        }).toList(growable: false);

        final updatedUsage = appt.materialUsage.copyWith(
          kitTemplateName: updatedKit.name,
          lines: newLines,
        );
        final updatedAppt = appt.copyWith(materialUsage: updatedUsage);

        // Pattern standard: local → queue → Firebase fire-and-forget
        await repository.saveAppointment(updatedAppt);

        updatedIds.add(appt.id);
        updated++;
        debugPrint(
            '[KitPropagation] Actualizat programare ${appt.id} (${newLines.length} linii)');
      } catch (e) {
        debugPrint('[KitPropagation] Skip programare ${appt.id}: $e');
        skipped++;
      }
    }

    debugPrint(
        '[KitPropagation] Terminat: updated=$updated skipped=$skipped kitId=${updatedKit.id}');
    return KitPropagationResult(
      updatedCount: updated,
      skippedCount: skipped,
      updatedAppointmentIds: updatedIds,
    );
  }

  /// Citește TOATE programările din SharedPreferences (același mecanism ca
  /// LocalAppDataRepository._readLocalAppointmentsOnly, fără cache în memorie).
  /// NU face query Firebase.
  Future<List<Appointment>> loadAllLocalAppointments() =>
      _loadAllLocalAppointments();

  Future<List<Appointment>> _loadAllLocalAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Appointment.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[KitPropagation] Eroare citire programări locale: $e');
      return const [];
    }
  }

  /// Returnează numărul de programări care folosesc kitul dat (local only).
  Future<int> countAffectedAppointments(String kitTemplateId) async {
    final all = await _loadAllLocalAppointments();
    return all
        .where((a) =>
            a.materialUsage.kitTemplateId.trim() == kitTemplateId.trim())
        .length;
  }
}
