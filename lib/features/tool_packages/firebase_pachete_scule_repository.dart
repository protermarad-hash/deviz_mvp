import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'pachete_scule_cloud_repository.dart';
import 'pachete_scule_models.dart';

class FirebasePacheteSculeRepository implements PacheteSculeCloudRepository {
  FirebasePacheteSculeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.toolPackages);

  CollectionReference<Map<String, dynamic>> get _handoverCollection =>
      _firestore.collection(FirebaseCollections.toolPackageHandovers);

  CollectionReference<Map<String, dynamic>> get _movementCollection =>
      _firestore.collection(FirebaseCollections.toolPackageMovements);

  CollectionReference<Map<String, dynamic>> get _notificationCollection =>
      _firestore.collection(FirebaseCollections.toolPackageNotifications);

  @override
  Future<void> deletePackage(String packageId) async {
    final id = packageId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<ToolPackageHandoverDocument>> listHandoverDocuments() async {
    final snapshot = await _handoverCollection.get();
    final rows = snapshot.docs
        .map((doc) => ToolPackageHandoverDocument.fromMap(_normalizeHandover(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.documentDate.compareTo(a.documentDate));
    return rows;
  }

  @override
  Future<List<ToolPackageMovementEvent>> listMovementEvents(String packageId) async {
    final id = packageId.trim();
    if (id.isEmpty) return const <ToolPackageMovementEvent>[];
    final snapshot =
        await _movementCollection.where('package_id', isEqualTo: id).get();
    final rows = snapshot.docs
        .map(
          (doc) => ToolPackageMovementEvent.fromMap(
            _normalizeMovement(doc.data()),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return rows;
  }

  @override
  Future<void> appendMovementEvent(ToolPackageMovementEvent item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _movementCollection.doc(id).set(
          _toCloudMovement(item),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<ToolPackageNotification>> listNotifications() async {
    final snapshot = await _notificationCollection.get();
    final rows = snapshot.docs
        .map(
          (doc) => ToolPackageNotification.fromMap(
            _normalizeNotification(doc.data()),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Future<void> saveNotification(ToolPackageNotification item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _notificationCollection.doc(id).set(
          _toCloudNotification(item),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> saveHandoverDocument(ToolPackageHandoverDocument item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _handoverCollection.doc(id).set(
          _toCloudHandover(item),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<ToolPackageRecord>> listPackages() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => ToolPackageRecord.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertPackage(ToolPackageRecord item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
          _toCloud(item),
          SetOptions(merge: true),
        );
  }

  @override
  Stream<List<ToolPackageRecord>> watchPackages() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ToolPackageRecord.fromMap(_normalize(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _toCloud(ToolPackageRecord item) {
    return <String, dynamic>{
      ...item.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    final toolIdsRaw = raw['tool_ids'] ?? raw['toolIds'] ?? const <dynamic>[];
    final toolIds = toolIdsRaw is List
        ? toolIdsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final toolCodesRaw =
        raw['tool_inventory_codes'] ?? raw['toolInventoryCodes'] ?? const <dynamic>[];
    final toolCodes = toolCodesRaw is List
        ? toolCodesRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'status': (raw['status'] ?? '').toString(),
      'tool_ids': toolIds,
      'tool_inventory_codes': toolCodes,
      'assigned_team_id':
          (raw['assigned_team_id'] ?? raw['assignedTeamId'] ?? '').toString(),
      'assigned_team_name':
          (raw['assigned_team_name'] ?? raw['assignedTeamName'] ?? '').toString(),
      'assigned_at':
          (raw['assigned_at'] ?? raw['assignedAt'] ?? '').toString(),
      'assigned_by_user_id':
          (raw['assigned_by_user_id'] ?? raw['assignedByUserId'] ?? '').toString(),
      'assigned_by_user_email': (raw['assigned_by_user_email'] ??
              raw['assignedByUserEmail'] ??
              '')
          .toString(),
      'created_at':
          (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at':
          (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _toCloudHandover(ToolPackageHandoverDocument item) {
    return <String, dynamic>{
      ...item.toMap(),
      'created_at': item.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeHandover(Map<String, dynamic> raw) {
    final toolIdsRaw = raw['tool_ids'] ?? raw['toolIds'] ?? const <dynamic>[];
    final toolIds = toolIdsRaw is List
        ? toolIdsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'document_number':
          (raw['document_number'] ?? raw['documentNumber'] ?? '').toString(),
      'document_date':
          (raw['document_date'] ?? raw['documentDate'] ?? '').toString(),
      'package_id': (raw['package_id'] ?? raw['packageId'] ?? '').toString(),
      'package_name':
          (raw['package_name'] ?? raw['packageName'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'team_name': (raw['team_name'] ?? raw['teamName'] ?? '').toString(),
      'operation_type':
          (raw['operation_type'] ?? raw['operationType'] ?? 'predare').toString(),
      'tool_ids': toolIds,
      'file_path': (raw['file_path'] ?? raw['filePath'] ?? '').toString(),
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '').toString(),
      'created_by_user_email': (raw['created_by_user_email'] ??
              raw['createdByUserEmail'] ??
              '')
          .toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _toCloudMovement(ToolPackageMovementEvent item) {
    return <String, dynamic>{
      ...item.toMap(),
      'event_date': item.eventDate.toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeMovement(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'package_id': (raw['package_id'] ?? raw['packageId'] ?? '').toString(),
      'package_name':
          (raw['package_name'] ?? raw['packageName'] ?? '').toString(),
      'event_type': (raw['event_type'] ?? raw['eventType'] ?? '').toString(),
      'event_date': (raw['event_date'] ?? raw['eventDate'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'team_name': (raw['team_name'] ?? raw['teamName'] ?? '').toString(),
      'performed_by_user_id':
          (raw['performed_by_user_id'] ?? raw['performedByUserId'] ?? '')
              .toString(),
      'performed_by_user_email': (raw['performed_by_user_email'] ??
              raw['performedByUserEmail'] ??
              '')
          .toString(),
      'notes': (raw['notes'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _toCloudNotification(ToolPackageNotification item) {
    return <String, dynamic>{
      ...item.toMap(),
      'created_at': item.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'package_id': (raw['package_id'] ?? raw['packageId'] ?? '').toString(),
      'package_name':
          (raw['package_name'] ?? raw['packageName'] ?? '').toString(),
      'target_team_id':
          (raw['target_team_id'] ?? raw['targetTeamId'] ?? '').toString(),
      'target_team_name':
          (raw['target_team_name'] ?? raw['targetTeamName'] ?? '').toString(),
      'source_team_id':
          (raw['source_team_id'] ?? raw['sourceTeamId'] ?? '').toString(),
      'source_team_name':
          (raw['source_team_name'] ?? raw['sourceTeamName'] ?? '').toString(),
      'event_type': (raw['event_type'] ?? raw['eventType'] ?? '').toString(),
      'message': (raw['message'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '').toString(),
      'created_by_user_email': (raw['created_by_user_email'] ??
              raw['createdByUserEmail'] ??
              '')
          .toString(),
      'processed': raw['processed'] == true,
      'processed_at': (raw['processed_at'] ?? raw['processedAt'] ?? '').toString(),
      'processed_by_user_id':
          (raw['processed_by_user_id'] ?? raw['processedByUserId'] ?? '')
              .toString(),
      'processed_by_user_email': (raw['processed_by_user_email'] ??
              raw['processedByUserEmail'] ??
              '')
          .toString(),
      'received_at': (raw['received_at'] ?? raw['receivedAt'] ?? '').toString(),
      'received_by_user_id':
          (raw['received_by_user_id'] ?? raw['receivedByUserId'] ?? '')
              .toString(),
      'received_by_user_email': (raw['received_by_user_email'] ??
              raw['receivedByUserEmail'] ??
              '')
          .toString(),
    };
  }
}
