import { describe, expect, it } from "vitest";
import {
  arraysOverlap,
  findHotFileConflict,
  normalizeHotFiles,
} from "../src/lock-check.js";
import type { BridgeBuild } from "../src/types.js";

function build(
  partial: Partial<BridgeBuild> & Pick<BridgeBuild, "id" | "task_id" | "status" | "hot_files">,
): BridgeBuild {
  return {
    track: "main",
    spec: "spec",
    model: null,
    verification: null,
    requested_by: "claude",
    created_at: "2026-07-06T00:00:00.000Z",
    updated_at: "2026-07-06T00:00:00.000Z",
    ...partial,
  };
}

describe("normalizeHotFiles", () => {
  it("trims and deduplicates files", () => {
    expect(normalizeHotFiles([" a.ts ", "a.ts", "b.ts", ""])).toEqual([
      "a.ts",
      "b.ts",
    ]);
  });

  it("returns empty array for undefined", () => {
    expect(normalizeHotFiles(undefined)).toEqual([]);
  });
});

describe("arraysOverlap", () => {
  it("returns overlapping entries", () => {
    expect(arraysOverlap(["a.ts", "b.ts"], ["b.ts", "c.ts"])).toEqual(["b.ts"]);
  });

  it("returns empty when either side is empty", () => {
    expect(arraysOverlap([], ["a.ts"])).toEqual([]);
    expect(arraysOverlap(["a.ts"], [])).toEqual([]);
  });
});

describe("findHotFileConflict", () => {
  it("detects overlap with in-flight builds", () => {
    const existing = [
      build({
        id: "11111111-1111-1111-1111-111111111111",
        task_id: "P1-1",
        status: "in_progress",
        hot_files: ["Sources/Audio/Scheduler.swift"],
      }),
    ];

    const conflict = findHotFileConflict(existing, [
      "Sources/Audio/Scheduler.swift",
      "docs/foo.md",
    ]);

    expect(conflict).not.toBeNull();
    expect(conflict?.overlapping).toEqual(["Sources/Audio/Scheduler.swift"]);
  });

  it("ignores completed builds", () => {
    const existing = [
      build({
        id: "11111111-1111-1111-1111-111111111111",
        task_id: "P1-1",
        status: "completed",
        hot_files: ["Sources/Audio/Scheduler.swift"],
      }),
    ];

    expect(findHotFileConflict(existing, ["Sources/Audio/Scheduler.swift"])).toBeNull();
  });

  it("allows non-overlapping hot files", () => {
    const existing = [
      build({
        id: "11111111-1111-1111-1111-111111111111",
        task_id: "P1-1",
        status: "requested",
        hot_files: ["Sources/Audio/Scheduler.swift"],
      }),
    ];

    expect(findHotFileConflict(existing, ["Sources/Sync/Clock.swift"])).toBeNull();
  });

  it("skips lock check when requested hot files are empty", () => {
    const existing = [
      build({
        id: "11111111-1111-1111-1111-111111111111",
        task_id: "P1-1",
        status: "requested",
        hot_files: ["Sources/Audio/Scheduler.swift"],
      }),
    ];

    expect(findHotFileConflict(existing, [])).toBeNull();
  });
});
