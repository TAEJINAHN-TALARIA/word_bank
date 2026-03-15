// Firebase configuration for Word Bank
//
// Android uses google-services.json for configuration.
// This file provides fallback options and configuration for other platforms.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions는 이 플랫폼을 지원하지 않습니다.\n'
          'flutterfire configure를 실행하여 firebase_options.dart를 재생성하세요.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEfZdEDdt5P04SAHo-nVX-Tjr1sPSWT_g',
    appId: '1:886343252244:android:8b6bb8bd84b7d06b46ea01',
    messagingSenderId: '886343252244',
    projectId: 'wordbank-6284f',
    authDomain: 'wordbank-6284f.firebaseapp.com',
    storageBucket: 'wordbank-6284f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBEfZdEDdt5P04SAHo-nVX-Tjr1sPSWT_g',
    appId: '1:886343252244:android:8b6bb8bd84b7d06b46ea01',
    messagingSenderId: '886343252244',
    projectId: 'wordbank-6284f',
    storageBucket: 'wordbank-6284f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '886343252244',
    projectId: 'wordbank-6284f',
    storageBucket: 'wordbank-6284f.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.taejinahn.wordbank',
  );
}
