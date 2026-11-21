# AB Learning API

Go API backed by MySQL for the AB Learning Flutter application. It provides
JWT authentication, role protected dashboards, course management and the
Instructor, Corporate, Employer, and Administration MVP workflows.

## Run locally

```bash
make up          # creates .env with random secrets, starts MySQL + API + MinIO
make smoke       # health, login, /me, public catalog against the running API
```

Configuration lives in `.env` (git-ignored). Templates for every environment
are in `env/` (`local`, `test`, `staging`, `production`). Docker Compose refuses
to start when a required value is missing, so no secret is hardcoded.

The schema is created only by the versioned migrations in `db/migrations`
(applied by the API at startup). `SEED_DEV=true` (local/test only) adds demo
accounts; they all use the password `Password123!`:

| Role | Email |
|---|---|
| Learner | `learner@ablearning.co` |
| Instructor | `instructor@ablearning.co` |
| Corporate Admin | `corpadmin@ablearning.co` |
| Corporate Manager | `corpmanager@ablearning.co` |
| Employer | `employer@ablearning.co` |
| Administration | `admin@ablearning.co` |

These accounts are for local development only. The API refuses `SEED_DEV` in
staging and production.

## Connect Flutter

By default, Flutter uses the real API at `http://localhost:8080/api/v1`.
Override it for a device or deployed backend with:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Mock mode is opt-in with `--dart-define=USE_MOCK_API=true`.

## Validation

```bash
go test ./...
go vet ./...
```

Role access is checked by the API middleware and domain handlers. The API
does not treat hidden Flutter navigation as an authorization boundary.
