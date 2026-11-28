import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/auth_repository.dart';
import '../../data/firebase_auth_repository.dart';
import '../../data/rest_auth_repository.dart';
import '../../domain/user_model.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_providers.dart';
import '../../../../core/router/role_guard.dart';

UserRole guardRoleFor(UserRoleType role) => switch (role) {
      UserRoleType.learner => UserRole.learner,
      UserRoleType.instructor => UserRole.instructor,
      UserRoleType.corporateAdmin => UserRole.corporateAdmin,
      UserRoleType.corporateManager => UserRole.corporateManager,
      UserRoleType.employer => UserRole.employer,
      UserRoleType.admin => UserRole.admin,
      UserRoleType.superAdmin => UserRole.superAdmin,
    };

/// Go + MySQL API when API_BASE_URL is defined, Firebase otherwise.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(useRestBackendProvider)) {
    final repo = RestAuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
      sessionExpired: ref.watch(sessionEventsProvider).expired,
    );
    ref.onDispose(repo.dispose);
    return repo;
  }
  return FirebaseAuthRepository(
      fb.FirebaseAuth.instance, FirebaseFirestore.instance);
});

final authStateStreamProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

class AuthState {
  final UserRole role;
  final String? uid;
  final String? email;
  final String? displayName;
  final bool isLoading;
  const AuthState(
      {required this.role,
      this.uid,
      this.email,
      this.displayName,
      this.isLoading = false});
}

final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authStateStreamProvider).when(
        data: (u) => u == null
            ? const AuthState(role: UserRole.guest)
            : AuthState(
                role: guardRoleFor(u.role),
                uid: u.uid,
                email: u.email,
                displayName: u.displayName,
              ),
        loading: () => const AuthState(role: UserRole.guest, isLoading: true),
        error: (_, __) => const AuthState(role: UserRole.guest),
      );
});

/// ให้ GoRouter ประเมิน redirect ใหม่ทุกครั้งที่ login/logout
final goRouterRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen(authStateStreamProvider, (_, __) => notifier.value++);
  ref.onDispose(notifier.dispose);
  return notifier;
});
