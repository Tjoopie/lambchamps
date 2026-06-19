---
name: devcockpit-platform
description: >
  How to build on DevCockpit. Bootstrap sequence, MCP tools, common mistakes,
  and the automated bug fix loop.
---

# Building on DevCockpit

You are building an app on the DevCockpit platform.

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
-> `dc__create_agent` with `anthropic` or `openai` provider step
-> Call via `/public/agents/execute` from frontend or `dc__execute_agent` from Cursor

### Need to read/write app data?
-> `dc__create_agent` with `mongodb` MCP steps (search, insert, update, delete)
-> Steps auto-route to your dedicated DB — no connection strings needed
-> Call via `/public/agents/execute` from frontend

### Need a data API for the browser?
-> Frontend calls `/public/agents/execute` with your agent_id
-> Returns JSON result synchronously — no Express server needed

### Need real-time chat?
-> Frontend calls `/public/agents/chat` with `stream: true`
-> SSE streaming with auto memory extraction — no custom WebSocket

### Need to process files/images?
-> DAM upload via `/public/dam/assets/upload`
-> Then `dam__process_image` or `dam__process_document` agent workflows

### Need IoT device data?
-> `/public/iot/telemetry` for reads
-> `dc__iot_device_register` for writes
-> MQTT -> Pulsar pipeline handles real-time ingestion

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

## Circuit Breaker

If ANY of these happen during your build session:
- A dc__* tool returns `insufficient_scope` -> STOP. The scope needs to be granted. Post a handoff note.
- A dc__* tool returns 500 or unexpected error -> STOP. Use dc_fix__diagnose_and_fix if available, or post a handoff note.
- /public/agents/execute returns rate_limited -> STOP. Wait and retry. Do NOT build a bypass.
- Agent creation fails -> STOP. Post a handoff note with the error.

In ALL cases: do NOT build direct MongoDB connections, raw LLM calls, or standalone servers as a workaround.

## Key Rules

- **Never invent template_ids.** Always get them from `dc__discover_app_schema` or `dc__propose_template_binding`.
- **Never call contextualizer-pipeline-v5 directly.** It's internal-only and will timeout. Use `dc__pim_upsert_smart` instead.
- **PIM writes**: ALWAYS use `dc__pim_upsert` or `POST /public/pim/items`. Collection is always `products`.
- **Template binding**: First-time template use requires `dc__propose_template_binding` -> review -> `dc__confirm_template_binding`.
- Check `dc__list_pending_proposals` at session start for orphaned proposals.

## When Things Break — The Fix Loop

If an MCP tool returns a 500 error, wrong data, or unexpected behavior:

1. **Code bug** -> call `dc_fix__diagnose_and_fix` with the tool name, error, and input
2. **Config issue** (403, "not in allowlist", "template not found") -> call `dc_fix__resolve_config`

### When NOT to use the fix tools
- **400 / 422** — your input is malformed. Fix your payload.
- **Tool not found** — feature request, not a bug.
- **Slow responses** — performance issue, not a code bug.

## Common Mistakes

1. Calling agents not in your allowlist (call `dc__list_agents` first)
2. Creating products without template bindings (always bind first)
3. Writing to custom MongoDB collections (data becomes invisible to platform)
4. Hardcoding template_ids instead of discovering them
5. Skipping `dc__describe_platform` (leads to using deprecated/nonexistent tools)