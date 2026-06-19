# <APP_NAME>

Built on [DevCockpit](https://devcockpit.ai) - composable agentic infrastructure.

## Getting Started

### 1. Connect to DevCockpit

Copy `.cursor/mcp.example.json` to `.cursor/mcp.json` and fill in:
- `<YOUR_APP_ID>` - your app instance ID (e.g., `app_xxxxxxxxxxxx`)
- `<YOUR_MCP_KEY>` - your MCP key (starts with `mcp_...`, get from admin)

Restart Cursor. You should see ~200 tools in the MCP panel.

### 2. Verify Connection

Ask Cursor to call `dc__describe_platform`. If it returns platform info, you're connected.

### 3. Bootstrap Your App

Follow the sequence in `.cursor/skills/devcockpit-platform.md`:
1. `dc__describe_platform`
2. `dc__discover_app_schema`
3. `dc__propose_template_binding`
4. `dc__confirm_template_binding`

### 4. Set Up Automated Bug Fixing (Optional)

The `dc_fix` server lets your Cursor automatically fix platform bugs:

1. Get a Cursor API key from cursor.com/dashboard/integrations
2. Get a GitHub PAT with repo + workflow scope
3. Get a `DC_OPS_MCP_KEY` from your DevCockpit admin
4. Fill in the `dc_fix` section in `.cursor/mcp.json`
5. Copy the DevCockpit repo path into the `args` array

When a platform tool fails, Cursor will automatically spawn a cloud agent to fix it.

### 5. Check Your Mailbox

Run `dc__handoff_list` to check for platform updates or messages from the DevCockpit team.

## Rules

All app logic goes through DevCockpit. See `.cursor/skills/devcockpit-platform.md`
for the full guide. Key rules:

- Data access: DC agents via `/public/agents/execute` (never direct MongoDB)
- LLM calls: DC agents with anthropic/openai steps (never raw API keys)
- If the platform fails: STOP, report via `dc__handoff_post`, do not build around it

## Project Structure

`
.cursor/
  skills/           # Cursor skill files for platform integration
  mcp.json          # MCP server connections (gitignored)
  mcp.example.json  # Template for mcp.json
src/                # Your app code
.env                # Environment variables (gitignored)
.env.template       # Template for .env
`

## Resources

- [DevCockpit Portal](https://devcockpit.ai)
- Platform skill: `.cursor/skills/devcockpit-platform.md`
- Fix protocol: `.cursor/skills/platform-bug-fix-protocol.md`