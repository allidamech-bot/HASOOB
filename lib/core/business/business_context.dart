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

  static String get businessId {
    if (_businessId == null) {
      throw StateError('BusinessContext not initialized. Accessing businessId before authentication.');
    }
    return _businessId!;
  }

  static String get userId {
    if (_userId == null) {
      throw StateError('BusinessContext not initialized. Accessing userId before authentication.');
    }
    return _userId!;
  }

  static String get role {
    if (_role == null) {
      return 'employee';
    }
    return _role!;
  }

  static String resolveBusinessId([String? businessId]) {
    if (businessId != null && businessId.trim().isNotEmpty) {
      return businessId;
    }
    return BusinessContext.businessId;
  }
}
