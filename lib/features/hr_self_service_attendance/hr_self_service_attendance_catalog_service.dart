import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_hr_self_service_attendance_repository.dart';
import 'hr_self_service_attendance_cloud_repository.dart';
import 'hr_self_service_attendance_models.dart';
import 'local_hr_self_service_attendance_store.dart';

class HrSelfServiceAttendanceCatalogService {
  HrSelfServiceAttendanceCatalogService({
    HrSelfServiceAttendanceCloudRepository? cloudRepository,
    LocalHrSelfServiceAttendanceStore? localStore,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrSelfServiceAttendanceRepository()
                : null),
        _localStore = localStore ?? LocalHrSelfServiceAttendanceStore();

  final HrSelfServiceAttendanceCloudRepository? _cloudRepository;
  final LocalHrSelfServiceAttendanceStore _localStore;

  String dataSourceLabel = 'cloud';
  String? fallbackReason;

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  void _markCloudPrimary() {
    dataSourceLabel = 'cloud';
    fallbackReason = null;
  }

  void _markLocalFallback(String reason) {
    dataSourceLabel = 'local_cache';
    fallbackReason = reason;
  }

  Future<List<HrSelfServiceAttendanceSession>> listSessions() async {
    final localRows = await _localStore.listSessions();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listSessions();
      await _localStore.saveSessions(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<void> upsertSession(HrSelfServiceAttendanceSession item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertSession(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listSessions()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveSessions(local);
  }

  Future<List<HrSelfServiceAttendanceSession>> listSessionsForEmployee(
    String employeeId,
  ) async {
    final rows = await listSessions();
    final target = employeeId.trim();
    return rows
        .where((item) => item.employeeId.trim() == target)
        .toList(growable: false)
      ..sort((a, b) => b.checkInAt.compareTo(a.checkInAt));
  }

  Future<HrSelfServiceAttendanceSession?> findOpenSession(
    String employeeId,
  ) async {
    final rows = await listSessionsForEmployee(employeeId);
    for (final item in rows) {
      if (item.isOpen) return item;
    }
    return null;
  }

  Future<HrSelfServiceAttendanceSession> checkIn({
    required String employeeId,
    required String hrEmployeeProfileId,
    required String userId,
    required DateTime at,
    String locationType = 'sediu',
    String jobId = '',
    String appointmentId = '',
    String notes = '',
  }) async {
    final existingOpen = await findOpenSession(employeeId);
    if (existingOpen != null) {
      return existingOpen;
    }
    final date = DateTime(at.year, at.month, at.day);
    final record = HrSelfServiceAttendanceSession(
      id: 'hr-self-attendance-${employeeId.trim()}-${at.millisecondsSinceEpoch}',
      employeeId: employeeId.trim(),
      hrEmployeeProfileId: hrEmployeeProfileId.trim(),
      userId: userId.trim(),
      date: date,
      checkInAt: at,
      checkOutAt: null,
      breakStartAt: null,
      breakEndAt: null,
      locationType: locationType.trim().isEmpty ? 'sediu' : locationType.trim(),
      jobId: jobId.trim(),
      appointmentId: appointmentId.trim(),
      notes: notes.trim(),
      status: 'open',
      createdAt: at,
      updatedAt: at,
    );
    await upsertSession(record);
    return record;
  }

  Future<HrSelfServiceAttendanceSession?> checkOut({
    required String employeeId,
    required DateTime at,
    String notes = '',
  }) async {
    final existingOpen = await findOpenSession(employeeId);
    if (existingOpen == null) return null;
    final updated = existingOpen.copyWith(
      checkOutAt: at,
      notes: notes.trim().isEmpty ? existingOpen.notes : notes.trim(),
      status: 'closed',
      updatedAt: at,
    );
    await upsertSession(updated);
    return updated;
  }

  Future<HrSelfServiceAttendanceSession?> startBreak({
    required String employeeId,
    required DateTime at,
  }) async {
    final existingOpen = await findOpenSession(employeeId);
    if (existingOpen == null || existingOpen.hasOpenBreak) return existingOpen;
    final updated = existingOpen.copyWith(
      breakStartAt: at,
      clearBreakEndAt: true,
      updatedAt: at,
    );
    await upsertSession(updated);
    return updated;
  }

  Future<HrSelfServiceAttendanceSession?> endBreak({
    required String employeeId,
    required DateTime at,
  }) async {
    final existingOpen = await findOpenSession(employeeId);
    if (existingOpen == null || !existingOpen.hasOpenBreak) return existingOpen;
    final updated = existingOpen.copyWith(
      breakEndAt: at,
      updatedAt: at,
    );
    await upsertSession(updated);
    return updated;
  }
}
