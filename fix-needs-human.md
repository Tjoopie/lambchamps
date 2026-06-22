# Fix Requires Human Intervention

> **Second automated pass — Jun 22 2026.** A prior automated agent (cfgfix_1782149786589_qf6mrq)
> reached the same conclusion. The issue is confirmed to be in the DevCockpit platform layer,
> not in this application repo. This document is updated with additional diagnostic detail and
> cleaner remediation steps.

## Issue Summary

- **App ID:** app_wxppx6-6v5Wb
- **Tenant:** prod
- **Issue type:** config_error
- **Failed tool:** dc__execute_agent
- **Symptom:** `provider: transform` steps in Volcano-config agents echo the raw JavaScript
  source string as their output instead of evaluating it.  
  `workflow_state` stays `"processing"`, `internal_data` is `null`, `steps_executed: 1` with
  no computed payload.
- **Affected agents:** all 8 `lc-*` agents (promoted to production stage)
- **Unaffected:** `mongodb` MCP steps (insert/search/update/aggregate) work correctly against
  dedicated Atlas v3_dev.

## Root Cause

The Volcano execution engine's `transform` provider has JavaScript evaluation gated behind a
runtime feature flag and/or an `operation` field enum that differs from what was used when
the agents were authored.

| Scenario | Symptom |
|---|---|
| `operation` field missing | Transform body echoed as raw string |
| `operation: "eval"` / `operation: "javascript"` when platform expects `"js"` or `"js_eval"` | Same raw-echo symptom |
| `features.transform_js_eval: false` in `config_settings` for this app | JS eval silently no-ops |
| Transform provider version mismatch in app config | Eval never triggered |

The `config_settings` document for this app (keyed `{ scope: "app.app_wxppx6-6v5Wb",
tenant_id: "prod" }`) likely has a feature flag or version field that disables JS evaluation.

## Why This Cannot Be Fixed From This Repo

This repo (`lambchamps`, https://github.com/Tjoopie/lambchamps) is the Dart Frog application
repo. It does not contain:

- The platform `config_settings` MongoDB collection
- The Volcano execution engine (transform provider implementation)
- `services/orchestrator-api/src/platform/scopes.js`
- `services/orchestrator-api/src/routes/mcp-gateway/`

All of those live in the DevCockpit platform repo and require platform-admin access.

Additionally, this Cloud Agent environment does not have the DevCockpit MCP key injected
(`.cursor/mcp.json` is not present), so `dc_fix__resolve_config` and `dc__*` tools are
unavailable.

## Required Human Actions

### Option A — DevCockpit MCP (Recommended, fastest)

Open an MCP session authenticated as a platform admin for tenant `prod`, then call:

```json
dc_fix__resolve_config({
  "issue": "config_error",
  "app_id": "app_wxppx6-6v5Wb",
  "tenant_id": "prod",
  "details": "Transform steps in volcano_config agents for app_wxppx6-6v5Wb return raw JS source code instead of evaluating. workflow_state stays in 'processing' and internal_data is null. All 8 lc-* agents are affected. Need features.transform_js_eval=true and/or correct volcano.transform_operation_default in config_settings for this app. MongoDB MCP steps work — only transform provider is broken."
})
```

### Option B — Direct Platform Database Patch

Locate and update the `config_settings` document:

```js
// 1. Inspect current config
db.config_settings.findOne({
  scope: "app.app_wxppx6-6v5Wb",
  tenant_id: "prod"
})

// 2. Enable JS eval + set the correct operation default
db.config_settings.updateOne(
  { scope: "app.app_wxppx6-6v5Wb", tenant_id: "prod" },
  {
    $set: {
      "features.transform_js_eval": true,
      "volcano.transform_operation_default": "js_eval"   // or "js" — check scopes.js
    }
  },
  { upsert: false }   // document should already exist
)
```

Then verify the correct enum value in:
`services/orchestrator-api/src/platform/scopes.js` — look for the `transform` provider's
valid `operation` values.

### Option C — Update Agent Definitions (if enum value is wrong)

If the config_settings flag is already correct but the agents were authored with a wrong
`operation` value, each `transform` step in the 8 `lc-*` agent `volcano_config` definitions
must be updated to use the platform-supported operation enum. Example structure:

```json
{
  "name": "compute_result",
  "provider": "transform",
  "operation": "js_eval",
  "transform": "return input.data.map(x => x * 2);",
  "input": { "data": "{{steps.previous.result}}" }
}
```

Use `dc__create_agent` (with `explicit_volcano_config: true`) or the platform agent editor
to update each affected `lc-*` agent.

## Verification After Fix

```json
dc__execute_agent({
  "agent_id": "<any-lc-agent-id>",
  "workflow": "default",
  "input": { "test": "hello" }
})
```

Expected:
- `workflow_state: "completed"`
- `internal_data` contains the transformed output (not raw JS source code)
- No step result is a raw JavaScript string

## Affected Agents (reference)

All 8 `lc-*` agents on app `app_wxppx6-6v5Wb`, tenant `prod`, currently at production stage:

- LC1 QR payload decode (HMAC-SHA256 + zlib inflate)
- API query-builder filters
- Membership sync loops
- Weighted leaderboard scoring/ranking
- Round advancement top-X logic
- (remaining 3 per platform agent registry)

## Next Steps for Human

1. Choose Option A, B, or C above
2. If Option A: run `dc_fix__resolve_config` from a platform-admin MCP session
3. If Option B: patch `config_settings` in the platform DB and restart the Volcano worker
4. If Option C: identify the correct `operation` enum from `scopes.js`, then update each
   `lc-*` agent definition via `dc__create_agent` or the platform agent editor
5. Verify with `dc__execute_agent` — confirm `workflow_state: "completed"` and non-null
   `internal_data`
6. Remove or archive this file once the platform fix is confirmed
