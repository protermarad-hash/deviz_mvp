import 'hr_attendance_models.dart';

abstract class HrAttendanceCloudRepository {
  Future<List<HrAttendanceEntry>> listEntries();
  Future<void> upsertEntry(HrAttendanceEntry item);
}
