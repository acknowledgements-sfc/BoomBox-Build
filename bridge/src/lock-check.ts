import type { BridgeBuild, HotFileConflict } from "./types.js";
import { ACTIVE_STATUSES } from "./types.js";

export function normalizeHotFiles(files: string[] | undefined): string[] {
  if (!files || files.length === 0) {
    return [];
  }
  const seen = new Set<string>();
  const normalized: string[] = [];
  for (const file of files) {
    const trimmed = file.trim();
    if (trimmed.length === 0 || seen.has(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    normalized.push(trimmed);
  }
  return normalized;
}

export function arraysOverlap(a: string[], b: string[]): string[] {
  if (a.length === 0 || b.length === 0) {
    return [];
  }
  const setB = new Set(b);
  return a.filter((item) => setB.has(item));
}

export function findHotFileConflict(
  existing: Pick<BridgeBuild, "id" | "task_id" | "status" | "hot_files">[],
  requested: string[],
): HotFileConflict | null {
  const normalized = normalizeHotFiles(requested);
  if (normalized.length === 0) {
    return null;
  }

  for (const build of existing) {
    if (!ACTIVE_STATUSES.includes(build.status as (typeof ACTIVE_STATUSES)[number])) {
      continue;
    }
    const overlapping = arraysOverlap(normalized, build.hot_files);
    if (overlapping.length > 0) {
      return {
        id: build.id,
        task_id: build.task_id,
        hot_files: build.hot_files,
        overlapping,
      };
    }
  }

  return null;
}

export function formatHotFileConflictError(conflict: HotFileConflict): string {
  return `Hot-file conflict with build ${conflict.id} (task ${conflict.task_id}): overlapping files: ${conflict.overlapping.join(", ")}`;
}
