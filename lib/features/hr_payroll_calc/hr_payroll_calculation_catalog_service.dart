import '../../core/cloud/firebase_bootstrap.dart';
import '../hr_core/hr_employee_catalog_service.dart';
import '../hr_payroll_input/hr_payroll_input_catalog_service.dart';
import '../hr_payroll_input/hr_payroll_input_snapshot_models.dart';
import '../hr_rules/hr_payroll_rules_catalog_service.dart';
import 'firebase_hr_payroll_calculation_repository.dart';
import 'hr_payroll_calculation_cloud_repository.dart';
import 'hr_payroll_calculation_models.dart';
import 'hr_payroll_calculator.dart';
import 'local_hr_payroll_calculation_store.dart';

class HrPayrollCalculationCatalogService {
  HrPayrollCalculationCatalogService({
    HrPayrollCalculationCloudRepository? cloudRepository,
    LocalHrPayrollCalculationStore? localStore,
    HrPayrollCalculator? calculator,
    HrPayrollInputCatalogService? payrollInputCatalogService,
    HrEmployeeCatalogService? employeeCatalogService,
    HrPayrollRulesCatalogService? payrollRulesCatalogService,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrPayrollCalculationRepository()
                : null),
        _localStore = localStore ?? LocalHrPayrollCalculationStore(),
        _calculator = calculator ?? const HrPayrollCalculator(),
        _payrollInputCatalogService =
            payrollInputCatalogService ?? HrPayrollInputCatalogService(),
        _employeeCatalogService =
            employeeCatalogService ?? HrEmployeeCatalogService(),
        _payrollRulesCatalogService =
            payrollRulesCatalogService ?? HrPayrollRulesCatalogService();

  final HrPayrollCalculationCloudRepository? _cloudRepository;
  final LocalHrPayrollCalculationStore _localStore;
  final HrPayrollCalculator _calculator;
  final HrPayrollInputCatalogService _payrollInputCatalogService;
  final HrEmployeeCatalogService _employeeCatalogService;
  final HrPayrollRulesCatalogService _payrollRulesCatalogService;

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

  Future<List<HrPayrollCalculationResult>> listResults() async {
    final localRows = await _localStore.listResults();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listResults();
      await _localStore.saveResults(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrPayrollCalculationResult>> listResultsForMonth(
    DateTime payrollMonth,
  ) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listResults();
    return rows
        .where((item) =>
            item.payrollMonth.year == target.year &&
            item.payrollMonth.month == target.month)
        .toList(growable: false)
      ..sort((a, b) => a.employeeId.compareTo(b.employeeId));
  }

  Future<HrPayrollCalculationResult?> findResultForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) async {
    final target = DateTime(payrollMonth.year, payrollMonth.month, 1);
    final rows = await listResultsForMonth(target);
    for (final row in rows) {
      if (row.employeeId.trim() == employeeId.trim()) return row;
    }
    return null;
  }

  Future<void> upsertResult(HrPayrollCalculationResult item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertResult(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listResults()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveResults(local);
  }

  Future<HrPayrollCalculationResult?> calculatePayrollForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
    HrPayrollInputSnapshot? inputSnapshot,
  }) async {
    final existing = await findResultForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: payrollMonth,
    );
    final result = await _calculator.calculatePayrollForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: payrollMonth,
      payrollInputCatalogService: _payrollInputCatalogService,
      employeeCatalogService: _employeeCatalogService,
      payrollRulesCatalogService: _payrollRulesCatalogService,
      existing: existing,
      inputSnapshot: inputSnapshot,
    );
    if (result == null) return null;
    await upsertResult(result);
    return result;
  }

  Future<HrPayrollCalculationResult?> recalculatePayrollForEmployeeMonth({
    required String employeeId,
    required DateTime payrollMonth,
  }) {
    return calculatePayrollForEmployeeMonth(
      employeeId: employeeId,
      payrollMonth: payrollMonth,
    );
  }
}
