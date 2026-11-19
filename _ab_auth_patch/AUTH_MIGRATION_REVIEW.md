# AB LEARNING — Backend Authentication Hardening Patch

This patch updates only the Go backend. It intentionally does **not** replace the Flutter authentication provider yet.

## Included changes

- Public self-registration is restricted to `LEARNER` and `INSTRUCTOR`.
- Registration creates the user, profile, and (for instructors) an `instructors` row with `verified_at = NULL` in one database transaction.
- Successful registration now returns the same access/refresh-token response shape as login.
- User responses include `instructor_verified`.
- Instructor APIs require a verified instructor record. The previous auto-create behavior has been removed.
- Instructor upload routes also enforce approval before accepting files.
- Admin endpoints:
  - `GET /api/v1/admin/instructors/pending`
  - `POST /api/v1/admin/instructors/{instructor_id}/approve`
- Instructor approval and audit logging happen in one database transaction.
- Added tests for rejecting privileged self-registration and blocking unverified instructors.
- Updated the minimal OpenAPI file.

## Database

No schema migration is required: the supplied schema already has `instructors.verified_at` and `audit_logs`.

## Important integration blocker — Flutter/Firebase

The supplied Flutter source still has multiple features that use `FirebaseAuth.instance.currentUser` to identify the signed-in user. A source scan found these dependencies in jobs, payments, revenue, learning progress, profile, instructor applications, reviews, certificates, enrollment, workspace, notifications, and marketplace repositories.

Switching the Flutter auth provider directly to Go JWT would make those Firebase-dependent features see a null Firebase user, even if Firebase Core/Firestore initialization remains enabled.

Before activating Go JWT in Flutter, choose one of these architectures:

1. **Migrate dependent features to Go API/JWT** (recommended when Go is the platform's source of truth).
2. **Keep Firebase as a secondary identity** by implementing a secure Go-to-Firebase custom-token bridge using Firebase Admin SDK and a stable backend-user-to-Firebase-UID mapping.

Do not implement a fragile dual sign-in by separately creating/signing into Firebase accounts with the same password.

## Remaining production requirements

- Refresh JWTs are currently stateless; there is no server-side refresh-token rotation/revocation or logout endpoint. Client logout can clear local tokens, but cannot invalidate an already-issued access token before its expiry.
- The supplied backend has no password-reset endpoint. The Flutter forgot-password screen must not claim that an email was sent until such a service exists.
- Email verification is not enforced by the current backend.
- Backend tests could not be executed in the patch environment because Go dependencies were not available offline. `gofmt` completed successfully; run the commands below in the project environment.

## Apply on Windows PowerShell

From `D:\Project\ab_learning`:

```powershell
Expand-Archive .\ab_learning_backend_auth_patch.zip .\_ab_auth_patch -Force
Copy-Item .\_ab_auth_patch\backend\* .\backend -Recurse -Force

Set-Location .\backend
go test -count=1 ./...
```

No Git reset/clean/commit/push is performed by this patch.
