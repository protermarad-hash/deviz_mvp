import 'partner_worker_master_models.dart';

/// Interfață repository pentru catalogul de muncitori parteneri, auto-conținut
/// în jobs/ — pattern identic cu `AngajatiCloudRepository`
/// (lib/features/employees/angajati_cloud_repository.dart).
abstract class PartnerWorkerMasterRepository {
  Future<List<PartnerWorkerMaster>> listPartnerWorkerMasters();
  Stream<List<PartnerWorkerMaster>> watchPartnerWorkerMasters();
  Future<void> upsertPartnerWorkerMaster(PartnerWorkerMaster worker);
  Future<void> deletePartnerWorkerMaster(String workerId);
}
