import 'hr_leave_models.dart';

abstract class HrLeaveCloudRepository {
  Future<List<HrLeaveType>> listLeaveTypes();
  Future<List<HrLeaveRequest>> listLeaveRequests();
  Future<void> upsertLeaveType(HrLeaveType item);
  Future<void> upsertLeaveRequest(HrLeaveRequest item);
}
