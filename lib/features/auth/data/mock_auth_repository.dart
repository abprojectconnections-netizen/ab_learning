import 'dart:async';
import '../domain/user_model.dart';
import 'auth_repository.dart';

/// Local demo identities. Production authorization must come from Firebase
/// custom claims, never from the email address.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  AppUser _fakeUser(String email, {bool forceLearner = false}) {
    final normalized = email.trim().toLowerCase();
    final role = forceLearner ? UserRoleType.learner : _demoRole(normalized);
    return AppUser(
      uid: role == UserRoleType.instructor
          ? 'instructor-1'
          : 'demo-${role.name}',
      email: normalized,
      displayName: normalized.split('@').first,
      role: role,
    );
  }

  UserRoleType _demoRole(String email) {
    if (email.contains('superadmin') || email.contains('super_admin')) {
      return UserRoleType.superAdmin;
    }
    if (email == 'krit@ablearning.com' || email.contains('instructor')) {
      return UserRoleType.instructor;
    }
    if (email == 'manager@ablearning.com' || email.contains('manager')) {
      return UserRoleType.corporateManager;
    }
    if (email == 'corp@ablearning.com' || email.contains('corp')) {
      return UserRoleType.corporateAdmin;
    }
    if (email == 'employer@ablearning.com' || email.contains('employer')) {
      return UserRoleType.employer;
    }
    if (email == 'admin@ablearning.com' || email.contains('admin')) {
      return UserRoleType.admin;
    }
    return UserRoleType.learner;
  }

  void _validate(String email, String password) {
    if (!email.contains('@') || password.length < 6) {
      throw Exception(
          'Enter a valid email and a password of at least 6 characters.');
    }
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _validate(email.trim(), password);
    _current = _fakeUser(email);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<AppUser> register(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _validate(email.trim(), password);
    _current = _fakeUser(email, forceLearner: true);
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
