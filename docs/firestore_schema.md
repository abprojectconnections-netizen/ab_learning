# Firestore schema (MVP)

All user references use Firebase Auth UID. Store times as Firestore `Timestamp`. Composite indexes in `firestore.indexes.json` correspond to real repository queries.

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
| `course_reviews/{uid_courseId}` | `studentId, studentName, courseId, rating (1-5), comment, createdAt` | Public read; enrolled learner creates one per course with own profile name; immutable. |
| `quizzes/{id}` | `courseId, lectureId, title, passThresholdPercent, questions[{id,text,options}], createdAt` | Enrolled learner / owner / admin read; no client write. Contains no answers. |
| `quiz_answers/{quizId}` | `answers{questionId:index}` | No client access. Read by `submitQuiz` only. |
| `quiz_attempts/{id}` | `studentId, courseId, quizId, scorePercent, passed, createdAt` | Owner reads; written by `submitQuiz` only. |
| `certificates/{uid_courseId}` | `studentId, learnerName, courseId, courseTitle, verificationCode, issuedAt` | Owner reads; issued by server when all lessons and quizzes are complete. |
| `certificate_verifications/{code}` | `courseTitle, learnerName, issuedAt` | Public `get` by exact code only; no list/write. |
| `users/{uid}/notifications/{id}` | `title, message, read, createdAt` | Owner reads and may only set `read`; created by Cloud Functions. |
| `sales/{transactionId}` | `instructorId, courseId, courseTitle, buyerName, amount, currency, status, createdAt` | Owning instructor/admin read; written when a payment is confirmed. |
| `payouts/{id}` | `instructorId, amount, status, requestedAt` | Owning instructor/admin read; created by `requestPayout` only. |
| `organizations/{orgId}` | `name, ownerUid, createdAt` | Members/admins read; created by `createOrganization` only. |
| `org_members/{orgId_uid}` | `orgId, uid, email, displayName, role (admin|manager|member), status, createdAt` | Owner and org staff read; org admin may only toggle `status`; created by `addOrgMember`. |
| `learning_paths/{id}` | `orgId, title, description, status, createdBy, createdAt` | Org members read; org admin creates/updates inside own org. |
| `job_postings/{id}` | `employerId, title, location, status (open|closed), createdAt` | Open postings public; employer manages own. |
| `job_applications/{jobId_uid}` | `jobId, employerId, candidateId, candidateName, status, createdAt` | Candidate creates once per open job; employer updates `status` only. |
| `platform_config/revenue` | `instructorShare, minPayout` | Server-only. Must be configured by the operator before payouts work. |
| `payment_mock/{id}` | `studentId, courseId, amount, currency, status, createdAt` | Owner reads; client may create `pending`; terminal status is server-only and never changes enrollment in these rules. |
| `audit_logs/{id}` | `actorUid, action, targetType, targetId, createdAt` | Super Admin read; client write denied. Server/Admin SDK writes only. |

Organization and recruitment collections are intentionally not defined yet. Add them only with explicit tenant boundaries, membership documents, and rules for every query/write.
