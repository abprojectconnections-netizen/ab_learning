import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_providers.dart';
import '../../data/notification_repository.dart';
import '../../data/rest_notification_repository.dart';
import '../../domain/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (ref.watch(useRestBackendProvider)) {
    final repo = RestNotificationRepository(
        ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return FirebaseNotificationRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
  );
});

/// Live stream; re-subscribes when the signed-in user changes.
final notificationProvider = StreamProvider<List<NotificationItem>>((ref) {
  ref.watch(authStateProvider.select((a) => a.uid));
  return ref.watch(notificationRepositoryProvider).watchMine();
});
