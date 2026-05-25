import 'scule_models.dart';

abstract class SculeCloudRepository {
  Future<List<ToolInventoryItem>> listTools();
  Stream<List<ToolInventoryItem>> watchTools();
  Future<void> upsertTool(ToolInventoryItem item);
  Future<void> deleteTool(String toolId);
  Future<List<ToolHandoverDocument>> listHandoverDocuments();
  Future<void> saveHandoverDocument(ToolHandoverDocument item);
  Future<List<ToolMovementEvent>> listMovementEvents(String toolId);
  Future<void> appendMovementEvent(ToolMovementEvent event);
  Future<List<String>> listToolCategories();
  Future<void> saveToolCategory(String category);
  Future<List<ToolTransferRequest>> listTransferRequests();
  Future<void> saveTransferRequest(ToolTransferRequest request);
  Future<List<ToolTransferNotification>> listTransferNotifications();
  Future<void> saveTransferNotification(ToolTransferNotification notification);
}
