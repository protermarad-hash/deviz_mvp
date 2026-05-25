import 'hr_leave_models.dart';

class HrLeaveResolver {
  const HrLeaveResolver();

  List<HrLeaveRequest> activeLeavesForEmployee(
    List<HrLeaveRequest> rows,
    String employeeId,
  ) {
    return rows
        .where(
          (item) =>
              item.employeeId.trim() == employeeId.trim() && item.isActive,
        )
        .toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<HrLeaveRequest> approvedLeavesForEmployee(
    List<HrLeaveRequest> rows,
    String employeeId,
  ) {
    return rows
        .where(
          (item) =>
              item.employeeId.trim() == employeeId.trim() && item.isApproved,
        )
        .toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<HrLeaveRequest> requestsInInterval({
    required List<HrLeaveRequest> rows,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return rows
        .where(
          (item) =>
              item.employeeId.trim() == employeeId.trim() &&
              item.isActive &&
              item.overlaps(dateFrom, dateTo),
        )
        .toList(growable: false)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<HrLeaveRequest> approvedRequestsInInterval({
    required List<HrLeaveRequest> rows,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return rows
        .where(
          (item) =>
              item.employeeId.trim() == employeeId.trim() &&
              item.isApproved &&
              item.overlaps(dateFrom, dateTo),
        )
        .toList(growable: false)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  HrLeaveIntervalSummary summarizeInterval({
    required List<HrLeaveRequest> rows,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    final requests = requestsInInterval(
      rows: rows,
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final calendarByType = <String, double>{};
    final workingByType = <String, double>{};
    for (final item in requests) {
      calendarByType[item.leaveTypeCode] =
          (calendarByType[item.leaveTypeCode] ?? 0) + item.calendarDays;
      workingByType[item.leaveTypeCode] =
          (workingByType[item.leaveTypeCode] ?? 0) + item.workingDays;
    }
    return HrLeaveIntervalSummary(
      employeeId: employeeId.trim(),
      dateFrom: DateTime(dateFrom.year, dateFrom.month, dateFrom.day),
      dateTo: DateTime(dateTo.year, dateTo.month, dateTo.day),
      requests: _dedupeRequests(requests),
      totalCalendarDays:
          requests.fold<double>(0, (sum, item) => sum + item.calendarDays),
      totalWorkingDays:
          requests.fold<double>(0, (sum, item) => sum + item.workingDays),
      calendarDaysByType: calendarByType,
      workingDaysByType: workingByType,
    );
  }

  HrLeaveIntervalSummary summarizeApprovedInterval({
    required List<HrLeaveRequest> rows,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    final requests = approvedRequestsInInterval(
      rows: rows,
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final calendarByType = <String, double>{};
    final workingByType = <String, double>{};
    for (final item in requests) {
      calendarByType[item.leaveTypeCode] =
          (calendarByType[item.leaveTypeCode] ?? 0) + item.calendarDays;
      workingByType[item.leaveTypeCode] =
          (workingByType[item.leaveTypeCode] ?? 0) + item.workingDays;
    }
    return HrLeaveIntervalSummary(
      employeeId: employeeId.trim(),
      dateFrom: DateTime(dateFrom.year, dateFrom.month, dateFrom.day),
      dateTo: DateTime(dateTo.year, dateTo.month, dateTo.day),
      requests: _dedupeRequests(requests),
      totalCalendarDays:
          requests.fold<double>(0, (sum, item) => sum + item.calendarDays),
      totalWorkingDays:
          requests.fold<double>(0, (sum, item) => sum + item.workingDays),
      calendarDaysByType: calendarByType,
      workingDaysByType: workingByType,
    );
  }

  List<HrLeaveRequest> findOverlaps({
    required List<HrLeaveRequest> rows,
    required HrLeaveRequest request,
  }) {
    return rows
        .where((item) => item.id != request.id)
        .where(
          (item) =>
              item.employeeId.trim() == request.employeeId.trim() &&
              item.isActive &&
              request.isActive &&
              item.overlaps(request.startDateOnly, request.endDateOnly),
        )
        .toList(growable: false)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  bool hasOverlap({
    required List<HrLeaveRequest> rows,
    required HrLeaveRequest request,
  }) {
    return findOverlaps(rows: rows, request: request).isNotEmpty;
  }

  List<HrLeaveRequest> _dedupeRequests(List<HrLeaveRequest> rows) {
    final map = <String, HrLeaveRequest>{};
    for (final row in rows) {
      final key = row.id.trim().isNotEmpty
          ? row.id.trim()
          : '${row.employeeId}|${row.leaveTypeCode}|${row.startDateOnly.toIso8601String()}|${row.endDateOnly.toIso8601String()}';
      final existing = map[key];
      if (existing == null || row.updatedAt.isAfter(existing.updatedAt)) {
        map[key] = row;
      }
    }
    return map.values.toList(growable: false)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }
}
