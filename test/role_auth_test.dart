import 'package:flutter_test/flutter_test.dart';
import 'support/mock_backend.dart';
import 'package:ab_learning/features/auth/domain/user_model.dart';

void main() {
  test('Firebase role claims map to each supported business role', () {
    expect(UserRoleTypeClaim.fromClaim('INSTRUCTOR'), UserRoleType.instructor);
    expect(
        UserRoleTypeClaim.fromClaim('CORP_ADMIN'), UserRoleType.corporateAdmin);
    expect(UserRoleTypeClaim.fromClaim('CORP_MANAGER'),
        UserRoleType.corporateManager);
    expect(UserRoleTypeClaim.fromClaim('EMPLOYER'), UserRoleType.employer);
    expect(UserRoleTypeClaim.fromClaim('ADMIN'), UserRoleType.admin);
    expect(UserRoleTypeClaim.fromClaim('SUPER_ADMIN'), UserRoleType.superAdmin);
    expect(UserRoleTypeClaim.fromClaim(null), UserRoleType.learner);
  });

  test('development demo accounts retain their individual roles', () async {
    final repository = MockAuthRepository();
    final cases = <String, UserRoleType>{
      'krit@ablearning.com': UserRoleType.instructor,
      'corp@ablearning.com': UserRoleType.corporateAdmin,
      'manager@ablearning.com': UserRoleType.corporateManager,
      'employer@ablearning.com': UserRoleType.employer,
      'admin@ablearning.com': UserRoleType.admin,
      'superadmin@ablearning.com': UserRoleType.superAdmin,
      'learner@ablearning.com': UserRoleType.learner,
    };

    for (final entry in cases.entries) {
      final user =
          await repository.signIn(email: entry.key, password: 'password123');
      expect(user.role, entry.value, reason: entry.key);
      await repository.signOut();
    }
  });
}
