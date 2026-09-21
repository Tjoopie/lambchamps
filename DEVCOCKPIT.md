# DevCockpit Integration

**App**: LAMBCHAMPS
**App ID**: `app_6uGYXH7Zvzq3`
**Description**: LAMBCHAMPS VOTING APP

## Quick Start

1. Get your MCP key from the DevCockpit admin panel
2. Copy `.cursor/mcp.example.json` to `.cursor/mcp.json` and fill in your key
3. Copy `.env.template` to `.env` and fill in your details
4. Restart Cursor and call `dc__describe_platform` first

## Architecture Rules

- All data access goes through DevCockpit agents → /public/agents/execute
- All LLM calls go through DevCockpit agents (anthropic/openai provider steps)
- NEVER use MongoClient, mongoose, or raw database connections in app code
- NEVER use raw ANTHROPIC_API_KEY or OPENAI_API_KEY in app code
- NEVER build standalone Express/API servers — use /public/agents/execute
- If a platform tool fails, STOP and report via dc__handoff_post — do not build around it

## MCP Connection

```json
{
  "mcpServers": {
    "devcockpit": {
      "url": "https://devcockpit.ai/mcp/app/app_6uGYXH7Zvzq3",
      "headers": {
        "Authorization": "Bearer <YOUR_MCP_KEY>"
      }
    }
  }
}
```

## Bootstrap Sequence

1. `dc__describe_platform` — understand available tools and agents
2. `dc__discover_app_schema` — discover templates for your domain
3. `dc__propose_template_binding` — propose template bindings
4. `dc__confirm_template_binding` — confirm bindings (two-phase commit)
5. `dc__pim_upsert_smart` — create products/entities with bound templates

## Architecture

This app connects to DevCockpit via MCP (Model Context Protocol).
All data operations go through platform tools — never write directly to platform databases.

### Key Rules
- Use `dc__pim_upsert` for all product/catalog data (collection is always `products`)
- Governed catalog writes (`dc__catalog_write`) are fail-closed: the platform mints the `prd_<uuid>` UID and a class only accepts writes once its match rule is ratified. A `match_rule_missing` reply is by design, not a bug — classes activate as rules are ratified.
- Resolve template IDs from the registry (never invent them)
- Use `dc__discover_app_schema` to understand your data model
- All telemetry goes through `dc__publish_telemetry`
- Check `dc__handoff_list` at session start for platform updates
- If a tool returns 500, use `dc_fix__diagnose_and_fix` (see platform-bug-fix-protocol.md)
