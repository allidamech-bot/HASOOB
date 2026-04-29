import '../models/auth_user_model.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  AuthUserModel? _currentUser;

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

    _currentUser = AuthUserModel(
      id: 'mock_user_123',
      email: email,
      displayName: email.split('@').first,
      businessId: 'mock_business_456',
      role: 'admin',
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

    _currentUser = AuthUserModel(
      id: 'mock_user_789',
      email: email,
      displayName: displayName ?? email.split('@').first,
      businessId: 'mock_business_000',
      role: 'owner',
    );

    return _currentUser!;
  }

  Future<void> signOut() async {
    _currentUser = null;
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
