import 'package:flutter/widgets.dart';

import '../../core/repositories/app_data_repository.dart';
import 'lucrari_page.dart';

class LucrariPlaceholderPage extends StatelessWidget {
  const LucrariPlaceholderPage({super.key, required this.repository});

  final AppDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return LucrariPage(repository: repository);
  }
}

class LucrariModulePage extends StatelessWidget {
  const LucrariModulePage({super.key, required this.repository});

  final AppDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return LucrariPage(repository: repository);
  }
}
