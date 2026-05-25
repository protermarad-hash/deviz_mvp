import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_payroll_rule_models.dart';
import 'hr_payroll_rules_cloud_repository.dart';

class FirebaseHrPayrollRulesRepository
    implements HrPayrollRulesCloudRepository {
  FirebaseHrPayrollRulesRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ruleSetsCollection =>
      _firestore.collection(FirebaseCollections.hrRuleSets);

  CollectionReference<Map<String, dynamic>> get _ruleVersionsCollection =>
      _firestore.collection(FirebaseCollections.hrRuleVersions);

  @override
  Future<List<HrPayrollRuleSet>> listRuleSets() async {
    final snapshot = await _ruleSetsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrPayrollRuleSet.fromMap(_normalizeRuleSet(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  @override
  Future<List<HrPayrollRuleVersion>> listRuleVersions() async {
    final snapshot = await _ruleVersionsCollection.get();
    final rows = snapshot.docs
        .map(
          (doc) => HrPayrollRuleVersion.fromMap(_normalizeRuleVersion(doc.data())),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return rows;
  }

  @override
  Future<void> upsertRuleSet(HrPayrollRuleSet item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _ruleSetsCollection.doc(id).set(
      item.toMap(),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> upsertRuleVersion(HrPayrollRuleVersion item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _ruleVersionsCollection.doc(id).set(
      item.toMap(),
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _normalizeRuleSet(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'jurisdiction': (raw['jurisdiction'] ?? '').toString(),
      'scope': (raw['scope'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _normalizeRuleVersion(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'rule_set_id': (raw['rule_set_id'] ?? raw['ruleSetId'] ?? '').toString(),
      'jurisdiction': (raw['jurisdiction'] ?? '').toString(),
      'version_code': (raw['version_code'] ?? raw['versionCode'] ?? '').toString(),
      'effective_from':
          (raw['effective_from'] ?? raw['effectiveFrom'] ?? '').toString(),
      'effective_to':
          (raw['effective_to'] ?? raw['effectiveTo'] ?? '').toString(),
      'rule_type': (raw['rule_type'] ?? raw['ruleType'] ?? '').toString(),
      'rule_payload': raw['rule_payload'] ?? raw['rulePayload'] ?? const <String, dynamic>{},
      'legal_basis': (raw['legal_basis'] ?? raw['legalBasis'] ?? '').toString(),
      'is_default': raw['is_default'] ?? raw['isDefault'] ?? false,
      'is_overridable':
          raw['is_overridable'] ?? raw['isOverridable'] ?? false,
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }
}
