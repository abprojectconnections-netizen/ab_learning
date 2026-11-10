// lib/features/notification/data/notification_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationItem>> watchMine();
  Future<void> markRead(String id);
}

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  @override
  Stream<List<NotificationItem>> watchMine() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((doc) {
              final d = doc.data();
              return NotificationItem(
                id: doc.id,
                title: d['title'] as String? ?? '',
                message: d['message'] as String? ?? '',
                timestamp:
                    (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                isRead: d['read'] == true,
              );
            }).toList());
  }

  @override
  Future<void> markRead(String id) async {
    await _col?.doc(id).update({'read': true});
  }
}
