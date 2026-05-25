import 'package:flutter/material.dart';

import '../../core/repositories/app_data_repository.dart';
import 'registratura_dashboard_page.dart';

class RegistraturaPage extends StatelessWidget {
  const RegistraturaPage({
    super.key,
    required this.repository,
  });

  final AppDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return RegistraturaDashboardPage(repository: repository);
  }
}
