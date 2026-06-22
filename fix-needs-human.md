# Fix Requires Human Intervention

## Issue
- **App ID:** app_wxppx6-6v5Wb
- **Issue type:** config_error
- **Failed tool:** dc__execute_agent
- **Error:** Transform step output is raw JS string; `workflow_state` stuck in "processing"; `internal_data` is null

## Root Cause Analysis

Transform steps in explicitly created `volcano_config` agents are returning the JS source
code verbatim as their output instead of evaluating/executing it. This means:

1. The Volcano engine is receiving the `transform` field value but not invoking a JS evaluator.
2. `workflow_state` never advances past "processing" because the transform output is a raw
   string rather than the structured JSON the next step or terminal normalizer expects.
3. `internal_data` is null because the workflow never produces a valid result payload.

### Most Likely Cause

The Volcano engine's transform provider requires the `operation` field to be set to the
correct evaluation mode. The supported values differ between platform versions. Common
root causes:

| Scenario | Symptom |
|---|---|
| `operation` omitted when JS eval is required | Transform body returned as raw string |
| `operation: "eval"` used but platform expects `"js"` or `"js_eval"` | Same |
| `features.transform_js_eval` disabled in app `config_settings` | JS eval silently no-ops |
| Transform provider version mismatch in app config | Eval never triggered |

The `config_settings` document for this app (keyed `{ scope: "app.app_wxppx6-6v5Wb",
tenant_id: "prod" }`) may have a feature flag or provider version field that disables
or misconfigures JS evaluation for transform steps.

## What Needs To Be Done

### Option A — Via DevCockpit Platform Admin (Recommended)

Use `dc_fix__resolve_config` from an MCP-authenticated session:

```json
dc_fix__resolve_config({
  "issue": "config_error",
  "app_id": "app_wxppx6-6v5Wb",
  "tenant_id": "prod",
  "details": "Transform steps in volcano_config agents return raw JS source code instead of evaluating. workflow_state stays in 'processing' and internal_data is null. Need to ensure config_settings enables JS eval for transform steps and/or the correct operation value is documented for this app instance."
})
```

### Option B — Direct Platform Database Fix

Locate the `config_settings` document:

```js
db.config_settings.findOne({
  scope: "app.app_wxppx6-6v5Wb",
  tenant_id: "prod"
})
```

Check for any of these fields and correct them:

```js
// If a transform feature flag is present and false, enable it:
db.config_settings.updateOne(
  { scope: "app.app_wxppx6-6v5Wb", tenant_id: "prod" },
  {
    $set: {
      "features.transform_js_eval": true,
      "volcano.transform_operation_default": "js_eval"  // or the correct enum value
    }
  }
)
```

### Option C — Agent Definition Fix (if operation value is wrong)

If the issue is in the agent definitions themselves (wrong `operation` value), each
`transform` step in the affected agent's `volcano_config` should be updated to use the
platform-supported operation enum. Check the platform scopes/providers file:

- `services/orchestrator-api/src/platform/scopes.js` — lists valid transform operation values
- `services/orchestrator-api/src/routes/mcp-gateway/` — MCP gateway for dc__execute_agent

Once the correct `operation` value is confirmed, update agent definitions via:

```json
dc__create_agent({
  "explicit_volcano_config": true,
  "volcano_config": {
    "workflows": {
      "default": {
        "steps": [
          {
            "name": "transform_result",
            "provider": "transform",
            "operation": "<correct-value-from-platform>",
            "transform": "{{input.data}}",
            "input": { "data": "{{steps.previous.result}}" }
          }
        ]
      }
    }
  }
})
```

## Why This Cannot Be Fixed From This Repo

This repo (`lambchamps`, https://github.com/Tjoopie/lambchamps) is the Dart Frog
application repo. It does not contain:

- The platform `config_settings` MongoDB collection
- The Volcano execution engine (transform provider implementation)
- `services/orchestrator-api/src/platform/scopes.js`
- `services/orchestrator-api/src/routes/mcp-gateway/`

All of those live in the DevCockpit platform repo and require platform-admin access.

## Verification After Fix

After applying the fix, verify with:

```json
dc__execute_agent({
  "agent_id": "<agent-with-transform-step>",
  "workflow": "default",
  "input": { "test": "hello" }
})
```

Expected result:
- `workflow_state: "completed"`
- `internal_data` contains the transformed output (not raw JS source code)
- No step shows raw JS string as its result

## Next Steps for Human

1. Open an MCP session authenticated as a platform admin for tenant `prod`
2. Run `dc_fix__resolve_config` with the details above (Option A), OR
3. Inspect and patch the platform `config_settings` document for `app.app_wxppx6-6v5Wb`
   to enable transform JS evaluation (Option B), OR
4. If the operation enum is wrong in agent definitions, identify the correct value from
   the platform scopes file and update agent definitions accordingly (Option C)
5. Re-run an agent with a `transform` step to confirm `workflow_state: "completed"` and
   non-null `internal_data`
