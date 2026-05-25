import '../../core/cloud/firebase_bootstrap.dart';
import 'firebase_hr_payroll_rules_repository.dart';
import 'hr_legal_rule_resolver.dart';
import 'hr_payroll_rule_models.dart';
import 'hr_payroll_rules_cloud_repository.dart';
import 'local_hr_payroll_rules_store.dart';

class HrPayrollRulesCatalogService {
  HrPayrollRulesCatalogService({
    HrPayrollRulesCloudRepository? cloudRepository,
    LocalHrPayrollRulesStore? localStore,
    HrLegalRuleResolver? resolver,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseHrPayrollRulesRepository()
                : null),
        _localStore = localStore ?? LocalHrPayrollRulesStore(),
        _resolver = resolver ?? const HrLegalRuleResolver();

  final HrPayrollRulesCloudRepository? _cloudRepository;
  final LocalHrPayrollRulesStore _localStore;
  final HrLegalRuleResolver _resolver;

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

  Future<List<HrPayrollRuleSet>> listRuleSets() async {
    final localRows = await _localStore.listRuleSets();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return HrPayrollRuleSeed.mergeRuleSetsWithRoDefaults(localRows);
    }
    try {
      final cloudRows = await cloud.listRuleSets();
      final merged = HrPayrollRuleSeed.mergeRuleSetsWithRoDefaults(cloudRows);
      await _localStore.saveRuleSets(merged);
      _markCloudPrimary();
      return merged;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return HrPayrollRuleSeed.mergeRuleSetsWithRoDefaults(localRows);
    }
  }

  Future<List<HrPayrollRuleVersion>> listRuleVersions() async {
    final localRows = await _localStore.listRuleVersions();
    final cloud = _cloudRepository;
    if (cloud == null) {
      _markLocalFallback('cloud_repository_unavailable');
      return HrPayrollRuleSeed.mergeWithRoDefaults(localRows);
    }
    try {
      final cloudRows = await cloud.listRuleVersions();
      final merged = HrPayrollRuleSeed.mergeWithRoDefaults(cloudRows);
      await _localStore.saveRuleVersions(merged);
      _markCloudPrimary();
      return merged;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      return HrPayrollRuleSeed.mergeWithRoDefaults(localRows);
    }
  }

  Future<void> upsertRuleSet(HrPayrollRuleSet item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertRuleSet(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listRuleSets()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveRuleSets(local);
  }

  Future<void> upsertRuleVersion(HrPayrollRuleVersion item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertRuleVersion(item);
        _markCloudPrimary();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback('cloud_unavailable:${_shortCloudError(error)}');
      }
    } else {
      _markLocalFallback('cloud_repository_unavailable');
    }
    final local = [...await _localStore.listRuleVersions()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveRuleVersions(local);
  }

  Future<HrPayrollRuleVersion?> resolveActiveRule({
    required String jurisdiction,
    required String scope,
    required String ruleType,
    required DateTime date,
  }) async {
    final rules = await listRuleVersions();
    return _resolver.resolveActiveRule(
      rules: rules,
      jurisdiction: jurisdiction,
      scope: scope,
      ruleType: ruleType,
      date: date,
    );
  }

  Future<HrPayrollRuleVersion?> resolveActiveRuleForPayrollMonth({
    required String jurisdiction,
    required String scope,
    required String ruleType,
    required DateTime payrollMonth,
  }) async {
    final rules = await listRuleVersions();
    return _resolver.resolveActiveRuleForPayrollMonth(
      rules: rules,
      jurisdiction: jurisdiction,
      scope: scope,
      ruleType: ruleType,
      payrollMonth: payrollMonth,
    );
  }
}
