import '../../core/auth/app_role_policy.dart';
import '../../core/auth_models.dart';

enum AsocierePermission {
  viewAssigned,
  manageProject,
  manageOperations,
  viewFinancial,
  configureRates,
  approveCosts,
  confirmExternal,
  confirmSettlement,
  archive,
}

class AsociereAccessPolicy {
  const AsociereAccessPolicy._();

  static bool allows(String? roleKey, AsocierePermission permission) {
    final role = AppRolePolicy.fromRoleKey(roleKey);
    if (role == null || role == UserRole.admin) return true;
    return switch (role) {
      UserRole.birou => switch (permission) {
          AsocierePermission.configureRates ||
          AsocierePermission.approveCosts ||
          AsocierePermission.confirmExternal ||
          AsocierePermission.confirmSettlement ||
          AsocierePermission.archive =>
            false,
          _ => true,
        },
      UserRole.sefEchipa => switch (permission) {
          AsocierePermission.viewAssigned ||
          AsocierePermission.manageOperations =>
            true,
          _ => false,
        },
      UserRole.tehnician => permission == AsocierePermission.viewAssigned,
      UserRole.admin => true,
    };
  }

  static void require(String? roleKey, AsocierePermission permission) {
    if (!allows(roleKey, permission)) {
      throw StateError('Rolul curent nu are permisiunea ${permission.name}.');
    }
  }
}
