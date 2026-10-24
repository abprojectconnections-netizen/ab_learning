import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, beta, production }

class AppConfig {
  final AppEnvironment environment;
  final bool useMockBackend;
  const AppConfig({required this.environment, required this.useMockBackend});

  static const dev =
      AppConfig(environment: AppEnvironment.dev, useMockBackend: true);
  static const devFirebase =
      AppConfig(environment: AppEnvironment.dev, useMockBackend: false);
  static const beta =
      AppConfig(environment: AppEnvironment.beta, useMockBackend: false);
  static const production =
      AppConfig(environment: AppEnvironment.production, useMockBackend: false);
}

/// ค่าจริงถูก override ใน main.dart ตาม --dart-define=ENV
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.dev);
