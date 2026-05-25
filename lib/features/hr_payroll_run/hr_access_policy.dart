import '../../core/auth/app_role_policy.dart';
import '../../core/auth_models.dart';

class HrAccessPolicy {
  const HrAccessPolicy._();

  // Self-service pentru angajat este activ.
  static const bool employeeHrSelfServiceEnabled = true;

  static bool canAccessHrModule(UserRole? role) {
    return AppRolePolicy.canAccessTeamLead(role);
  }

  static bool canViewFinancialHr(UserRole? role) {
    return AppRolePolicy.canAccessOffice(role);
  }

  static bool canManageSensitiveHr(UserRole? role) {
    return canViewFinancialHr(role);
  }

  static bool canApproveOperationalHr(UserRole? role) {
    return AppRolePolicy.canAccessTeamLead(role);
  }

  static bool canEditOperationalHr(UserRole? role) {
    return canApproveOperationalHr(role);
  }

  static bool canUseEmployeeSelfService(UserRole? role) {
    if (!employeeHrSelfServiceEnabled) return false;
    return AppRolePolicy.isEmployee(role);
  }

  static bool canUseEmployeeAttendanceSelfService(UserRole? role) {
    return canUseEmployeeSelfService(role);
  }

  static bool canUseEmployeeLeaveSelfService(UserRole? role) {
    return canUseEmployeeSelfService(role);
  }

  static bool canUseEmployeePayslipSelfService(UserRole? role) {
    return canUseEmployeeSelfService(role);
  }

  static bool canAccessEmployeeSelfServiceRoute(UserRole? role) {
    return canUseEmployeeSelfService(role);
  }
}
