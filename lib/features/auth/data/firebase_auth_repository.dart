// lib/features/auth/data/firebase_auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  FirebaseAuthRepository(this._auth, this._firestore);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final tokenResult = await user.getIdTokenResult(true);
      final role = UserRoleTypeClaim.fromClaim(tokenResult.claims?['role']);
      return AppUser(
        uid: user.uid,
        email: user.email ?? '',
        role: role,
      );
    });
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final tokenResult = await cred.user!.getIdTokenResult(true);
    final role = UserRoleTypeClaim.fromClaim(tokenResult.claims?['role']);
    return AppUser(uid: cred.user!.uid, email: email, role: role);
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user!;
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': _displayName(firstName, lastName) ??
          user.displayName ??
          email.split('@').first,
      'email': email.trim(),
      'role': 'learner',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return AppUser(uid: user.uid, email: email, role: UserRoleType.learner);
  }

  static String? _displayName(String? first, String? last) {
    final name = '${first ?? ''} ${last ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
