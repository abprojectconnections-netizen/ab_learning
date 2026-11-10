import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { dev, beta, production }

class AppConfig {
  final AppEnvironment environment;
  const AppConfig({required this.environment});

  static const dev = AppConfig(environment: AppEnvironment.dev);
  static const beta = AppConfig(environment: AppEnvironment.beta);
  static const production = AppConfig(environment: AppEnvironment.production);
}

/// ค่าจริงถูก override ใน main.dart ตาม --dart-define=ENV
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.dev);
