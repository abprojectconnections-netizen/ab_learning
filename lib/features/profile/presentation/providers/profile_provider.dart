import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FirebaseProfileRepository(
    firestore: FirebaseFirestore.instance,
    auth: fb.FirebaseAuth.instance,
    storage: FirebaseStorage.instance,
  );
});

final myProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getMyProfile();
});
