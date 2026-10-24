# AB Learning Online

Flutter MVP for Web and Mobile. The current build has mock-backed role workspaces and repository-driven learner/instructor flows. Firebase SDK dependencies are present, but Firebase project options and Firestore repositories are not configured yet; `ENV=beta` and `ENV=production` intentionally fail closed.

## Supported roles

- Learner / Student
- Instructor
- Corporate Admin and Corporate Manager
- Employer
- Admin
- Super Admin

The learning-platform core follows the supplied four-role plan. Corporate roles remain additional demo workspaces. Super Admin can inspect a role directory and sample audit trail; privileged role changes must be performed by a trusted server after Firebase setup.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

The development mock accepts valid email addresses with passwords of at least six characters. Demo role accounts use `password123`:

| Email | Role |
| --- | --- |
| `learner@ablearning.com` | Learner |
| `krit@ablearning.com` | Instructor |
| `corp@ablearning.com` | Corporate Admin |
| `manager@ablearning.com` | Corporate Manager |
| `employer@ablearning.com` | Employer |
| `admin@ablearning.com` | Admin |
| `superadmin@ablearning.com` | Super Admin |

These are local mock identities, not real Firebase accounts. Their data is not durable across app restarts.

## Validate

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

## Architecture and Firebase setup

- [Architecture](docs/architecture.md)
- [Firestore schema](docs/firestore_schema.md)
- [Security rules](docs/security_rules.md)
- [Environment setup](docs/environment_setup.md)
- [Release checklist](docs/release_checklist.md)

Firestore rules are deny-by-default. Client-created enrollments can unlock only published free courses, client payment records remain pending, and role/audit changes are server-only. Do not deploy the rules without emulator tests and a dedicated Firebase project.
