import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return web; // نستخدم نفس إعدادات web لويندوز
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDgPS4mzsNLIV1Qbqgl3iE5zaT0H8ByOeY',
    appId: '1:532543856833:web:8a2d44c376471c6b797440',
    messagingSenderId: '532543856833',
    projectId: 'hasoob-4a281',
    authDomain: 'hasoob-4a281.firebaseapp.com',
    storageBucket: 'hasoob-4a281.firebasestorage.app',
    measurementId: 'G-T9XPNLDDVY',
  );
}