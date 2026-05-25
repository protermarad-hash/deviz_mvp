import 'appointment_models.dart';

abstract class ProgramariCloudRepository {
  Future<List<Appointment>> listAppointments();
  Stream<List<Appointment>> watchAppointments();
  Future<void> upsertAppointment(Appointment appointment);
  Future<void> deleteAppointment(String appointmentId);
}

