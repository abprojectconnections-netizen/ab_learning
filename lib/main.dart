
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'core/config/app_config.dart';
import 'core/config/firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --------------------------------------------------
  // 1. Application Environment
  // --------------------------------------------------

  const env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  final config = switch (env) {
    'beta' => AppConfig.beta,
    'production' => AppConfig.production,
    _ => AppConfig.dev,
  };

  // --------------------------------------------------
  // 2. Firebase Initialization
  // --------------------------------------------------

  try {
    await Firebase.initializeApp(
      options: FirebaseOptionsFromEnvironment.currentPlatform,
    );

    // ------------------------------------------------
    // 3. Firebase Emulator Configuration
    // ------------------------------------------------

    const useEmulators = bool.fromEnvironment(
      'USE_FIREBASE_EMULATORS',
      defaultValue: false,
    );

    if (useEmulators) {
      const emulatorHost = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );

      // Chrome ใช้ localhost แทน 127.0.0.1
      // เพื่อหลีกเลี่ยงปัญหา host resolution
      final host = kIsWeb && emulatorHost == '127.0.0.1'
          ? 'localhost'
          : emulatorHost;

      // Firebase Authentication Emulator
      await FirebaseAuth.instance.useAuthEmulator(
        host,
        9099,
      );

      // Firestore Emulator
      const firestorePort = int.fromEnvironment(
        'FIRESTORE_EMULATOR_PORT',
        defaultValue: 8180,
      );

      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        firestorePort,
      );

      // Cloud Functions Emulator
      FirebaseFunctions.instance.useFunctionsEmulator(
        host,
        5001,
      );

      await FirebaseStorage.instance.useStorageEmulator(host, 9199);

      debugPrint('Firebase Emulators connected:');
      debugPrint('Auth: $host:9099');
      debugPrint('Firestore: $host:$firestorePort');
      debugPrint('Functions: $host:5001');
      debugPrint('Storage: $host:9199');
    }

    // Profile avatars and lesson videos use Firebase Storage (see storage.rules),
    // so the emulator must be connected together with the others above.
    // ------------------------------------------------
    // 4. Run Application
    // ------------------------------------------------

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
        ],
        child: const ABLearningApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Application startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      StartupErrorApp(
        message: error.toString(),
      ),
    );
  }
}

// ====================================================
// Startup Error Screen
// ====================================================

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 640,
              ),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 48,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Application Startup Failed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ไม่สามารถเริ่มต้นระบบได้ '
                      'กรุณาตรวจสอบการตั้งค่า Firebase '
                      'และ Emulator',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF64748B),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ERROR DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ตรวจสอบค่า --dart-define และ '
                      'การทำงานของ Firebase Emulator '
                      'ใน docs/environment_setup.md',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
