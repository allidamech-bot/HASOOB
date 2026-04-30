import '../models/auth_user_model.dart';
import '../models/business_model.dart';
import '../../core/business/business_context.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const String fallbackBusinessId = 'local_business_123';

  AuthUserModel? _currentUser;
  final List<AuthUserModel> _users = [];
  final List<BusinessModel> _businesses = [];

  AuthUserModel? get currentUser => _currentUser;

  Future<AuthUserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      throw const AuthException('Email and password cannot be empty.');
    }

    // Mock local delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if user exists in mock storage
    final existingUser = _users.firstWhere(
      (u) => u.email == email,
      orElse: () {
        // For development convenience, if not found, we could throw or create
        // Request says "Return user with stored businessId"
        throw const AuthException('User not found.');
      },
    );

    _currentUser = existingUser;
    BusinessContext.initialize(
      businessId: _currentUser!.businessId,
      userId: _currentUser!.id,
      role: _currentUser!.role,
    );
    return _currentUser!;
  }

  Future<AuthUserModel> registerWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw const AuthException('Email and password cannot be empty.');
    }

    // Mock local delay
    await Future.delayed(const Duration(milliseconds: 500));

    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final businessId = 'bus_${DateTime.now().millisecondsSinceEpoch}';

    // Create BusinessModel
    final business = BusinessModel(
      id: businessId,
      name: displayName ?? email.split('@').first,
      ownerId: userId,
      createdAt: DateTime.now(),
    );
    _businesses.add(business);

    // Create AuthUserModel
    final newUser = AuthUserModel(
      id: userId,
      email: email,
      displayName: displayName ?? email.split('@').first,
      businessId: businessId,
      role: 'owner',
    );
    _users.add(newUser);

    _currentUser = newUser;
    BusinessContext.initialize(
      businessId: _currentUser!.businessId,
      userId: _currentUser!.id,
      role: _currentUser!.role,
    );
    return _currentUser!;
  }

  Future<void> signOut() async {
    _currentUser = null;
  }

  // Helper for tests
  void clearMockData() {
    _users.clear();
    _businesses.clear();
    _currentUser = null;
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
