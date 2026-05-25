import 'programare_kit_models.dart';

abstract class ProgramareKitCloudRepository {
  Future<List<AppointmentMaterialKitTemplate>> listTemplates();
  Future<void> upsertTemplate(AppointmentMaterialKitTemplate template);
  Future<void> deleteTemplate(String templateId);
}
