import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { BridgeDb, resetBridgeDbForTests } from "../src/db.js";

const dbUrl = process.env.SUPABASE_DB_URL;
const describeWithDb = dbUrl ? describe : describe.skip;

describeWithDb("bridge round-trip", () => {
  let db: BridgeDb;
  const taskId = `slice0-test-${randomUUID()}`;
  const hotFiles = [`bridge/tests/${taskId}/file-a.ts`];

  beforeAll(async () => {
    if (!dbUrl) {
      return;
    }
    resetBridgeDbForTests();
    db = new BridgeDb(dbUrl);
  });

  afterAll(async () => {
    if (db) {
      await db.close();
    }
    resetBridgeDbForTests();
  });

  it("runs request, claim, update, complete, and rejects overlap", async () => {
    const requested = await db.requestBuild({
      track: "infra",
      taskId,
      spec: "integration test build",
      hotFiles,
    });

    expect(requested.buildId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    );

    const stateAfterRequest = await db.getState();
    expect(stateAfterRequest.activeBuilds.some((b) => b.id === requested.buildId)).toBe(
      true,
    );

    const overlapAttempt = db.requestBuild({
      track: "infra",
      taskId: `${taskId}-overlap`,
      spec: "should fail",
      hotFiles,
    });
    await expect(overlapAttempt).rejects.toThrow(/Hot-file conflict/);

    const claimed = await db.claimBuild(requested.buildId);
    expect(claimed.status).toBe("in_progress");

    const stateAfterClaim = await db.getState();
    expect(stateAfterClaim.state.open_hot_files).toEqual(
      expect.arrayContaining(hotFiles),
    );

    const updated = await db.postUpdate({
      buildId: requested.buildId,
      summary: "tests passing",
      status: "in_progress",
      verification: { tests: true },
    });
    expect(updated.updateId).toBeTruthy();
    expect(updated.build.verification).toEqual({ tests: true });

    const completed = await db.completeBuild(requested.buildId);
    expect(completed.status).toBe("completed");

    const stateAfterComplete = await db.getState();
    expect(
      stateAfterComplete.activeBuilds.some((b) => b.id === requested.buildId),
    ).toBe(false);
    expect(stateAfterComplete.state.open_hot_files).not.toEqual(
      expect.arrayContaining(hotFiles),
    );
  });
});
