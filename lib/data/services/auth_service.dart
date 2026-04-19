import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapCodeToMessage(error.code));
    } catch (_) {
      throw const AuthException('حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.');
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await signIn(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email?.trim() ?? email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapCodeToMessage(error.code));
    } on FirebaseException {
      throw const AuthException(
        'تم إنشاء الحساب لكن حدثت مشكلة أثناء حفظ بيانات المستخدم في قاعدة البيانات.',
      );
    } catch (_) {
      throw const AuthException('حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.');
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> logout() => signOut();

  String _mapCodeToMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'يرجى إدخال بريد إلكتروني صحيح.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'يوجد حساب مسجل بهذا البريد الإلكتروني.';
      case 'weak-password':
        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالشبكة. تحقق من الإنترنت ثم حاول مجدداً.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالبريد الإلكتروني غير مفعّل في Firebase حالياً.';
      default:
        return 'فشلت عملية المصادقة. حاول مرة أخرى.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}