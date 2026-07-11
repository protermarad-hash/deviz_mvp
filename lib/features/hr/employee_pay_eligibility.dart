import '../programari/appointment_models.dart';
import '../programari/appointment_status_utils.dart';
import 'employee_financial_models.dart';

List<EmployeePayEntry> filterPayEntriesForCompletedAppointments(
  Iterable<EmployeePayEntry> entries,
  Iterable<Appointment> appointments,
) {
  final completedAppointmentIds = appointments
      .where(isAppointmentEligibleForEmployeePay)
      .map((appointment) => appointment.id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  return entries.where((entry) {
    final appointmentId = entry.appointmentId.trim();
    return appointmentId.isNotEmpty &&
        completedAppointmentIds.contains(appointmentId);
  }).toList(growable: false);
}

Map<String, double> calculateDueByEmployeeForCompletedAppointments(
  Iterable<EmployeePayEntry> entries,
  Iterable<Appointment> appointments,
) {
  final dueByEmployee = <String, double>{};
  for (final entry in filterPayEntriesForCompletedAppointments(
    entries,
    appointments,
  )) {
    dueByEmployee[entry.employeeId] =
        (dueByEmployee[entry.employeeId] ?? 0) + entry.amountDue;
  }
  return dueByEmployee;
}
