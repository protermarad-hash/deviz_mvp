import 'pachete_scule_models.dart';

abstract class PacheteSculeCloudRepository {
  Future<List<ToolPackageRecord>> listPackages();
  Stream<List<ToolPackageRecord>> watchPackages();
  Future<void> upsertPackage(ToolPackageRecord item);
  Future<void> deletePackage(String packageId);
  Future<List<ToolPackageHandoverDocument>> listHandoverDocuments();
  Future<void> saveHandoverDocument(ToolPackageHandoverDocument item);
  Future<List<ToolPackageMovementEvent>> listMovementEvents(String packageId);
  Future<void> appendMovementEvent(ToolPackageMovementEvent item);
  Future<List<ToolPackageNotification>> listNotifications();
  Future<void> saveNotification(ToolPackageNotification item);
}
