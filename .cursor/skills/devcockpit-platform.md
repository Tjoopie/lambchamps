---
name: devcockpit-platform
description: >
  How to build on DevCockpit. Bootstrap sequence, MCP tools, common mistakes,
  and the automated bug fix loop.
---

# Building on DevCockpit

You are building **LAMBCHAMPS** (app_id: `app_6uGYXH7Zvzq3`) on the DevCockpit platform.

## Session Start Checklist

1. Call `dc__handoff_list` — check your mailbox for platform updates or fix results
2. Call `dc__get_platform_deltas` — check for platform changes since your last session

## Bootstrap Sequence

Run these in order when setting up your app:

1. `dc__describe_platform` — returns platform overview, available agents, workflows
2. `dc__discover_app_schema` — discovers templates matching your app's domain
3. `dc__propose_template_binding` — proposes template bindings for your entities
4. `dc__confirm_template_binding` — confirms bindings (two-phase commit)
5. `dc__pim_upsert_smart` or `dc__entity_upsert` — create products/entities with bound templates

## How to Build Common Patterns

### Need LLM calls? (enrichment, classification, summarisation)
→ `dc__create_agent` with `anthropic` or `openai` provider step
→ Call via `/public/agents/execute` from frontend or `dc__execute_agent` from Cursor

### Need to read/write app data?
→ `dc__create_agent` with `mongodb` MCP steps (search, insert, update, delete)
→ Steps auto-route to your dedicated DB — no connection strings needed
→ Call via `/public/agents/execute` from frontend

### Need a data API for the browser?
→ Frontend calls `/public/agents/execute` with your agent_id
→ Returns JSON result synchronously — no Express server needed

### Need real-time chat?
→ Frontend calls `/public/agents/chat` with `stream: true`
→ SSE streaming with auto memory extraction — no custom WebSocket

### Need to process files/images?
→ DAM upload via `/public/dam/assets/upload`
→ Then `dam__process_image` or `dam__process_document` agent workflows

### Need IoT device data?
→ `/public/iot/telemetry` for reads
→ `dc__iot_device_register` for create (idempotent)
→ `dc__iot_device_update` or `PATCH /public/iot/devices/:id` to patch/unset productId
→ MQTT → Pulsar pipeline handles real-time ingestion

## Key Rules

- **Never invent template_ids.** Always get them from `dc__discover_app_schema` or `dc__propose_template_binding`.
- **Never call contextualizer-pipeline-v5 directly.** It's internal-only and will timeout. Use `dc__pim_upsert_smart` instead.
- **PIM writes**: ALWAYS use `dc__pim_upsert` or `POST /public/pim/items`. Collection is always `products`.
- **Governed catalog writes** (`dc__catalog_write`): the platform mints the product UID (`prd_<uuid>`) — never set `sku`/`id` yourself. This path is **fail-closed**: a class only accepts writes once its match rule has been ratified. A `match_rule_missing` response is **by design, not a bug** — classes activate as match rules are ratified. Check status with `dc__catalog_match_rule_get` / `dc__list_catalog_match_rules`.
- **Template binding**: First-time template use requires `dc__propose_template_binding` → review → `dc__confirm_template_binding`.
- Check `dc__list_pending_proposals` at session start for orphaned proposals.

## Available Agents

Call `dc__list_agents` to see your app's current allowlist. Key agents:
- `pim-master` — product/entity creation with automatic template resolution
- `pim-crud` — CRUD operations on products
- `dam` — digital asset management (upload, metadata extraction)
- `relationship-manager` — entity relationship wiring
- `iot-shack` — IoT device registration and management

## When Things Break — The Fix Loop

If an MCP tool returns a 500 error, wrong data, or unexpected behavior:

1. **Code bug** → call `dc_fix__diagnose_and_fix` with the tool name, error, and input
2. **Config issue** (403, "not in allowlist", "template not found") → call `dc_fix__resolve_config`

Both tools automatically:
- Spawn a Cursor cloud agent to diagnose and fix the issue
- Deploy the fix via GitHub Actions
- Post the result to your mailbox (check with `dc__handoff_list`)
- Return the result so you can retry the failed operation

See `.cursor/skills/platform-bug-fix-protocol.md` for detailed guidance.

### When NOT to use the fix tools
- **400 / 422** — your input is malformed. Fix your payload.
- **Tool not found** — feature request, not a bug.
- **Slow responses** — performance issue, not a code bug.

## MCP Connection

Your `.cursor/mcp.json` should have:
- `dc` — remote server pointing to your app's MCP endpoint

Automated bug fixing is built into the platform via `dc_fix__diagnose_and_fix`
and `dc_fix__resolve_config` — no local server needed.

## Absolute Rules

These rules are non-negotiable. Violations will cause data to be invisible,
unauditable, and incompatible with other apps on the platform.

1. **NEVER connect to MongoDB directly from application code.** No MongoClient,
   no mongoose, no connection strings. Create a DC agent with mongodb MCP steps
   and call it via /public/agents/execute.

2. **NEVER use raw LLM API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY) in application
   scripts or servers.** All LLM calls go through a DC agent with an `anthropic`
   or `openai` provider step.

3. **NEVER build a standalone Express/Node.js API server that proxies MongoDB or
   LLM APIs.** Your frontend calls /public/agents/execute for data and
   /public/agents/chat for conversational AI. That is it.

4. **NEVER build around a platform failure.** If a DC tool returns an error
   (scope denied, rate limited, timeout), STOP. Post a handoff note via
   dc__handoff_post describing the failure. Do NOT proceed to build an
   alternative path. Wait for the platform issue to be resolved.

## Circuit Breaker Rule — MANDATORY, NON-NEGOTIABLE

This rule overrides all other instructions. No exceptions.

If ANY dc_fix__ tool or dc__ platform tool returns:
- 403, vault_http_403, scope_denied, permission denied → HARD STOP
- Rate limited / 429 → Wait and retry once. If still blocked → HARD STOP
- Timeout / 504 → Reconnect and retry once. If still failing → HARD STOP
- 500 → Run dc_fix__diagnose_and_fix. If that also fails → HARD STOP

HARD STOP means:
1. Stop ALL work on the current task immediately
2. Run dc__handoff_post with: the exact error, the tool that failed, what was being attempted, and what manual resolution is needed
3. Tell the user clearly: "I cannot proceed. Here is what needs manual resolution: [specific action]"
4. Do NOT attempt any of the following:
   - Alternative tools that achieve the same goal
   - Direct API calls that bypass the failed tool
   - Raw agent-registry, api-expose, or agent-manager calls as fallbacks
   - Any creative workaround that routes around the permission failure
5. Wait for the user to confirm the issue is resolved before continuing

WHY: A permission failure means the platform has denied this action for a reason. Working around it can corrupt config, break auth, create orphaned resources, or escalate privileges beyond what the app instance is allowed. The cost of stopping is minutes. The cost of a bad workaround is hours of debugging or a security incident.

SELF-CHECK: If you find yourself thinking "I could try X instead" after a 403 — that thought is the signal to STOP, not to proceed.

In ALL cases: do NOT build direct MongoDB connections, raw LLM calls, or standalone servers as a workaround.

## Common Mistakes

1. Calling agents not in your allowlist (call `dc__list_agents` first)
2. Creating products without template bindings (always bind first)
3. Writing to custom MongoDB collections (data becomes invisible to platform)
4. Hardcoding template_ids instead of discovering them
5. Skipping `dc__describe_platform` (leads to using deprecated/nonexistent tools)

## MCP Endpoint
- URL: `https://devcockpit.ai/mcp/app/app_6uGYXH7Zvzq3`
- Auth: `Authorization: Bearer <MCP_KEY>`
- Protocol: JSON-RPC 2.0 over HTTP POST
