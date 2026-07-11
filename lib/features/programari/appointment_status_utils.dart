import 'appointment_models.dart';

String normalizeAppointmentStatus(String? raw) {
  final value = (raw ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ș', 's')
      .replaceAll('ş', 's')
      .replaceAll('ț', 't')
      .replaceAll('ţ', 't')
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  switch (value) {
    case 'planificata':
    case 'planned':
    case 'noua':
      return 'planificata';
    case 'in_curs':
    case 'incurs':
    case 'in_progress':
      return 'in_curs';
    case 'finalizata':
    case 'done':
    case 'completed':
      return 'finalizata';
    case 'amanata':
    case 'postponed':
      return 'amanata';
    case 'anulata':
    case 'canceled':
    case 'cancelled':
      return 'anulata';
    default:
      return 'planificata';
  }
}

bool isCompletedAppointmentStatus(String? raw) =>
    normalizeAppointmentStatus(raw) == 'finalizata';

bool isAppointmentEligibleForEmployeePay(Appointment appointment) =>
    isCompletedAppointmentStatus(appointment.status);
