import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

/// Broadcasts when the stored session can no longer be refreshed, so the UI
/// can return to the login screen instead of failing silently.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void notifyExpired() {
    if (!_expired.isClosed) _expired.add(null);
  }

  void dispose() => _expired.close();
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

/// Authenticated HTTP client with automatic token refresh. Only used when
/// [useRestBackendProvider] is true.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: ref.watch(sessionEventsProvider).notifyExpired,
  );
  ref.onDispose(client.close);
  return client;
});
