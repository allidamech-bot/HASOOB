enum UserRole {
  owner,
  manager,
  accountant,
  employee,
}

enum Permission {
  manageBranches,
  manageInventory,
  manageFinancials,
  createInvoice,
  deleteInvoice,
  manageUsers,
  exportReports,
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  UserRole _currentUserRole = UserRole.employee;

  void setUserRole(UserRole role) {
    _currentUserRole = role;
  }

  bool hasPermission(Permission permission) {
    switch (_currentUserRole) {
      case UserRole.owner:
        return true; // Owner has all permissions
      case UserRole.manager:
        return permission != Permission.manageUsers; // Manager can't manage users (usually owner only)
      case UserRole.accountant:
        return [
          Permission.manageInventory,
          Permission.manageFinancials,
          Permission.createInvoice,
          Permission.exportReports,
        ].contains(permission);
      case UserRole.employee:
        return [
          Permission.createInvoice,
        ].contains(permission);
    }
  }

  bool canManageBranches() => hasPermission(Permission.manageBranches);
  bool canManageInventory() => hasPermission(Permission.manageInventory);
  bool canManageFinancials() => hasPermission(Permission.manageFinancials);
  bool canCreateInvoice() => hasPermission(Permission.createInvoice);
  bool canDeleteInvoice() => hasPermission(Permission.deleteInvoice);
  bool canManageUsers() => hasPermission(Permission.manageUsers);
  bool canExportReports() => hasPermission(Permission.exportReports);
}
