import 'job_site_document_models.dart';

abstract class JobSiteDocumentsCloudRepository {
  Future<List<JobSiteDocumentRecord>> listDocumentsForJob(String jobId);
  Future<void> upsertDocument(JobSiteDocumentRecord document);
  Future<void> deleteDocument(String documentId);
}
