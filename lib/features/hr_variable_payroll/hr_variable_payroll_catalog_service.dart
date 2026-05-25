import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_hr_variable_payroll_repository.dart';
import 'hr_variable_payroll_cloud_repository.dart';
import 'hr_variable_payroll_models.dart';
import 'hr_variable_payroll_resolver.dart';
import 'local_hr_variable_payroll_store.dart';

class HrVariablePayrollCatalogService {
  HrVariablePayrollCatalogService({
    HrVariablePayrollCloudRepository? cloudRepository,
    LocalHrVariablePayrollStore? localStore,
    HrVariablePayrollResolver? resolver,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrVariablePayrollRepository()
                : null),
        _localStore = localStore ?? LocalHrVariablePayrollStore(),
        _resolver = resolver ?? const HrVariablePayrollResolver();

  final HrVariablePayrollCloudRepository? _cloudRepository;
  final LocalHrVariablePayrollStore _localStore;
  final HrVariablePayrollResolver _resolver;

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

  Future<List<HrBonus>> listBonuses() async {
    final localRows = await _localStore.listBonuses();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listBonuses();
      await _localStore.saveBonuses(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrDeduction>> listDeductions() async {
    final localRows = await _localStore.listDeductions();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listDeductions();
      await _localStore.saveDeductions(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrAdvance>> listAdvances() async {
    final localRows = await _localStore.listAdvances();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listAdvances();
      await _localStore.saveAdvances(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrGarnishment>> listGarnishments() async {
    final localRows = await _localStore.listGarnishments();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listGarnishments();
      await _localStore.saveGarnishments(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<void> upsertBonus(HrBonus item) async {
    await _upsertItem<HrBonus>(
      item: item,
      remote: (cloud) => cloud.upsertBonus(item),
      listLocal: _localStore.listBonuses,
      saveLocal: _localStore.saveBonuses,
      idOf: (row) => row.id,
    );
  }

  Future<void> upsertDeduction(HrDeduction item) async {
    await _upsertItem<HrDeduction>(
      item: item,
      remote: (cloud) => cloud.upsertDeduction(item),
      listLocal: _localStore.listDeductions,
      saveLocal: _localStore.saveDeductions,
      idOf: (row) => row.id,
    );
  }

  Future<void> upsertAdvance(HrAdvance item) async {
    await _upsertItem<HrAdvance>(
      item: item,
      remote: (cloud) => cloud.upsertAdvance(item),
      listLocal: _localStore.listAdvances,
      saveLocal: _localStore.saveAdvances,
      idOf: (row) => row.id,
    );
  }

  Future<void> upsertGarnishment(HrGarnishment item) async {
    await _upsertItem<HrGarnishment>(
      item: item,
      remote: (cloud) => cloud.upsertGarnishment(item),
      listLocal: _localStore.listGarnishments,
      saveLocal: _localStore.saveGarnishments,
      idOf: (row) => row.id,
    );
  }

  Future<HrVariablePayrollMonthlyBundle> buildMonthlyBundle({
    required String employeeId,
    required DateTime month,
  }) async {
    final bonuses = await listBonuses();
    final deductions = await listDeductions();
    final advances = await listAdvances();
    final garnishments = await listGarnishments();
    return _resolver.buildMonthlyBundle(
      employeeId: employeeId,
      month: month,
      bonuses: bonuses,
      deductions: deductions,
      advances: advances,
      garnishments: garnishments,
    );
  }

  Future<List<HrBonus>> activeBonusesForMonth({
    required String employeeId,
    required DateTime month,
  }) async {
    final rows = await listBonuses();
    return _resolver.activeBonusesForMonth(
      rows,
      employeeId: employeeId,
      month: month,
    );
  }

  Future<List<HrDeduction>> activeDeductionsForMonth({
    required String employeeId,
    required DateTime month,
  }) async {
    final rows = await listDeductions();
    return _resolver.activeDeductionsForMonth(
      rows,
      employeeId: employeeId,
      month: month,
    );
  }

  Future<List<HrAdvance>> activeAdvancesForMonth({
    required String employeeId,
    required DateTime month,
  }) async {
    final rows = await listAdvances();
    return _resolver.activeAdvancesForMonth(
      rows,
      employeeId: employeeId,
      month: month,
    );
  }

  Future<List<HrGarnishment>> activeGarnishmentsForMonth({
    required String employeeId,
    required DateTime month,
  }) async {
    final rows = await listGarnishments();
    return _resolver.activeGarnishmentsForMonth(
      rows,
      employeeId: employeeId,
      month: month,
    );
  }

  Future<void> _upsertItem<T>({
    required T item,
    required Future<void> Function(HrVariablePayrollCloudRepository cloud)
        remote,
    required Future<List<T>> Function() listLocal,
    required Future<void> Function(List<T>) saveLocal,
    required String Function(T row) idOf,
  }) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await remote(cloud);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await listLocal()];
    final id = idOf(item);
    final index = local.indexWhere((row) => idOf(row) == id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await saveLocal(local);
  }
}
