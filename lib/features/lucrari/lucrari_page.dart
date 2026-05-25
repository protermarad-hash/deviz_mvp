import 'package:flutter/widgets.dart';

import '../../core/repositories/app_data_repository.dart';
import '../jobs/jobs_page.dart';

class LucrariPage extends StatelessWidget {
  const LucrariPage({
    super.key,
    required this.repository,
    this.fieldAuthRoleKey,
    this.fieldAuthUserId,
    this.fieldAuthUserLabel,
    this.fieldAuthTeamId,
  });

  final AppDataRepository repository;
  final String? fieldAuthRoleKey;
  final String? fieldAuthUserId;
  final String? fieldAuthUserLabel;
  final String? fieldAuthTeamId;

  @override
  Widget build(BuildContext context) {
    return JobsPage(
      repository: repository,
      fieldAuthRoleKey: fieldAuthRoleKey,
      fieldAuthUserId: fieldAuthUserId,
      fieldAuthUserLabel: fieldAuthUserLabel,
      fieldAuthTeamId: fieldAuthTeamId,
    );
  }
}
