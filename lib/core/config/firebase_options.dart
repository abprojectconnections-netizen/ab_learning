import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase app identifiers are supplied by FlutterFire per build environment.
/// These values are public client configuration, never server credentials.
class FirebaseOptionsFromEnvironment {
  static String _required(String key, String value) {
    if (value.isEmpty) {
      throw StateError(
          'Missing --dart-define=$key for Firebase initialization.');
    }
    return value;
  }

  static FirebaseOptions get currentPlatform {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const webAppId = String.fromEnvironment('FIREBASE_APP_ID_WEB');
    const androidAppId = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
    const iosAppId = String.fromEnvironment('FIREBASE_APP_ID_IOS');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

    final appId = kIsWeb
        ? _required('FIREBASE_APP_ID_WEB', webAppId)
        : switch (defaultTargetPlatform) {
            TargetPlatform.android =>
              _required('FIREBASE_APP_ID_ANDROID', androidAppId),
            TargetPlatform.iOS ||
            TargetPlatform.macOS =>
              _required('FIREBASE_APP_ID_IOS', iosAppId),
            _ => throw UnsupportedError(
                'Firebase Auth MVP supports Web, Android, and iOS.'),
          };

    return FirebaseOptions(
      apiKey: _required('FIREBASE_API_KEY', apiKey),
      appId: appId,
      messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID', senderId),
      projectId: _required('FIREBASE_PROJECT_ID', projectId),
      authDomain: kIsWeb ? _required('FIREBASE_AUTH_DOMAIN', authDomain) : null,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
  }
}
