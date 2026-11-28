import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base URL of the AB Learning REST API (host only, e.g. https://api.example.com).
/// Supplied per environment with --dart-define=API_BASE_URL=...
///
/// When it is empty the app keeps using Firebase, so the REST backend can be
/// adopted one environment at a time.
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

final apiBaseUrlProvider = Provider<String>((ref) => kApiBaseUrl);

/// True when the app should talk to the Go + MySQL API instead of Firebase.
final useRestBackendProvider =
    Provider<bool>((ref) => ref.watch(apiBaseUrlProvider).trim().isNotEmpty);
