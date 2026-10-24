enum UserRoleType {
  learner,
  instructor,
  corporateAdmin,
  corporateManager,
  employer,
  admin,
  superAdmin
}

extension UserRoleTypeClaim on UserRoleType {
  static UserRoleType fromClaim(Object? value) {
    final claim = value?.toString().trim().toLowerCase().replaceAll('-', '_');
    return switch (claim) {
      null || '' || 'learner' => UserRoleType.learner,
      'instructor' => UserRoleType.instructor,
      'corp_admin' ||
      'corporate_admin' ||
      'corporateadmin' =>
        UserRoleType.corporateAdmin,
      'corp_manager' ||
      'corporate_manager' ||
      'corporatemanager' =>
        UserRoleType.corporateManager,
      'employer' => UserRoleType.employer,
      'admin' || 'administration' => UserRoleType.admin,
      'super_admin' || 'superadmin' => UserRoleType.superAdmin,
      _ => throw FormatException('Unsupported Firebase role claim: $value'),
    };
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRoleType role;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final double? totalRevenue;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.totalRevenue,
  });

  AppUser copyWith({String? displayName, String? photoUrl, String? bio}) =>
      AppUser(
        uid: uid,
        email: email,
        role: role,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        bio: bio ?? this.bio,
        totalRevenue: totalRevenue,
      );
}
