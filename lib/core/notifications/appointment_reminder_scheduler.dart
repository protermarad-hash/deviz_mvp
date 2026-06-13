import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/notification_runtime_service.dart';

/// Scheduler reminder-uri programări.
/// Apelat la login și după fiecare sync pentru a trimite notificări
/// despre programările de mâine în care utilizatorul curent este implicat.
class AppointmentReminderScheduler {
  AppointmentReminderScheduler._();
  static final AppointmentReminderScheduler instance =
      AppointmentReminderScheduler._();

  static const String _appointmentsKey = 'ultra_appointments_v1';

  Future<void> scheduleRemindersForTomorrow() async {
    try {
      final currentUserId =
          (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
      if (currentUserId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tStart =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final tEnd = tStart.add(const Duration(days: 1));

      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);

        // Verifică dacă utilizatorul curent este implicat
        final employeeIds =
            (map['employee_ids'] as List? ?? <dynamic>[]).cast<String>();
        final assignedUserId = (map['assigned_user_id'] ?? '').toString();
        final assignedEmail =
            (map['assigned_user_email'] ?? '').toString().toLowerCase();
        final currentEmail =
            FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

        final isInvolved = employeeIds.contains(currentUserId) ||
            assignedUserId == currentUserId ||
            (assignedEmail.isNotEmpty &&
                currentEmail.isNotEmpty &&
                assignedEmail == currentEmail);
        if (!isInvolved) continue;

        // Verifică că programarea e mâine
        final startRaw = map['start_time'] ?? map['startTime'] ?? '';
        final startDt = DateTime.tryParse(startRaw.toString());
        if (startDt == null) continue;
        if (startDt.isBefore(tStart) || startDt.isAfter(tEnd)) continue;

        final titlu = (map['titlu'] ?? map['title'] ?? 'Programare')
            .toString()
            .trim();
        final beneficiar =
            (map['beneficiar'] ?? map['client_name'] ?? '').toString().trim();
        final ora =
            '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}';
        final id = (map['id'] ?? '').toString();

        await NotificationRuntimeService.instance.showReminderProgramare(
          titlu: titlu,
          beneficiar: beneficiar,
          ora: ora,
          tehnician: FirebaseAuth.instance.currentUser?.displayName ?? '',
          appointmentId: id,
        );
      }
    } catch (e) {
      debugPrint('[ReminderScheduler] ❌ $e');
    }
  }

  /// Apelat când un tehnician finalizează o programare.
  Future<void> notifyFinalizare({
    required String titlu,
    required String appointmentId,
  }) async {
    try {
      await NotificationRuntimeService.instance.showProgramareFinalizata(
        titlu: titlu,
        tehnician:
            FirebaseAuth.instance.currentUser?.displayName ?? 'Tehnician',
        appointmentId: appointmentId,
      );
    } catch (e) {
      debugPrint('[ReminderScheduler] ❌ notifyFinalizare: $e');
    }
  }
}
