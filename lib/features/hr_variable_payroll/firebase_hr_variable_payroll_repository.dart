import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_variable_payroll_cloud_repository.dart';
import 'hr_variable_payroll_models.dart';

class FirebaseHrVariablePayrollRepository
    implements HrVariablePayrollCloudRepository {
  FirebaseHrVariablePayrollRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bonusesCollection =>
      _firestore.collection(FirebaseCollections.hrBonuses);
  CollectionReference<Map<String, dynamic>> get _deductionsCollection =>
      _firestore.collection(FirebaseCollections.hrDeductions);
  CollectionReference<Map<String, dynamic>> get _advancesCollection =>
      _firestore.collection(FirebaseCollections.hrAdvances);
  CollectionReference<Map<String, dynamic>> get _garnishmentsCollection =>
      _firestore.collection(FirebaseCollections.hrGarnishments);

  @override
  Future<List<HrBonus>> listBonuses() async {
    final snapshot = await _bonusesCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrBonus.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.effectiveMonth.compareTo(a.effectiveMonth));
    return rows;
  }

  @override
  Future<List<HrDeduction>> listDeductions() async {
    final snapshot = await _deductionsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrDeduction.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.legalPriority.compareTo(b.legalPriority));
    return rows;
  }

  @override
  Future<List<HrAdvance>> listAdvances() async {
    final snapshot = await _advancesCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrAdvance.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.effectiveMonth.compareTo(a.effectiveMonth));
    return rows;
  }

  @override
  Future<List<HrGarnishment>> listGarnishments() async {
    final snapshot = await _garnishmentsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrGarnishment.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.legalPriority.compareTo(b.legalPriority));
    return rows;
  }

  @override
  Future<void> upsertBonus(HrBonus item) => _upsert(
        _bonusesCollection,
        item.id,
        item.toMap(),
      );

  @override
  Future<void> upsertDeduction(HrDeduction item) => _upsert(
        _deductionsCollection,
        item.id,
        item.toMap(),
      );

  @override
  Future<void> upsertAdvance(HrAdvance item) => _upsert(
        _advancesCollection,
        item.id,
        item.toMap(),
      );

  @override
  Future<void> upsertGarnishment(HrGarnishment item) => _upsert(
        _garnishmentsCollection,
        item.id,
        item.toMap(),
      );

  Future<void> _upsert(
    CollectionReference<Map<String, dynamic>> collection,
    String id,
    Map<String, dynamic> payload,
  ) async {
    final target = id.trim();
    if (target.isEmpty) return;
    await collection.doc(target).set(payload, SetOptions(merge: true));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw);
  }
}
