import 'job_models.dart';

abstract class LucrariCloudRepository {
  Future<List<JobRecord>> listJobs();
  Stream<List<JobRecord>> watchJobs();
  Future<void> upsertJob(JobRecord job);
  Future<void> deleteJob(String jobId);
}

