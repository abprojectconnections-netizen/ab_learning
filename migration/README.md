# MySQL → Firebase migration (local first)

1. `cp mapping.example.js mapping.js` and edit the SQL/maps to match your tables (mapping.js is git-ignored).
2. `npm install` (Node 22).
3. Start the emulators (auth, firestore) in another terminal.
4. Set MySQL credentials in your shell only (never commit them):
   `$env:MYSQL_HOST="127.0.0.1"; $env:MYSQL_USER="..."; $env:MYSQL_PASSWORD="..."; $env:MYSQL_DATABASE="..."`
5. Point at the emulators:
   `$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8180"; $env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"; $env:GCLOUD_PROJECT="demo-ab-learning"`
6. `npm run dry-run` — validates every row and reports problems, writes nothing.
7. Fix mapping/data until it reports no skipped rows, then `npm run commit`.

Scope: users (no passwords imported; users reset via "forgot password"), courses, enrollments.
Not migrated: sales/payouts (server-only ledger), lessons/videos, progress, certificates.
Legacy IDs become `legacy-<id>` and are kept in a `legacyId` field. Re-running is idempotent.
The script refuses any target that is not the emulators or a `-dev` project.
