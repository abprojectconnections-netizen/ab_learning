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
4. Run the Rules suite with `firebase emulators:exec --only firestore,storage --project demo-ab-learning "npm test --prefix rules-tests"`. To seed local data, run `firebase emulators:exec --only firestore --project demo-ab-learning "npm run seed:dev --prefix functions"`. To run Auth/Firestore/Functions for the app, start `firebase emulators:start --only auth,firestore,functions,storage --project demo-ab-learning`. Firestore uses port 8180 here to avoid the existing service on 8080.
5. Run Web against emulators with `--dart-define=ENV=dev --dart-define=USE_FIREBASE_EMULATORS=true` plus `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID_WEB`, and `FIREBASE_AUTH_DOMAIN` values from FlutterFire. Android emulator also needs `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`.
6. For the real DEV project, use the same flags without `USE_FIREBASE_EMULATORS`; Deploy `firestore.rules`, indexes, and Functions only after emulator tests pass.
7. Keep Beta and Production as separate Firebase projects and require an explicit release workflow to select them.

`ENV=beta` and `ENV=production` use Firebase and fail closed if configuration is missing. Cloud Functions require a Blaze plan for deployment; local emulators can be used without connecting payment services. Firebase identifiers are public client config, but service-account credentials are never appropriate in Flutter or source control.

## Payments (Stripe Checkout)

Production payments use hosted Stripe Checkout. The client never marks a
payment as paid: the signature-verified `stripeWebhook` function is the only
path that activates a paid enrollment (`confirmMockPayment` is refused outside
DEV projects).

1. Store secrets (never in the app or repo):
   `firebase functions:secrets:set STRIPE_SECRET_KEY` and
   `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`.
2. Allow the web origins Stripe may return to, e.g. in `functions/.env.<project>`:
   `CHECKOUT_RETURN_ORIGINS=https://app.example.com`.
3. In the Stripe dashboard add a webhook endpoint pointing at the deployed
   `stripeWebhook` URL with events `checkout.session.completed`,
   `checkout.session.async_payment_succeeded` and `checkout.session.expired`.
4. Mobile builds open the hosted page in the browser and return to
   `--dart-define=WEB_APP_URL=https://app.example.com`.
5. Test with Stripe test keys and `stripe listen --forward-to <emulator URL>`
   before using live keys.

Other production prerequisites: `platform_config/revenue` must exist,
signed video URLs need the functions service account to hold
`roles/iam.serviceAccountTokenCreator`, and Storage rules are in `storage.rules`.


## Connecting to a real DEV Firebase project

1. Create a Firebase project whose ID ends in `-dev` (e.g. `absmart-dev`), enable Authentication (Email/Password), Firestore, Storage, and the Blaze plan (needed for Functions).
2. Register a Web app and copy `env/dev.example.json` to `env/dev.json`, filling the values (this file is git-ignored).
3. `firebase use --add` and give the project the alias `dev`.
4. Deploy the backend and seed sample data: `powershell -File scripts/dev-deploy.ps1 -Project absmart-dev -Seed` (the script refuses non-`-dev` project IDs).
5. Run the app: `flutter run -d chrome --dart-define-from-file=env/dev.json` (no `USE_FIREBASE_EMULATORS`).
6. Create accounts by signing up in the app, then grant the first Super Admin with `functions/bootstrap_superadmin.js` using `GCLOUD_PROJECT=absmart-dev` and Application Default Credentials (`gcloud auth application-default login`).


## Demo data for testing every menu (emulator only)

With the Auth and Firestore emulators running:

```powershell
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8180"
$env:GCLOUD_PROJECT="demo-ab-learning"
npm run seed:demo --prefix functions
```

Creates 20-30 records per menu (categories, courses with lessons and quizzes, enrollments, sales, payouts,
reviews, certificates, notifications, jobs and applications, organization members, learning paths,
instructor applications, audit logs) plus 25 learners (`learner01@demo.test` ... `learner25@demo.test`),
5 instructors (`instructor@demo.test`, `instructor02..05@demo.test`) and 3 employers. Password for all demo
accounts is `Demo#12345`. IDs are deterministic, so the script is safe to re-run. It refuses to run unless
both emulator hosts are set.
