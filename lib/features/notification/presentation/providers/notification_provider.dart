import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/notification_model.dart';

class NotificationNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationNotifier() : super([
    NotificationItem(
      id: 'notif-1',
      title: 'ยินดีต้อนรับสู่ AB Learning',
      message: 'เริ่มต้นเรียนรู้คอร์สแรกของคุณได้เลยวันนี้',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ]);

  void addNotification(String title, String message) {
    state = [
      NotificationItem(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        timestamp: DateTime.now(),
      ),
      ...state,
    ];
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<NotificationItem>>((ref) {
  return NotificationNotifier();
});