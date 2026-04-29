enum UserRole {
  owner,
  manager,
  employee
}

class AppPermissions {
  static bool canManageUsers(String role) {
    return role == "owner";
  }

  static bool canEditProducts(String role) {
    return role == "owner" || role == "manager";
  }

  static bool canViewReports(String role) {
    return role == "owner" || role == "manager";
  }

  static bool canSell(String role) {
    return true;
  }

  static bool canDelete(String role) {
    return role == "owner";
  }
}
