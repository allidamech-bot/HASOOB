import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = AuthRepository.instance;
      authRepository.clearMockData();
    });

    test('registerWithEmailAndPassword creates business and sets owner role', () async {
      const email = 'newuser@example.com';
      const password = 'password123';
      const displayName = 'New User';

      final user = await authRepository.registerWithEmailAndPassword(
        email,
        password,
        displayName: displayName,
      );

      expect(user.email, email);
      expect(user.role, 'owner');
      expect(user.businessId, isNotEmpty);
      expect(authRepository.currentUser, isNotNull);
      expect(authRepository.currentUser!.businessId, user.businessId);
    });

    test('login preserves businessId after registration', () async {
      const email = 'login_test@example.com';
      const password = 'password123';

      final registeredUser = await authRepository.registerWithEmailAndPassword(email, password);
      final registeredBusId = registeredUser.businessId;

      await authRepository.signOut();
      expect(authRepository.currentUser, isNull);

      final loggedInUser = await authRepository.signInWithEmailAndPassword(email, password);
      expect(loggedInUser.businessId, registeredBusId);
      expect(loggedInUser.role, 'owner');
    });

    test('empty email or password throws AuthException', () async {
      expect(
        () => authRepository.signInWithEmailAndPassword('', 'password'),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => authRepository.registerWithEmailAndPassword('email@test.com', ''),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut clears currentUser', () async {
      await authRepository.registerWithEmailAndPassword('test@example.com', 'password');
      expect(authRepository.currentUser, isNotNull);

      await authRepository.signOut();
      expect(authRepository.currentUser, isNull);
    });
  });
}
