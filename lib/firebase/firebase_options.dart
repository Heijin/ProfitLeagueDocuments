import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {

    // Конфигурация по платформам
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyA6KN7oOfV8xMyiQnoiA9xEHxwakjfazlo',
          appId: '1:555319309212:android:3bfda62bf85ae11c578e59',
          messagingSenderId: '555319309212',
          projectId: 'profit-league-documents',
          storageBucket: 'profit-league-documents.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyAutz_L3VIxdzSec-rroyztfls-v2H-B80',
          appId: '1:555319309212:ios:cbed8319645789d4578e59',
          messagingSenderId: '555319309212',
          projectId: 'profit-league-documents',
          storageBucket: 'profit-league-documents.firebasestorage.app',
          //iosClientId: '555319309212-abc123xyz.apps.googleusercontent.com',
          iosBundleId: 'ru.prlg.profit-league-documents',
        );
      default:
        throw UnsupportedError('FirebaseOptions не настроены для этой платформы');
    }
  }
}
