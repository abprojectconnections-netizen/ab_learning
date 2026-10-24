// lib/features/auth/data/auth_repository.dart
import '../domain/user_model.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> register({required String email, required String password});
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}