import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Конфигурация для Web
      return const FirebaseOptions(
        apiKey: 'AIzaSyD31PUKCR1HRCZYsSxxE-XZZVSx9An_Uj4',
        authDomain: 'profit-league-documents.firebaseapp.com',
        projectId: 'profit-league-documents',
        storageBucket: 'profit-league-documents.firebasestorage.app',
        messagingSenderId: '555319309212',
        appId: '1:555319309212:web:e0ce8b6d75336697578e59',
        measurementId: 'G-BV3NNZQHND',
      );
    }

    // Конфигурация по платформам
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyA6KN7oOfV8xMyiQnoiA9xEHxwakjfazlo',
          appId: '1:555319309212:android:3bfda62bf85ae11c578e59',
          messagingSenderId: '555319309212',
          projectId: '555319309212',
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
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyD..._MACOS',
          appId: '1:555319309212:macos:xxxxxxxxxxxxxxxxxxx',
          messagingSenderId: '555319309212',
          projectId: 'profit-league-documents',
          storageBucket: 'profit-league-documents.appspot.com',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const FirebaseOptions(
          apiKey: 'AIzaSyD..._DESKTOP',
          appId: '1:555319309212:desktop:xxxxxxxxxxxxxxxxxxx',
          messagingSenderId: '555319309212',
          projectId: 'profit-league-documents',
          storageBucket: 'profit-league-documents.appspot.com',
        );
      default:
        throw UnsupportedError('FirebaseOptions не настроены для этой платформы');
    }
  }
}
