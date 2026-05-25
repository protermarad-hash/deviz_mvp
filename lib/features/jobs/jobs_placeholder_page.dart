import 'package:flutter/widgets.dart';

import '../../core/repositories/app_data_repository.dart';
import 'jobs_page.dart';

class JobsPlaceholderPage extends StatelessWidget {
  const JobsPlaceholderPage({super.key, required this.repository});

  final AppDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return JobsPage(repository: repository);
  }
}
