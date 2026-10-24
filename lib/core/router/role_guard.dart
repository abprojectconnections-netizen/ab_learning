enum UserRole {
  guest,
  learner,
  instructor,
  corporateAdmin,
  corporateManager,
  employer,
  admin,
  superAdmin
}

String homePathForRole(UserRole role) => switch (role) {
      UserRole.guest || UserRole.learner => '/',
      UserRole.instructor => '/instructor',
      UserRole.corporateAdmin || UserRole.corporateManager => '/corporate',
      UserRole.employer => '/employer',
      UserRole.admin => '/admin',
      UserRole.superAdmin => '/super-admin',
    };

/// Route authorization is a UI guard only. Firebase rules/API must enforce the
/// same permissions using trusted custom claims.
class RoleGuard {
  static bool canAccess({
    required UserRole currentRole,
    required List<UserRole> allowedRoles,
  }) =>
      allowedRoles.contains(currentRole);
}
