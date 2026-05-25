import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'programare_kit_cloud_repository.dart';
import 'programare_kit_models.dart';

class FirebaseProgramareKitRepository
    implements ProgramareKitCloudRepository {
  FirebaseProgramareKitRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.appointmentMaterialKitTemplates);

  @override
  Future<void> deleteTemplate(String templateId) async {
    final id = templateId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<AppointmentMaterialKitTemplate>> listTemplates() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => AppointmentMaterialKitTemplate.fromMap(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<void> upsertTemplate(AppointmentMaterialKitTemplate template) async {
    await _collection.doc(template.id).set(
          template.toMap(),
          SetOptions(merge: true),
        );
  }
}
