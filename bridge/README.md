# Coordination Bridge MCP Server

Shared state store for Claude (strategist) and Cursor (builder). Slice #0 infra.

## Deploy (Vercel)

1. Ensure the Supabase project exists and `bridge_0001` migration is applied
   (`supabase/migrations/bridge_0001_bridge_tables.sql`).
2. Set Vercel environment variables (Production + Preview):

| Name | Value |
|------|-------|
| `BRIDGE_TOKEN` | Shared bearer secret for both clients |
| `SUPABASE_DB_URL` | Postgres URI via **transaction pooler (port 6543)** |
| `SUPABASE_SECRET_KEY` | Server-only `sb_secret_...` key |

3. Deploy from repo root:

```bash
npm install
npx vercel deploy --prod
```

Public MCP endpoint: `https://<project>.vercel.app/mcp`

## Local development

```bash
npm install
npm run typecheck
npm test
```

Integration tests (`bridge/tests/round-trip.test.ts`) run when `SUPABASE_DB_URL` is set.

## Cursor connection (`.cursor/mcp.json`)

```json
{
  "mcpServers": {
    "parkjukebox-bridge": {
      "url": "https://<project>.vercel.app/mcp",
      "headers": {
        "Authorization": "Bearer <BRIDGE_TOKEN>"
      }
    }
  }
}
```

## Claude custom connector

- **URL:** `https://<project>.vercel.app/mcp`
- **Transport:** Streamable HTTP
- **Auth:** Bearer token header with `BRIDGE_TOKEN`

## MCP tools

| Tool | Caller | Purpose |
|------|--------|---------|
| `request_build` | Claude | Queue a build; rejects overlapping `hotFiles` |
| `get_state` | both | Snapshot + active builds |
| `list_tasks` | both | Filter builds by status/track |
| `claim_build` | Cursor | `requested` -> `in_progress` |
| `post_update` | Cursor | Append progress + update build |
| `post_decision` | Claude | Record locked decision changes |
| `complete_build` | Cursor | Mark build completed |

## Session rituals

**Cursor:** `get_state` -> `list_tasks` -> `claim_build` -> build -> `post_update` -> `complete_build`

**Claude:** `get_state` at session start; `request_build` when a slice is ready; `post_decision` when a lock changes.
