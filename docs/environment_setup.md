# Environment setup

## Local mock development

1. Install a Flutter SDK compatible with `pubspec.yaml` (Dart `>=3.3.0 <4.0.0`).
2. Run `flutter pub get`.
3. Run `flutter run -d chrome` or `flutter run` for a connected mobile target. The default `ENV=dev` uses mock repositories.
4. Run `flutter analyze --no-pub` and `flutter test --no-pub` before committing.

## Firebase DEV

1. Create a dedicated Firebase development project and register Web/Android/iOS apps.
2. Run `firebase login` using the project owner's Google account, then `firebase projects:list`. Select the intended DEV project explicitly; do not create/deploy against an assumed project.
3. Run `flutterfire configure --project <dev-project-id>` for Web, Android, and iOS. Read the generated `firebase_options.dart` values for the public identifiers used by the build flags below. Never add service-account credentials.
4. Run the Rules suite with `firebase emulators:exec --only firestore --project demo-ab-learning "npm test --prefix rules-tests"`. To seed local data, run `firebase emulators:exec --only firestore --project demo-ab-learning "npm run seed:dev --prefix functions"`. To run Auth/Firestore/Functions for the app, start `firebase emulators:start --only auth,firestore,functions --project demo-ab-learning`. Firestore uses port 8180 here to avoid the existing service on 8080.
5. Run Web against emulators with `--dart-define=ENV=dev --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=true` plus `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID_WEB`, and `FIREBASE_AUTH_DOMAIN` values from FlutterFire. Android emulator also needs `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`.
6. For the real DEV project, use the same flags without `USE_FIREBASE_EMULATORS`; Firebase Auth and Firestore repositories are selected automatically. Deploy `firestore.rules`, indexes, and Functions only after emulator tests pass.
7. Keep Beta and Production as separate Firebase projects and require an explicit release workflow to select them.

`ENV=beta` and `ENV=production` use Firebase and fail closed if configuration is missing. Cloud Functions require a Blaze plan for deployment; local emulators can be used without connecting payment services. Firebase identifiers are public client config, but service-account credentials are never appropriate in Flutter or source control.
