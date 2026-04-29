import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/data/repositories/auth_repository.dart';

void main() {
  group('AuthRepository', () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = AuthRepository.instance;
    });

    tearDown(() async {
      await authRepository.signOut();
    });

    test('signInWithEmailAndPassword returns a user and sets currentUser', () async {
      const email = 'test@example.com';
      const password = 'password123';

      final user = await authRepository.signInWithEmailAndPassword(email, password);

      expect(user.email, email);
      expect(authRepository.currentUser, isNotNull);
      expect(authRepository.currentUser!.email, email);
    });

    test('registerWithEmailAndPassword returns a user and sets currentUser', () async {
      const email = 'newuser@example.com';
      const password = 'password123';
      const displayName = 'New User';

      final user = await authRepository.registerWithEmailAndPassword(
        email,
        password,
        displayName: displayName,
      );

      expect(user.email, email);
      expect(user.displayName, displayName);
      expect(authRepository.currentUser, isNotNull);
      expect(authRepository.currentUser!.email, email);
    });

    test('empty email or password throws AuthException in signIn', () async {
      expect(
        () => authRepository.signInWithEmailAndPassword('', 'password'),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => authRepository.signInWithEmailAndPassword('email@test.com', ''),
        throwsA(isA<AuthException>()),
      );
    });

    test('empty email or password throws AuthException in register', () async {
      expect(
        () => authRepository.registerWithEmailAndPassword('', 'password'),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => authRepository.registerWithEmailAndPassword('email@test.com', ''),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut clears currentUser', () async {
      await authRepository.signInWithEmailAndPassword('test@example.com', 'password');
      expect(authRepository.currentUser, isNotNull);

      await authRepository.signOut();
      expect(authRepository.currentUser, isNull);
    });
  });
}
