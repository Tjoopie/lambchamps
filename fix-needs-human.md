# Fix Requires Human Intervention

## Issue
- **App ID:** app_wxppx6-6v5Wb
- **Issue type:** missing_scope
- **Failed tool:** dc__store_app_secret / dc__get_app_secret
- **Error:** vault_write_failed: vault_http_403: permission denied

## Root Cause
The app session scopes for `app_wxppx6-6v5Wb` do not include the `vault` or `secrets`
read/write scope. As a result, both `dc__store_app_secret` (write) and `dc__get_app_secret`
(read) return 403 permission denied.

## What Needs To Be Done

### Option A — Via DevCockpit Platform Admin (Recommended)
Use `dc_fix__resolve_config` from an MCP-authenticated session:
```
dc_fix__resolve_config({
  issue: "missing_scope",
  app_id: "app_wxppx6-6v5Wb",
  tenant_id: "prod",
  details: "Need vault:read and vault:write scopes added to app config_settings so dc__store_app_secret and dc__get_app_secret work for MONGO_URI storage"
})
```

### Option B — Direct Platform Database Fix
The config_settings document for this app (query: `{ scope: "app.app_wxppx6-6v5Wb", tenant_id: "prod" }`)
needs the `vault:read` and `vault:write` (or equivalent) scopes added to its `scopes` array.

### Option C — Platform Repo Code Change
If the vault scope is not registered in the scopes allowlist, it must be added to:
- `services/orchestrator-api/src/platform/scopes.js` (platform repo)
- And the MCP gateway scope-check logic in `services/orchestrator-api/src/routes/mcp-gateway/`

## Why This Cannot Be Fixed From This Repo
This repo (`lambchamps`, https://github.com/Tjoopie/lambchamps) is the Dart Frog
application repo. It does not contain:
- The platform `config_settings` MongoDB collection
- `services/orchestrator-api/src/platform/scopes.js`
- `services/orchestrator-api/src/routes/mcp-gateway/`

All of those live in the DevCockpit platform repo and require platform-admin access.

## Next Steps for Human
1. Open an MCP session authenticated as a platform admin for tenant `prod`
2. Run `dc_fix__resolve_config` with the details above, OR
3. Directly update the platform `config_settings` document for `app.app_wxppx6-6v5Wb`
   to include `vault:read` and `vault:write` in the `scopes` array
4. Verify by re-running `dc__store_app_secret` and `dc__get_app_secret` from an app session
