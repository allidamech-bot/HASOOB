import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/user_settings_model.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<UserSettingsModel> getUserSettings(String email) {
    return _firestore.collection('users').doc(email).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return UserSettingsModel(email: email, role: 'employee', permissions: {});
      }
      return UserSettingsModel.fromMap(doc.data()!, doc.id);
    });
  }

  @override
  Future<void> updateUserSettings(UserSettingsModel settings) async {
    await _firestore.collection('users').doc(settings.email).set(
          settings.toMap(),
          SetOptions(merge: true),
        );
  }
}
