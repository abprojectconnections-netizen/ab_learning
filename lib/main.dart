import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/config/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  final config = switch (env) {
    'beta' => AppConfig.beta,
    'production' => AppConfig.production,
    _ => AppConfig.dev,
  };

  await Firebase.initializeApp(
      options: FirebaseOptionsFromEnvironment.currentPlatform);
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (useEmulators) {
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    const host =
        kIsWeb && emulatorHost == '127.0.0.1' ? 'localhost' : emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    const firestorePort = int.fromEnvironment(
      'FIRESTORE_EMULATOR_PORT',
      defaultValue: 8081,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const ABLearningApp(),
    ),
  );
}
