// lib/features/profile/data/profile_repository.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? bio;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
  });
}

abstract class ProfileRepository {
  Future<UserProfile> getMyProfile();

  /// Writes only displayName / bio / photoUrl (+ updatedAt) — the exact key
  /// whitelist enforced by firestore.rules for `users/{uid}` updates.
  Future<void> updateMyProfile({
    required String displayName,
    String? bio,
    String? photoUrl,
  });

  /// Uploads to avatars/{uid} (images up to 5 MB), stores the download URL in
  /// the profile and returns it.
  Future<String> uploadAvatar(Uint8List bytes, String contentType);

  /// Permanently deletes the account and personal data (server side). Throws
  /// [AccountDeletionBlocked] when it cannot be done, e.g. the user still owns courses.
  Future<void> deleteMyAccount();
}

class AccountDeletionBlocked implements Exception {
  const AccountDeletionBlocked(this.message);
  final String message;
  @override
  String toString() => message;
}
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseStorage storage,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to manage your profile.');
    return user;
  }

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_user.uid);

  @override
  Future<UserProfile> getMyProfile() async {
    final snapshot = await _doc.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: _user.uid,
      email: data['email'] as String? ?? _user.email ?? '',
      displayName:
          data['displayName'] as String? ?? _user.displayName ?? '',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
    );
  }

  @override
  Future<void> updateMyProfile({
    required String displayName,
    String? bio,
    String? photoUrl,
  }) {
    return _doc.update({
      'displayName': displayName.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String contentType) async {
    if (bytes.length >= 5 * 1024 * 1024) {
      throw ArgumentError('Image must be smaller than 5 MB.');
    }
    final ref = _storage.ref('avatars/${_user.uid}');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _doc.update({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
    return url;
  }

  @override
  Future<void> deleteMyAccount() async {
    try {
      await _functions.httpsCallable('deleteMyAccount').call({'confirm': 'DELETE'});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw AccountDeletionBlocked(e.message ?? 'Account cannot be deleted yet.');
      }
      rethrow;
    }
  }
}
