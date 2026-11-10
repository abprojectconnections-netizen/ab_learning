import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const AppErrorState(message: 'โหลดการแจ้งเตือนไม่สำเร็จ'),
        data: (notifs) => notifs.isEmpty
            ? const AppEmptyState(message: 'ยังไม่มีการแจ้งเตือนในขณะนี้')
            : ListView.separated(
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = notifs[index];
                  final t = n.timestamp;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(n.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined),
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(n.message),
                    trailing: Text(
                      '${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: n.isRead
                        ? null
                        : () => ref.read(notificationRepositoryProvider).markRead(n.id),
                  );
                },
              ),
      ),
    );
  }
}
