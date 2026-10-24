import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../../../../core/widgets/empty_state.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: notifs.isEmpty
          ? const AppEmptyState(message: 'ยังไม่มีการแจ้งเตือนในขณะนี้')
          : ListView.separated(
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifs[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.notifications_active_outlined),
                  ),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.message),
                  trailing: Text(
                    '${n.timestamp.hour}:${n.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}