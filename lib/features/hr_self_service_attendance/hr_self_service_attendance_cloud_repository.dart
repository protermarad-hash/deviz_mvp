import 'hr_self_service_attendance_models.dart';

abstract class HrSelfServiceAttendanceCloudRepository {
  Future<List<HrSelfServiceAttendanceSession>> listSessions();
  Future<void> upsertSession(HrSelfServiceAttendanceSession item);
}
