import { Pool, type PoolClient, type QueryResultRow } from "pg";
import {
  formatHotFileConflictError,
  normalizeHotFiles,
} from "./lock-check.js";
import type {
  BridgeBuild,
  BridgeState,
  BuildStatus,
  HotFileConflict,
} from "./types.js";
import { ACTIVE_STATUSES } from "./types.js";

export class BridgeDb {
  private readonly pool: Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({
      connectionString,
      max: 2,
      ssl: connectionString.includes("localhost")
        ? undefined
        : { rejectUnauthorized: false },
    });
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  async withTransaction<T>(
    fn: (client: PoolClient) => Promise<T>,
  ): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await fn(client);
      await client.query("COMMIT");
      return result;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async findHotFileConflict(hotFiles: string[]): Promise<HotFileConflict | null> {
    const normalized = normalizeHotFiles(hotFiles);
    if (normalized.length === 0) {
      return null;
    }

    const result = await this.pool.query<{
      id: string;
      task_id: string;
      hot_files: string[];
    }>(
      `SELECT id, task_id, hot_files
       FROM bridge_builds
       WHERE status = ANY($1::text[])
         AND hot_files && $2::text[]
       LIMIT 1`,
      [ACTIVE_STATUSES, normalized],
    );

    const row = result.rows[0];
    if (!row) {
      return null;
    }

    const overlapping = normalized.filter((file) => row.hot_files.includes(file));
    return {
      id: row.id,
      task_id: row.task_id,
      hot_files: row.hot_files,
      overlapping,
    };
  }

  async requestBuild(input: {
    track: string;
    taskId: string;
    spec: string;
    hotFiles?: string[];
    model?: string;
    requestedBy?: string;
  }): Promise<{ buildId: string }> {
    const hotFiles = normalizeHotFiles(input.hotFiles);
    const conflict = await this.findHotFileConflict(hotFiles);
    if (conflict) {
      throw new Error(formatHotFileConflictError(conflict));
    }

    return this.withTransaction(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO bridge_builds (track, task_id, spec, model, hot_files, requested_by)
         VALUES ($1, $2, $3, $4, $5::text[], $6)
         RETURNING id`,
        [
          input.track,
          input.taskId,
          input.spec,
          input.model ?? null,
          hotFiles,
          input.requestedBy ?? "claude",
        ],
      );

      const buildId = insert.rows[0]?.id;
      if (!buildId) {
        throw new Error("Failed to create build");
      }

      await this.refreshBridgeState(client);
      return { buildId };
    });
  }

  async getState(): Promise<{
    state: BridgeState;
    activeBuilds: BridgeBuild[];
  }> {
    const [stateResult, buildsResult] = await Promise.all([
      this.pool.query<BridgeState>("SELECT * FROM bridge_state WHERE id = 1"),
      this.pool.query<BridgeBuild>(
        `SELECT * FROM bridge_builds
         WHERE status = ANY($1::text[])
         ORDER BY created_at DESC`,
        [ACTIVE_STATUSES],
      ),
    ]);

    const state = stateResult.rows[0];
    if (!state) {
      throw new Error("bridge_state seed row is missing");
    }

    return {
      state,
      activeBuilds: buildsResult.rows,
    };
  }

  async listTasks(filters?: {
    status?: BuildStatus;
    track?: string;
  }): Promise<BridgeBuild[]> {
    const clauses: string[] = [];
    const params: string[] = [];

    if (filters?.status) {
      params.push(filters.status);
      clauses.push(`status = $${params.length}`);
    }
    if (filters?.track) {
      params.push(filters.track);
      clauses.push(`track = $${params.length}`);
    }

    const where = clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";
    const result = await this.pool.query<BridgeBuild>(
      `SELECT * FROM bridge_builds ${where} ORDER BY created_at DESC`,
      params,
    );
    return result.rows;
  }

  async claimBuild(buildId: string): Promise<BridgeBuild> {
    return this.withTransaction(async (client) => {
      const updated = await client.query<BridgeBuild>(
        `UPDATE bridge_builds
         SET status = 'in_progress', updated_at = now()
         WHERE id = $1 AND status = 'requested'
         RETURNING *`,
        [buildId],
      );

      const build = updated.rows[0];
      if (!build) {
        throw new Error(`Build ${buildId} is not claimable (must be requested)`);
      }

      await this.refreshBridgeState(client);
      return build;
    });
  }

  async postUpdate(input: {
    buildId: string;
    summary: string;
    status?: BuildStatus;
    verification?: Record<string, unknown>;
    author?: string;
  }): Promise<{ updateId: string; build: BridgeBuild }> {
    return this.withTransaction(async (client) => {
      const existing = await client.query<BridgeBuild>(
        "SELECT * FROM bridge_builds WHERE id = $1",
        [input.buildId],
      );
      const build = existing.rows[0];
      if (!build) {
        throw new Error(`Build ${input.buildId} not found`);
      }

      const nextStatus = input.status ?? build.status;
      const verification =
        input.verification === undefined ? build.verification : input.verification;

      const updated = await client.query<BridgeBuild>(
        `UPDATE bridge_builds
         SET status = $2,
             verification = $3::jsonb,
             updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [input.buildId, nextStatus, verification ? JSON.stringify(verification) : null],
      );

      const nextBuild = updated.rows[0];
      if (!nextBuild) {
        throw new Error(`Failed to update build ${input.buildId}`);
      }

      const updateInsert = await client.query<{ id: string }>(
        `INSERT INTO bridge_updates (build_id, author, summary, status, verification)
         VALUES ($1, $2, $3, $4, $5::jsonb)
         RETURNING id`,
        [
          input.buildId,
          input.author ?? "cursor",
          input.summary,
          nextStatus,
          verification ? JSON.stringify(verification) : null,
        ],
      );

      const updateId = updateInsert.rows[0]?.id;
      if (!updateId) {
        throw new Error("Failed to create update");
      }

      await this.refreshBridgeState(client);
      return { updateId, build: nextBuild };
    });
  }

  async postDecision(input: {
    title: string;
    detail: string;
    supersedes?: string;
  }): Promise<{ decisionId: string }> {
    return this.withTransaction(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO bridge_decisions (title, detail, supersedes)
         VALUES ($1, $2, $3)
         RETURNING id`,
        [input.title, input.detail, input.supersedes ?? null],
      );

      const decisionId = insert.rows[0]?.id;
      if (!decisionId) {
        throw new Error("Failed to create decision");
      }

      await client.query(
        "UPDATE bridge_state SET last_updated = now() WHERE id = 1",
      );

      return { decisionId };
    });
  }

  async completeBuild(buildId: string): Promise<BridgeBuild> {
    return this.withTransaction(async (client) => {
      const updated = await client.query<BridgeBuild>(
        `UPDATE bridge_builds
         SET status = 'completed', updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [buildId],
      );

      const build = updated.rows[0];
      if (!build) {
        throw new Error(`Build ${buildId} not found`);
      }

      await this.refreshBridgeState(client);
      return build;
    });
  }

  private async refreshBridgeState(client: PoolClient): Promise<void> {
    const active = await client.query<QueryResultRow & BridgeBuild>(
      `SELECT * FROM bridge_builds
       WHERE status = ANY($1::text[])
       ORDER BY updated_at DESC`,
      [ACTIVE_STATUSES],
    );

    const openHotFiles = new Set<string>();
    for (const build of active.rows) {
      for (const file of build.hot_files) {
        openHotFiles.add(file);
      }
    }

    const latest = active.rows[0];
    const currentSlice = latest ? `${latest.track}/${latest.task_id}` : null;
    const currentStatus = latest?.status ?? null;

    await client.query(
      `UPDATE bridge_state
       SET current_slice = $1,
           current_status = $2,
           open_hot_files = $3::text[],
           last_updated = now()
       WHERE id = 1`,
      [currentSlice, currentStatus, Array.from(openHotFiles)],
    );
  }
}

let sharedDb: BridgeDb | null = null;

export function getBridgeDb(connectionString: string): BridgeDb {
  if (!sharedDb) {
    sharedDb = new BridgeDb(connectionString);
  }
  return sharedDb;
}

export function resetBridgeDbForTests(): void {
  sharedDb = null;
}
