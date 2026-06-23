# Fix Requires Human Intervention

> **Third automated pass — Jun 23 2026.** Two prior automated agents
> (`cfgfix_1782149786589_qf6mrq`, and a second Jun 22 pass) diagnosed earlier
> issues (transform evaluation). Those are now resolved — Mongo MCP steps work
> and `lc-data-crud list` returns `workflow_state: "completed"`. This document
> supersedes the previous version and covers the **new** issue: HTTP 403 on
> all Volcano agent `http` steps targeting the app-backend.

---

## Issue Summary

- **App ID:** `app_wxppx6-6v5Wb`
- **Tenant:** `prod`
- **Issue type:** `config_error`
- **Failed tool:** `app-wxppx6-6v5wb--lc-leaderboard-recompute__group`
- **Symptom:** Every Volcano `http` step that calls
  `https://devcockpit.ai/public/app-backend/app_wxppx6-6v5Wb/internal/*`
  returns HTTP 403 **before the Dart container processes the request**.

Affected agent workflows (all share the same root cause):

| Agent | Workflow |
|-------|----------|
| `lc-leaderboard-recompute` | `group`, `round` |
| `lc-results-ingest-qr` | `ingest` |
| `lc-rounds-advance` | `advance` |
| `lc-membership-sync` | `reconcile` |
| `lc-data-crud` | `list_with_params` |
| `lc-animals-import` | `import_row` |

**Unaffected:** Mongo MCP steps inside the same agents work correctly against
the dedicated Atlas `v3_dev` database.

---

## Root Cause Analysis

The `/public/app-backend/:app_id/*` path is a Kong-proxied route that the
DevCockpit gateway registers when a backend is deployed via `dc__deploy_backend`.
A 403 at this layer (before the Dart container sees the request) indicates one
or more of the following mis-configurations in `config_settings` and/or the
agent definitions:

### Cause A — Kong route not yet registered (most likely)

`dc__deploy_backend` was dispatched (commit `b925593`, GHCR image public) but
the deploy workflow may not have completed the Kong route registration step.
The proxy has no upstream to forward to, so it rejects with 403.

`config_settings` field to check:

```js
// Expected after a successful dc__deploy_backend
db.config_settings.findOne(
  { scope: "app.app_wxppx6-6v5Wb", tenant_id: "prod" },
  { "settings.backend": 1 }
)
```

A healthy document should contain:

```json
{
  "settings.backend": {
    "image":              "ghcr.io/tjoopie/lambchamps:latest",
    "port":               8080,
    "health_check_path":  "/health",
    "status":             "running",
    "kong_route_id":      "<uuid>",
    "routes_prefix":      "/public/app-backend/app_wxppx6-6v5Wb"
  }
}
```

If `kong_route_id` is absent, `status` is `"pending"` / `"failed"`, or
`settings.backend` is missing entirely, the Kong route was never created.

### Cause B — Volcano HTTP steps missing the app auth header

The app-backend proxy requires the caller to present a valid credential.
Volcano `http` steps that omit an `Authorization` (or equivalent internal
service token) header are rejected 403 by the gateway even when the Kong route
is registered.

---

## Why This Cannot Be Fixed From This Repo

`lambchamps` is the Dart Frog application repo. It does not contain:

- The platform `config_settings` MongoDB collection
- The Kong route management layer
- The Volcano agent definitions for the `lc-*` agents
- `services/orchestrator-api/src/platform/scopes.js`

All remediation steps below require a **platform-admin MCP session** or direct
Atlas access.

---

## Remediation

### Step 1 — Diagnose backend deploy state

```js
// Run in MongoDB Atlas (platform db) or via a platform-admin MCP session
const doc = db.config_settings.findOne(
  { scope: "app.app_wxppx6-6v5Wb", tenant_id: "prod" }
);
printjson(doc?.settings?.backend);
```

### Step 2A — If backend is not deployed / Kong route missing

Re-dispatch the backend deploy from a platform-admin MCP session:

```json
dc__deploy_backend({
  "app_id": "app_wxppx6-6v5Wb",
  "image": "ghcr.io/tjoopie/lambchamps:latest",
  "port": 8080,
  "health_check_path": "/health"
})
```

Then verify the deploy reached a running state:

```json
dc__deploy_status({})
```

Expected: `backend.status === "running"` and `backend.kong_route_id` populated.

### Step 2B — If Kong route is registered but HTTP steps still return 403

The Volcano `http` steps need an app-scoped auth token. The canonical pattern:

1. Store an App API key in Vault (if not already present):

```json
dc__store_app_secret({
  "key": "APP_API_KEY",
  "value": "<ak_... key from DevCockpit App Instances panel>"
})
```

2. Each affected agent needs an additional `http` step to fetch a short-lived
   JWT before calling the app-backend, **or** the `http` step headers must
   include the App API key directly if the proxy accepts `x-api-key`:

```json
{
  "provider": "http",
  "name": "call_backend",
  "url": "https://devcockpit.ai/public/app-backend/app_wxppx6-6v5Wb/internal/leaderboard/recompute",
  "method": "POST",
  "headers": {
    "Content-Type": "application/json",
    "x-api-key": "{{context.app_secrets.APP_API_KEY}}"
  },
  "input": { "round": "{{input.round}}", "group_number": "{{input.group_number}}" }
}
```

   Check `services/orchestrator-api/src/routes/app-backend-proxy.js` for the
   exact header name the proxy expects (`x-api-key`, `Authorization`, or an
   internal `x-dc-internal-token`).

3. Update each of the 6 affected agents via `dc__create_agent` (explicit
   volcano_config) or the platform agent editor.

### Step 3 — Verify

```json
dc__execute_agent({
  "agent_id": "app-wxppx6-6v5wb--lc-leaderboard-recompute",
  "workflow": "group",
  "input": { "round": 1, "group_number": 1 }
})
```

Expected: `workflow_state: "completed"`, `internal_data.message` contains
`"Leaderboard recomputed for round 1 group 1"`.

---

## Dart Application Status

The Dart Frog backend code is **correct and ready**:

- All internal routes exist under `routes/internal/`:
  - `POST /internal/leaderboard/recompute`
  - `POST /internal/rounds/advance`
  - `POST /internal/membership/reconcile`
  - `POST /internal/import/row`
  - `POST /internal/qr/ingest`
  - `POST /internal/qr/build-results`
  - `POST /internal/qr/decode`
  - `POST /internal/query/build`
- GHCR image `ghcr.io/tjoopie/lambchamps:latest` is public, CI green at
  commit `b925593`
- Health endpoint `GET /health` returns `{"status": "ok"}`
- No code changes are needed in this repository

**No changes to this application repo will resolve the 403 — the fix is
entirely in the DevCockpit platform layer (Kong route registration and/or
Volcano agent HTTP step auth headers).**

---

## Checklist for Human Reviewer

- [ ] Run Step 1 diagnostic — inspect `config_settings.settings.backend`
- [ ] If `kong_route_id` missing → run Step 2A (re-deploy backend)
- [ ] Confirm `GET https://devcockpit.ai/public/app-backend/app_wxppx6-6v5Wb/health`
      returns 200 (not 403/404/502)
- [ ] If Kong route exists but 403 persists → run Step 2B (add auth headers to
      each Volcano `http` step)
- [ ] Run Step 3 verification → confirm `workflow_state: "completed"`
- [ ] Archive this file once all agents pass
