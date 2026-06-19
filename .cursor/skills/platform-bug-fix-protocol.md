---
name: platform-bug-fix-protocol
description: >-
  Teaches app instance Cursors when and how to use dc_fix__diagnose_and_fix
  and dc_fix__resolve_config to automatically fix DevCockpit platform bugs
  and configuration issues via Cursor SDK cloud agents.
---

# Platform Bug Fix Protocol

When you hit a platform bug or configuration issue while building against the
DevCockpit MCP gateway, two tools are available for automated resolution.
Both tools post results to the originating app's mailbox automatically so
there is an audit trail even if the calling session dies.

## Which Tool to Use

| Symptom | Tool | Why |
|---|---|---|
| **500 / runtime crash** from a `dc__*` tool | `dc_fix__diagnose_and_fix` | Code bug — needs a source-code patch |
| **Wrong data returned** (fields missing, null, incorrect) | `dc_fix__diagnose_and_fix` | Code bug in the handler |
| **403 insufficient_scope** | `dc_fix__resolve_config` (issue_type: `missing_scope`) | App's scope array is incomplete |
| **tool_not_allowed** | `dc_fix__resolve_config` (issue_type: `missing_allowlist`) | Tool not in the app's allowlist |
| **template_not_found** | `dc_fix__resolve_config` (issue_type: `missing_template`) | Template binding missing or wrong |
| **Config-related error** (bad default, wrong env ref) | `dc_fix__resolve_config` (issue_type: `config_error`) | Misconfiguration in config_settings |
| **Stale/orphaned data** blocking operations | `dc_fix__resolve_config` (issue_type: `stale_data`) | Cleanup needed |

### When NOT to use either tool

- **400 / 422** — your input is malformed. Fix your payload, not the platform.
- **Tool not found** — the tool doesn't exist yet. That's a feature request, not a bug.
- **Slow responses** — performance issues need profiling, not a code patch.
- **Missing feature** — if the tool exists but doesn't do what you want, that's a feature gap.

## dc_fix__diagnose_and_fix — Code Bugs

Use for 500s, wrong data, runtime crashes, and handler errors.

```json
{
  "tool_name": "dc__pim_upsert",
  "error_message": "500 Internal Server Error: Cannot read properties of undefined (reading 'template_id')",
  "error_stack": "TypeError: Cannot read properties of undefined...\n    at handlePimUpsert (mcp-gateway.js:4231:42)",
  "input_payload": "{\"app_id\":\"payf_001\",\"items\":[{\"name\":\"Test Product\"}]}",
  "context": "Trying to upsert a PIM product for the PAYF catalog. The upsert worked yesterday but fails today after the template binding changes.",
  "app_id": "payf_001",
  "mailbox_note_id": "6789abc..."
}
```

### Required fields

- `tool_name` — which dc__ tool failed
- `error_message` — the error text or HTTP status
- `context` — what you were trying to do (be specific, this helps the agent find the bug)

### Optional but helpful

- `error_stack` — stack trace if you have it
- `input_payload` — the JSON input that caused the failure
- `app_id` — your app instance ID (required for mailbox feedback)
- `mailbox_note_id` — the `_id` of the mailbox note that prompted this fix (links audit trail)

## dc_fix__resolve_config — Configuration & Data Issues

Use for scope/allowlist/template/config/stale-data problems.

```json
{
  "app_id": "app_hfxOaTPQdZ7I",
  "issue_type": "missing_scope",
  "tool_name": "dc__pim_upsert",
  "error_message": "insufficient_scope: requires pim:write",
  "context": "App needs pim:write scope to upsert products but it was not granted at registration.",
  "mailbox_note_id": "6789abc..."
}
```

### Required fields

- `app_id` — the affected app instance ID
- `issue_type` — one of: `missing_scope`, `missing_allowlist`, `missing_template`, `config_error`, `stale_data`
- `tool_name` — the MCP tool that surfaced the error
- `error_message` — the error message
- `context` — what the app was trying to do

### Optional

- `mailbox_note_id` — links the fix to the originating complaint

## After the Fix

Both tools return the same shape:

- `fixed: true/false` — whether a fix was pushed
- `deploy_status` — `success`, `failed`, `timeout`, `dispatch_failed`, or `not_required` (config fixes)
- `retry_now: true/false` — whether you should retry your original operation

### Mailbox audit trail

Both tools automatically post the result to the app's mailbox via
`dc__ops_handoff_post`. Check `dc__handoff_list` to see the audit trail.
Tags: `auto-fix`, `addressed` or `partial`, and the tool name.

### If `retry_now: true`

Retry your original failed operation immediately. The fix has been deployed (or pushed for config changes).

### If `retry_now: false`

Stop and report the issue to the operator. Possible reasons:
- The agent couldn't identify the bug
- The fix was pushed but deploy failed
- The error requires architectural changes (agent wrote `/tmp/fix-needs-human.md`)

## Retry Limits

- **Max 5 fix attempts per session.** After 5, stop and escalate to the operator.
- **Same-error rule:** If you retry after a fix and get the **exact same error**, stop immediately. The fix didn't work. Do not call the same tool again with the same error — escalate instead.

## Good vs Bad Bug Reports

### Good

> `context`: "Upserting a PIM product with template binding template:content:youtube_reel.
> Yesterday this worked. Today it returns 500 with 'template_id undefined'. The template
> was confirmed via dc__propose_template_binding last week."

Specific, includes timeline, mentions what changed.

### Bad

> `context`: "It doesn't work"

No detail. The cloud agent will waste time guessing.
