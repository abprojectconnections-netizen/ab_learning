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

  try {
    await Firebase.initializeApp(
        options: FirebaseOptionsFromEnvironment.currentPlatform);
  } on StateError catch (error) {
    // Missing --dart-define values: show the cause instead of a blank page.
    runApp(StartupErrorApp(message: error.message));
    return;
  }
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
      defaultValue: 8180,
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

/// Shown when the app cannot start because configuration is missing.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firebase is not configured',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  SelectableText(message),
                  const SizedBox(height: 12),
                  const Text(
                      'Pass FIREBASE_API_KEY, FIREBASE_PROJECT_ID, '
                      'FIREBASE_MESSAGING_SENDER_ID, FIREBASE_APP_ID_WEB and '
                      'FIREBASE_AUTH_DOMAIN with --dart-define. '
                      'See docs/environment_setup.md.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
