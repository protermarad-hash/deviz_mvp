import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_hr_leave_repository.dart';
import 'hr_leave_cloud_repository.dart';
import 'hr_leave_models.dart';
import 'hr_leave_resolver.dart';
import 'local_hr_leave_store.dart';

class HrLeaveCatalogService {
  HrLeaveCatalogService({
    HrLeaveCloudRepository? cloudRepository,
    LocalHrLeaveStore? localStore,
    HrLeaveResolver? resolver,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrLeaveRepository()
                : null),
        _localStore = localStore ?? LocalHrLeaveStore(),
        _resolver = resolver ?? const HrLeaveResolver();

  final HrLeaveCloudRepository? _cloudRepository;
  final LocalHrLeaveStore _localStore;
  final HrLeaveResolver _resolver;

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

  Future<List<HrLeaveType>> listLeaveTypes() async {
    final localRows = await _localStore.listLeaveTypes();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listLeaveTypes();
      await _localStore.saveLeaveTypes(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrLeaveRequest>> listLeaveRequests() async {
    final localRows = await _localStore.listLeaveRequests();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listLeaveRequests();
      await _localStore.saveLeaveRequests(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<void> upsertLeaveType(HrLeaveType item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertLeaveType(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listLeaveTypes()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveLeaveTypes(local);
  }

  Future<void> upsertLeaveRequest(HrLeaveRequest item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertLeaveRequest(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listLeaveRequests()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveLeaveRequests(local);
  }

  Future<List<HrLeaveRequest>> activeLeavesForEmployee(
      String employeeId) async {
    final rows = await listLeaveRequests();
    return _resolver.activeLeavesForEmployee(rows, employeeId);
  }

  Future<List<HrLeaveRequest>> approvedLeavesForEmployee(
    String employeeId,
  ) async {
    final rows = await listLeaveRequests();
    return _resolver.approvedLeavesForEmployee(rows, employeeId);
  }

  Future<List<HrLeaveRequest>> requestsInInterval({
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final rows = await listLeaveRequests();
    return _resolver.requestsInInterval(
      rows: rows,
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  Future<HrLeaveIntervalSummary> summarizeInterval({
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final rows = await listLeaveRequests();
    return _resolver.summarizeInterval(
      rows: rows,
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  Future<HrLeaveIntervalSummary> summarizeApprovedInterval({
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final rows = await listLeaveRequests();
    return _resolver.summarizeApprovedInterval(
      rows: rows,
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  Future<void> submitLeaveRequest({
    required String requestId,
    String submittedByUserId = '',
  }) async {
    final item = await _findById(requestId);
    if (item == null) return;
    final now = DateTime.now();
    await upsertLeaveRequest(
      item.copyWith(
        status: 'submitted',
        submittedAt: now,
        submittedByUserId: submittedByUserId,
        clearApprovedAt: true,
        approvedByUserId: '',
        clearReviewedAt: true,
        reviewedByUserId: '',
        reviewNotes: '',
        updatedAt: now,
      ),
    );
  }

  Future<void> approveLeaveRequest({
    required String requestId,
    String approvedByUserId = '',
  }) async {
    final item = await _findById(requestId);
    if (item == null) return;
    final now = DateTime.now();
    await upsertLeaveRequest(
      item.copyWith(
        status: 'approved',
        approvedAt: now,
        approvedByUserId: approvedByUserId,
        clearReviewedAt: true,
        reviewedByUserId: '',
        reviewNotes: '',
        updatedAt: now,
      ),
    );
  }

  Future<void> markLeaveRequestNeedsReview({
    required String requestId,
    String reviewedByUserId = '',
    String reviewNotes = '',
  }) async {
    final item = await _findById(requestId);
    if (item == null) return;
    final now = DateTime.now();
    await upsertLeaveRequest(
      item.copyWith(
        status: 'needs_review',
        reviewedAt: now,
        reviewedByUserId: reviewedByUserId,
        reviewNotes: reviewNotes,
        clearApprovedAt: true,
        approvedByUserId: '',
        updatedAt: now,
      ),
    );
  }

  Future<void> rejectLeaveRequest({
    required String requestId,
    String reviewedByUserId = '',
    String reviewNotes = '',
  }) async {
    final item = await _findById(requestId);
    if (item == null) return;
    final now = DateTime.now();
    await upsertLeaveRequest(
      item.copyWith(
        status: 'rejected',
        reviewedAt: now,
        reviewedByUserId: reviewedByUserId,
        reviewNotes: reviewNotes,
        clearApprovedAt: true,
        approvedByUserId: '',
        updatedAt: now,
      ),
    );
  }

  Future<bool> hasOverlap(HrLeaveRequest request) async {
    final rows = await listLeaveRequests();
    return _resolver.hasOverlap(rows: rows, request: request);
  }

  Future<List<HrLeaveRequest>> findOverlaps(HrLeaveRequest request) async {
    final rows = await listLeaveRequests();
    return _resolver.findOverlaps(rows: rows, request: request);
  }

  Future<HrLeaveRequest?> _findById(String requestId) async {
    final target = requestId.trim();
    if (target.isEmpty) return null;
    final rows = await listLeaveRequests();
    for (final row in rows) {
      if (row.id.trim() == target) return row;
    }
    return null;
  }
}
