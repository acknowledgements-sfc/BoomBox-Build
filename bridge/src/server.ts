import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { BridgeDb } from "./db.js";
import { ALL_STATUSES } from "./types.js";

const buildStatusSchema = z.enum(ALL_STATUSES);

function jsonText(value: unknown): { type: "text"; text: string } {
  return {
    type: "text",
    text: JSON.stringify(value, null, 2),
  };
}

function toolFailure(message: string): {
  content: { type: "text"; text: string }[];
  isError: true;
} {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}

export function createBridgeServer(db: BridgeDb): McpServer {
  const server = new McpServer({
    name: "parkjukebox-bridge",
    version: "0.1.0",
  });

  server.registerTool(
    "request_build",
    {
      description:
        "Insert a bridge_builds row (status requested). Rejects overlapping hotFiles with in-flight builds.",
      inputSchema: {
        track: z.string().default("main"),
        taskId: z.string().min(1),
        spec: z.string().min(1),
        hotFiles: z.array(z.string()).optional(),
        model: z.string().optional(),
      },
    },
    async ({ track, taskId, spec, hotFiles, model }) => {
      try {
        const result = await db.requestBuild({
          track,
          taskId,
          spec,
          hotFiles,
          model,
        });
        return {
          content: [jsonText(result)],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "request_build failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "get_state",
    {
      description:
        "Return bridge_state snapshot plus all non-terminal builds.",
      inputSchema: {},
    },
    async () => {
      try {
        const result = await db.getState();
        return {
          content: [jsonText(result)],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "get_state failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "list_tasks",
    {
      description: "List bridge_builds, optionally filtered by status and track.",
      inputSchema: {
        status: buildStatusSchema.optional(),
        track: z.string().optional(),
      },
    },
    async ({ status, track }) => {
      try {
        const tasks = await db.listTasks({ status, track });
        return {
          content: [jsonText({ tasks })],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "list_tasks failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "claim_build",
    {
      description: "Mark a requested build in_progress and refresh bridge_state.",
      inputSchema: {
        buildId: z.string().uuid(),
      },
    },
    async ({ buildId }) => {
      try {
        const build = await db.claimBuild(buildId);
        return {
          content: [jsonText({ build })],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "claim_build failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "post_update",
    {
      description:
        "Append bridge_updates and update build status/verification.",
      inputSchema: {
        buildId: z.string().uuid(),
        summary: z.string().min(1),
        status: buildStatusSchema.optional(),
        verification: z.record(z.unknown()).optional(),
      },
    },
    async ({ buildId, summary, status, verification }) => {
      try {
        const result = await db.postUpdate({
          buildId,
          summary,
          status,
          verification,
        });
        return {
          content: [jsonText(result)],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "post_update failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "post_decision",
    {
      description:
        "Insert a bridge_decisions row (Claude only). Builder tools cannot write decisions.",
      inputSchema: {
        title: z.string().min(1),
        detail: z.string().min(1),
        supersedes: z.string().optional(),
      },
    },
    async ({ title, detail, supersedes }) => {
      try {
        const result = await db.postDecision({ title, detail, supersedes });
        return {
          content: [jsonText(result)],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "post_decision failed";
        return toolFailure(message);
      }
    },
  );

  server.registerTool(
    "complete_build",
    {
      description: "Mark a build completed and clear its hot files from bridge_state.",
      inputSchema: {
        buildId: z.string().uuid(),
      },
    },
    async ({ buildId }) => {
      try {
        const build = await db.completeBuild(buildId);
        return {
          content: [jsonText({ build })],
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : "complete_build failed";
        return toolFailure(message);
      }
    },
  );

  return server;
}
