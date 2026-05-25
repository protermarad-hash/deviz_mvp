import 'hr_payroll_accounting_report_models.dart';

abstract class HrPayrollAccountingReportCloudRepository {
  Future<List<HrPayrollAccountingReport>> listReports();
  Future<void> upsertReport(HrPayrollAccountingReport item);
}
