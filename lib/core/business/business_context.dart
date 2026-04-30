class BusinessContext {
  static String? _businessId;
  static String? _userId;
  static String? _role;

  static void initialize({
    required String businessId,
    required String userId,
    required String role,
  }) {
    _businessId = businessId;
    _userId = userId;
    _role = role;
  }

  static String get businessId => _businessId ?? 'demo-business';

  static String get userId => _userId ?? 'demo-user';

  static String get role => _role ?? 'employee';

  static String resolveBusinessId([String? businessId]) {
    if (businessId != null && businessId.trim().isNotEmpty) {
      return businessId;
    }
    return BusinessContext.businessId;
  }
}
