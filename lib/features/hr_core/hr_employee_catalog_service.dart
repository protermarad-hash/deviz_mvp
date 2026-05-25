import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_hr_employee_repository.dart';
import 'hr_contract_resolver.dart';
import 'hr_employee_cloud_repository.dart';
import 'hr_employee_models.dart';
import 'local_hr_employee_store.dart';

class HrEmployeeCatalogService {
  HrEmployeeCatalogService({
    HrEmployeeCloudRepository? cloudRepository,
    LocalHrEmployeeStore? localStore,
    HrContractResolver? contractResolver,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrEmployeeRepository()
                : null),
        _localStore = localStore ?? LocalHrEmployeeStore(),
        _contractResolver = contractResolver ?? const HrContractResolver();

  final HrEmployeeCloudRepository? _cloudRepository;
  final LocalHrEmployeeStore _localStore;
  final HrContractResolver _contractResolver;

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

  Future<List<HrEmployeeProfile>> listProfiles() async {
    final localRows = await _localStore.listProfiles();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listProfiles();
      await _localStore.saveProfiles(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<List<HrContract>> listContracts() async {
    final localRows = await _localStore.listContracts();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return localRows;
    }
    try {
      final cloudRows = await cloud.listContracts();
      await _localStore.saveContracts(cloudRows);
      _markCloudPrimary();
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return localRows;
    }
  }

  Future<void> upsertProfile(HrEmployeeProfile item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertProfile(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listProfiles()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveProfiles(local);
  }

  Future<void> upsertContract(HrContract item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertContract(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listContracts()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveContracts(local);
  }

  Future<HrEmployeeProfile?> findProfileByEmployeeId(String employeeId) async {
    final target = employeeId.trim();
    if (target.isEmpty) return null;
    final rows = await listProfiles();
    for (final row in rows) {
      if (row.employeeId.trim() == target) return row;
    }
    return null;
  }

  Future<HrContract?> resolveActiveContract({
    required String employeeId,
    required DateTime date,
  }) async {
    final contracts = await listContracts();
    return _contractResolver.resolveActiveContract(
      contracts: contracts,
      employeeId: employeeId,
      date: date,
    );
  }
}
