# Firestore schema (MVP)

All user references use Firebase Auth UID. Store times as Firestore `Timestamp`. Create composite indexes only when a real repository query requires one; the initial index manifest is empty.

| Collection / document | Key fields | Access summary |
| --- | --- | --- |
| `users/{uid}` | `uid, displayName, email, role, status, createdAt, updatedAt` | User can read own profile and edit profile fields; role/status are immutable from client. No user directory listing. |
| `instructor_applications/{id}` | `uid, displayName, experience, status, createdAt, reviewedAt, reviewedBy` | Applicant creates/reads own; admin reviews status. |
| `categories/{id}` | `name, sortOrder, active` | Public read; admin write. |
| `courses/{id}` | `title, description, price, categoryId, instructorId, status, createdAt, updatedAt` | Public reads published; instructor owns drafts; admin reviews status. |
| `courses/{id}/sections/{sectionId}` | `title, order, createdAt` | Owner manages draft sections; section titles are readable for published courses. |
| `courses/{id}/lessons/{lessonId}` | `sectionId, title, order, videoProvider, videoReference, durationSeconds, isPreview` | Owner edits draft lessons; preview or enrolled learner reads published lessons. |
| `enrollments/{uid_courseId}` | `studentId, courseId, status, enrolledAt` | Learner reads own; client can create active enrollment only for a free published course. |
| `users/{uid}/progress/{lessonId}` | `lessonId, courseId, completed, lastPositionSeconds, updatedAt` | Owner only and requires active enrollment. |
| `course_reviews/{id}` | `studentId, courseId, rating, comment, createdAt` | Public read; enrolled learner creates; immutable after creation. |
| `payment_mock/{id}` | `studentId, courseId, amount, currency, status, createdAt` | Owner reads; client may create `pending`; terminal status is server-only and never changes enrollment in these rules. |
| `audit_logs/{id}` | `actorUid, action, targetType, targetId, createdAt` | Super Admin read; client write denied. Server/Admin SDK writes only. |

Organization and recruitment collections are intentionally not defined yet. Add them only with explicit tenant boundaries, membership documents, and rules for every query/write.
