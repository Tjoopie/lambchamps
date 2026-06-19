# lambchamps_df

Backend API for **Lamb Champs** — a single-competition livestock judging system.
Built with [Dart Frog](https://dartfrog.vgv.dev/) + MongoDB. Firebase is used for
authentication only; all competition data lives in MongoDB.

## Architecture

| Concern        | Approach                                                       |
| -------------- | -------------------------------------------------------------- |
| Framework      | Dart Frog                                                      |
| Database       | MongoDB (`mongo_dart`)                                         |
| Auth           | Firebase ID token verify on login; link to Mongo user by email |
| Generic CRUD   | `/v1/{collection}` for animals, users, groups, criteria, etc.  |
| Custom routes  | Excel import/export, QR result ingest, leaderboard compute     |
| Deployment     | Docker container (DevCockpit `dc__deploy_backend`)             |

## Configuration

Set the Mongo connection string via the `MONGO_URI` environment variable.
Falls back to `mongodb://localhost:27017/v2_dev` for local dev.

Auth is gated by `kFirebaseAuthBypass` in `constants/k.dart` — keep it `true`
for local dev until the Firebase service account is provisioned, then drop in
the real service account JSON and set it to `false`.

## Run locally

```bash
dart pub global activate dart_frog_cli   # one-time
dart_frog dev                            # serves on http://localhost:8080
```

## Deploy (DevCockpit)

Pushing to `main` triggers `.github/workflows/deploy-backend.yml`, which builds
the Docker image and publishes it to GHCR. The running container is then
deployed via the DevCockpit `dc__deploy_backend` MCP tool, with `MONGO_URI`
injected as an app secret.
