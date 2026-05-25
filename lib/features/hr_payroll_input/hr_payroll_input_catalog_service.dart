import '../../core/cloud/firebase_bootstrap.dart';
import '../hr_core/hr_employee_catalog_service.dart';
import '../hr_monthly_timesheet/monthly_timesheet_models.dart';
import '../hr_rules/hr_payroll_rules_catalog_service.dart';
import '../hr_variable_payroll/hr_variable_payroll_catalog_service.dart';
import '../hr_variable_payroll/hr_variable_payroll_models.dart';
import 'firebase_hr_payroll_input_repository.dart';
import 'hr_payroll_input_cloud_repository.dart';
import 'hr_payroll_input_snapshot_models.dart';
import 'local_hr_payroll_input_store.dart';

/// Rezumatul datelor derivate din grila de pontaj lunar pentru un angajat.
/// Toate calculele de salarizare se bazeaza STRICT pe aceste date —
/// submodulele separate de prezenta (hr_attendance) si concedii (hr_leave)
/// nu sunt folosite in procesul de generare snapshot.
class _TimesheetDerivedInputs {
  const _TimesheetDerivedInputs({
    required this.workedHours,
    required this.workedDayCount,
    required this.vacationDays,
    required this.medicalDays,
    required this.otherLeaveDays,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.isChildcareLeaveActive,
    required this.eligibilityBreakdown,
  });

  final double workedHours;
  final double workedDayCount;
  final double vacationDays;
  final double medicalDays;
  final double otherLeaveDays;
  final double paidLeaveDays;
  final double unpaidLeaveDays;
  final bool isChildcareLeaveActive;
  final Map<String, double> eligibilityBreakdown;

  static _TimesheetDerivedInputs fromRow(MonthlyTimesheetEmployeeRow row) {
    var workedHours = 0.0;
    var workedDayCount = 0.0;
    final breakdown = <String, double>{
      for (final entry in MealTicketEligibilityRules.defaults.entries)
        entry.key: 0.0,
    };
    for (final entry in row.dayValues.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final hours = MonthlyTimesheetValueParser.hoursFromValue(value);
      if (hours > 0) {
        workedHours += hours;
        workedDayCount += 1.0;
        breakdown['worked_hours'] = (breakdown['worked_hours'] ?? 0.0) + 1.0;
        continue;
      }
      final code = MonthlyTimesheetValueParser.codeFromValue(value);
      if (code.isEmpty) continue;
      breakdown[code] = (breakdown[code] ?? 0.0) + 1.0;
    }
    final coDays = breakdown['CO'] ?? 0.0;
    final cmDays = breakdown['CM'] ?? 0.0;
    final cccDays = breakdown['CCC'] ?? 0.0;
    final invDays = breakdown['INV'] ?? 0.0;
    final absDays = breakdown['ABS'] ?? 0.0;
    final matDays = breakdown['MAT'] ?? 0.0;
    final stDays = breakdown['ST'] ?? 0.0;
    final altDays = breakdown['ALT'] ?? 0.0;
    // CO, CM, MAT = concedii platite; INV, ABS, ST, ALT = neplatite/partial
    final paidLeaveDays = coDays + cmDays + matDays;
    final unpaidLeaveDays = invDays + absDays + stDays + altDays;
    final otherLeaveDays = invDays + absDays + matDays + stDays + altDays;
    return _TimesheetDerivedInputs(
      workedHours: workedHours,
      workedDayCount: workedDayCount,
      vacationDays: coDays,
      medicalDays: cmDays,
      otherLeaveDays: otherLeaveDays,
      paidLeaveDays: paidLeaveDays,
      unpaidLeaveDays: unpaidLeaveDays,
      isChildcareLeaveActive: cccDays > 0,
      eligibilityBreakdown: breakdown,
    );
  }

  /// Fallback pentru cazul in care nu exista rand de pontaj salvat.
  static _TimesheetDerivedInputs empty() {
    return _TimesheetDerivedInputs(
      workedHours: 0,
      workedDayCount: 0,
      vacationDays: 0,
      medicalDays: 0,
      otherLeaveDays: 0,
      paidLeaveDays: 0,
      unpaidLeaveDays: 0,
      isChildcareLeaveActive: false,
      eligibilityBreakdown: <String, double>{
        for (final entry in MealTicketEligibilityRules.defaults.entries)
          entry.key: 0.0,
      },
    );
  }
}

class HrPayrollInputCatalogService {
  HrPayrollInputCatalogService({
    HrPayrollInputCloudRepository? cloudRepository,
    LocalHrPayrollInputStore? localStore,
    HrEmployeeCatalogService? employeeCatalogService,
    HrPayrollRulesCatalogService? payrollRulesCatalogService,
    HrVariablePayrollCatalogService? variablePayrollCatalogService,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrPayrollInputRepository()
                : null),
        _localStore = localStore ?? LocalHrPayrollInputStore(),
        _employeeCatalogService =
            employeeCatalogService ?? HrEmployeeCatalogService(),
        _payrollRulesCatalogService =
            payrollRulesCatalogService ?? HrPayrollRulesCatalogService(),
        _variablePayrollCatalogService =
            variablePayrollCatalogService ?? HrVariablePayrollCatalogService();

  final HrPayrollInputCloudRepository? _cloudRepository;
  final LocalHrPayrollInputStore _localStore;
  final HrEmployeeCatalogService _employeeCatalogService;
  final HrPayrollRulesCatalogService _payrollRulesCatalogService;
  final HrVariablePayrollCatalogService _variablePayrollCatalogService;

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

  Future<List<HrPayrollInputSnapshot>> listSnapshots() async {
    final localRows = await _localStore.listSnapshots();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listSnapshots();
      await _localStore.saveSnapshots(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrPayrollInputSnapshot>> listSnapshotsForMonth(
    DateTime payrollMonth,
  ) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listSnapshots();
    return rows
        .where((item) =>
            item.payrollMonth.year == target.year &&
            item.payrollMonth.month == target.month)
        .toList(growable: false)
      ..sort((a, b) => a.employeeId.compareTo(b.employeeId));
  }

  Future<HrPayrollInputSnapshot?> findSnapshotForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listSnapshotsForMonth(target);
    for (final row in rows) {
      if (row.employeeId.trim() == employeeId.trim()) return row;
    }
    return null;
  }

  Future<void> upsertSnapshot(HrPayrollInputSnapshot item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertSnapshot(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listSnapshots()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveSnapshots(local);
  }

  Future<HrPayrollInputSnapshot?> generateMonthlySnapshotForEmployee({
    required String employeeId,
    required DateTime payrollMonth,
    String generatedByUserId = '',
    String notes = '',
    double mealTicketBudgetOverride = 0.0,
    int workedDaysHint = 0,
    MonthlyTimesheetEmployeeRow? timesheetRow,
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final profile =
        await _employeeCatalogService.findProfileByEmployeeId(employeeId);
    if (profile == null) return null;

    final contract = await _employeeCatalogService.resolveActiveContract(
      employeeId: employeeId,
      date: month,
    );
    if (contract == null) return null;

    // ── Deriva toate datele de prezenta STRICT din grila de pontaj ──────────
    // Nu se mai folosesc submodulele hr_attendance sau hr_leave.
    final ts = timesheetRow != null
        ? _TimesheetDerivedInputs.fromRow(timesheetRow)
        : _TimesheetDerivedInputs.empty();

    // Daca nu avem rand de pontaj dar avem workedDaysHint (fallback vechi),
    // suprascriem workedDayCount cu hint-ul.
    final effectiveWorkedDayCount = ts.workedDayCount > 0
        ? ts.workedDayCount
        : (workedDaysHint > 0 ? workedDaysHint.toDouble() : 0.0);

    // Daca contractul are concediu crestere copil activ in luna, suprascrie
    // datele din pontaj (CCC din contract are prioritate fata de CCC din grila).
    final isChildcareLeaveActive = ts.isChildcareLeaveActive ||
        contract.hasChildcareLeaveOverlapInMonth(month);

    final activeRules = await _resolveActiveRuleIds(month);
    final variableEntries = isChildcareLeaveActive
        ? HrVariablePayrollMonthlyBundle(
            employeeId: '',
            month: DateTime.utc(2000, 1, 1),
            bonuses: <HrBonus>[],
            deductions: <HrDeduction>[],
            advances: <HrAdvance>[],
            garnishments: <HrGarnishment>[],
          )
        : await _variablePayrollCatalogService.buildMonthlyBundle(
            employeeId: employeeId,
            month: month,
          );
    final existing = await findSnapshotForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: month,
    );
    final now = DateTime.now();
    final snapshotId = existing?.id ?? _buildSnapshotId(employeeId, month);
    final hoursPerDay = contract.employmentNormHoursPerDay > 0
        ? contract.employmentNormHoursPerDay
        : 8.0;

    // ── Tichete de masa ────────────────────────────────────────────────────
    final timesheetMealTicketBudget = timesheetRow?.mealTicketBudgetRon ?? 0.0;
    final mealTicketMode =
        (existing?.mealTicketCalculationMode.trim().isNotEmpty ?? false)
            ? existing!.mealTicketCalculationMode.trim()
            : 'monthly_budget_divided_by_eligible_days';
    // Tichetele sunt active daca: (a) s-a setat un buget explicit, sau
    // (b) exista un snapshot anterior cu tichete activate, sau
    // (c) exista zile lucrate (implicit activat).
    final mealTicketsEnabled = isChildcareLeaveActive
        ? false
        : (mealTicketBudgetOverride > 0 ||
                timesheetMealTicketBudget > 0 ||
                (existing?.mealTicketsEnabled ?? false) ||
                effectiveWorkedDayCount > 0)
            ? true
            : false;
    // Valoarea plafonului legal zilnic pentru tichetele de masa (RO).
    final mealTicketRuleForMonth =
        await _payrollRulesCatalogService.resolveActiveRuleForPayrollMonth(
      jurisdiction: 'RO',
      scope: 'meal_ticket',
      ruleType: 'meal_ticket',
      payrollMonth: month,
    );
    final mealTicketDailyCapRon =
        ((mealTicketRuleForMonth?.rulePayload['daily_cap_ron']) as num?)
                ?.toDouble() ??
            40.96;
    final mealTicketFiscalTreatment =
        (mealTicketRuleForMonth?.rulePayload['fiscal_treatment'] ??
                'exempt_cas_subject_cass_subject_income_tax_10pct')
            .toString();
    final mealTicketEligibilityRules = MealTicketEligibilityRules.normalize(
      existing?.mealTicketEligibilityRules ??
          MealTicketEligibilityRules.defaults,
    );

    // Breakdown-ul vine direct din grila de pontaj.
    final mealTicketEligibilityBreakdown = isChildcareLeaveActive
        ? <String, double>{
            for (final entry in MealTicketEligibilityRules.defaults.entries)
              entry.key: entry.key == 'CCC' ? 1.0 : 0.0,
          }
        : (timesheetRow != null
            ? ts.eligibilityBreakdown
            : <String, double>{
                for (final entry in MealTicketEligibilityRules.defaults.entries)
                  entry.key: 0.0,
              });

    final mealTicketConfiguredEligibleDays =
        (existing?.mealTicketConfiguredEligibleDays ??
                    effectiveWorkedDayCount) >
                0
            ? (existing?.mealTicketConfiguredEligibleDays ??
                effectiveWorkedDayCount)
            : effectiveWorkedDayCount;
    final mealTicketsMonthlyBudget = isChildcareLeaveActive
        ? 0.0
        : (mealTicketBudgetOverride > 0
            ? mealTicketBudgetOverride
            : ((existing?.mealTicketsMonthlyBudget ?? 0.0) > 0
                ? (existing?.mealTicketsMonthlyBudget ?? 0.0)
                : timesheetMealTicketBudget));
    final mealTicketEligibleDays = isChildcareLeaveActive
        ? 0.0
        : _calculateMealTicketEligibleDays(
            breakdown: mealTicketEligibilityBreakdown,
            rules: mealTicketEligibilityRules,
          );
    // Daca nu s-a setat un buget explicit (din pontaj sau override), calculam
    // bugetul implicit ca: zile_eligibile × plafon_zilnic_legal.
    final effectiveMealTicketBudget = mealTicketsMonthlyBudget > 0
        ? mealTicketsMonthlyBudget
        : (mealTicketsEnabled && mealTicketEligibleDays > 0
            ? mealTicketDailyCapRon * mealTicketEligibleDays
            : 0.0);
    final mealTicketValuePerDay = mealTicketsEnabled
        ? _resolveMealTicketValuePerDay(
            mode: mealTicketMode,
            monthlyBudget: effectiveMealTicketBudget,
            configuredEligibleDays: mealTicketConfiguredEligibleDays > 0
                ? mealTicketConfiguredEligibleDays
                : mealTicketEligibleDays,
            existingValuePerDay:
                (existing != null && existing.mealTicketValuePerDay > 0)
                    ? existing.mealTicketValuePerDay
                    : mealTicketDailyCapRon,
          )
        : 0.0;
    // Cand exista budget override, total = bugetul setat direct (nu mai
    // depindem de numarul de zile eligibile).
    final mealTicketsTotalValue = mealTicketsEnabled
        ? (mealTicketBudgetOverride > 0
            ? mealTicketBudgetOverride
            : mealTicketValuePerDay * mealTicketEligibleDays)
        : 0.0;

    final snapshot = HrPayrollInputSnapshot(
      id: snapshotId,
      employeeId: employeeId.trim(),
      hrEmployeeProfileId: profile.id,
      contractId: contract.id,
      payrollMonth: month,
      ruleVersionIds: activeRules,
      workedHours: isChildcareLeaveActive ? 0 : ts.workedHours,
      overtimeHours: 0, // netracat separat in grila de pontaj
      nightHours: 0, // netracat separat in grila de pontaj
      leaveHoursPaid:
          isChildcareLeaveActive ? 0 : ts.paidLeaveDays * hoursPerDay,
      leaveHoursUnpaid:
          isChildcareLeaveActive ? 0 : ts.unpaidLeaveDays * hoursPerDay,
      vacationWorkingDays: isChildcareLeaveActive ? 0 : ts.vacationDays,
      medicalLeaveWorkingDays: isChildcareLeaveActive ? 0 : ts.medicalDays,
      otherLeaveWorkingDays: isChildcareLeaveActive ? 0 : ts.otherLeaveDays,
      baseSalaryGross: isChildcareLeaveActive ? 0 : contract.baseSalaryGross,
      currency: contract.currency,
      mealTicketsEnabled: mealTicketsEnabled,
      mealTicketCalculationMode: mealTicketMode,
      mealTicketsMonthlyBudget: effectiveMealTicketBudget,
      mealTicketConfiguredEligibleDays: mealTicketConfiguredEligibleDays > 0
          ? mealTicketConfiguredEligibleDays
          : mealTicketEligibleDays,
      mealTicketValuePerDay: mealTicketValuePerDay,
      mealTicketEligibleDays: mealTicketEligibleDays,
      mealTicketsTotalValue: mealTicketsTotalValue,
      mealTicketEligibilityRules: mealTicketEligibilityRules,
      mealTicketEligibilityBreakdown: mealTicketEligibilityBreakdown,
      bonusEntries: variableEntries.bonusEntries,
      deductionEntries: variableEntries.deductionEntries,
      allowanceEntries: variableEntries.allowanceEntries,
      sourceRefs: <String, dynamic>{
        'leave_source_mode': 'monthly_timesheet_authoritative',
        'contract_id': contract.id,
        'is_childcare_leave_active': isChildcareLeaveActive,
        'childcare_leave_start_date':
            contract.childcareLeaveStartDate?.toIso8601String() ?? '',
        'childcare_leave_end_date':
            contract.childcareLeaveEndDate?.toIso8601String() ?? '',
        'rule_version_ids': activeRules,
        'attendance_worked_day_count': effectiveWorkedDayCount,
        'timesheet_worked_hours': ts.workedHours,
        'timesheet_vacation_days': ts.vacationDays,
        'timesheet_medical_days': ts.medicalDays,
        'timesheet_other_leave_days': ts.otherLeaveDays,
        'bonus_ids': variableEntries.bonuses
            .map((item) => item.id)
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        'deduction_ids': variableEntries.deductions
            .map((item) => item.id)
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        'advance_ids': variableEntries.advances
            .map((item) => item.id)
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        'garnishment_ids': variableEntries.garnishments
            .map((item) => item.id)
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        'meal_ticket_eligibility_rules': mealTicketEligibilityRules,
        'meal_ticket_eligibility_breakdown': mealTicketEligibilityBreakdown,
        'meal_ticket_fiscal_treatment': mealTicketFiscalTreatment,
      },
      status: 'generated',
      generatedAt: now,
      generatedByUserId: generatedByUserId,
      notes: isChildcareLeaveActive
          ? [notes.trim(), 'CCC activ: snapshot salarial generat cu venit 0.']
              .where((item) => item.isNotEmpty)
              .join('\n')
          : notes.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await upsertSnapshot(snapshot);
    return snapshot;
  }

  double _resolveMealTicketValuePerDay({
    required String mode,
    required double monthlyBudget,
    required double configuredEligibleDays,
    required double existingValuePerDay,
  }) {
    if (mode.trim() == 'fixed_value_per_ticket') {
      return existingValuePerDay;
    }
    if (configuredEligibleDays <= 0) {
      return 0.0;
    }
    return monthlyBudget / configuredEligibleDays;
  }

  double _calculateMealTicketEligibleDays({
    required Map<String, double> breakdown,
    required Map<String, bool> rules,
  }) {
    var total = 0.0;
    final normalizedRules = MealTicketEligibilityRules.normalize(rules);
    for (final entry in normalizedRules.entries) {
      if (!entry.value) {
        continue;
      }
      total += breakdown[entry.key] ?? 0.0;
    }
    return total;
  }

  Future<HrPayrollInputSnapshot?> regenerateMonthlySnapshotForEmployee({
    required String employeeId,
    required DateTime payrollMonth,
    String generatedByUserId = '',
    String notes = '',
  }) {
    return generateMonthlySnapshotForEmployee(
      employeeId: employeeId,
      payrollMonth: payrollMonth,
      generatedByUserId: generatedByUserId,
      notes: notes,
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> buildVariableEntriesForMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final bundle = await _variablePayrollCatalogService.buildMonthlyBundle(
      employeeId: employeeId,
      month: payrollMonth,
    );
    return <String, List<Map<String, dynamic>>>{
      'bonus_entries': bundle.bonusEntries,
      'deduction_entries': bundle.deductionEntries,
      'allowance_entries': bundle.allowanceEntries,
    };
  }

  String _buildSnapshotId(String employeeId, DateTime month) {
    final employee = employeeId.trim();
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return 'hr-payroll-snapshot-$employee-$monthKey';
  }

  Future<List<String>> _resolveActiveRuleIds(DateTime month) async {
    const requestedRules = <Map<String, String>>[
      {'scope': 'payroll', 'ruleType': 'minimum_wage'},
      {'scope': 'payroll', 'ruleType': 'salary_tax'},
      {'scope': 'leave', 'ruleType': 'vacation_leave'},
      {'scope': 'medical_leave', 'ruleType': 'medical_leave'},
      {'scope': 'overtime', 'ruleType': 'overtime'},
      {'scope': 'garnishment', 'ruleType': 'garnishment'},
      {'scope': 'meal_ticket', 'ruleType': 'meal_ticket'},
    ];
    final ids = <String>[];
    for (final item in requestedRules) {
      final rule =
          await _payrollRulesCatalogService.resolveActiveRuleForPayrollMonth(
        jurisdiction: 'RO',
        scope: item['scope'] ?? '',
        ruleType: item['ruleType'] ?? '',
        payrollMonth: month,
      );
      final id = (rule?.id ?? '').trim();
      if (id.isNotEmpty && !ids.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }
}
