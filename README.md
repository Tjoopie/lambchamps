# LAMBCHAMPS

Built on [DevCockpit](https://devcockpit.ai) — composable agentic infrastructure.

## Getting Started

### 1. Connect to DevCockpit

Copy `.cursor/mcp.example.json` to `.cursor/mcp.json` and fill in:
- `<YOUR_MCP_KEY>` — your MCP key (starts with `mcp_...`, get from admin)

Restart Cursor. You should see ~200 tools in the MCP panel.

### 2. Verify Connection

Ask Cursor to call `dc__describe_platform`. If it returns platform info, you're connected.

### 3. Bootstrap Your App

Follow the sequence in `.cursor/skills/devcockpit-platform.md`:
1. `dc__describe_platform`
2. `dc__discover_app_schema`
3. `dc__propose_template_binding`
4. `dc__confirm_template_binding`

### 4. Automated Bug Fixing (Built-in)

If a platform tool returns a 500 error, call `dc_fix__diagnose_and_fix` via your MCP
connection. For config issues (403, missing scope), use `dc_fix__resolve_config`.
Both spawn a cloud agent to diagnose and fix the issue automatically.

### 5. Check Your Mailbox

Run `dc__handoff_list` to check for platform updates or messages from the DevCockpit team.

## Rules

All app logic goes through DevCockpit. See `.cursor/skills/devcockpit-platform.md`
for the full guide. Key rules:

- Data access: DC agents via `/public/agents/execute` (never direct MongoDB)
- LLM calls: DC agents with anthropic/openai steps (never raw API keys)
- If the platform fails: STOP, report via `dc__handoff_post`, do not build around it

## Project Structure

```
.cursor/
  skills/           # Cursor skill files for platform integration
  mcp.json          # MCP server connections (gitignored)
  mcp.example.json  # Template for mcp.json
src/                # Your app code
.env                # Environment variables (gitignored)
.env.template       # Template for .env
```

## Resources

- [DevCockpit Portal](https://devcockpit.ai)
- Platform skill: `.cursor/skills/devcockpit-platform.md`
- Fix protocol: `.cursor/skills/platform-bug-fix-protocol.md`
- App ID: `app_6uGYXH7Zvzq3`
