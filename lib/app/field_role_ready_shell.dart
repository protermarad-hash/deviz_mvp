import 'package:flutter/material.dart';

import '../core/auth/field_auth_service.dart';
import '../core/auth/field_auth_models.dart';
import '../core/update/update_available_banner.dart';
import '../features/notifications/notification_runtime_service.dart';

class FieldRoleReadyShell extends StatelessWidget {
  const FieldRoleReadyShell({
    super.key,
    required this.authService,
    required this.child,
    this.onLogout,
  });

  final FieldAuthService authService;
  final Widget child;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    // Afișează numele real din Firestore dacă e disponibil, altfel email-ul
    final displayName = (authService.userName ?? '').isNotEmpty
        ? authService.userName!
        : (authService.userEmail ?? '').isNotEmpty
            ? (authService.userEmail!.contains('@')
                ? authService.userEmail!.split('@').first
                : authService.userEmail!)
            : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForRole(authService.role)),
        actions: [
          if (displayName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  displayName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await NotificationRuntimeService.instance.deactivateCurrentDevice();
              await authService.logout();
              onLogout?.call();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateAvailableBanner(),
          Expanded(child: child),
        ],
      ),
    );
  }

  String _titleForRole(FieldUserRole? role) {
    switch (role) {
      case FieldUserRole.admin:
        return 'Panou admin';
      case FieldUserRole.office:
        return 'Panou office';
      case FieldUserRole.teamLead:
        return 'Panou șef echipă';
      case FieldUserRole.employee:
        return 'Panou angajat';
      case null:
        return 'Aplicație';
    }
  }
}
