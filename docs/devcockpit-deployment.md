# Lamb Champs — DevCockpit Deployment

## App instance

| Key | Value |
|-----|-------|
| App ID | `app_wxppx6-6v5Wb` |
| Agent prefix | `app-wxppx6-6v5wb--` |
| Public API | `https://devcockpit.ai/public` |
| Dedicated Mongo | `v3_dev` (Atlas URI configured in DevCockpit secrets) |

## Architecture

- **Volcano agents** — CRUD, reads, aggregation, response shaping (object `transform` steps only).
- **Compute backend** — Dart Frog container for crypto (HMAC/zlib), membership reconcile loops, query-builder, single-row import.
- **Flutter** — calls `POST /public/agents/execute` with Contact JWT.

## Compute backend

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/tjoopie/lambchamps:latest` |
| Port | `8080` |
| Health | `GET /health` |
| Public prefix | `/public/app-backend/app_wxppx6-6v5Wb` |
| Base URL | `https://devcockpit.ai/public/app-backend/app_wxppx6-6v5Wb` |

### Internal routes (Volcano `http` steps only)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/internal/qr/decode` | LC1 base64url + zlib + HMAC-8 verify |
| POST | `/internal/qr/ingest` | Full QR result ingest flow |
| POST | `/internal/qr/build-results` | Build result payload from QR batch |
| POST | `/internal/query/build` | Build Mongo filter from query-builder params |
| POST | `/internal/membership/reconcile` | Bidirectional group/user membership sync |
| POST | `/internal/import/row` | Single animal upsert by `_id` |
| POST | `/internal/leaderboard/recompute` | Recompute round or group leaderboard scores |
| POST | `/internal/rounds/advance` | Advance to next round (top-X selection) |

### Environment (via DevCockpit secrets)

- `MONGO_URI` — Atlas connection string (required)
- `SUBMISSION_SIGNING_SECRET` — defaults to `lamb-champs-dev-secret` in code if unset

## Agents (production)

| Agent | Workflows |
|-------|-----------|
| `lc-data-crud` | `list`, `list_with_params`, `get`, `create`, `update`, `delete` |
| `lc-auth-login` | `login` |
| `lc-membership-sync` | `reconcile`, `add_user_to_group`, `remove_user_from_group`, `set_group_judges` |
| `lc-animals-import` | `import_batch`, `import_row` |
| `lc-results-ingest-qr` | `ingest` |
| `lc-leaderboard-recompute` | `group`, `round` |
| `lc-leaderboards-read` | `read` |
| `lc-rounds-advance` | `advance` |

## Mongo indexes (apply once in Atlas UI)

```
users:           { firebase_uid: 1 }, { deleted: 1 }
animals:         { firebase_uid: 1 }, { group_id: 1, deleted: 1 }
judging_results: { qr_batch_id: 1 }, { round: 1, animal_id: 1 }, { deleted: 1 }
leaderboards:    { round: 1, rank: 1 }, { round: 1, group_number: 1 }
memberships:     { user_id: 1, group_id: 1 } unique
```

## Verification (2026-06-23)

| Check | Result |
|-------|--------|
| Terminal transform (`lc-data-crud` list) | PASS |
| CRUD list `round_config` | PASS |
| Leaderboard recompute aggregate | PASS (empty seed) |
| Backend health (`GET /health`) | BLOCKED — 403 from app-backend proxy |
| QR decode / membership HTTP steps | BLOCKED — 403 from app-backend proxy |
| All Volcano `http` steps to `/internal/*` | BLOCKED — see `fix-needs-human.md` |

> **Action required:** Backend Kong route not registered or Volcano HTTP steps
> missing auth header. Follow `fix-needs-human.md` for step-by-step remediation.

## Transform steps

Use **object** transforms with `{{steps.*}}` placeholders only. Never put JavaScript strings in `transform` fields.

```json
{
  "provider": "transform",
  "name": "terminal_response",
  "transform": {
    "success": true,
    "workflow_state": "completed",
    "internal_data": { "data": "{{steps.search.result}}" }
  }
}
```
