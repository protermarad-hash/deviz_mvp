class MonthlyTimesheetEmployeeRow {
  const MonthlyTimesheetEmployeeRow({
    required this.employeeId,
    required this.employeeName,
    this.teamId = '',
    this.teamName = '',
    this.dayValues = const <String, String>{},
    this.notes = '',
    this.mealTicketBudgetRon = 0.0,
  });

  final String employeeId;
  final String employeeName;
  final String teamId;
  final String teamName;
  final Map<String, String> dayValues;
  final String notes;
  final double mealTicketBudgetRon;

  MonthlyTimesheetEmployeeRow copyWith({
    String? employeeId,
    String? employeeName,
    String? teamId,
    String? teamName,
    Map<String, String>? dayValues,
    String? notes,
    double? mealTicketBudgetRon,
  }) {
    return MonthlyTimesheetEmployeeRow(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      dayValues: dayValues ?? this.dayValues,
      notes: notes ?? this.notes,
      mealTicketBudgetRon: mealTicketBudgetRon ?? this.mealTicketBudgetRon,
    );
  }

  double get totalWorkedHours {
    var total = 0.0;
    for (final value in dayValues.values) {
      total += MonthlyTimesheetValueParser.hoursFromValue(value);
    }
    return total;
  }

  int countCode(String code) {
    final target = code.trim().toUpperCase();
    if (target.isEmpty) {
      return 0;
    }
    return dayValues.values
        .where((value) =>
            MonthlyTimesheetValueParser.codeFromValue(value) == target)
        .length;
  }

  Map<String, int> codeCounts(Iterable<String> codes) {
    return <String, int>{
      for (final code in codes) code.trim().toUpperCase(): countCode(code),
    };
  }

  MonthlyTimesheetEmployeeRow normalizeForDays(int daysInMonth) {
    final normalizedValues = <String, String>{
      for (var day = 1; day <= daysInMonth; day++)
        '$day': (dayValues['$day'] ?? '').trim(),
    };
    return copyWith(dayValues: normalizedValues);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_id': employeeId,
      'employee_name': employeeName,
      'team_id': teamId,
      'team_name': teamName,
      'day_values': dayValues,
      'notes': notes,
      'meal_ticket_budget_ron': mealTicketBudgetRon,
    };
  }

  factory MonthlyTimesheetEmployeeRow.fromMap(Map<String, dynamic> map) {
    final rawDayValues =
        map['day_values'] ?? map['dayValues'] ?? const <String, dynamic>{};
    final parsedDayValues = <String, String>{};
    if (rawDayValues is Map) {
      for (final entry in rawDayValues.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        parsedDayValues[key] = (entry.value ?? '').toString().trim();
      }
    }
    return MonthlyTimesheetEmployeeRow(
      employeeId: (map['employee_id'] ?? map['employeeId'] ?? '').toString(),
      employeeName:
          (map['employee_name'] ?? map['employeeName'] ?? '').toString(),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString(),
      teamName: (map['team_name'] ?? map['teamName'] ?? '').toString(),
      dayValues: parsedDayValues,
      notes: (map['notes'] ?? '').toString(),
      mealTicketBudgetRon: () {
        final raw = map['meal_ticket_budget_ron'] ?? map['mealTicketBudgetRon'];
        if (raw is num) return raw.toDouble();
        return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ??
            0.0;
      }(),
    );
  }
}

class MonthlyTimesheetRecord {
  const MonthlyTimesheetRecord({
    required this.id,
    required this.year,
    required this.month,
    required this.rows,
    this.status = 'draft',
    this.createdByUserId = '',
    this.createdByName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int year;
  final int month;
  final List<MonthlyTimesheetEmployeeRow> rows;
  final String status;
  final String createdByUserId;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  MonthlyTimesheetRecord copyWith({
    String? id,
    int? year,
    int? month,
    List<MonthlyTimesheetEmployeeRow>? rows,
    String? status,
    String? createdByUserId,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyTimesheetRecord(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      rows: rows ?? this.rows,
      status: status ?? this.status,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  double get totalWorkedHours =>
      rows.fold<double>(0.0, (sum, row) => sum + row.totalWorkedHours);

  int totalCodeCount(String code) {
    return rows.fold<int>(0, (sum, row) => sum + row.countCode(code));
  }

  Map<String, int> totalCodeCounts(Iterable<String> codes) {
    return <String, int>{
      for (final code in codes) code.trim().toUpperCase(): totalCodeCount(code),
    };
  }

  MonthlyTimesheetRecord normalizeForMonth() {
    return copyWith(
      rows: rows
          .map((row) => row.normalizeForDays(daysInMonth))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'year': year,
      'month': month,
      'rows': rows.map((row) => row.toMap()).toList(growable: false),
      'status': status,
      'created_by_user_id': createdByUserId,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MonthlyTimesheetRecord.fromMap(Map<String, dynamic> map) {
    final rawRows = map['rows'] ?? const <dynamic>[];
    return MonthlyTimesheetRecord(
      id: (map['id'] ?? '').toString(),
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (map['month'] as num?)?.toInt() ?? DateTime.now().month,
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map(
                (row) => MonthlyTimesheetEmployeeRow.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(growable: false)
          : const <MonthlyTimesheetEmployeeRow>[],
      status: (map['status'] ?? 'draft').toString(),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
              .toString(),
      createdByName:
          (map['created_by_name'] ?? map['createdByName'] ?? '').toString(),
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}

class MonthlyTimesheetValueParser {
  static const List<String> supportedCodes = <String>[
    'CO',
    'CM',
    'CCC',
    'INV',
    'ABS',
    'MAT',
    'ST',
    'ALT',
  ];

  static String normalize(String raw) {
    final value = raw.trim().toUpperCase().replaceAll(',', '.');
    if (value.isEmpty) {
      return '';
    }
    final hours = double.tryParse(value);
    if (hours != null) {
      return hours == hours.roundToDouble()
          ? hours.toStringAsFixed(0)
          : hours.toStringAsFixed(2);
    }
    final code = codeFromValue(value);
    return code;
  }

  static double hoursFromValue(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    return double.tryParse(value) ?? 0.0;
  }

  static String codeFromValue(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) {
      return '';
    }
    final numericValue = value.replaceAll(',', '.');
    if (double.tryParse(numericValue) != null) {
      // Numeric values represent worked hours, not leave codes.
      return '';
    }
    if (supportedCodes.contains(value)) {
      return value;
    }
    return 'ALT';
  }
}

class MonthlyTimesheetCodeOption {
  const MonthlyTimesheetCodeOption(this.code, this.label);

  final String code;
  final String label;

  static const List<MonthlyTimesheetCodeOption> defaults =
      <MonthlyTimesheetCodeOption>[
    MonthlyTimesheetCodeOption('CO', 'Concediu'),
    MonthlyTimesheetCodeOption('CM', 'Medical'),
    MonthlyTimesheetCodeOption('CCC', 'Crestere copil'),
    MonthlyTimesheetCodeOption('INV', 'Invoire'),
    MonthlyTimesheetCodeOption('ABS', 'Absent'),
    MonthlyTimesheetCodeOption('MAT', 'Maternitate'),
    MonthlyTimesheetCodeOption('ST', 'Somaj tehnic'),
    MonthlyTimesheetCodeOption('ALT', 'Alt cod'),
  ];
}
