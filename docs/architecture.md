# Learning Online architecture

## Current application

- Flutter + Dart targets Web, Android, and iOS.
- Riverpod is the state and dependency layer; `go_router` owns navigation.
- Feature-first modules separate presentation from repositories.
- Development currently uses in-memory/mock repositories. Firebase packages are present, but no FlutterFire project configuration is checked in and `main.dart` deliberately refuses non-dev environments.
- The app supports learner, instructor, corporate admin, corporate manager, employer, admin, and super admin roles. The four-role learning platform in the product plan is the core; the three business roles remain supported as additional workspaces.

## Intended Firebase boundary

Flutter UI -> Riverpod providers -> feature repositories -> Firebase Auth / Cloud Firestore.

Repositories own serialization and queries. Widgets must not issue Firestore queries directly. Firebase custom claims and Firestore Rules are the authorization boundary; route guards and hidden controls are only user experience.

## Role policy

| Role | Client capabilities | Trusted boundary |
| --- | --- | --- |
| Learner / Student | Read published catalog, free enrollments, own lessons and progress | Rules verify course is free and enrollment belongs to the learner |
| Instructor | Own drafts, lessons, and submission for review | Rules verify `instructorId` and allowed status transitions |
| Admin | Review instructor applications and course status | Admin custom claim; role grants must be issued by a trusted server |
| Super Admin | Read audit records and system role directory | Role changes and audit writes are server-only |
| Corporate Admin / Manager, Employer | Demo workspaces in current MVP | Organization and recruitment data collections are not yet provisioned; deny by default |

## Environment separation

Use separate Firebase projects for dev, beta, and production. Select options at build time; never select a project by editing scattered URLs or committing private service-account credentials. Web/mobile production configuration is intentionally not fabricated without real Firebase project metadata.

## Data lifecycle

Course states: `draft -> pending_review -> published | rejected -> archived`.

Enrollment document IDs are deterministic: `{studentUid}_{courseId}`. Client-created active enrollments are allowed only for published free courses. A mock payment can stay pending, but client-written payment status never grants access.
