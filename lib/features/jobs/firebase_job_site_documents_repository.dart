import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'job_site_document_models.dart';
import 'job_site_documents_cloud_repository.dart';

class FirebaseJobSiteDocumentsRepository
    implements JobSiteDocumentsCloudRepository {
  FirebaseJobSiteDocumentsRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.jobSiteDocuments);

  @override
  Future<void> deleteDocument(String documentId) async {
    final id = documentId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<JobSiteDocumentRecord>> listDocumentsForJob(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty) return const <JobSiteDocumentRecord>[];
    final snapshot = await _collection.where('job_id', isEqualTo: id).get();
    final rows = snapshot.docs
        .map((doc) => JobSiteDocumentRecord.fromMap(doc.data()))
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> upsertDocument(JobSiteDocumentRecord document) async {
    final id = document.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(document.toMap(), SetOptions(merge: true));
  }
}
