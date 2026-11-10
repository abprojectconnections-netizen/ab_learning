// lib/features/workspace/domain/workspace_models.dart
// Read models for the corporate, recruitment and administration workspaces.

class OrgMember {
  final String orgId;
  final String uid;
  final String email;
  final String displayName;
  final String role; // admin | manager | member
  final String status; // active | suspended
  const OrgMember({
    required this.orgId,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
  });
  bool get isActive => status == 'active';
}

class LearningPath {
  final String id;
  final String orgId;
  final String title;
  final String description;
  final String status; // draft | active | archived
  const LearningPath({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.status,
  });
}

class TeamMemberProgress {
  final String uid;
  final String displayName;
  final String email;
  final String memberStatus;
  final int enrolledCourses;
  final int completedCourses;
  const TeamMemberProgress({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.memberStatus,
    required this.enrolledCourses,
    required this.completedCourses,
  });
}

class JobPosting {
  final String id;
  final String title;
  final String location;
  final String status; // open | closed
  const JobPosting({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
  });
  bool get isOpen => status == 'open';
}

class JobApplication {
  final String id;
  final String jobId;
  final String candidateName;
  final String status; // new | screened | interview | offer | rejected
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.candidateName,
    required this.status,
  });
}

class AdminUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String status;
  const AdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
  });
  bool get isActive => status == 'active';
}

class PendingCourse {
  final String id;
  final String title;
  final String instructorName;
  const PendingCourse({
    required this.id,
    required this.title,
    required this.instructorName,
  });
}

class InstructorApplication {
  final String id;
  final String uid;
  final String displayName;
  final String experience;
  const InstructorApplication({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.experience,
  });
}

class AuditEntry {
  final String id;
  final String action;
  final String actorUid;
  final String targetType;
  final DateTime? createdAt;
  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.targetType,
    this.createdAt,
  });
}

class SalesToday {
  final int count;
  final double total;
  const SalesToday({required this.count, required this.total});
}
