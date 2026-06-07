class UserSettingsModel {
  final String email;
  final String role; // 'owner' | 'manager' | 'employee'
  final Map<String, bool> permissions;

  UserSettingsModel({
    required this.email,
    required this.role,
    required this.permissions,
  });

  factory UserSettingsModel.fromMap(Map<String, dynamic> map, String emailId) {
    return UserSettingsModel(
      email: emailId,
      role: map['role'] ?? 'employee',
      permissions: Map<String, bool>.from(map['permissions'] ?? {
        'canEditInventory': false,
        'canViewReports': false,
        'canManageInvoices': false,
      }),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'permissions': permissions,
    };
  }
}
