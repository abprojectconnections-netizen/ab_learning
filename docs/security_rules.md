# Firestore security rules

`firestore.rules` is deny-by-default and uses the Firebase ID token `role` custom claim. Supported privileged claims are `instructor`, `admin`, and `super_admin`; ordinary accounts have no privilege claim and are learners by default. Corporate roles currently receive no organization-data access because those collections are not yet implemented.

Security properties enforced in the starter rules:

- A client cannot create a user profile with a privileged role or change its role/status later.
- Instructors create only their own drafts and cannot publish directly or edit another instructor's course.
- Admin approval is restricted to course status fields and supported states.
- Learners read/write only their own progress and need an active enrollment.
- An active client enrollment is possible only for a published zero-price course.
- Payment mock writes can only be pending; the client cannot mark payment successful or unlock a paid course.
- Audit records cannot be written by clients and are visible only to super admins.

Custom claims must be assigned using Firebase Admin SDK in a trusted, access-controlled server process. Never put a service-account key in Flutter or grant claims from a client callable without verifying the actor's authority. Route guards do not replace these rules.

## Emulator checks

The Firebase Emulator Suite configuration is in `firebase.json`. Run `firebase emulators:exec --only firestore --project demo-ab-learning "npm test --prefix rules-tests"` to execute the allow/deny suite against a local demo project. Do not use production data for rule experiments.

Rules are not considered production-verified until emulator tests cover allowed and denied cases for each role, including cross-user reads, cross-instructor writes, paid-course enrollment, and client payment-success forgery.
