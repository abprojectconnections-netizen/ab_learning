// lib/features/notification/data/rest_notification_repository.dart
import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/polling_stream.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/notification_model.dart';
import 'notification_repository.dart';

/// Notifications from the Go API, refreshed periodically and after changes.
class RestNotificationRepository implements NotificationRepository {
  RestNotificationRepository(
    this._api,
    this._tokens, {
    this.interval = const Duration(seconds: 60),
  });

  final ApiClient _api;
  final TokenStorage _tokens;
  final Duration interval;
  final _changed = StreamController<void>.broadcast();

  void dispose() => _changed.close();

  @override
  Stream<List<NotificationItem>> watchMine() =>
      pollingStream(_load, interval: interval, refresh: _changed.stream);

  Future<List<NotificationItem>> _load() async {
    if (!await _tokens.hasSession()) return const [];
    final res = await _api.get('/api/v1/notifications?limit=100');
    final body = jsonDecode(res.body);
    final items = body is Map<String, dynamic> ? body['items'] : body;
    if (items is! List) return const [];
    return items.whereType<Map<String, dynamic>>().map(_item).toList();
  }

  @override
  Future<void> markRead(String id) async {
    if (int.tryParse(id) == null) {
      throw ArgumentError.value(id, 'id', 'not a numeric id');
    }
    await _api.post('/api/v1/notifications/$id/read');
    if (!_changed.isClosed) _changed.add(null);
  }

  static NotificationItem _item(Map<String, dynamic> n) => NotificationItem(
        id: '${n['id']}',
        title: '${n['title'] ?? ''}',
        message: '${n['body'] ?? ''}',
        timestamp:
            DateTime.tryParse('${n['created_at']}')?.toLocal() ?? DateTime.now(),
        isRead: n['is_read'] == true,
      );
}
