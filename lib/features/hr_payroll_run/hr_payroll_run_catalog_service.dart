import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/repositories/app_data_repository.dart';
import '../../core/repositories/cloud_app_data_repository.dart';
import '../../core/repositories/local_app_data_repository.dart';
import '../hr_core/hr_employee_catalog_service.dart';
import '../hr_core/hr_employee_models.dart';
import '../hr_monthly_timesheet/monthly_timesheet_models.dart';
import '../hr_payroll_calc/hr_payroll_calculation_catalog_service.dart';
import '../hr_payroll_input/hr_payroll_input_catalog_service.dart';
import 'firebase_hr_payroll_accounting_report_repository.dart';
import 'hr_payroll_accounting_report_cloud_repository.dart';
import 'hr_payroll_accounting_report_models.dart';
import 'firebase_hr_payroll_run_repository.dart';
import 'hr_payroll_run_cloud_repository.dart';
import 'hr_payroll_run_models.dart';
import 'local_hr_payroll_accounting_report_store.dart';
import 'local_hr_payroll_run_store.dart';

class HrPayrollRunCatalogService {
  HrPayrollRunCatalogService({
    HrPayrollRunCloudRepository? cloudRepository,
    LocalHrPayrollRunStore? localStore,
    HrPayrollAccountingReportCloudRepository? accountingReportCloudRepository,
    LocalHrPayrollAccountingReportStore? accountingReportLocalStore,
    HrEmployeeCatalogService? employeeCatalogService,
    HrPayrollInputCatalogService? payrollInputCatalogService,
    HrPayrollCalculationCatalogService? payrollCalculationCatalogService,
    AppDataRepository? repository,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrPayrollRunRepository()
                : null),
        _localStore = localStore ?? LocalHrPayrollRunStore(),
        _accountingReportCloudRepository = accountingReportCloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrPayrollAccountingReportRepository()
                : null),
        _accountingReportLocalStore =
            accountingReportLocalStore ?? LocalHrPayrollAccountingReportStore(),
        _employeeCatalogService =
            employeeCatalogService ?? HrEmployeeCatalogService(),
        _payrollInputCatalogService =
            payrollInputCatalogService ?? HrPayrollInputCatalogService(),
        _repository = repository ??
            (FirebaseBootstrap.isInitialized
                ? CloudAppDataRepository()
                : LocalAppDataRepository()),
        _payrollCalculationCatalogService = payrollCalculationCatalogService ??
            HrPayrollCalculationCatalogService();

  final HrPayrollRunCloudRepository? _cloudRepository;
  final LocalHrPayrollRunStore _localStore;
  final HrPayrollAccountingReportCloudRepository?
      _accountingReportCloudRepository;
  final LocalHrPayrollAccountingReportStore _accountingReportLocalStore;
  final HrEmployeeCatalogService _employeeCatalogService;
  final HrPayrollInputCatalogService _payrollInputCatalogService;
  final AppDataRepository _repository;
  final HrPayrollCalculationCatalogService _payrollCalculationCatalogService;

  String dataSourceLabel = 'cloud';
  String? fallbackReason;

  Future<Map<String, MonthlyTimesheetEmployeeRow>>
      _timesheetRowByEmployeeIdForMonth(DateTime payrollMonth) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await _repository.listMonthlyTimesheets();
    MonthlyTimesheetRecord? timesheet;
    for (final item in rows) {
      if (item.year == month.year && item.month == month.month) {
        timesheet = item.normalizeForMonth();
        break;
      }
    }
    if (timesheet == null) {
      return const <String, MonthlyTimesheetEmployeeRow>{};
    }
    return <String, MonthlyTimesheetEmployeeRow>{
      for (final row in timesheet.rows) row.employeeId.trim(): row,
    };
  }

  Future<MonthlyTimesheetEmployeeRow?> _timesheetRowForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final byEmployeeId = await _timesheetRowByEmployeeIdForMonth(payrollMonth);
    return byEmployeeId[employeeId.trim()];
  }

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

  Future<List<HrPayrollRun>> listRuns() async {
    final localRows = await _localStore.listRuns();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listRuns();
      await _localStore.saveRuns(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrPayrollRun>> listRunsForMonth(DateTime payrollMonth) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listRuns();
    return rows
        .where((item) =>
            item.payrollMonth.year == target.year &&
            item.payrollMonth.month == target.month)
        .toList(growable: false);
  }

  Future<HrPayrollRun?> findRunForMonth(DateTime payrollMonth) async {
    final rows = await listRunsForMonth(payrollMonth);
    if (rows.isEmpty) return null;
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows.first;
  }

  Future<void> upsertRun(HrPayrollRun item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertRun(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listRuns()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveRuns(local);
  }

  Future<List<HrPayslip>> listPayslips() async {
    final localRows = await _localStore.listPayslips();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listPayslips();
      await _localStore.savePayslips(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrPayslip>> listPayslipsForMonth(DateTime payrollMonth) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listPayslips();
    return rows
        .where((item) =>
            item.payrollMonth.year == target.year &&
            item.payrollMonth.month == target.month)
        .toList(growable: false)
      ..sort((a, b) => a.employeeId.compareTo(b.employeeId));
  }

  Future<HrPayslip?> findPayslipForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final rows = await listPayslipsForMonth(payrollMonth);
    for (final row in rows) {
      if (row.employeeId.trim() == employeeId.trim()) return row;
    }
    return null;
  }

  Future<void> upsertPayslip(HrPayslip item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertPayslip(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listPayslips()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.savePayslips(local);
  }

  Future<List<HrPayrollAccountingReport>> listAccountingReports() async {
    final localRows = await _accountingReportLocalStore.listReports();
    final cloud = _accountingReportCloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listReports();
      await _accountingReportLocalStore.saveReports(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrPayrollAccountingReport>> listAccountingReportsForMonth(
    DateTime payrollMonth,
  ) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listAccountingReports();
    return rows
        .where((item) =>
            item.payrollMonth.year == target.year &&
            item.payrollMonth.month == target.month)
        .toList(growable: false);
  }

  Future<HrPayrollAccountingReport?> findAccountingReportForMonth(
    DateTime payrollMonth,
  ) async {
    final rows = await listAccountingReportsForMonth(payrollMonth);
    if (rows.isEmpty) return null;
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows.first;
  }

  Future<void> upsertAccountingReport(HrPayrollAccountingReport item) async {
    final cloud = _accountingReportCloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertReport(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _accountingReportLocalStore.listReports()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _accountingReportLocalStore.saveReports(local);
  }

  Future<HrPayrollRun?> lockPayrollMonth({
    required DateTime payrollMonth,
    String lockedByUserId = '',
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final existing = await findRunForMonth(month);
    if (existing == null) return null;
    if (existing.isLocked) return existing;
    final now = DateTime.now();
    final updated = HrPayrollRun(
      id: existing.id,
      payrollMonth: existing.payrollMonth,
      jurisdiction: existing.jurisdiction,
      status: 'locked',
      employeeIds: existing.employeeIds,
      calculationResultIds: existing.calculationResultIds,
      generatedAt: existing.generatedAt,
      generatedByUserId: existing.generatedByUserId,
      notes: existing.notes,
      lockedAt: now,
      lockedByUserId: lockedByUserId,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await upsertRun(updated);
    return updated;
  }

  Future<HrPayrollRun?> unlockPayrollMonth({
    required DateTime payrollMonth,
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final existing = await findRunForMonth(month);
    if (existing == null) return null;
    if (!existing.isLocked) return existing;
    final now = DateTime.now();
    final updated = HrPayrollRun(
      id: existing.id,
      payrollMonth: existing.payrollMonth,
      jurisdiction: existing.jurisdiction,
      status: 'generated',
      employeeIds: existing.employeeIds,
      calculationResultIds: existing.calculationResultIds,
      generatedAt: existing.generatedAt,
      generatedByUserId: existing.generatedByUserId,
      notes: existing.notes,
      lockedAt: null,
      lockedByUserId: '',
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await upsertRun(updated);
    return updated;
  }

  Future<HrPayrollAccountingReport?> markAccountingReportReady({
    required String reportId,
    String reviewedByUserId = '',
    String reviewNotes = '',
  }) async {
    final rows = await listAccountingReports();
    final existing = rows
        .where((item) => item.id.trim() == reportId.trim())
        .cast<HrPayrollAccountingReport?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (existing == null) return null;
    final now = DateTime.now();
    final updated = HrPayrollAccountingReport(
      id: existing.id,
      payrollMonth: existing.payrollMonth,
      payrollRunId: existing.payrollRunId,
      jurisdiction: existing.jurisdiction,
      status: 'ready_for_accounting',
      generatedAt: existing.generatedAt,
      generatedByUserId: existing.generatedByUserId,
      employeeCount: existing.employeeCount,
      currency: existing.currency,
      lineItems: existing.lineItems,
      totals: existing.totals,
      notes: existing.notes,
      approvedAt: null,
      approvedByUserId: '',
      reviewedAt: now,
      reviewedByUserId: reviewedByUserId,
      reviewNotes: reviewNotes,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await upsertAccountingReport(updated);
    return updated;
  }

  Future<HrPayrollAccountingReport?> approveAccountingReport({
    required String reportId,
    String approvedByUserId = '',
    String reviewNotes = '',
  }) async {
    final rows = await listAccountingReports();
    final existing = rows
        .where((item) => item.id.trim() == reportId.trim())
        .cast<HrPayrollAccountingReport?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (existing == null) return null;
    final now = DateTime.now();
    final updated = HrPayrollAccountingReport(
      id: existing.id,
      payrollMonth: existing.payrollMonth,
      payrollRunId: existing.payrollRunId,
      jurisdiction: existing.jurisdiction,
      status: 'approved',
      generatedAt: existing.generatedAt,
      generatedByUserId: existing.generatedByUserId,
      employeeCount: existing.employeeCount,
      currency: existing.currency,
      lineItems: existing.lineItems,
      totals: existing.totals,
      notes: existing.notes,
      approvedAt: now,
      approvedByUserId: approvedByUserId,
      reviewedAt: now,
      reviewedByUserId: approvedByUserId,
      reviewNotes: reviewNotes,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await upsertAccountingReport(updated);
    return updated;
  }

  Future<HrPayrollAccountingReport?> markAccountingReportNeedsReview({
    required String reportId,
    String reviewedByUserId = '',
    String reviewNotes = '',
  }) async {
    final rows = await listAccountingReports();
    final existing = rows
        .where((item) => item.id.trim() == reportId.trim())
        .cast<HrPayrollAccountingReport?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (existing == null) return null;
    final now = DateTime.now();
    final updated = HrPayrollAccountingReport(
      id: existing.id,
      payrollMonth: existing.payrollMonth,
      payrollRunId: existing.payrollRunId,
      jurisdiction: existing.jurisdiction,
      status: 'needs_review',
      generatedAt: existing.generatedAt,
      generatedByUserId: existing.generatedByUserId,
      employeeCount: existing.employeeCount,
      currency: existing.currency,
      lineItems: existing.lineItems,
      totals: existing.totals,
      notes: existing.notes,
      approvedAt: null,
      approvedByUserId: '',
      reviewedAt: now,
      reviewedByUserId: reviewedByUserId,
      reviewNotes: reviewNotes,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await upsertAccountingReport(updated);
    return updated;
  }

  Future<HrPayslip?> generatePayslipForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
    String payrollRunId = '',
    String generatedByUserId = '',
    String notes = '',
    MonthlyTimesheetEmployeeRow? timesheetRow,
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final run = await findRunForMonth(month);
    if (run?.isLocked == true) return null;
    final effectiveTimesheetRow = timesheetRow ??
        await _timesheetRowForEmployeeMonth(
          employeeId: employeeId,
          payrollMonth: month,
        );
    final profile =
        await _employeeCatalogService.findProfileByEmployeeId(employeeId);
    if (profile == null || !profile.isActive) return null;

    final contract = await _employeeCatalogService.resolveActiveContract(
      employeeId: employeeId,
      date: month,
    );
    if (contract == null) return null;

    await _payrollInputCatalogService.generateMonthlySnapshotForEmployee(
      employeeId: employeeId,
      payrollMonth: month,
      generatedByUserId: generatedByUserId,
      notes: notes,
      timesheetRow: effectiveTimesheetRow,
    );
    final snapshot =
        await _payrollInputCatalogService.findSnapshotForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: month,
    );
    final calculation = await _payrollCalculationCatalogService
        .calculatePayrollForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: month,
    );
    if (calculation == null) return null;

    final existing = await findPayslipForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: month,
    );
    final now = DateTime.now();
    final payslip = HrPayslip(
      id: existing?.id ?? _buildPayslipId(employeeId, month),
      employeeId: employeeId.trim(),
      hrEmployeeProfileId: profile.id,
      contractId: contract.id,
      payrollMonth: month,
      payrollRunId: payrollRunId.trim(),
      calculationResultId: calculation.id,
      currency: calculation.currency,
      grossTotal:
          calculation.grossTotalTaxable + calculation.grossNonTaxableAllowances,
      casAmount: calculation.employeeCasAmount,
      cassAmount: calculation.employeeCassAmount,
      incomeTaxAmount: calculation.incomeTaxAmount,
      deductionTotal: calculation.deductionTotal,
      advanceRecoveryTotal: calculation.advanceRecoveryTotal,
      garnishmentReservedTotal: calculation.garnishmentReservedTotal,
      netFinal: calculation.netFinal,
      breakdown: <String, dynamic>{
        ...calculation.breakdown,
        'employee_profile': <String, dynamic>{
          'full_name': profile.fullName,
          'employee_id': profile.employeeId,
          'team_id': profile.teamId,
        },
        'contract': <String, dynamic>{
          'job_title': contract.jobTitle,
          'contract_type': contract.contractType,
          'base_salary_gross': contract.baseSalaryGross,
          'currency': contract.currency,
        },
        'meal_tickets': <String, dynamic>{
          'enabled': snapshot?.mealTicketsEnabled ?? false,
          'calculation_mode': snapshot?.mealTicketCalculationMode ??
              'monthly_budget_divided_by_eligible_days',
          'monthly_budget': snapshot?.mealTicketsMonthlyBudget ?? 0.0,
          'configured_eligible_days':
              snapshot?.mealTicketConfiguredEligibleDays ?? 0.0,
          'eligible_days': snapshot?.mealTicketEligibleDays ?? 0.0,
          'value_per_day': snapshot?.mealTicketValuePerDay ?? 0.0,
          'total_value': snapshot?.mealTicketsTotalValue ?? 0.0,
          'eligibility_rules':
              snapshot?.mealTicketEligibilityRules ?? const <String, bool>{},
          'eligibility_breakdown': snapshot?.mealTicketEligibilityBreakdown ??
              const <String, double>{},
          'fiscal_treatment':
              snapshot?.sourceRefs['meal_ticket_fiscal_treatment'] ??
                  'exempt_cas_subject_cass_subject_income_tax_10pct',
        },
      },
      sourceRefs: <String, dynamic>{
        ...calculation.sourceRefs,
        'payroll_run_id': payrollRunId.trim(),
        'calculation_result_id': calculation.id,
        'hr_employee_profile_id': profile.id,
        'contract_id': contract.id,
      },
      status: 'generated',
      generatedAt: now,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await upsertPayslip(payslip);
    return payslip;
  }

  Future<HrPayrollRun> generatePayrollRunForMonth({
    required DateTime payrollMonth,
    String jurisdiction = 'RO',
    String generatedByUserId = '',
    String notes = '',
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final existing = await findRunForMonth(month);
    if (existing?.isLocked == true) return existing!;
    final profiles = await _employeeCatalogService.listProfiles();
    final eligibleProfiles = <HrEmployeeProfile>[];
    for (final profile in profiles) {
      if (!profile.isActive) continue;
      final contract = await _employeeCatalogService.resolveActiveContract(
        employeeId: profile.employeeId,
        date: month,
      );
      if (contract == null) continue;
      eligibleProfiles.add(profile);
    }

    final timesheetRowByEmployeeId =
        await _timesheetRowByEmployeeIdForMonth(month);

    final calculationResultIds = <String>[];
    final employeeIds = <String>[];
    for (final profile in eligibleProfiles) {
      await _payrollInputCatalogService.generateMonthlySnapshotForEmployee(
        employeeId: profile.employeeId,
        payrollMonth: month,
        generatedByUserId: generatedByUserId,
        notes: notes,
        timesheetRow: timesheetRowByEmployeeId[profile.employeeId.trim()],
      );
      final calculation = await _payrollCalculationCatalogService
          .calculatePayrollForEmployeeMonth(
        employeeId: profile.employeeId,
        payrollMonth: month,
      );
      if (calculation == null) continue;
      final payslip = await generatePayslipForEmployeeMonth(
        employeeId: profile.employeeId,
        payrollMonth: month,
        payrollRunId: existing?.id ?? _buildRunId(month),
        generatedByUserId: generatedByUserId,
        notes: notes,
        timesheetRow: timesheetRowByEmployeeId[profile.employeeId.trim()],
      );
      if (payslip == null) continue;
      employeeIds.add(profile.employeeId);
      calculationResultIds.add(calculation.id);
    }

    final now = DateTime.now();
    final run = HrPayrollRun(
      id: existing?.id ?? _buildRunId(month),
      payrollMonth: month,
      jurisdiction: jurisdiction,
      status: 'generated',
      employeeIds: employeeIds.toSet().toList(growable: false)..sort(),
      calculationResultIds: calculationResultIds.toSet().toList(growable: false)
        ..sort(),
      generatedAt: now,
      generatedByUserId: generatedByUserId,
      notes: notes,
      lockedAt: existing?.lockedAt,
      lockedByUserId: existing?.lockedByUserId ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await upsertRun(run);

    if (run.id.trim().isNotEmpty) {
      for (final employeeId in run.employeeIds) {
        final payslip = await findPayslipForEmployeeMonth(
          employeeId: employeeId,
          payrollMonth: month,
        );
        if (payslip == null) continue;
        if (payslip.payrollRunId.trim() == run.id.trim()) continue;
        await upsertPayslip(
          HrPayslip(
            id: payslip.id,
            employeeId: payslip.employeeId,
            hrEmployeeProfileId: payslip.hrEmployeeProfileId,
            contractId: payslip.contractId,
            payrollMonth: payslip.payrollMonth,
            payrollRunId: run.id,
            calculationResultId: payslip.calculationResultId,
            currency: payslip.currency,
            grossTotal: payslip.grossTotal,
            casAmount: payslip.casAmount,
            cassAmount: payslip.cassAmount,
            incomeTaxAmount: payslip.incomeTaxAmount,
            deductionTotal: payslip.deductionTotal,
            advanceRecoveryTotal: payslip.advanceRecoveryTotal,
            garnishmentReservedTotal: payslip.garnishmentReservedTotal,
            netFinal: payslip.netFinal,
            breakdown: payslip.breakdown,
            sourceRefs: <String, dynamic>{
              ...payslip.sourceRefs,
              'payroll_run_id': run.id,
            },
            status: payslip.status,
            generatedAt: payslip.generatedAt,
            createdAt: payslip.createdAt,
            updatedAt: now,
          ),
        );
      }
    }

    return run;
  }

  Future<HrPayrollAccountingReport?> generateAccountingReportForMonth({
    required DateTime payrollMonth,
    String generatedByUserId = '',
    String notes = '',
  }) async {
    final month = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final existingRun = await findRunForMonth(month);
    if (existingRun?.isLocked == true) {
      return findAccountingReportForMonth(month);
    }
    final run = await generatePayrollRunForMonth(
      payrollMonth: month,
      generatedByUserId: generatedByUserId,
      notes: notes,
    );
    final payslips = await listPayslipsForMonth(month);
    if (payslips.isEmpty) return null;

    final profiles = await _employeeCatalogService.listProfiles();
    final profileByEmployeeId = <String, HrEmployeeProfile>{
      for (final item in profiles) item.employeeId.trim(): item,
    };
    final existing = await findAccountingReportForMonth(month);
    final now = DateTime.now();

    double sumBy(num Function(HrPayslip row) selector) {
      return payslips.fold<double>(0, (sum, row) => sum + selector(row));
    }

    double breakdown(HrPayslip item, String section, String key) {
      final sec = item.breakdown[section];
      if (sec is Map) {
        final v = sec[key];
        if (v is num) return v.toDouble();
      }
      return 0.0;
    }

    final lineItems = payslips.map((item) {
      final profile = profileByEmployeeId[item.employeeId.trim()];
      final contractMap = item.breakdown['contract'];
      final jobTitle = contractMap is Map
          ? (contractMap['job_title'] ?? '').toString()
          : '';
      return <String, dynamic>{
        'employee_id': item.employeeId,
        'employee_name': profile?.fullName.trim().isNotEmpty == true
            ? profile!.fullName.trim()
            : item.employeeId,
        'job_title': jobTitle,
        'worked_hours': breakdown(item, 'attendance_leave_inputs', 'worked_hours'),
        'gross_total': item.grossTotal,
        'cas_amount': item.casAmount,
        'cass_amount': item.cassAmount,
        'venit_net': breakdown(item, 'salary_tax_percentages', 'venit_net'),
        'personal_deduction_amount':
            breakdown(item, 'salary_tax_percentages', 'personal_deduction_amount'),
        'taxable_base_for_income_tax':
            breakdown(item, 'salary_tax_percentages', 'taxable_base_for_income_tax'),
        'income_tax_amount': item.incomeTaxAmount,
        'net_without_tm':
            breakdown(item, 'salary_tax_percentages', 'net_without_tm'),
        'meal_ticket_total':
            breakdown(item, 'salary_tax_percentages', 'meal_ticket_total'),
        'net_final': item.netFinal,
        'deduction_total': item.deductionTotal,
        'advance_recovery_total': item.advanceRecoveryTotal,
        'garnishment_reserved_total': item.garnishmentReservedTotal,
        'status': item.status,
      };
    }).toList(growable: false)
      ..sort((a, b) => (a['employee_name'] ?? '')
          .toString()
          .compareTo((b['employee_name'] ?? '').toString()));

    double sumLineItems(String key) =>
        lineItems.fold<double>(0, (s, row) {
          final v = row[key];
          return s + (v is num ? v.toDouble() : 0.0);
        });

    final totals = <String, dynamic>{
      'gross_total': sumBy((row) => row.grossTotal),
      'cas_amount': sumBy((row) => row.casAmount),
      'cass_amount': sumBy((row) => row.cassAmount),
      'income_tax_amount': sumBy((row) => row.incomeTaxAmount),
      'deduction_total': sumBy((row) => row.deductionTotal),
      'advance_recovery_total': sumBy((row) => row.advanceRecoveryTotal),
      'garnishment_reserved_total':
          sumBy((row) => row.garnishmentReservedTotal),
      'net_final': sumBy((row) => row.netFinal),
      'venit_net': sumLineItems('venit_net'),
      'personal_deduction_amount': sumLineItems('personal_deduction_amount'),
      'taxable_base_for_income_tax': sumLineItems('taxable_base_for_income_tax'),
      'net_without_tm': sumLineItems('net_without_tm'),
      'meal_ticket_total': sumLineItems('meal_ticket_total'),
    };

    final report = HrPayrollAccountingReport(
      id: existing?.id ?? _buildAccountingReportId(month),
      payrollMonth: month,
      payrollRunId: run.id,
      jurisdiction: run.jurisdiction,
      status: 'ready_for_accounting',
      generatedAt: now,
      generatedByUserId: generatedByUserId,
      employeeCount: payslips.length,
      currency: payslips.first.currency,
      lineItems: lineItems,
      totals: totals,
      notes: notes,
      approvedAt: existing?.approvedAt,
      approvedByUserId: existing?.approvedByUserId ?? '',
      reviewedAt: existing?.reviewedAt,
      reviewedByUserId: existing?.reviewedByUserId ?? '',
      reviewNotes: existing?.reviewNotes ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await upsertAccountingReport(report);
    return report;
  }

  String _buildRunId(DateTime payrollMonth) {
    final monthKey =
        '${payrollMonth.year.toString().padLeft(4, '0')}-${payrollMonth.month.toString().padLeft(2, '0')}';
    return 'hr-payroll-run-$monthKey';
  }

  String _buildPayslipId(String employeeId, DateTime payrollMonth) {
    final monthKey =
        '${payrollMonth.year.toString().padLeft(4, '0')}-${payrollMonth.month.toString().padLeft(2, '0')}';
    return 'hr-payslip-${employeeId.trim()}-$monthKey';
  }

  String _buildAccountingReportId(DateTime payrollMonth) {
    final monthKey =
        '${payrollMonth.year.toString().padLeft(4, '0')}-${payrollMonth.month.toString().padLeft(2, '0')}';
    return 'hr-payroll-accounting-report-$monthKey';
  }
}
