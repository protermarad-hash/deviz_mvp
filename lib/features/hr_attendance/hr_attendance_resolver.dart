import 'hr_attendance_models.dart';

class HrAttendanceResolver {
  const HrAttendanceResolver();

  HrAttendanceDaySummary summarizeDay({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime date,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final filtered = entries.where((item) {
      return item.employeeId.trim() == employeeId.trim() &&
          item.isCounted &&
          item.dateOnly == targetDate;
    }).toList(growable: false);
    return HrAttendanceDaySummary(
      employeeId: employeeId.trim(),
      date: targetDate,
      entries: _dedupeEntries(filtered),
      workedHours: _sum(filtered, (item) => item.workedHours),
      overtimeHours: _sum(filtered, (item) => item.overtimeHours),
      nightHours: _sum(filtered, (item) => item.nightHours),
      leaveHours: _sum(filtered, (item) => item.leaveHours),
    );
  }

  HrAttendanceIntervalSummary summarizeInterval({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    final from = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final to = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final filtered = entries.where((item) {
      if (!item.isCounted) return false;
      if (item.employeeId.trim() != employeeId.trim()) return false;
      final target = item.dateOnly;
      if (target.isBefore(from)) return false;
      if (target.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
    return HrAttendanceIntervalSummary(
      employeeId: employeeId.trim(),
      dateFrom: from,
      dateTo: to,
      entryCount: _dedupeEntries(filtered).length,
      workedHours: _sum(filtered, (item) => item.workedHours),
      overtimeHours: _sum(filtered, (item) => item.overtimeHours),
      nightHours: _sum(filtered, (item) => item.nightHours),
      leaveHours: _sum(filtered, (item) => item.leaveHours),
    );
  }

  HrAttendanceMonthlySummary summarizeMonth({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final filtered = entries.where((item) {
      if (!item.isCounted) return false;
      if (item.employeeId.trim() != employeeId.trim()) return false;
      final target = item.dateOnly;
      if (target.isBefore(start)) return false;
      if (target.isAfter(end)) return false;
      return true;
    }).toList(growable: false);

    final grouped = <DateTime, List<HrAttendanceEntry>>{};
    for (final item in filtered) {
      final key = item.dateOnly;
      grouped.putIfAbsent(key, () => <HrAttendanceEntry>[]).add(item);
    }
    final daySummaries = grouped.entries
        .map(
          (entry) => HrAttendanceDaySummary(
            employeeId: employeeId.trim(),
            date: entry.key,
            entries: _dedupeEntries(entry.value),
            workedHours: _sum(entry.value, (item) => item.workedHours),
            overtimeHours: _sum(entry.value, (item) => item.overtimeHours),
            nightHours: _sum(entry.value, (item) => item.nightHours),
            leaveHours: _sum(entry.value, (item) => item.leaveHours),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    return HrAttendanceMonthlySummary(
      employeeId: employeeId.trim(),
      month: start,
      daySummaries: daySummaries,
      workedHours: _sum(filtered, (item) => item.workedHours),
      overtimeHours: _sum(filtered, (item) => item.overtimeHours),
      nightHours: _sum(filtered, (item) => item.nightHours),
      leaveHours: _sum(filtered, (item) => item.leaveHours),
    );
  }

  HrAttendanceDaySummary summarizeApprovedDay({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime date,
  }) {
    return summarizeDay(
      entries: entries.where((item) => item.isApproved).toList(growable: false),
      employeeId: employeeId,
      date: date,
    );
  }

  HrAttendanceIntervalSummary summarizeApprovedInterval({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return summarizeInterval(
      entries: entries.where((item) => item.isApproved).toList(growable: false),
      employeeId: employeeId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  HrAttendanceMonthlySummary summarizeApprovedMonth({
    required List<HrAttendanceEntry> entries,
    required String employeeId,
    required DateTime month,
  }) {
    return summarizeMonth(
      entries: entries.where((item) => item.isApproved).toList(growable: false),
      employeeId: employeeId,
      month: month,
    );
  }

  double _sum(
    List<HrAttendanceEntry> rows,
    double Function(HrAttendanceEntry item) picker,
  ) {
    return rows.fold<double>(0, (sum, item) => sum + picker(item));
  }

  List<HrAttendanceEntry> _dedupeEntries(List<HrAttendanceEntry> rows) {
    final map = <String, HrAttendanceEntry>{};
    for (final row in rows) {
      final key = row.id.trim().isNotEmpty
          ? row.id.trim()
          : '${row.employeeId}|${row.dateOnly.toIso8601String()}|${row.sourceType}|${row.sourceRefId}';
      final existing = map[key];
      if (existing == null || row.updatedAt.isAfter(existing.updatedAt)) {
        map[key] = row;
      }
    }
    final values = map.values.toList(growable: false)
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return values;
  }
}
