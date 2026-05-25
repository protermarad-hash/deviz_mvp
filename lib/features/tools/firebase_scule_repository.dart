import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'scule_cloud_repository.dart';
import 'scule_models.dart';

class FirebaseSculeRepository implements SculeCloudRepository {
  FirebaseSculeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.tools);

  CollectionReference<Map<String, dynamic>> get _handoverDocuments =>
      _firestore.collection(FirebaseCollections.toolHandovers);

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection(FirebaseCollections.toolCategories);

  CollectionReference<Map<String, dynamic>> get _transferRequests =>
      _firestore.collection(FirebaseCollections.toolTransferRequests);

  CollectionReference<Map<String, dynamic>> get _transferNotifications =>
      _firestore.collection(FirebaseCollections.toolTransferNotifications);

  CollectionReference<Map<String, dynamic>> _historyCollection(String toolId) =>
      _collection.doc(toolId).collection('history');

  @override
  Future<void> deleteTool(String toolId) async {
    final id = toolId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<void> appendMovementEvent(ToolMovementEvent event) async {
    final toolId = event.toolId.trim();
    final id = event.id.trim();
    if (toolId.isEmpty || id.isEmpty) return;
    await _historyCollection(toolId).doc(id).set(
          _normalizeMovement(event.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<ToolInventoryItem>> listTools() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => ToolInventoryItem.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<ToolMovementEvent>> listMovementEvents(String toolId) async {
    final id = toolId.trim();
    if (id.isEmpty) return const <ToolMovementEvent>[];
    final snapshot = await _historyCollection(id).get();
    final rows = snapshot.docs
        .map((doc) => ToolMovementEvent.fromMap(_normalizeMovement(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return rows;
  }

  @override
  Future<void> upsertTool(ToolInventoryItem item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
          _toCloud(item),
          SetOptions(merge: true),
        );
  }

  @override
  Stream<List<ToolInventoryItem>> watchTools() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ToolInventoryItem.fromMap(_normalize(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  @override
  Future<List<ToolHandoverDocument>> listHandoverDocuments() async {
    final snapshot = await _handoverDocuments.get();
    final rows = snapshot.docs
        .map((doc) => ToolHandoverDocument.fromMap(_normalizeHandover(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.documentDate.compareTo(a.documentDate));
    return rows;
  }

  @override
  Future<void> saveHandoverDocument(ToolHandoverDocument item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _handoverDocuments.doc(id).set(
          _normalizeHandover(item.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<String>> listToolCategories() async {
    final snapshot = await _categories.get();
    final rows = snapshot.docs
        .map((doc) => (doc.data()['label'] ?? '').toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    rows.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return rows;
  }

  @override
  Future<void> saveToolCategory(String category) async {
    final normalized = category.trim();
    if (normalized.isEmpty) return;
    final docId = normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    await _categories.doc(docId).set(
          <String, dynamic>{
            'id': docId,
            'label': normalized,
            'normalized_label': normalized.toLowerCase(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<ToolTransferRequest>> listTransferRequests() async {
    final snapshot = await _transferRequests.get();
    final rows = snapshot.docs
        .map((doc) => ToolTransferRequest.fromMap(_normalizeTransfer(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Future<void> saveTransferRequest(ToolTransferRequest request) async {
    final id = request.id.trim();
    if (id.isEmpty) return;
    await _transferRequests.doc(id).set(
          _normalizeTransfer(request.toMap()),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<ToolTransferNotification>> listTransferNotifications() async {
    final snapshot = await _transferNotifications.get();
    final rows = snapshot.docs
        .map(
          (doc) => ToolTransferNotification.fromMap(
            _normalizeTransferNotification(doc.data()),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Future<void> saveTransferNotification(
    ToolTransferNotification notification,
  ) async {
    final id = notification.id.trim();
    if (id.isEmpty) return;
    await _transferNotifications.doc(id).set(
          _normalizeTransferNotification(notification.toMap()),
          SetOptions(merge: true),
        );
  }

  Map<String, dynamic> _toCloud(ToolInventoryItem item) {
    return <String, dynamic>{
      ...item.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'category': (raw['category'] ?? '').toString(),
      'brand': (raw['brand'] ?? '').toString(),
      'model': (raw['model'] ?? '').toString(),
      'description': (raw['description'] ?? raw['descriere'] ?? '').toString(),
      'serial_number':
          (raw['serial_number'] ?? raw['serialNumber'] ?? '').toString(),
      'inventory_code':
          (raw['inventory_code'] ?? raw['inventoryCode'] ?? '').toString(),
      'purchase_date':
          (raw['purchase_date'] ?? raw['purchaseDate'] ?? '').toString(),
      'purchase_value': raw['purchase_value'] ?? raw['purchaseValue'] ?? 0,
      'unit': (raw['unit'] ?? '').toString(),
      'status': (raw['status'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'assigned_team_id':
          (raw['assigned_team_id'] ?? raw['assignedTeamId'] ?? '').toString(),
      'assigned_team_name': (raw['assigned_team_name'] ??
              raw['assignedTeamName'] ??
              '')
          .toString(),
      'assigned_employee_id':
          (raw['assigned_employee_id'] ?? raw['assignedEmployeeId'] ?? '')
              .toString(),
      'assigned_employee_name':
          (raw['assigned_employee_name'] ?? raw['assignedEmployeeName'] ?? '')
              .toString(),
      'assigned_at':
          (raw['assigned_at'] ?? raw['assignedAt'] ?? '').toString(),
      'assigned_by_user_id': (raw['assigned_by_user_id'] ??
              raw['assignedByUserId'] ??
              '')
          .toString(),
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

  Map<String, dynamic> _normalizeMovement(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'tool_id': (raw['tool_id'] ?? raw['toolId'] ?? '').toString(),
      'event_type': (raw['event_type'] ?? raw['eventType'] ?? '').toString(),
      'event_date': (raw['event_date'] ?? raw['eventDate'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'team_name': (raw['team_name'] ?? raw['teamName'] ?? '').toString(),
      'performed_by_user_id': (raw['performed_by_user_id'] ??
              raw['performedByUserId'] ??
              '')
          .toString(),
      'performed_by_user_email': (raw['performed_by_user_email'] ??
              raw['performedByUserEmail'] ??
              '')
          .toString(),
      'notes': (raw['notes'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _normalizeHandover(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'document_number':
          (raw['document_number'] ?? raw['documentNumber'] ?? '').toString(),
      'document_date':
          (raw['document_date'] ?? raw['documentDate'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'team_name': (raw['team_name'] ?? raw['teamName'] ?? '').toString(),
      'responsible_name':
          (raw['responsible_name'] ?? raw['responsibleName'] ?? '').toString(),
      'tool_ids': raw['tool_ids'] ?? raw['toolIds'] ?? const <dynamic>[],
      'lines': raw['lines'] ?? const <dynamic>[],
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

  Map<String, dynamic> _normalizeTransfer(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'tool_id': (raw['tool_id'] ?? raw['toolId'] ?? '').toString(),
      'inventory_code':
          (raw['inventory_code'] ?? raw['inventoryCode'] ?? '').toString(),
      'tool_name': (raw['tool_name'] ?? raw['toolName'] ?? '').toString(),
      'source_employee_id':
          (raw['source_employee_id'] ?? raw['sourceEmployeeId'] ?? '').toString(),
      'source_employee_name': (raw['source_employee_name'] ??
              raw['sourceEmployeeName'] ??
              '')
          .toString(),
      'target_employee_id':
          (raw['target_employee_id'] ?? raw['targetEmployeeId'] ?? '').toString(),
      'target_employee_name': (raw['target_employee_name'] ??
              raw['targetEmployeeName'] ??
              '')
          .toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'status': (raw['status'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '').toString(),
      'created_by_user_email': (raw['created_by_user_email'] ??
              raw['createdByUserEmail'] ??
              '')
          .toString(),
      'processed_at':
          (raw['processed_at'] ?? raw['processedAt'] ?? '').toString(),
      'processed_by_user_id': (raw['processed_by_user_id'] ??
              raw['processedByUserId'] ??
              '')
          .toString(),
      'processed_by_user_email': (raw['processed_by_user_email'] ??
              raw['processedByUserEmail'] ??
              '')
          .toString(),
      'decision_notes':
          (raw['decision_notes'] ?? raw['decisionNotes'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _normalizeTransferNotification(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'request_id': (raw['request_id'] ?? raw['requestId'] ?? '').toString(),
      'tool_id': (raw['tool_id'] ?? raw['toolId'] ?? '').toString(),
      'inventory_code':
          (raw['inventory_code'] ?? raw['inventoryCode'] ?? '').toString(),
      'tool_name': (raw['tool_name'] ?? raw['toolName'] ?? '').toString(),
      'source_employee_id':
          (raw['source_employee_id'] ?? raw['sourceEmployeeId'] ?? '').toString(),
      'source_employee_name': (raw['source_employee_name'] ??
              raw['sourceEmployeeName'] ??
              '')
          .toString(),
      'target_employee_id':
          (raw['target_employee_id'] ?? raw['targetEmployeeId'] ?? '').toString(),
      'target_employee_name': (raw['target_employee_name'] ??
              raw['targetEmployeeName'] ??
              '')
          .toString(),
      'message': (raw['message'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '').toString(),
      'created_by_user_email': (raw['created_by_user_email'] ??
              raw['createdByUserEmail'] ??
              '')
          .toString(),
      'processed': raw['processed'] == true,
      'processed_at':
          (raw['processed_at'] ?? raw['processedAt'] ?? '').toString(),
      'processed_by_user_id': (raw['processed_by_user_id'] ??
              raw['processedByUserId'] ??
              '')
          .toString(),
      'processed_by_user_email': (raw['processed_by_user_email'] ??
              raw['processedByUserEmail'] ??
              '')
          .toString(),
    };
  }
}
