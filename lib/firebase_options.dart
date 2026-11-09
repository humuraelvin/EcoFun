import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase settings for the Android and iOS apps already registered in Firebase.
/// Web and desktop registrations need their own Firebase client configuration.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('EcoStep has no Firebase web app registered yet.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'EcoStep Firebase is configured for Android and iOS only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmLV8C7-36-9gbKBY--I4T5xgYyHW3yuY',
    appId: '1:749042750071:android:7261406e83a2706bbaac72',
    messagingSenderId: '749042750071',
    projectId: 'ecostep-92e88',
    storageBucket: 'ecostep-92e88.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCWPZvw8xHbNBRJHLoKOUFMHW_Ad0MJfgk',
    appId: '1:749042750071:ios:c7a2c0c7ca9d74ecbaac72',
    messagingSenderId: '749042750071',
    projectId: 'ecostep-92e88',
    storageBucket: 'ecostep-92e88.firebasestorage.app',
    iosBundleId: 'io.github.a3xhaust.ecostep',
  );
}
