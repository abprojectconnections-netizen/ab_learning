# Release checklist

## Before Web Beta

- [ ] Dedicated Beta Firebase project and FlutterFire options selected at build time.
- [ ] Firestore rules tested in Emulator Suite for allowed and denied cases across all supported roles.
- [ ] No test-mode rules, service-account keys, real user data, or payment secrets in the client/repository.
- [ ] Auth registration, login, logout, password reset, role claim loading, and disabled-account behavior verified against Firebase.
- [ ] Course draft/review/publish flow, free enrollment, lesson access, and persisted progress verified against Firestore.
- [ ] Payment terminal transitions and enrollment activation are server controlled (Stripe webhook verified).
- [ ] Web responsive check and Android device integration pass; iOS requires macOS/Xcode.
- [ ] Privacy, account deletion, backup/recovery, and usage monitoring decisions documented.
- [ ] `flutter analyze --no-pub`, `flutter test --no-pub`, and release build pass.

## Current readiness

All features read and write live Firebase data and CI (`flutter analyze`, `flutter test`, Firestore/Storage rules tests, Functions lint) runs on every pull request. Still open before Beta: a real DEV/Beta Firebase project exercised end to end, Stripe secrets and webhook configuration, privacy policy and data-retention decisions, a production deploy workflow, and device testing on Android/iOS.

Account deletion (`deleteMyAccount`) removes personal data and keeps anonymised financial records; users who still own courses or organizations must transfer them first.
