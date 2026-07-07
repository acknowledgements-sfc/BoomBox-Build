import type { VercelRequest, VercelResponse } from "@vercel/node";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isAuthorized, isOriginAllowed, loadBridgeEnv } from "../bridge/src/auth.js";
import { getBridgeDb } from "../bridge/src/db.js";
import { createBridgeServer } from "../bridge/src/server.js";

function readBody(req: VercelRequest): unknown {
  if (req.body === undefined || req.body === null || req.body === "") {
    return undefined;
  }
  if (typeof req.body === "string") {
    try {
      return JSON.parse(req.body) as unknown;
    } catch {
      return req.body;
    }
  }
  return req.body;
}

export default async function handler(
  req: VercelRequest,
  res: VercelResponse,
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  let env;
  try {
    env = loadBridgeEnv();
  } catch (error) {
    const message = error instanceof Error ? error.message : "Configuration error";
    res.status(500).json({ error: message });
    return;
  }

  if (!isAuthorized(req.headers.authorization, env.bridgeToken)) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  if (!isOriginAllowed(req.headers.origin)) {
    res.status(403).json({ error: "Forbidden origin" });
    return;
  }

  const db = getBridgeDb(env.supabaseDbUrl);
  const server = createBridgeServer(db);
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, readBody(req));
  } catch (error) {
    const message = error instanceof Error ? error.message : "MCP handler failed";
    if (!res.headersSent) {
      res.status(500).json({ error: message });
    }
  }
}
