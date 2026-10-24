# Release checklist

## Before Web Beta

- [ ] Dedicated Beta Firebase project and FlutterFire options selected at build time.
- [ ] Firestore rules tested in Emulator Suite for allowed and denied cases across all supported roles.
- [ ] No test-mode rules, service-account keys, real user data, or payment secrets in the client/repository.
- [ ] Auth registration, login, logout, password reset, role claim loading, and disabled-account behavior verified against Firebase.
- [ ] Course draft/review/publish flow, free enrollment, lesson access, and persisted progress verified against Firestore.
- [ ] Payment mock terminal transitions and enrollment activation are server controlled.
- [ ] Web responsive check and Android device integration pass; iOS requires macOS/Xcode.
- [ ] Privacy, account deletion, backup/recovery, and usage monitoring decisions documented.
- [ ] `flutter analyze --no-pub`, `flutter test --no-pub`, and release build pass.

## Current readiness

The app is a role-aware mock MVP. Firebase project configuration, Firestore repositories, emulator rules tests, persisted progress, and deploy configuration remain prerequisites before Beta; the presence of Firebase dependencies alone is not a Firebase integration.
